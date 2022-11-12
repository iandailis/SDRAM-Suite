/* Created by Ian Dailis */
/* Last Edited: August 2022 */
module dma_controller (
	input logic Clk, Reset,
	input logic Direction, /* 0 is JTAG --> SDRAM, 1 is SDRAM --> JTAG */

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

logic [7:0] lower;
logic start;
logic ready;

logic last_direction;

enum logic [1:0] {
	DMA_BURST,
	Check
} curr_state;

always_ff @ (posedge Clk) begin

	last_direction <= Direction;
	if (Direction != last_direction) begin
		dma_addr <= '0;
		start <= 1'b0;
	end

	/* saving the bottom 8 bits for the next cycle 
	   which will write the top 8 bits */
	if (dma_addr[0] == 0) begin
		lower <= jtag_Dout;
	end

	if (ready) begin
		start <= 1'b1;
	end

	inc_addr <= jtag_Act & start;
	if (inc_addr) begin
		dma_addr <= dma_addr + 26'd1;
		inc_addr <= 1'b0;
	end

end

always_comb begin
	ready = jtag_A & jtag_R & sdram_R;

	jtag_Clk = Clk;
	jtag_Reset = Reset;
	jtag_Act = ready && (~Direction || (Direction && start));
	jtag_WE = Direction;

	sdram_Clk = Clk;
	sdram_Reset = Reset;
	sdram_Addr = dma_addr[25:1];
	sdram_WE = ~Direction & (start || jtag_A);
	sdram_Focus = 1'b0;

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
end

endmodule
