/* Created by Ian Dailis */
/* Last Edited: August 2022 */
module ian_sdram (
	input logic Clk, Reset,
	input logic [24:0] Addr,
	input logic [15:0] Din,
	output logic [15:0] Dout,
	input logic WE, /* Write Enable for SDRAM */

	
	input logic Focus, /* Stops SDRAM refresh cycles while asserted.
	                      Useful for time-sensitive bursts. May
	                      corrupt SDRAM if asserted for too long. */ 
	input logic Direction, /* JTAG Transfer direction. 
	                          0 is JTAG --> SDRAM, 1 is SDRAM --> JTAG */
	input logic Act, /* JTAG Action to begin and continue a transfer. */
	output logic R, /* SDRAM Read/Write ready signal. */ 

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

logic [15:0] sdram_Dout;
logic [15:0] sdram_Din;
logic [24:0] sdram_Addr;
logic sdram_Focus, sdram_WE, sdram_Clk, sdram_Reset;
logic sdram_R;

logic [15:0] dma_sdram_Dout;
logic [15:0] dma_sdram_Din;
logic [24:0] dma_sdram_Addr;
logic dma_sdram_R;
logic dma_sdram_Focus, dma_sdram_WE, dma_sdram_Clk, dma_sdram_Reset;

logic [7:0] jtag_Din, jtag_Dout;
logic jtag_Clk, jtag_Reset;
logic jtag_Act, jtag_WE, jtag_R, jtag_A;

always_comb begin
	sdram_Clk = dma_sdram_Clk;
	sdram_Reset = dma_sdram_Reset;

	Dout = sdram_Dout;
	R = sdram_R;

	dma_sdram_Dout = sdram_Dout;
	dma_sdram_R = sdram_R;
	case (Act)
		/* when no JTAG action, user can access SDRAM */
		1'b0 : begin
			sdram_Din = Din;
			sdram_Addr = Addr;
			sdram_Focus = Focus;
			sdram_WE = WE;
		end
		/* when the JTAG is doing a transfer, use the DMA signals */
		1'b1 : begin
			sdram_Din = dma_sdram_Din;
			sdram_Addr = dma_sdram_Addr;
			sdram_Focus = dma_sdram_Focus;
			sdram_WE = dma_sdram_WE;
		end
	endcase
end

dma_controller dma (
	.Clk(Clk),
	.Reset(Reset),
	.Direction(Direction),
	.Act(Act),

	.sdram_Dout(dma_sdram_Dout),
	.sdram_Din(dma_sdram_Din),
	.sdram_Addr(dma_sdram_Addr),
	.sdram_R(dma_sdram_R),
	.sdram_Clk(dma_sdram_Clk),
	.sdram_Reset(dma_sdram_Reset),
	.sdram_WE(dma_sdram_WE),
	.sdram_Focus(dma_sdram_Focus),

	.jtag_Dout(jtag_Dout),
	.jtag_Din(jtag_Din),
	.jtag_R(jtag_R),
	.jtag_A(jtag_A),
	.jtag_Clk(jtag_Clk),
	.jtag_Reset(jtag_Reset),
	.jtag_WE(jtag_WE),
	.jtag_Act(jtag_Act)
);

jtag_controller jtag (
	.Act(jtag_Act),
	.WE(jtag_WE),
	.R(jtag_R),
	.A(jtag_A),
	.Clk(jtag_Clk), 
	.Reset(jtag_Reset),
	.Din(jtag_Din),
	.Dout(jtag_Dout)
);

sdram_controller sdram (
	.Clk(sdram_Clk),
	.Reset(sdram_Reset), 
	.Din(sdram_Din), 
	.Dout(sdram_Dout),
	.WE(sdram_WE),
	.Addr(sdram_Addr),

	.Focus(sdram_Focus),
	.R(sdram_R),
	.*
);

endmodule
