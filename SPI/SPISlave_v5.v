`include "SPISlaveCore_H3.v"
`include "SPIModeSet.v"

module SPISlave_v5(
	spi_clk,
	CPHA,
	CPOL,
	cs,
	MOSI,
	restN,
	readDataBus,
	MISO,
	read,
	write,
	RegisterAddrs,
	writeDataBus
);


input wire	spi_clk;
input wire	CPHA;
input wire	CPOL;
input wire	cs;
input wire	MOSI;
input wire	restN;
input wire	[7:0] readDataBus;
output wire	MISO;
output wire	read;
output wire	write;
output wire	[7:0] RegisterAddrs;
output wire	[7:0] writeDataBus;

wire	WIRE_CNT;
wire	WIRE_CLK;


SPIModeSet	b2v_u1(
	.spi_clk(spi_clk),
	.CPHA(CPHA),
	.CPOL(CPOL),
	.counter(WIRE_CNT),
	.clk(WIRE_CLK));


SPISlaveCore_H3	b2v_u2(
	.CPHA(WIRE_CNT),
	.resetN(restN),
	.cs(cs),
	.spiClk(WIRE_CLK),
	.MOSI(MOSI),
	.readDataBus(readDataBus),
	.read(read),
	.write(write),
	.MISO(MISO),
	.dataAddress(RegisterAddrs),
	.writeDataBus(writeDataBus));
	


endmodule
