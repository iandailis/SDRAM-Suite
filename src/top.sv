module top (
	input logic MAX10_CLK1_50,
	
	/* DE-10 I/O */
	input logic [1:0] KEY,	// top button is KEY[0], bottom button is KEY[1]. active low (low when pressed).
	input logic [9:0] SW,
	output logic [9:0] LEDR,
	
	/* HEX */
	output logic [7:0] HEX0,
	output logic [7:0] HEX1,
	output logic [7:0] HEX2,
	output logic [7:0] HEX3,
	output logic [7:0] HEX4,
	output logic [7:0] HEX5,
	
	/* SDRAM */	
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
	output logic DRAM_WE_N,	
	
	/* I/O BOARD */
	// inout logic [15:0] ARDUINO_IO,
	// inout logic ARDUINO_RESET_N,
	
	/* VGA OUTPUT logic */
	output logic [3:0] VGA_R,
	output logic [3:0] VGA_G,
	output logic [3:0] VGA_B,
	output logic VGA_HS,
	output logic VGA_VS
);

logic [1:0] key_sync;
logic [9:0] sw_sync;
logic [23:0] hex_in;

logic ian_Clk, ian_Reset;
logic [24:0] ian_Addr;
logic [15:0] ian_Din;
logic [15:0] ian_Dout;
logic ian_WE, ian_Focus, ian_Direction, ian_Act;
logic ian_R;

logic image_Clk;
logic [24:0] image_sdram_Addr;
logic [15:0] image_sdram_Dout;
logic image_sdram_R;
logic image_sdram_Focus;

always_comb begin
	ian_Clk = MAX10_CLK1_50;
	ian_Reset = ~key_sync[0];
	ian_Addr = image_sdram_Addr;
	ian_Din = sw_sync[7:0];
	ian_WE = sw_sync[8];
	ian_Focus = image_sdram_Focus;
	ian_Direction = sw_sync[9];
	ian_Act = ~key_sync[1];
end

always_comb begin
	image_Clk = MAX10_CLK1_50;
	image_sdram_Dout = ian_Dout;
	image_sdram_R = ian_R;
end

always_comb begin
	hex_in = {ian_Addr[15:0], ian_Dout[7:0]};
	LEDR[9] = ian_R;
	LEDR[8] = ian_Focus;
	LEDR[7:0] = sw_sync[7:0];
end

sync sync_KEY [1:0] (.clk(MAX10_CLK1_50), .in(KEY), .out(key_sync));
sync sync_SW [9:0] (.clk(MAX10_CLK1_50), .in(SW), .out(sw_sync));

Hex_Driver Hex_Driver [5:0] (
	.in  (hex_in),
	.dp  ({1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}),
	.out ({HEX5, HEX4, HEX3, HEX2, HEX1, HEX0})
);

sdram_image image (
	.Clk         (image_Clk),
	.sdram_Addr  (image_sdram_Addr),
	.sdram_Dout  (image_sdram_Dout),
	.sdram_R     (image_sdram_R),
	.sdram_Focus (image_sdram_Focus),
	/* the clock's slack is really bad, so this number is arbitrary but it works ok */
	.delay       (9'd15), 
	.*
);

ian_sdram ian (
	.Clk       (ian_Clk),
	.Reset     (ian_Reset),
	.Addr      (ian_Addr),
	.Din       (ian_Din),
	.Dout      (ian_Dout),
	.WE        (ian_WE),
	.Focus     (ian_Focus),
	.Direction (ian_Direction),
	.Act       (ian_Act),
	.R         (ian_R),
	.*
);

endmodule
