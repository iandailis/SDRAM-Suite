/* Created by Ian Dailis */
/* Last Edited: August 2022 */
module dma_controller (
	input logic Clk, Reset,
	input logic Direction, /* 0 is JTAG --> SDRAM, 1 is SDRAM --> JTAG */
	input logic Act, /* begin and continue an action in the specificed direction */

	/* SDRAM Signals */
	input logic [15:0] sdram_Dout,
	output logic [15:0] sdram_Din,
	output logic [24:0] sdram_Addr,
	input logic sdram_R,
	output logic sdram_Clk, sdram_Reset, sdram_WE, sdram_Focus,

	/* JTAG UART Signals */
	input logic [7:0] jtag_Dout,
	output logic [7:0] jtag_Din,
	input logic jtag_R, jtag_A,
	output logic jtag_Clk, jtag_Reset, jtag_WE, jtag_Act
);

logic [25:0] dma_addr;
logic inc_addr;

logic stable_jtag_A;
logic [15:0] count;

logic [7:0] lower;

enum logic [1:0] {
	DMA_BURST,
	Check
} curr_state;

always_ff @ (posedge Clk) begin

	/* saving the bottom 8 bits for the next cycle 
	   which will write the top 8 bits */
	if (dma_addr[0] == 0) begin
		lower <= jtag_Dout;
	end

	/* make sure the A signal is actually stable before using
	   as the signals are not always correct */
	if (stable_jtag_A != jtag_A) begin
		count <= count + 16'h1;
		if (count == 16'hFFFF) begin
			stable_jtag_A <= jtag_A;
		end
	end else begin
		count <= 0;
	end

	case (curr_state)
		DMA_BURST: begin
			/* increment the address 1 clock cycle after a jtag action */
			if (jtag_Act) begin
				inc_addr <= 1'b1;
			end else if (inc_addr) begin
				dma_addr <= dma_addr + 26'd1;
				inc_addr <= 1'b0;
			end
			/* return to Check when the action signal is lowered */
			if (!Act) begin
				curr_state <= Check;
			end
		end
		Check : begin
			dma_addr <= 26'h0;
			/* upon an action, begin bursting */
			if (Act && sdram_R) begin
				curr_state <= DMA_BURST;
			end
		end
		default : begin
			curr_state <= Check;
		end
	endcase
end

always_comb begin
	jtag_Clk = Clk;
	jtag_Reset = Reset;
	jtag_Act = 1'b0;
	jtag_WE = 1'b0;

	sdram_Clk = Clk;
	sdram_Reset = Reset;
	sdram_Addr = 25'h0;
	sdram_WE = 1'b0;

	/* write the lower vs the upper 8 bits during a burst */
	case (dma_addr[0])
		1'b0 : begin
			sdram_Din = {8'h0, jtag_Dout};
			jtag_Din = sdram_Dout[7:0];
		end
		1'b1 : begin
			sdram_Din = {jtag_Dout, lower};
			jtag_Din = sdram_Dout[15:8];
		end
	endcase

	sdram_Focus = 1'b0;
	case (curr_state)
		DMA_BURST : begin
			/* the burst logic is bidirectional, the Direction signal 
			   differentiates a read vs a write burst */
			jtag_WE = Direction;
			sdram_WE = ~Direction;

			sdram_Addr = dma_addr[25:1];
			if (jtag_A & jtag_R & sdram_R) begin
				jtag_Act = 1'b1;
			end
		end
		Check : begin
			/* when the SDRAM is ready and action is asserted, begin the burst */
			if (Act && stable_jtag_A && sdram_R) begin
				jtag_Act = 1'b1;
			end
		end
	endcase
end

endmodule
