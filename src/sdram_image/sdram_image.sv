/* Created by Ian Dailis */
/* Last Edited: August 2022 */
module sdram_image (
	input logic Clk, /* 50 MHz */

	/* SDRAM Signals */
	output logic [24:0] sdram_Addr,
	input logic [15:0] sdram_Dout,
	input logic sdram_R,
	output logic sdram_Focus,

	/* Delay before bursting into the VRAM */
	input logic [8:0] delay,

	/* VGA Signals */
	output logic [3:0] VGA_R,
	output logic [3:0] VGA_G,
	output logic [3:0] VGA_B,
	output logic VGA_HS,
	output logic VGA_VS
);

/* VGA Controller Signals */
logic vga_clk;
logic [9:0] DrawX, DrawY;
logic v_blank, h_blank;

/* VRAM Signals */
logic [11:0] vram_data;
logic [8:0] vram_rdaddress;
logic vram_rdclock;
logic [8:0] vram_wraddress;
logic vram_wrclock;
logic vram_wren;
logic [11:0] vram_q;

logic burst;
logic [19:0] index;
logic blank;
assign blank = !(v_blank | h_blank);

/* focus the SDRAM while drawing */
assign sdram_Focus = blank; 

/* set the colors */
always_ff @ (posedge vga_clk) begin
	VGA_R <= 4'h0;
	VGA_G <= 4'h0;
	VGA_B <= 4'h0;
	if (blank) begin
		VGA_R <= vram_q[11:8];
		VGA_G <= vram_q[7:4];
		VGA_B <= vram_q[3:0];
	end
end

always_ff @ (posedge Clk) begin

	/* reset the address at the bottom of the screen */
	if (DrawY == 10'd480 && DrawX == 10'd0) begin
		sdram_Addr <= 0;

	/* increment the address when bursting */
	end else if (burst) begin
		sdram_Addr <= sdram_Addr + 25'd1;
	end

end

always_comb begin
	vram_rdclock = vga_clk;

	/* set the index into the image */
	if (blank) begin
		index = DrawX + (DrawY*10'd640);

	/* set the index to the next line when out of bounds */
	end else begin
		index = (DrawY+10'd1)*10'd640;
	end

	vram_rdaddress = index[8:0];

	vram_wrclock = Clk;

	/* CAS latency = 2, so the address must be offset by 2 */
	vram_wraddress = sdram_Addr[8:0]-9'd2;

	vram_data = sdram_Dout[11:0];
	vram_wren = 1'b1;

	burst = 1'b0;
	case (v_blank)
		1'b0 : begin
			/* burst when the index begins approaching the SDRAM address */
			if (index > sdram_Addr - delay && sdram_R) begin
				burst = 1'b1;
			end
		end
		1'b1 : begin
			/* burst to prepare the first line */
			if (sdram_Addr < delay && sdram_R) begin
				burst = 1'b1;
			end
		end
	endcase
end

PLL_VGA_CLK PLL_VGA_CLK (
	.inclk0 (Clk),
	.c0     (vga_clk)
);

VGA_Controller VGA_Controller (
	.vga_clk (vga_clk),
	.Reset   (),
	.hs      (VGA_HS),
	.vs      (VGA_VS),
	.v_blank (v_blank),
	.h_blank (h_blank),
	.DrawX   (DrawX),
	.DrawY   (DrawY)
);

ram vram (
	.data      (vram_data),
	.rdaddress (vram_rdaddress),
	.rdclock   (vram_rdclock),
	.wraddress (vram_wraddress),
	.wrclock   (vram_wrclock),
	.wren      (vram_wren),
	.q         (vram_q)
);

endmodule
