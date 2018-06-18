// модуль передачи байта по протоколу RMII
// частота тактового сигнала 100МГц

module rmii_tx
(	input clk,
	input rst,
	input [7:0]dataIn,		// данные для передачи
	input [15:0]dataLen,	// количество байт для передачи
	input start, 			// начать передачу
	output reg getByte,		// запрос сед. байта
	output ready,			// признак окончания передачи
	output [1:0]dataOut,	// данные на rmii
	output reg TXEN,		// включение передатчика rmii
	output [15:0]numByteSend);	// номер текущего передаваемого байта

// 50МГц для интерфейса
reg clkDev2 /*verilator public*/;
always @(posedge clk, posedge rst)
if(rst)
	clkDev2 <= 0;
else
	clkDev2 <= ~clkDev2;

// байт для передачи
reg [7:0]dataTransmit /*verilator public*/;

// два младших бита для передачи
assign dataOut = dataTransmit[1:0];

// машина состояний
reg [1:0]state  /*verilator public*/;
parameter idle		= 2'b00;
parameter send		= 2'b01;

reg [4:0]countBitSend /*verilator public*/; //счетчик переданных бит
reg [15:0]countByteSend /*verilator public*/; //счетчик переданных байт
reg [15:0]lenByteSend; // хранимое значение размера пакета

assign numByteSend = countByteSend;

// в режиме простоя на выход - 1
// в режиме простоя сигн. готовности
assign ready = (state == idle) ? 1:0;

always @(negedge clk, posedge rst)
if(rst)
begin
	dataTransmit <= 0;
	countBitSend <= 0;
	TXEN <= 0;
	state <= idle;
	countByteSend <= 0;
	lenByteSend <= 0;
	getByte <= 0;
end
else
begin
	if(clkDev2)
	begin
		case(state)
		idle:
		begin
			if(start)
			begin // записать данные в буфер
				countByteSend <= 1;
				lenByteSend <= dataLen;
				dataTransmit <= dataIn;
				state <= send;
				TXEN <= 1;
				countBitSend <= 0;
			end
			else
				TXEN <= 0;
		end
		
		send: // режим передачи
		begin
			if(countBitSend == 2)
				getByte <= 1;
			else
				getByte <= 0;
				
			if(countBitSend < 3)
			begin
				dataTransmit <= dataTransmit >> 2;
				countBitSend <= countBitSend + 1;
			end
			else if(countBitSend == 3)
			begin
				dataTransmit <= dataIn;
				countBitSend <= 0;
				countByteSend <= countByteSend + 1;
				if(countByteSend >= lenByteSend) // если переданы все байты
				begin
					state <= idle;
					TXEN <= 0;
				end
			end
		end
		endcase
	end
end

endmodule

