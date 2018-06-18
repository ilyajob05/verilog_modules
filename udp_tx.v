// модуль передачи пакета UDP
// данные UDP должны быть обновлены по сигналу getByte
// входные данные должны оставаться неизменными до окончания передачи данных

module udp_tx
(	input clk,
	input rst,
	input startSend,		// начать передачу пакета
	output ready,			// признак готовности
	output getByte,			// запрос данных UDP
	input [7:0]dataIn,		// данные UDP
	// свойства пакета
	input [47:0]macLoc,		// локальный МАС адрес
	input [47:0]macRem,		// удаленный МАС адрес
	input [31:0]ipLoc,		// локальный IP адреc
	input [31:0]ipRem,		// удаленный IP адрес
	input [15:0]ipID,		// идентификатор
	input [15:0]portLoc,	// локальный порт
	input [15:0]portRem,	// удаленный порт
	input [15:0]lenUdp,		// размер пакета
	// интерфейс
	output [1:0]PhyTxd,		// данные на интерфейс rmii
	output reg PhyClk50Mhz,	// выход 50 МГц для отладки
	output PhyTxEn,			// данные на интерфейс rmii
	output reg PhyRstn		// включение передатчика
);
	
// размер без UDP
// 8 	- sync preambule
// 14 	- Ethernet header
// 4 	- CRC Ethernet
// 20 	- IP header
// 8 	- UDP header
parameter lenAllEthHeader = 8 + 14 + 20;
parameter lenIpUdpHeaders = 20;

reg [15:0] lenEthPack;
reg [15:0] lenIpPack;

// счетчик переданных байт
reg [15:0] countEthByteSnd;

// счетчик для подзаголовков
reg [3:0] countHeaderByte;

// состояния
reg [5:0]stateEth /*verilator public*/;
parameter idle 			= 0;	// ожидание
parameter sendHead		= 1;	// передача преамбулы
parameter sendMAC 		= 2;	// передача МАС адресов и типа
parameter sendIpHead	= 3;	// передача версии IP размера заголовка и типа сервиса
parameter sendIpAddr 	= 4;	// передача адресов отправителя и получателя
parameter sendUDPHead	= 5;	// передача UDP заголовка
parameter sendUDPData	= 6;	// передача данных UDP
parameter sendEthCRC	= 7;	// передача контрольной суммы

// реакция на фронт от RMII модуля getByte
wire rmiiGetByte;
reg cmpGetByte;
assign rmiiGetByte = ((getByteRmii == 1) && (cmpGetByte == 0));

// запрос данных UDP
reg getByteUDPEn;
assign getByte = getByteUDPEn & rmiiGetByte;

always @(posedge clk, posedge rst)
if(rst)
begin
	getByteUDPEn <= 0;
	lenIpPack <= 0;
	lenEthPack <= 0;
	cmpGetByte <= 0;
	stateEth <= idle;
	countEthByteSnd <= 0;
	countHeaderByte <= 0;
	PhyRstn <= 1;
end
else
begin
	cmpGetByte <= getByteRmii; // детектор фронта
	
	case(stateEth)
	idle:
	begin
		if(startSend & readyRMII) // начало передачи
		begin
			lenEthPack <= lenAllEthHeader + lenUdp + 4; // вычисление размера 
			countEthByteSnd <= 1;
			//countHeaderByte <= 0;
			startSendRmii <= 1;		// включить передатчик
			byteSendRmii <= 8'h55;	// преамбула
			lenIpPack <= lenIpUdpHeaders + lenUdp; // вычисение размера IP пакета
			stateEth <= sendHead;
		end
	end

	sendHead:
	begin
		if(rmiiGetByte)
		begin
			countEthByteSnd <= countEthByteSnd + 1;

			case(countEthByteSnd)
			// 0...6 nop nop...
			7:	begin
				byteSendRmii <= 8'hD5;		// преамбула
				crc32En <= 1;
				startSendRmii <= 0;
				end
			// Ethernet
			8:	byteSendRmii <= macRem[47:40];	// MAC 
			9:	byteSendRmii <= macRem[39:32];
			10:	byteSendRmii <= macRem[31:24];
			11:	byteSendRmii <= macRem[23:16];
			12:	byteSendRmii <= macRem[15:8];
			13:	byteSendRmii <= macRem[7:0];
			14:	byteSendRmii <= macLoc[47:40];
			15:	byteSendRmii <= macLoc[39:32];
			16:	byteSendRmii <= macLoc[31:24];
			17:	byteSendRmii <= macLoc[23:16];
			18:	byteSendRmii <= macLoc[15:8];
			19: byteSendRmii <= macLoc[7:0];
			20: byteSendRmii <= 8'h08;			// ether type
			21:	byteSendRmii <= 0;				// ether type
			// IP
			22:	byteSendRmii <= 8'h45;			// ver, HLen
			23: byteSendRmii <= 8'h00;			// тип сервиса
			24:	byteSendRmii <= lenIpPack[15:8];// размер IP пакета
			25:	byteSendRmii <= lenIpPack[7:0];	// размер IP пакета
			26:	byteSendRmii <= ipID[15:8];		// идентификатор IP пакета
			27:	byteSendRmii <= ipID[7:0];		// идентификатор IP пакета
			28:	byteSendRmii <= 0;				// флаги и указатель фрагмента
			29:	byteSendRmii <= 0;				// флаги и указатель фрагмента
			30:	byteSendRmii <= 8'h80;			// время жизни
			31:	byteSendRmii <= 8'h11;			// протокол - UDP
			32:	byteSendRmii <= crc16Ip[15:8];	// контрольная сумма заголовка!!!
			33:	byteSendRmii <= crc16Ip[8:0];	// контрольная сумма заголовка!!!
			34:	byteSendRmii <= ipLoc[31:24];	// ip отправителя
			35:	byteSendRmii <= ipLoc[23:16];	// ip отправителя
			36:	byteSendRmii <= ipLoc[15:8];	// ip отправителя
			37:	byteSendRmii <= ipLoc[7:0];		// ip отправителя
			38:	byteSendRmii <= ipRem[31:24];	// ip получателя
			39:	byteSendRmii <= ipRem[23:16];	// ip получателя
			40:	byteSendRmii <= ipRem[15:8];	// ip получателя
			41:	byteSendRmii <= ipRem[7:0];		// ip получателя
			// UDP
			42:	byteSendRmii <= portLoc[15:8];	// порт источника
			43:	byteSendRmii <= portLoc[7:0];	// порт источника
			44:	byteSendRmii <= portRem[15:8];	// порт назначения
			45:	byteSendRmii <= portRem[7:0];	// порт назначения
			46:	byteSendRmii <= lenUdp[15:8];	// размер UDP пакета
			47:	byteSendRmii <= lenUdp[7:0];	// размер UDP пакета
			48:	byteSendRmii <= 0;				// контрольная сумма UDP
			49:	begin
					byteSendRmii <= 0;			//	контрольная сумма UDP
					getByteUDPEn <= 1;			//	разрешение запроса следующего байта UDP
					stateEth <= sendUDPData;
				end
			endcase
			
		end
	end
	
	sendUDPData:
	begin
		if(rmiiGetByte)
		begin
			countEthByteSnd <= countEthByteSnd + 1;
			if(countEthByteSnd < lenEthPack - 4)
				byteSendRmii <= dataIn;
			else
			begin
				crc32En <= 0;
				byteSendRmii <= ~crc32Eth[31:24];	// загрузка контрольной суммы
				crc32EthBuf <= ~crc32Eth << 8;
				getByteUDPEn <= 0;
				stateEth <= sendEthCRC;
			end
		end
	end
	
	sendEthCRC:
	begin
		if(rmiiGetByte)
		begin
			countEthByteSnd <= countEthByteSnd + 1;
			byteSendRmii <= crc32EthBuf[31:24];
			crc32EthBuf <= crc32EthBuf << 8;
		end
		if(countEthByteSnd > lenEthPack)	// ожидание завершения передачи
			stateEth <= idle;
	end
	
	endcase
