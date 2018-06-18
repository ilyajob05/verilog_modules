// модуль приема пакета UDP
// модуль принимает записывает принятые данные в память
// сигнал готовности формаируется в случае совпадения сетевых адресов и правильной контрольной суммы

module udp_rx #(parameter packSizePow2 = 10) // packSize - максимальный размер принимаемого пакета, степень 2
(	input clk,
	input rst,
	output ready,				// признак готовности
	reg [3:0]packStatus,		// статус принятых данных
	input modeTransp,			// режим работы,  прием всех пакетов/прием только пакетов с заданным адресом
	//output [7:0]dataIn,		// данные UDP
	// свойства пакета
	input [47:0]macLoc,			// локальный МАС адрес
	output reg [47:0]macRem,	// удаленный МАС адрес
	output reg [31:0]ipLoc,		// локальный IP адреc
	output reg [31:0]ipRem,		// удаленный IP адрес
	output reg [15:0]ipID,		// идентификатор
	output reg [15:0]portLoc,		// локальный порт
	output reg [15:0]portRem,	// удаленный порт
	output reg [15:0]lenUdp,		// размер пакета
	// интерфейс
	input [1:0]PhyRxd,			// данные от интерфейса rmii
	input PhyClk50Mhz,			// вход 50 МГц, LAN8720а от модуля передачи
	input PhyCRsDv,				// сигнал приема данных
	input PhyRstn				// включение передатчика
);
	

/************************************************* MEM **************************************************/
reg en_a, we_a, en_b, we_b;
reg [9:0] addr_a;
reg [7:0] w_data_a;
wire [7:0] r_data_a;
//wire [9:0] addr_b;
//wire [7:0] w_data_b;
wire [7:0] r_data_b;

mem_2port #(.N(8), .L(10), .do_clk_b(0))
mem2pr(.clk(clk), .en_a(en_a), .we_a(we_a), .addr_a(addr_a), .w_data_a(w_data_a), .r_data_a(r_data_a),
						 .clk_b(clk), .en_b(0), .we_b(0), .addr_b(0), .w_data_b(0), .r_data_b(r_data_b));


						 
/************************************************* RMII **************************************************/
reg [7:0] rmiiRcvByte;
wire rmiiRcvRdy;
wire rmiiRcvBusy;
rmii_rx_byte rmiiRB(.clk(clk), .rst(rst), .rmii_clk(PhyClk50Mhz), .fast_eth(1), .rm_rx_data(PhyRxd),
				.rm_crs_dv(PhyCRsDv), .data(rmiiRcvByte), .rdy(rmiiRcvRdy), .busy(rmiiRcvBusy));

				
// размер без UDP
// 8 	- sync preambule
// 14 	- Ethernet header
// 4 	- CRC Ethernet
// 20 	- IP header
// 8 	- UDP header
parameter lenAllEthHeader = 8 + 14/* + 4*/ + 20/* + 8*/;
parameter lenIpUdpHeaders = 20;

reg [15:0] lenEthPack;
reg [15:0] lenIpPack;

// счетчик переданных байт
reg [15:0] countEthByteRcv;

// счетчик для подзаголовков
reg [3:0] countHeaderByte;

// состояния
reg [5:0]stateEth /*verilator public*/;
parameter idle 			= 0;	// ожидание
parameter recvHead		= 1;	// прием преамбулы
parameter sendMAC 		= 2;	// прием МАС адресов и типа
parameter sendIpHead	= 3;	// прием версии IP размера заголовка и типа сервиса
parameter sendIpAddr 	= 4;	// прием адресов отправителя и получателя
parameter sendUDPHead	= 5;	// прием UDP заголовка
parameter reciveUDPData	= 6;	// прием данных UDP
parameter sendEthCRC	= 7;	// прием контрольной суммы

// реакция на фронт от RMII модуля getByte
//wire rmiiGetByte;
//reg cmpGetByte;
//assign rmiiGetByte = ((getByteRmii == 1) && (cmpGetByte == 0));

