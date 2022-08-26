/* Created by Ian Dailis */
/* Last Edited: August 2022 */
module jtag_controller(
	input logic Clk, Reset,
	input logic Act, WE,
	output logic R, A,
	input logic [7:0] Din,
	output logic [7:0] Dout
);

/* How does this work:

	Upon an Act (Action), the jtag controller will attempt to do one
	read or write, depending upon WE (Write Enable).

	R tells the user whether the jtag is ready for an operation.
	
	A tells the user whether the jtag has any data available to read,
	or has space available to write, depending upon WE.

	jtag_dataavailable and jtag_readyfordata are trash signals.
	They are not always correct. Thus, they should be taken with
	a grain of salt, and must be stabilized.

*/

/* JTAG INPUTS */
logic jtag_clk;
logic jtag_chipselect;
logic [31:0] jtag_address;
logic jtag_read_n;
logic jtag_write_n;
logic [31:0] jtag_writedata;
logic jtag_reset_n;

/* JTAG OUTPUTS */
logic jtag_irq;
logic [31:0] jtag_readdata;
logic jtag_waitrequest;
logic jtag_dataavailable, jtag_readyfordata;

logic stable; /* stablizer for jtag_readyfordata */

always_ff @ (posedge Clk) begin
	/* when the command is acknowledged */
	if (!jtag_waitrequest) begin
		/* when the readdata is valid */
		if (jtag_readdata[15]) begin
			Dout <= jtag_readdata[7:0];
		end
		stable <= 1'b0;
	end else begin
		stable <= 1'b1;
	end
end

always_comb begin
	jtag_clk = Clk;
	jtag_chipselect = 1'b1;
	jtag_reset_n = 1'b1;

	jtag_address = 32'h0;

	jtag_writedata = Din;

	/* Either read or write. Not both at the same time. */
	jtag_write_n = ~(Act & WE);
	jtag_read_n = ~(Act & ~WE);

	R = jtag_waitrequest;

	/* 
		Set A to a different signal depending upon 
		whether the user is reading or writing 
	*/
	case (WE)
		1'b0 : begin
			A = jtag_dataavailable;
		end
		1'b1 : begin
			A = jtag_readyfordata & stable;
		end
	endcase
end

jtag_uart jtag (
	// inputs:
	.av_address(jtag_address),
	.av_chipselect(jtag_chipselect),
	.av_read_n(jtag_read_n),
	.av_write_n(jtag_write_n),
	.av_writedata(jtag_writedata),
	.clk(jtag_clk),
	.rst_n(jtag_reset_n),

	// outputs:
	.av_irq(jtag_irq),
	.av_readdata(jtag_readdata),
	.av_waitrequest(jtag_waitrequest),
	.dataavailable(jtag_dataavailable),
	.readyfordata(jtag_readyfordata) 
);

endmodule