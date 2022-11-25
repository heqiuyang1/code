//compare with H2, can clear the address and data at negedge cs;
module SPISlaveCore_H3(
	input CPHA,
	input reg [7:0] readDataBus,
	input spiClk,
	input cs,
	input MOSI,
	input resetN,
	output reg read,
	output write,
	output [7:0] writeDataBus,
	output reg [7:0] dataAddress,
	output MISO
);

localparam maxDataAddress = 8'hFF;

localparam  	statusIdle 		  = 4'b0000,
	        statusReceiveCommand      = 4'b0001,
	        statusReceiveDataAddressL = 4'b0011,
	        statusReceiveData         = 4'b0100,
	        statusReceiveData1        = 4'b0101,
	        statusSendData            = 4'b0110,
	        statusSendData1           = 4'b0111,
	        statusErr                 = 4'b1000,

	        commandRead              = 3'b110,
	        commandWrite             = 3'b101,
	        commandErr               = 3'b011;

reg [7:0] slaveSendBuffer,slaveReceivedBuffer;
reg [3:0] status;
reg [2:0] posCnt,negCnt,negCnt1,command;

reg MISO1,isStart1,isStart2,shouldIncAddress;

wire [3:0] nextStatus;
wire isStart,clearFlag,workStatus;
wire ackPhase,changeStatus;
//wire CPOL; 
//assign CPOL = cs & spiClk;

//wire receiveStatus;
//assign receiveStatus = (status == statusReceiveCommand) | (status == statusReceiveAddressL) | (status == statusReceiveData) | (status == statusReceiveData1);
assign writeDataBus = slaveReceivedBuffer;

assign isStart = isStart1 ^ isStart2;
assign workStatus = isStart1 | isStart2;
assign clearFlag = ~(cs | workStatus) | ~resetN;

assign ackPhase = (posCnt & negCnt & negCnt1) == 3'h7;
assign changeStatus = (isStart | ackPhase) & !cs &resetN;
assign write = changeStatus & status == statusReceiveData;
assign MISO = read?readDataBus[7] : MISO1; 

assign nextStatus =     (!resetN || cs)? statusReceiveCommand:
			(status == statusIdle)? statusReceiveCommand:
			(status == statusReceiveCommand)? statusReceiveDataAddressL:
			(status == statusReceiveDataAddressL)? ((command == commandRead)? statusSendData1: (command == commandWrite)?statusReceiveData1: statusErr):
			(status == statusSendData1)? statusSendData:
			(status == statusReceiveData1)?statusReceiveData:
			(status == statusSendData)?statusSendData:
			(status == statusReceiveData)? statusReceiveData:
			(status == statusErr)?statusErr:statusIdle;

//contribute start single
always@(posedge spiClk, negedge resetN, posedge cs) begin
	if(!resetN) isStart1 <= 1'b0;
	else if(cs) isStart1 <= 1'b0;
	else isStart1 <= 1'b1;
end

always@(negedge spiClk, negedge resetN, posedge cs) begin
	if(!resetN) isStart2 <= 1'b0;
	else if(cs) isStart2 <= 1'b0;
	else isStart2 <= 1'b1;
end

//read data from RAM
always@(posedge spiClk, negedge resetN, posedge cs) begin
	if(!resetN) slaveSendBuffer <= 8'h0;
	else if(cs) slaveSendBuffer <= 8'h0;
	else if(read) slaveSendBuffer <= readDataBus;
end

//change status
always@(negedge resetN, posedge cs, posedge changeStatus) begin
	if(!resetN) status <= statusIdle;
	else if(cs) status <= statusIdle;
	else if(changeStatus) status <= nextStatus;
end

//posedge clk is spi slave receive data
always@(posedge spiClk, negedge resetN, posedge cs)begin
	if(!resetN) posCnt <= 3'h7;
	else if(cs) posCnt <= 3'h7;
	else posCnt <= (posCnt == 3'h0)?3'h7 : (posCnt - 1'b1);
end

always@(posedge spiClk, negedge resetN, posedge clearFlag)begin
	if(!resetN) slaveReceivedBuffer <= 8'h0;
	else if(clearFlag) slaveReceivedBuffer <= 8'h0;
	else slaveReceivedBuffer[posCnt] <= MOSI;
end

always@(negedge spiClk, negedge resetN, posedge clearFlag)begin
	if(!resetN) begin
		dataAddress <= 8'h0;
		shouldIncAddress <= 1'b0;
	end
	else if(clearFlag) begin
		dataAddress <= 8'h0;
		shouldIncAddress <= 1'b0;
	end
	else begin
		if(posCnt == 8'h7) begin
			if(status == statusReceiveCommand) dataAddress <= 8'h0;
			else if(status == statusReceiveData1 || status == statusSendData1) dataAddress <= slaveReceivedBuffer;				
		end
		
		if(posCnt == 3'h4 &&  status == statusReceiveData || status == statusSendData || status == statusSendData1) shouldIncAddress <= 1'b1;
		if(posCnt ==3'h3 && (status == statusReceiveData || status == statusSendData || statusSendData1)) begin
				shouldIncAddress <= 1'b0;
				dataAddress <= dataAddress + ((dataAddress < maxDataAddress)? shouldIncAddress : 1'b0);
		end
	end	
end

//negedge clk is spi slave send data
always@(negedge spiClk, negedge resetN, posedge cs) begin
	if(!resetN) begin
		read <= 1'b0;
		command <= 3'b111;
		negCnt <= 3'h6;
		negCnt1 <= 3'h7;
		MISO1 <= 1'b0;
	end else if(cs) begin
		read <= 1'b0;
		command <= 3'b111;
		negCnt <= 3'h6;
		negCnt1 <= 3'h7;
		MISO1 <= 1'b0;
	end else begin
		if(CPHA) begin
			negCnt <= (negCnt == 3'h0)? 3'h7 : (negCnt - 1'b1);	// diff the CPHA
			negCnt1 <= 3'h7;
		end else begin 
			negCnt1 <= (negCnt1 == 3'h0)? 3'h7 : (negCnt1 - 1'b1);
			negCnt <= 3'h7;
		end
		
		if((status == statusSendData || status == statusSendData1)) begin
			if(posCnt == 3'h7) read <= 1'b1;
			else begin 
				read <= 1'b0;
				MISO1 <= slaveSendBuffer[posCnt];	
			end
		end
		
		if(posCnt == 3'h7 && status == statusReceiveDataAddressL) command <= slaveReceivedBuffer;
	end
end

endmodule

