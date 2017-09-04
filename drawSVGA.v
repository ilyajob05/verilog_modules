`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Derendyaev Ilya
// 
// Create Date:    12/10/2015 
// Design Name:    drawSVGA
// Module Name:    drawSVGA 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
 

module drawSVGA(
    input clk,
    input nrst,
	input key1, key2, key3,
    output reg [3:0] vgaR,
    output reg [3:0] vgaG,
    output reg [3:0] vgaB,
    output vgaHsync,
    output vgaVsync,
    output reg ledReady
    );

wire rst;
assign rst = ~nrst;
wire clk65;
/////////////////////////////////////////////////////////////////
// memory image
/////////////////////////////////////////////////////////////////
reg[14:0] addrImg;
wire[12:0] dataImg;
wire we_a, w_data_a;
mem_2port #(.N(12), .L(15), .do_clk_b(0)) memImg1(.clk(clk65), .clk_b(clk), .en_a(1), .w_data_a(w_data_a), .addr_a(addrImg), .r_data_a(dataImg), .we_a(we_a));

/////////////////////////////////////////////////////////////////
// SVGA module
/////////////////////////////////////////////////////////////////

// clock gen, devider 4
reg clkPix = 0;
//wire vclk;
always @(posedge clk)
	clkPix <= ~clkPix;

//assign vclk = clkPix > 1;
///////////////////

wire [10:0] CounterX;
wire [9:0] CounterY;
wire blank;
SVGA SVGAdisp(.vclk(clk65), .rst(rst), .hsync(vgaHsync), .vsync(vgaVsync), .blank(blank), .CounterX(CounterX), .CounterY(CounterY));

/////////////////////////////////////////////////////////////////
// user logic
/////////////////////////////////////////////////////////////////
// start position
reg[9:0] beginPosX, beginPosY;

// LED 
wire tlOut;
timer #(.period(25_000_000)) timeLed(.clk(clk65), .rst(rst), .out(tlOut));
always @(posedge clk65, posedge rst)
if(rst)
	ledReady <= 0;
else
	if(tlOut)
		ledReady <= ~ledReady;

// select timer for position update
wire updatePosition, updatePosition1, updatePosition2, updatePosition3;
assign updatePosition = (updatePosition1 & key1) | (updatePosition2 & key2) | (updatePosition3 & key3);
reg updPosSync;
timer #(.period(30_000_000)) timePosition1(.clk(clk65), .rst(rst), .out(updatePosition1));
timer #(.period(10_000_000)) timePosition2(.clk(clk65), .rst(rst), .out(updatePosition2));
timer #(.period(1_000_000))  timePosition3(.clk(clk65), .rst(rst), .out(updatePosition3));

// random generator
wire [31:0] rand;
LFSR randLFSR(.rst(rst), .clk(clk65), .out(rand));

// get color
always @(posedge clk65)
if(rst)
begin
	updPosSync <= 0;
	beginPosX <= 0;
	beginPosY <= 0;
	addrImg <= 0;
	vgaR <= 0;
	vgaG <= 0;
	vgaB <= 0;
end
else
begin
	// get pixel
	if(!blank)
	begin
		vgaB <= dataImg[3:0];
		vgaG <= dataImg[7:4];
		vgaR <= dataImg[11:8];
	end
	else
	begin
		vgaR <= 0;
		vgaG <= 0;
		vgaB <= 0;
	end
	
	if(updatePosition)
		updPosSync <= 1;
		
	// change image position
	if((CounterX == 0) & (CounterY == 0))
	begin
		if(updPosSync)
		begin
			updPosSync <= 0;
			beginPosX <= rand[8:0];		// set random position
			beginPosY <= rand[17:9];	// set random position
			addrImg <= 0;
		end
	end
	// draw image
	else if((CounterX < (200 + beginPosX)) && (CounterX > beginPosX) && 
	(CounterY < (150 + beginPosY)) && (CounterY > beginPosY))
		addrImg <= (CounterX - beginPosX) + ((CounterY - beginPosY) * 200);
	else
		addrImg <= 0;
end


/////////////////////////////////////////////////////////////////
// clock gen
/////////////////////////////////////////////////////////////////
wire clkFeedBack;

   PLLE2_BASE #(
      .BANDWIDTH("OPTIMIZED"),  // OPTIMIZED, HIGH, LOW
      .CLKFBOUT_MULT(8),        // Multiply value for all CLKOUT, (2-64)
      .CLKFBOUT_PHASE(0.0),     // Phase offset in degrees of CLKFB, (-360.000-360.000).
      .CLKIN1_PERIOD(10.0),      // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
      // CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for each CLKOUT (1-128)
      .CLKOUT0_DIVIDE(20),
      .CLKOUT1_DIVIDE(1),
      .CLKOUT2_DIVIDE(1),
      .CLKOUT3_DIVIDE(1),
      .CLKOUT4_DIVIDE(1),
      .CLKOUT5_DIVIDE(1),
      // CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for each CLKOUT (0.001-0.999).
      .CLKOUT0_DUTY_CYCLE(0.5),
      .CLKOUT1_DUTY_CYCLE(0.5),
      .CLKOUT2_DUTY_CYCLE(0.5),
      .CLKOUT3_DUTY_CYCLE(0.5),
      .CLKOUT4_DUTY_CYCLE(0.5),
      .CLKOUT5_DUTY_CYCLE(0.5),
      // CLKOUT0_PHASE - CLKOUT5_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
      .CLKOUT0_PHASE(0.0),
      .CLKOUT1_PHASE(0.0),
      .CLKOUT2_PHASE(0.0),
      .CLKOUT3_PHASE(0.0),
      .CLKOUT4_PHASE(0.0),
      .CLKOUT5_PHASE(0.0),
      .DIVCLK_DIVIDE(1),        // Master division value, (1-56)
      .REF_JITTER1(0.0),        // Reference input jitter in UI, (0.000-0.999).
      .STARTUP_WAIT("FALSE")    // Delay DONE until PLL Locks, ("TRUE"/"FALSE")
   )
   PLLE2_BASE_inst (
      // Clock Outputs: 1-bit (each) output: User configurable clock outputs
      .CLKOUT0(clk65),
      // Feedback Clocks: 1-bit (each) output: Clock feedback ports
      .CLKFBOUT(clkFeedBack), // 1-bit output: Feedback clock
      // Clock Input: 1-bit (each) input: Clock input
      .CLKIN1(clk),     // 1-bit input: Input clock
      // Control Ports: 1-bit (each) input: PLL control ports
      .PWRDWN(0),     // 1-bit input: Power-down
      .RST(0),           // 1-bit input: Reset
      // Feedback Clocks: 1-bit (each) input: Clock feedback ports
      .CLKFBIN(clkFeedBack)    // 1-bit input: Feedback clock
   );

endmodule
