`timescale 1ns / 1ps

module pwm2digit#(parameter N=8)
	(
    input in,
    output reg [N-1:0] out,
    input clk,
    input rst
    );
	
	reg [N-1:0]count;
	reg [N-1:0] countPeriod;
	
	// счетчик
	always @(posedge clk, posedge rst)
	if(rst)
		count <= 0;
	else
		count <= count + 1;
		
	// счетчик периода
	always @(posedge clk, posedge rst)
	if(rst)
	begin
		out <= 0;
		countPeriod <= 0;
	end
	else
	begin
	if(count == 0)
	begin
		countPeriod <= 0;
		out <= countPeriod;
	end
	else if(in)
		countPeriod <= countPeriod + 1;
	end
endmodule













