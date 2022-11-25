module SPIModeSet(
	input spi_clk,
	input CPHA,
	input CPOL,
	output counter,
	output clk
);

assign clk = (CPHA^CPOL)?~spi_clk:spi_clk;
assign counter = ~CPHA;

endmodule