// список ошибок для статуса принятых данных
// packStatus
parameter packStOk			= 0;
parameter packStErrCRCEth	= 1;
parameter packStErrMACAddr	= 2;
parameter packStErrIpAddr	= 3;
parameter packStErrUDPPort	= 4;
parameter packStErrCRCIp	= 5;
parameter packStErrCRCType	= 6;
parameter packStErrVer		= 7;


// запрос данных UDP
reg getByteUDPEn;
wire getByte;
//assign getByte = getByteUDPEn & rmiiGetByte;

always @(posedge clk, posedge rst)
if(rst)
begin
	getByteUDPEn <= 0;
	lenIpPack <= 0;
	lenEthPack <= 0;
	//cmpGetByte <= 0;
	stateEth <= idle;
	countEthByteRcv <= 0;
	countHeaderByte <= 0;
	
	en_a <= 0;
	we_a <= 0;
	addr_a <= 0;
	w_data_a <= 0;
end
else
begin
	//cmpGetByte <= getByteRmii; // детектор фронта
	
	case(stateEth)
	idle:
	begin
		if(PhyCRsDv) // начало приема
		begin
			///lenEthPack <= lenAllEthHeader + lenUdp + 4; // вычисление размера 
			countEthByteRcv <= 1;
			//countHeaderByte <= 0;
			///startSendRmii <= 1;		// включить передатчик
			packStatus <= (rmiiRcvByte == 8'h55) ? packStOk : packStErrCRCIp;	// преамбула
			///lenIpPack <= lenIpUdpHeaders + lenUdp; // вычисение размера IP пакета
			stateEth <= recvHead;
		end
	end

	recvHead:
	begin
		if(PhyCRsDv)
		begin
			countEthByteRcv <= countEthByteRcv + 1;

			case(countEthByteRcv)
			// 0...6 nop nop...
			0,1,2,3,4,5,6: packStatus <= (rmiiRcvByte == 8'h55) ? packStOk : packStErrCRCIp; // преамбула
			7:	begin
				packStatus <= (rmiiRcvByte == 8'hD5) ? packStOk : packStErrCRCIp;		// преамбула
				crc32En <= 1;
				end
			// Ethernet
			8:	macRem[47:40]	<= rmiiRcvByte;	// запись МАС адреса отправителя
			9:	macRem[39:32]	<= rmiiRcvByte;
			10:	macRem[31:24]	<= rmiiRcvByte;
			11:	macRem[23:16]	<= rmiiRcvByte;
			12:	macRem[15:8]	<= rmiiRcvByte;
			13:	macRem[7:0]		<= rmiiRcvByte;
			14:	packStatus		<= (rmiiRcvByte == macLoc[47:40])	? packStOk : packStErrCRCIp; // сравнение со своим МАС адресом
			15:	packStatus		<= (rmiiRcvByte == macLoc[39:32])	? packStOk : packStErrCRCIp;
			16:	packStatus		<= (rmiiRcvByte == macLoc[31:24])	? packStOk : packStErrCRCIp;
			17:	packStatus		<= (rmiiRcvByte == macLoc[23:16])	? packStOk : packStErrCRCIp;
			18:	packStatus		<= (rmiiRcvByte == macLoc[15:8])	? packStOk : packStErrCRCIp;
			19: packStatus		<= (rmiiRcvByte == macLoc[7:0])		? packStOk : packStErrCRCIp;
			20: packStatus		<= (rmiiRcvByte == 8'h08)			? packStOk : packStErrCRCType; // ether type
			21:	packStatus		<= (rmiiRcvByte == 8'h00)			? packStOk : packStErrCRCType; // ether type
			// IP
			22:	packStatus		<= (rmiiRcvByte == 8'h45)			? packStOk : packStErrVer; // версия и размер заголовка
			23: packStatus		<= (rmiiRcvByte == 8'h00)			? packStOk : packStErrVer; // тип сервиса
			24:	lenIpPack[15:8]	<= rmiiRcvByte;		// размер IP пакета
			25:	lenIpPack[7:0]	<= rmiiRcvByte;		// размер IP пакета
			26:	ipID[15:8]		<= rmiiRcvByte;		// идентификатор IP пакета
			27:	ipID[7:0]		<= rmiiRcvByte;		// идентификатор IP пакета
			28:	rmiiRcvByte		<= 0;				// флаги и указатель фрагмента - не регистрируется
			29:	rmiiRcvByte		<= 0;				// флаги и указатель фрагмента - не регистрируется
			30:	rmiiRcvByte		<= 8'h80;			// время жизни - не регистрируется
			31:	packStatus		<= (rmiiRcvByte == 8'h11) ? packStOk : packStErrVer; // протокол - UDP
			32:	crc16Ip[15:8]	<= rmiiRcvByte;	// контрольная сумма заголовка!!!
			33:	crc16Ip[8:0]	<= rmiiRcvByte;	// контрольная сумма заголовка!!!
			34:	ipLoc[31:24]	<= rmiiRcvByte;	// ip отправителя
			35:	ipLoc[23:16]	<= rmiiRcvByte;	// ip отправителя
			36:	ipLoc[15:8]		<= rmiiRcvByte;	// ip отправителя
			37:	ipLoc[7:0]		<= rmiiRcvByte;	// ip отправителя
			38:	ipRem[31:24]	<= rmiiRcvByte;	// ip получателя
			39:	ipRem[23:16]	<= rmiiRcvByte;	// ip получателя
			40:	ipRem[15:8]		<= rmiiRcvByte;	// ip получателя
			41:	ipRem[7:0]		<= rmiiRcvByte;	// ip получателя
			// UDP
			42:	portLoc[15:8]	<= rmiiRcvByte;	// порт источника
			43:	portLoc[7:0]	<= rmiiRcvByte;	// порт источника
			44:	portRem[15:8]	<= rmiiRcvByte;	// порт назначения
			45:	portRem[7:0]	<= rmiiRcvByte;	// порт назначения
			46:	lenUdp[15:8]	<= rmiiRcvByte;	// размер UDP пакета
			47:	lenUdp[7:0]		<= rmiiRcvByte;	// размер UDP пакета
			48:	;				// контрольная сумма UDP - не регистрируется
			49:	begin
					;			//	контрольная сумма UDP - не регистрируется
					getByteUDPEn <= 1;			//	разрешение запроса следующего байта UDP
					en_a <= 1;					// разрешение на запись в память
					stateEth <= reciveUDPData;
				end
			endcase
			
		end
	end
	
	reciveUDPData:
	begin
		if(rmiiRcvRdy)
		begin
			we_a <= 1;
			countEthByteRcv <= countEthByteRcv + 1;
			if(countEthByteRcv < lenEthPack - 4)
			begin
				w_data_a <= rmiiRcvByte;
				addr_a <= addr_a + 1;
			end
			else
			begin
				crc32En <= 0;
				rmiiRcvByte <= ~crc32Eth[31:24];	// загрузка контрольной суммы
				crc32EthBuf <= ~crc32Eth << 8;
				getByteUDPEn <= 0;
				stateEth <= sendEthCRC;
			end
		end
		else
			we_a <= 0;
	end
	
	sendEthCRC:
	begin
		if(rmiiRcvRdy)
		begin
			countEthByteRcv <= countEthByteRcv + 1;
			rmiiRcvByte <= crc32EthBuf[31:24];
			crc32EthBuf <= crc32EthBuf << 8;
		end
		if(countEthByteRcv > lenEthPack)	// ожидание завершения приема
			stateEth <= idle;
	end
	
	endcase
end

reg [15:0]countByteSend /*verilator public*/; //счетчик переданных байт


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
crc_32_802_3 crc_32(.data_in(rmiiRcvByte), .crc(crc32Eth), .new_crc(crc32Res));

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
	else if((countEthByteRcv > 7) & rmiiRcvRdy)
		crc32Eth <= crc32Res;
	else
		crc32Eth <= crc32Eth;
end

endmodule


