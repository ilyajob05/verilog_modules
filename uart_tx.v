// модуль передачи байта по протоколу UART

module uart_tx #(
parameter T = 9600, // скорость передачи бод
par = 0, // бит четности  0-нет, 1-есть
parType = 0, // тип контроля четности 0-xor
stop = 1, // количество стоп бит
dataLen = 8) // количество информационных бит
(	input clk,
	input rst,
	input [dataLen-1:0]data, // данные для передачи
	input start, // 
	output ready,
	output reg dataOut);

function integer log2;
input integer value;
begin
	for (log2=0; value>0; log2=log2+1)
		value = value>>1;
end
endfunction

// частота тактового сигнала
parameter F_clk_Gz = 100_000_000;
// период передачи одного бита
parameter periodUart = F_clk_Gz/T;
// размер бит для передачи
parameter dataLenUart = dataLen + stop + 1 + par;
// регистр таймера
reg [log2(periodUart)-1:0]waitSndTimer;

// 0 бит - стартовый
reg [dataLenUart:0]dataUart;

// машина состояний
reg [1:0]state;
parameter idle		= 3'b00;
parameter send		= 3'b01;
parameter waitSnd	= 3'b10;
parameter parity	= 3'b11;

reg [3:0]countBitSend;

// в режиме простоя на выход - 1
//assign dataOut = (state == idle) ? 1:dataUart[0];
// в режиме простоя сигн. готовности
assign ready = (state == idle) ? 1:0;

always @(posedge clk, posedge rst)
if(rst)
begin
	dataOut <= 1;
	dataUart <= 0;
	countBitSend <= 0;
	state <= idle;
	waitSndTimer <= 0;
end
else
begin
	case(state)
	idle:
	begin
		if(start)
		begin // записать данные и стартовый бит в буфер
			dataUart[dataLen:0] <= {data, 1'b0};
			if(par == 1) // если включена проверка четности
			begin
				dataUart[dataLen + 1] <= ^data;
				if(stop == 1)
					dataUart[dataLen + 2] <= 1;
				else if(stop == 2)
					dataUart[dataLen + 4:dataLen + 3] <= 2'b11;
			end
			else if(par == 0) // если нет проверки четности
			begin
				if(stop == 1)
					dataUart[dataLen + 1] <= 1;
				else if(stop == 2)
					dataUart[dataLen + 3:dataLen + 2] <= 2'b11;
			end
			state <= send;
		end
	end
	
	send: // режим передачи
	begin
		if(countBitSend > dataLenUart - 1) // если переданы все биты
		begin
			countBitSend <= 0;
			dataOut <= 1;
			state <= idle;
		end
		else
		begin
			dataUart <= dataUart >> 1;
			dataOut <= dataUart[0];
			countBitSend <= countBitSend + 1;
			state <= waitSnd;
		end
	end
	
	waitSnd: // задержка для передачи одного бита
	begin
		if(waitSndTimer > periodUart)
		begin
			waitSndTimer <= 0;
			state <= send;
		end
		else
			waitSndTimer <= waitSndTimer + 1;
	end
	endcase
end


endmodule


