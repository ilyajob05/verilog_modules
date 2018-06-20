// модуль приема байта по протоколу UART

module uart_rx #(
parameter T = 9600, // скорость передачи бод
par = 0, // бит четности  0-нет, 1-есть
parType = 0, // тип контроля четности 0-xor
stop = 1, // количество стоп бит
dataLen = 8) // количество информационных битов
(	input clk,
	input rst,
	output reg[dataLen-1:0]data, // выход данных
	output reg ready, 		// готовность данных
	input inData,		// вход данных
	output reg corrupt);	// признак корректности данных

function integer log2;
input integer value;
begin
	for (log2=0; value>0; log2=log2+1)
		value = value>>1;
end
endfunction

// частота тактового сигнала
parameter F_clk_Gz = 100_000_000;
// период приема одного бита
parameter periodUart = F_clk_Gz/T;
// половина периода приема одного бита
parameter periodUartDev2 = F_clk_Gz/T/2;
// размер бит для передачи
parameter dataLenUart = dataLen + stop + 1 + par;
// регистр таймера
reg [log2(periodUart)-1:0]waitRecvTimer;

// 0 бит - стартовый
reg [dataLenUart:0]dataUart;

// машина состояний
reg [2:0]state;
parameter idle			= 3'b000;
parameter recv			= 3'b001;
parameter waitRecv		= 3'b010;
parameter waitRecvStart = 3'b011;
parameter parity		= 3'b100;


reg [3:0]countBitRecv;


always @(posedge clk, posedge rst)
if(rst)
begin
	data <= 0;
	countBitRecv <= 0;
	state <= idle;
	waitRecvTimer <= 0;
end
else
begin
	case(state)
	idle:
	begin
		if(inData == 0)
		begin // записать данные и стартовый бит в буфер
			state <= waitRecvStart;
			data <= 0;
		end
		else
		begin
			ready <= 0;
			corrupt <= 0;
		end
	end
	
	recv: // режим приема
	begin
		if(countBitRecv > dataLenUart - 1) // если приняты все биты
		begin
			countBitRecv <= 0;
			ready <= 1;		// признак готовности данных
			state <= idle;
		end
		else
		begin
			// проверка стопового бита
			if(countBitRecv == dataLen + par + stop)
			begin
				if(inData == 0)
					corrupt <= 1;
				//else
				//	corrupt <= 0;
				
				ready <= 1;
				countBitRecv <= 0;
				waitRecvTimer <= 0;
				state <= idle;
			end
			else if((par != 0) & (countBitRecv == dataLen + par)) // проверка на четность
			begin
				if(inData != ^data[dataLen-1:0])
					corrupt <= 1;
			end
			else // обработка всех информационных бит
			begin
				data[dataLen-1:0] <= {inData, data[dataLen-1:1]}; // запись данных
				countBitRecv <= countBitRecv + 1;
				state <= waitRecv;	// переход на задержку
			end
		end
	end
	
	waitRecv: // задержка для приема одного бита
	begin
		if(waitRecvTimer > periodUart)
		begin
			waitRecvTimer <= 0;
			state <= recv;
		end
		else
			waitRecvTimer <= waitRecvTimer + 1;
	end
	
	waitRecvStart:
	begin
		if(waitRecvTimer > periodUartDev2)
		begin
			if(inData == 0)
			begin
				waitRecvTimer <= 0;
				state <= recv;
			end
			else
			begin
				state <= idle;
				data <= 0;
				countBitRecv <= 0;
				waitRecvTimer <= 0;
			end
		end
		else
			waitRecvTimer <= waitRecvTimer + 1;
	end

	endcase

end

endmodule