end


// RMII
///////////////////////////////////////////////////////////////////
reg [15:0]countByteSend /*verilator public*/; //счетчик переданных байт
reg [7:0]byteSendRmii; // текущий байт для передачи
reg startSendRmii; // сигнал на начало передачи пакета

always @(posedge clk, posedge rst)
if(rst)
	PhyClk50Mhz <= 0;
else
	PhyClk50Mhz <= ~PhyClk50Mhz;
	
wire getByteRmii; // запрос на установку следующего байта для передачи
wire readyRMII /*verilator public*/;
wire [15:0]numByteRmiiSend;

rmii_tx rmiiTx(.clk(clk), .rst(rst), .dataIn(byteSendRmii), .start(startSendRmii), .dataLen(lenEthPack), /*+CRC4byte*/
	.ready(readyRMII), .dataOut(PhyTxd), .TXEN(PhyTxEn), .getByte(getByteRmii), .numByteSend(numByteRmiiSend));


// CRC
///////////////////////////////////////////////////////////////////
wire [15:0]crc16Ip;       //контрольная сумма IP заголовка пакета
wire [31:0]ip_crc_step0; //результат вычислений контрольной суммы IP на первом шаге
wire [31:0]ip_crc_step1; //результат вычислений контрольной суммы IP на втором шаге

assign ip_crc_step0 = 32'h4500 + 32'h002E + 32'hB3FE + 32'h8011 + {16'd0,ipLoc[31:16]} + {16'd0,ipLoc[15:0]} + {16'd0,ipRem[31:16]} + {16'd0,ipRem[15:0]}; //первый шаг вычислений контрольной суммы IP:разбиваем всё содержимое IP headera на пары байт и складываем их.Байты ip crc считаем равными 0000_0000
assign ip_crc_step1 = {16'd0 ,ip_crc_step0[31:16]}+{16'd0,ip_crc_step0[15:0]};//второй шаг - получившийся на первом шаге результат-32 битный dword разбиваем на пары байт (младшие 16 бит и старшие),дополняем старшие разряды нулями 16'd0 и складываем
assign crc16Ip = ~{ip_crc_step1[31:16]+ip_crc_step1[15:0]};//третий шаг - получившийся на втором шаге результат-32 битный dword разбиваем на пары байт (младшие 16 бит и старшие), складываем и инвертрируем ~


// вычисление контрольной суммы Ethernet
// CRC для Ethernet пакета
reg [31:0] crc32Eth /*verilator public*/;
reg [31:0] crc32EthBuf;
wire [31:0] crc32Res;
reg crc32En;
crc_32_802_3 crc_32(.data_in(byteSendRmii), .crc(crc32Eth), .new_crc(crc32Res));

always @(posedge clk, posedge rst)
if(rst)
begin
	crc32Eth <=  0;//32'hB331881B;
	//crc32EthBuf <= 0;
end
else
begin
	if(countByteSend == 0)
		crc32Eth <= -1;
	else if((countEthByteSnd > 7) & rmiiGetByte)
		crc32Eth <= crc32Res;
	else
		crc32Eth <= crc32Eth;
end

endmodule


