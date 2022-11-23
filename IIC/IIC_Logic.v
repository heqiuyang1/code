module IICSlaveCore_V11(input[6:0] slaveAddress, output reg read, output reg write, output reg[7:0] dataAddress, 
                   output reg isStart, output reg isStop, output[7:0] writeDataBus, input[7:0] readDataBus, input resetN, 
                   output sdaToBus, output enableInterfaceOutput, input sclFromBus, input sdaFromBus);

  parameter maxDataAddress = 8'hFF;

  parameter status_Idle                    = 3'b000,
	          status_ReceiveDeviceAddress    = 3'b001,
	          status_ReceiveRegisterAddressH = 3'b011,
	          status_ReceiveRegisterAddressL = 3'b010,
	          status_ReceiveData             = 3'b110,
	          status_SendData                = 3'b101;
  reg[7:0] buffer;
  reg[3:0] counter;
  reg[2:0] status;
  reg lastReceiveBit, shouldIncAddress;
  wire sender, receiver, ackPhase, bitNeedToSend, meetSlaveAddress, sdaToBus2;

  assign sender = status == status_SendData;
  assign receiver = status == status_ReceiveDeviceAddress ||
                    status == status_ReceiveRegisterAddressL ||
                    status == status_ReceiveData;
  assign ackPhase = counter == 4'hF;
  assign bitNeedToSend = ~ackPhase & buffer[counter];
  assign sdaToBus2 = ~((sender && !ackPhase) || (receiver && ackPhase)) | bitNeedToSend;
  assign sdaToBus = sdaToBus2 | (status == status_ReceiveDeviceAddress && !meetSlaveAddress);

  assign meetSlaveAddress = slaveAddress == buffer[7:1];
  assign writeDataBus = buffer;
  assign enableInterfaceOutput = status != status_Idle;

  always@(posedge sclFromBus, negedge resetN)
    if(!resetN) lastReceiveBit <= 0; 
    else lastReceiveBit <= sdaFromBus;

//  reg isStart,isStop;
  assign resetStartStop = !sclFromBus || !resetN;
  always@(negedge sdaFromBus, posedge resetStartStop) 
    if(resetStartStop) isStart <= 0;
    else isStart <= sclFromBus;
  always@(posedge sdaFromBus, posedge resetStartStop) 
    if(resetStartStop) isStop <= 0;
    else isStop <= sclFromBus;
  
  always@(negedge sclFromBus, negedge resetN) begin
    if(!resetN) begin
      dataAddress <= 0;
      status <= status_Idle;
      buffer <= 0;
      counter <= 4'h8;
      read <= 0;
      write <= 0;
      shouldIncAddress <= 0;
    end /* End of if(!resetN) */
    else begin
      if(isStart || isStop) begin
        counter <= 4'h7; 
        read <= 0;
        write <= 0;
	    buffer <= 0;
        shouldIncAddress <= 0;
        status <= isStart ? status_ReceiveDeviceAddress : status_Idle;
      end /* End of if(isStart || isStop) */
      else begin
        if(status != status_Idle) counter <= (counter == 4'hF)? 4'h7:(counter - 1);
        if(read) buffer <= readDataBus;
        else if(receiver) buffer[counter] <= lastReceiveBit; 
        read  <= (counter == 4'h0 && (status == status_SendData || (status == status_ReceiveDeviceAddress && lastReceiveBit && meetSlaveAddress)));
	    write <= (counter == 4'h0 && (status == status_ReceiveData));
	    if(counter == 4'h7 && shouldIncAddress) begin
	      shouldIncAddress <= 0;
//	      dataAddress <= dataAddress + shouldIncAddress;
	      dataAddress <= dataAddress + ((dataAddress < maxDataAddress) ? shouldIncAddress : 1'b0);
	    end
	    else if(ackPhase) begin
          if(status == status_ReceiveDeviceAddress) begin
            if(!meetSlaveAddress) status <= status_Idle;    
	        else status <= buffer[0] ? status_SendData : status_ReceiveRegisterAddressL;
	      end
          if(status == status_ReceiveRegisterAddressL) begin
	        status <= status_ReceiveData;
	        dataAddress[7:0] <= buffer;
          end
          if(status == status_SendData && lastReceiveBit) status <= status_Idle;

          if(status == status_ReceiveData || status == status_SendData ||  (status == status_ReceiveDeviceAddress && buffer[0] && meetSlaveAddress)) 
            shouldIncAddress <= 1;
        end /* End of if(ackPhase) */

      end /* End of else (isStart || isStop) */
    end /* End of else (!resetN) */
  end /* End of always */
endmodule
