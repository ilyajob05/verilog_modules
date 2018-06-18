// ├¼├«├ñ├│├½├╝ ├»├Ñ├░├Ñ├ñ├á├À├¿ ├¡├Ñ├▒├¬├«├½├╝├¬├¿├Á ├í├á├®├▓ ├»├« ├»├░├«├▓├«├¬├«├½├│ rmii,
// ├»├Ñ├░├Ñ├ñ├á├Ñ├▓├▒├┐ ├»├á├¬├Ñ├▓ UDP, ├»├« ├▓├á├®├¼├Ñ├░├│


module rmii_send_pack
(	input clk,
	input nrst,
	output [1:0]PhyTxd,		// ├ñ├á├¡├¡├╗├Ñ ├¡├á ├¿├¡├▓├Ñ├░├┤├Ñ├®├▒ rmii
	output reg PhyClk50Mhz,	// ├ó├╗├Á├«├ñ 50 ├î├â├Â ├ñ├½├┐ ├«├▓├½├á├ñ├¬├¿
	output PhyTxEn,			// ├ñ├á├¡├¡├╗├Ñ ├¡├á ├¿├¡├▓├Ñ├░├┤├Ñ├®├▒ rmii
	output reg PhyRstn);		// ├ó├¬├½├¥├À├Ñ├¡├¿├Ñ ├»├Ñ├░├Ñ├ñ├á├▓├À├¿├¬├á
	
wire rst;
assign rst = ~nrst;

wire start;

timer #(.period(1000000)) startTimer(.clk(clk),.rst(rst),.out(start));

//├º├á├ú├░├│├º├¬├á ├»├á├¬├Ñ├▓├á
parameter lenPack = 72;
reg [7:0]packUDP[0:lenPack-1] /*verilator public*/;
initial $readmemh("packUDP.hex",packUDP); // ├º├á├ú├░├│├º├¬├á ├ñ├á├¡├¡├╗├Á ├¿├º ├┤├á├®├½├á

reg [15:0]countByteSend /*verilator public*/; //├▒├À├Ñ├▓├À├¿├¬ ├»├Ñ├░├Ñ├ñ├á├¡├¡├╗├Á ├í├á├®├▓

reg [7:0]byteSendRmii; // ├▓├Ñ├¬├│├╣├¿├® ├í├á├®├▓ ├ñ├½├┐ ├»├Ñ├░├Ñ├ñ├á├À├¿
reg startSendRmii; // ├▒├¿├ú├¡├á├½ ├¡├á ├¡├á├À├á├½├« ├»├Ñ├░├Ñ├ñ├á├À├¿ ├»├á├¬├Ñ├▓├á

always @(posedge clk, posedge rst)
if(rst)
	PhyClk50Mhz <= 0;
else
	PhyClk50Mhz <= ~PhyClk50Mhz;
	
wire getByte; // ├º├á├»├░├«├▒ ├¡├á ├│├▒├▓├á├¡├«├ó├¬├│ ├▒├½├Ñ├ñ├│├¥├╣├Ñ├ú├« ├í├á├®├▓├á ├ñ├½├┐ ├»├Ñ├░├Ñ├ñ├á├À├¿
wire readyRMII /*verilator public*/;
rmii_tx rmiiTx(.clk(clk), .rst(rst), .dataIn(byteSendRmii), .start(startSendRmii), .dataLen(72),
	.ready(readyRMII), .dataOut(PhyTxd), .TXEN(PhyTxEn), .getByte(getByte));

reg [1:0] state /*verilator public*/;
parameter idle 	= 2'b00;
parameter send	= 2'b01;

reg tmpGetByte;
always @(posedge clk, posedge rst)
if(rst)
begin
	countByteSend <= 0;
	byteSendRmii <= 0;
	startSendRmii <= 0;
	state <= idle;
	tmpGetByte <= 0;
	PhyRstn <= 0;
end
else
begin
	PhyRstn <= 1;	// ├¬├½├¥├À├Ñ├¡├¿├Ñ ├»├Ñ├░├Ñ├ñ├á├▓├À├¿├¬├á
	tmpGetByte <= getByte; // ├ñ├Ñ├▓├Ñ├¬├▓├«├░ ├┤├░├«├¡├▓├á
	case(state)
	idle:	// ├░├Ñ├ª├¿├¼ ├»├░├«├▒├▓├«├┐
	begin
		if(start)
		begin
			countByteSend <= 1;		// ├¡├á├À├á├½├╝├¡├╗├® ├á├ñ├░├Ñ├▒ 0, ├▒├½├Ñ├ñ ├│├▒├▓├á├¡├á├ó├½├¿├ó├á├Ñ├▓├▒├┐ ├ó 1
			byteSendRmii <= packUDP[countByteSend];	// ├º├á├ú├░├│├º├¬├á ├ñ├á├¡├¡├╗├Á ├¿├º ├»├á├¼├┐├▓├¿
			startSendRmii <= 1;		// ├▒├¿├ú├¡├á├½ ├¡├á ├▒├▓├á├░├▓ ├»├Ñ├░├Ñ├ñ├á├À├¿
			
			state <= send;
		end
	end
	
	send:	// ├░├Ñ├ª├¿├¼ ├»├Ñ├░├Ñ├ñ├á├À├¿
	begin

		if((getByte == 1) && (tmpGetByte == 0)) // ├ñ├Ñ├▓├Ñ├¬├▓├¿├░├«├ó├á├¡├¿├Ñ ├┤├░├«├¡├▓├á
		begin
			startSendRmii <= 0; // ├▒├í├░├«├▒ ├▒├¿├ú├¡├á├½├á ├¡├á├À├á├½├á ├»├Ñ├░├Ñ├ñ├á├À├¿ - ├»├Ñ├░├Ñ├ñ├á├▓├À├¿├¬ ├░├á├í├«├▓├á├Ñ├▓ ├¡├á 50├î├â├Â
			countByteSend <= countByteSend + 1;
			byteSendRmii <= packUDP[countByteSend];	// ├º├á├ú├░├│├º├¬├á ├ñ├á├¡├¡├╗├Á ├¿├º ├»├á├¼├┐├▓├¿
		end
		else if(readyRMII & (countByteSend >= lenPack)) // ├Ñ├▒├½├¿ ├»├Ñ├░├Ñ├ñ├á├▓├À├¿├¬ ├º├á├¬├«├¡├À├¿├½ ├Â├¿├¬├½ ├»├Ñ├░├Ñ├ñ├á├À├¿ ├¿ ├»├Ñ├░├Ñ├ñ├á├¡├╗ ├ó├▒├Ñ ├í├á├®├▓├╗
		begin
			state <= idle;
			countByteSend <= 0;
		end
	end
	endcase
end

endmodule

