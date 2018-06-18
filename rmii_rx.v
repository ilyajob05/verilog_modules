// модуль приема байт по протоколу RMII
// частота тактового сигнала 100МГц
// частота работы RMII 50МГц

module rmii_rx
(	input clk,
	input clk50Mgz,	// частота 50 МГц от интерфейса
	input rst,
	input [1:0]RXD,				// данные с интерфейса
	input CRS_DV,				// признак приема данных
	output reg [7:0]byteOut,		// принятые данные
	output reg [15:0]byteCount,	// текущее количество принятых байт
	output reg syncBegin, 		// признак получения сигнала синхронизации
	output reg readyByte,		// признак что байт принят
	output reg syncEnd			// признак окончания пакета
);

//синхронизация внешних сигналов
reg [1:0]RXDi;
reg clk50Mgzi;
reg CRS_DVi;
always @(posedge clk, posedge rst)
if(rst)
begin
	RXDi <= 0;
	clk50Mgzi <= 0;
	CRS_DVi <= 0;
end
else
begin
	RXDi <= RXD;
	clk50Mgzi <= clk50Mgz;
	CRS_DVi <= CRS_DV;
end


// байт для приема
reg [7:0]dataRcv /*verilator public*/;

// машина состояний
reg [1:0]state  /*verilator public*/;
parameter idle		= 2'b00;
parameter recv		= 2'b01;

reg [1:0]countBitRecv /*verilator public*/; //счетчик принятых бит
reg [6:0]countBitFoot /*verilator public*/; //счетчик бит до конца пакета

always @(negedge clk, posedge rst)
if(rst)
begin
	byteCount <= 0;
	syncBegin <= 0;
	syncEnd <= 0;
	readyByte <= 0;
	dataRcv <= 0;
	state <= idle;
	countBitRecv <= 0;
	countBitFoot <= 0;
	byteOut <= 0;
end
else
begin
	if(~clk50Mgzi)
	begin
		dataRcv <= {RXDi, dataRcv[7:2]};
		case(state)
		idle:
		begin
			if((dataRcv == 8'hD5) & CRS_DVi)	// синхросигнал
			begin
				byteCount <= 0;
				countBitRecv <= 0;
				countBitFoot <= 0;
				syncBegin <= 1;		// сигнал начала приема пакета
				state <= recv;
			end
			syncEnd <= 0;	//сброс синхросигнала
		end
		
		recv: // режим приема
		begin
			syncBegin <= 0;	//сброс синхросигнала
			if(CRS_DVi | (countBitRecv == 3)) // ждать завершения приема байта, + испр.
			begin
				countBitRecv <= countBitRecv + 1; //подсчет принятых данных, сброс по переполнению
				countBitFoot <= 0;
				if(countBitRecv == 3)	// признак готовности байта
				begin
					readyByte <= 1;
					byteOut <= dataRcv;	// записать байт
					byteCount <= byteCount + 1;	//считать байт в пакете
				end
				else
				begin
					readyByte <= 0;
				end
				if(!CRS_DV) // + испр.
					countBitRecv <= 0;
			end
			else
			begin
				countBitFoot <= countBitFoot + 1;
				if(countBitFoot == 63)
				begin
					countBitFoot <= 0;
					state <= idle;
					syncEnd <= 1;	// сигнал окончания приема пакета
				end
				readyByte <= 0;
			end
			end
		endcase
	end
end


endmodule
