/* Created by Ian Dailis */
/* Last Edited: August 2022 */
module sdram_controller(
	input logic Clk, Reset, WE, /* Active High */
	input logic Focus,        /* Force Reads/Writes past periodic refreshes */
	input logic [24:0] Addr,
	input logic [15:0] Din,
	output logic [15:0] Dout,
	output logic R,           /* Controller ready to accept Reads/Writes */

	/* SDRAM Pins */
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA,
	output logic DRAM_CAS_N,
	output logic DRAM_CLK,
	output logic DRAM_CKE,
	output logic DRAM_CS_N,
	inout [15:0] DRAM_DQ, /* PROD */
	// logic [15:0] DRAM_DQ, /* SIMULATION */
	output logic DRAM_LDQM,
	output logic DRAM_RAS_N,
	output logic DRAM_UDQM,
	output logic DRAM_WE_N
);

/* How does this work:

	The controller has two states: Read_Write, and Exec.
	
	Read_Write is the default state, which allows reading
	and writing to the SDRAM. During Read_Write, the RW 
	command is continuously sent to the SDRAM.

	Exec is the state for running programs to manage the SDRAM,
	such as initialization, selecting a new row/bank, and
	refreshing.
	
	Each program is made up of multiple operations, depending
	upon the task which needs to be done. All programs end with 
	an Activate operation.
	
	Each operation is made up of multiple commands. Some commands
	require multiple clock cycles to complete, so the operations
	have NOP commands to give the SDRAM time. All operations end
	with a DESL command (which is never actually sent to the SDRAM,
	it is just used for branching).
	
	During an Exec, the program counter increments every clock cycle
	through each command in a given operation.

*/

/* Must refresh 8192 times every 64 ms */
/* clk_freq * max_time = refresh_delay */
/* 50,000,000 hz * 0.064 ms / 8192 iterations = 390.625 cycles */
`define refresh_delay 32'd390 /* round down to 390 */

/* locations of each operation in the operation cache */
`define pall_PC 5'd0
`define ref_PC 5'd3
`define mrs_PC 5'd12
`define act_PC 5'd15
`define rw_PC 5'd18

/* locations of each program in the program cache */
`define init_prog 4'd0
`define select_prog 4'd5
`define refresh_prog 4'd7

logic [31:0] time_since_refresh;
logic [14:0] curr_row;
logic [4:0] curr_PC;
logic [3:0] curr_prog;
logic [4:0] prog [16];

enum logic {
	Exec,
	Read_Write
} curr_state;

enum logic [3:0] {
	DESL,     /* Device deselect */
	NOP,      /* No operation */
	BST,      /* Burst stop */ /* unused */
	RW,    	  /* Read/Write */
	RW_AP,    /* Read/Write with auto precharge */ /* unused */
	ACT,      /* Bank activate */
	PRE,      /* Precharge select bank */ /* unused */
	PALL,     /* Precharge all banks */
	REF,      /* CBR Auto-Refresh */
	SELF,     /* Self-Refresh */ /* unused */
	MRS       /* Mode register set */
} curr_op, next_op, instructions[32];

/* timing taken from SDRAM documentation */
assign instructions = '{
	/* 00 */ PALL, /* t_rp = 2 */ /* PRECHARGE */
	/* 01 */ NOP,
	/* 02 */ DESL,

	/* 03 */ REF, /* t_rc = 8 */ /* REFRESH */
	/* 04 */ NOP,
	/* 05 */ NOP,
	/* 06 */ NOP,
	/* 07 */ NOP,
	/* 08 */ NOP,
	/* 09 */ NOP,
	/* 10 */ NOP,
	/* 11 */ DESL,

	/* 12 */ MRS, /* t_mrd = 2 */ /* MODE SELECT */
	/* 13 */ NOP, 
	/* 14 */ DESL,

	/* 15 */ ACT, /* t_rcd = 2 */ /* ACTIVATE */
	/* 16 */ NOP, 
	/* 17 */ DESL,

	/* 18 */ RW, /* RW */
	/* 19 */ DESL,

	/* 20 */ DESL, 
	/* 21 */ DESL,
	/* 22 */ DESL,
	/* 23 */ DESL,
	/* 24 */ DESL,
	/* 25 */ DESL,
	/* 26 */ DESL,
	/* 27 */ DESL,
	/* 28 */ DESL,
	/* 29 */ DESL,
	/* 30 */ DESL,
	/* 31 */ DESL
};

assign prog = '{
	`pall_PC, /* INIT */
	`ref_PC,
	`ref_PC,
	`mrs_PC,
	`act_PC,

	`pall_PC, /* SELECT */
	`act_PC,

	`pall_PC, /* REFRESH */
	`ref_PC,
	`act_PC,

	5'd0,
	5'd0,
	5'd0,
	5'd0,
	5'd0,
	5'd0
};

always_ff @ (posedge DRAM_CLK) begin

	/* refresh timer, maximum count is delay * 8192 */
	if (time_since_refresh < `refresh_delay * 32'd8192) begin
		time_since_refresh <= time_since_refresh + 32'd1;
	end

	if (Reset) begin
		curr_state <= Exec;
		curr_prog <= `init_prog;
		curr_PC <= prog[`init_prog];
		time_since_refresh <= 32'd0;
	end else begin
		case (curr_state)

			Exec : begin
				/* execute the current operation */
				if (next_op != DESL) begin
					curr_PC <= curr_PC + 5'd1;
				
				/* when the operation is finished, go to the next operation */
				end else begin
					/* go the RW when the last operation was an activate */
					if (prog[curr_prog] == `act_PC) begin
						curr_state <= Read_Write;
						curr_PC <= `rw_PC;
						curr_row <= Addr[24:10];
					end else begin
						curr_prog <= curr_prog + 4'd1;
						curr_PC <= prog[curr_prog + 4'd1];
					end
				end
			end

			Read_Write : begin
				/* check if it's time to refresh */
				if (~Focus && time_since_refresh >= `refresh_delay) begin
					curr_state <= Exec;
					curr_prog <= `refresh_prog;
					curr_PC <= prog[`refresh_prog];
					time_since_refresh <= time_since_refresh - `refresh_delay;
				end 
				/* check if we need to select a new row/bank */
				else if (Addr[24:10] != curr_row) begin
					curr_state <= Exec;
					curr_prog <= `select_prog;
					curr_PC <= prog[`select_prog];
				end
			end

			default : begin
				curr_state <= Exec;
				curr_prog <= `init_prog;
				curr_PC <= prog[`init_prog];
				time_since_refresh <= 32'd0;
			end

		endcase
	end
end

always_comb begin
	curr_op = instructions[curr_PC];
	next_op = instructions[curr_PC + 5'd1];
	/* don't read/write if the row is not currently selcted */
	if ((curr_op == RW || curr_op == RW_AP) && Addr[24:10] != curr_row) begin
		curr_op = NOP;
	end

	Dout = DRAM_DQ;

	/* ready for user input only in Read_Write and if the correct row is selected */
	R = (curr_state == Read_Write && Addr[24:10] == curr_row);
end

/* taken from the SDRAM documentation */
/* READ and WRITE are combined into RW */
always_comb begin

	DRAM_CLK = Clk;
	DRAM_UDQM = 1'b0;
	DRAM_LDQM = 1'b0;

	DRAM_ADDR = 13'hX;
	DRAM_BA = 2'hX;
	DRAM_CAS_N = 1'bX;
	DRAM_CKE = 1'bX;
	DRAM_CS_N = 1'bX;
	DRAM_DQ = 16'hZ;
	DRAM_RAS_N = 1'bX;
	DRAM_WE_N = 1'bX;

	case (curr_op)
		DESL : begin
			DRAM_CKE = 1'b1;
			DRAM_CS_N = 1'b1;
		end
		NOP : begin
			DRAM_CKE = 1'b1;
			DRAM_CS_N = 1'b0;
			DRAM_RAS_N = 1'b1;
			DRAM_CAS_N = 1'b1;
			DRAM_WE_N = 1'b1;
		end
		BST : begin
			DRAM_CKE = 1'b1;
			DRAM_CS_N = 1'b0;
			DRAM_RAS_N = 1'b1;
			DRAM_CAS_N = 1'b1;
			DRAM_WE_N = 1'b0;	
		end
		RW : begin
			DRAM_CKE = 1'b1;
			DRAM_CS_N = 1'b0;
			DRAM_RAS_N = 1'b1;
			DRAM_CAS_N = 1'b0;

			DRAM_WE_N = ~WE; /* only this differentiates a Read from a Write */

			if (WE) begin
				DRAM_DQ = Din;
			end

			DRAM_BA = Addr[24:23];
			DRAM_ADDR[9:0] = Addr[9:0];
			DRAM_ADDR[10] = 1'b0;
		end
		RW_AP : begin
			DRAM_CKE = 1'b1;
			DRAM_CS_N = 1'b0;
			DRAM_RAS_N = 1'b1;
			DRAM_CAS_N = 1'b0;

			DRAM_WE_N = ~WE; /* only this differentiates a Read from a Write */

			if (WE) begin
				DRAM_DQ = Din;
			end

			DRAM_BA = Addr[24:23];
			DRAM_ADDR[9:0] = Addr[9:0];
			DRAM_ADDR[10] = 1'b1;
		end
		ACT : begin
			DRAM_CKE = 1'b1;
			DRAM_CS_N = 1'b0;
			DRAM_RAS_N = 1'b0;
			DRAM_CAS_N = 1'b1;
			DRAM_WE_N = 1'b1;

			DRAM_BA = Addr[24:23];
			DRAM_ADDR = Addr[22:10];
		end
		PRE : begin
			DRAM_CKE = 1'b1;
			DRAM_CS_N = 1'b0;
			DRAM_RAS_N = 1'b0;
			DRAM_CAS_N = 1'b1;
			DRAM_WE_N = 1'b0;

			DRAM_BA = Addr[24:23];
			DRAM_ADDR[10] = 1'b0;
		end
		PALL : begin
			DRAM_CKE = 1'b1;
			DRAM_CS_N = 1'b0;
			DRAM_RAS_N = 1'b0;
			DRAM_CAS_N = 1'b1;
			DRAM_WE_N = 1'b0;

			DRAM_ADDR[10] = 1'b1;
		end
		REF : begin
			DRAM_CKE = 1'b1;
			DRAM_CS_N = 1'b0;
			DRAM_RAS_N = 1'b0;
			DRAM_CAS_N = 1'b0;
			DRAM_WE_N = 1'b1;
		end
		SELF : begin
			DRAM_CKE = 1'b1;
			DRAM_CS_N = 1'b0;
			DRAM_RAS_N = 1'b0;
			DRAM_CAS_N = 1'b0;
			DRAM_WE_N = 1'b1;
		end
		MRS : begin
			DRAM_CKE = 1'b1;
			DRAM_CS_N = 1'b0;
			DRAM_RAS_N = 1'b0;
			DRAM_CAS_N = 1'b0;
			DRAM_WE_N = 1'b0;

			DRAM_BA = 2'b0;
			DRAM_ADDR[12:10] = 3'h0;
			/* No Write Burst, X, 2 cycle latency, Sequential, 1 burst length */
			DRAM_ADDR[9:0] = {1'h1, 2'h0, 3'h2, 1'h0, 3'h0};
		end
	endcase
end

endmodule
