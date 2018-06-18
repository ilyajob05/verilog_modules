`timescale 1ns / 1ps

//gtype == 0 - беззнаковый шим
//gtype == 1 - знаковый шим
// out[1] - знак

module pwm_generator #(parameter N=8, gtype=0)
(
	input rst,
	input clk,
	input [N-1:0]in,
	output reg [1:0]out
);


// счетчик шим
reg [N-1-gtype:0]count;
always @(posedge clk, posedge rst)
if(rst)
	count <= 0;
else
	count <= count + 1;


always @(posedge clk, posedge rst)
if(rst)
	begin
		out <= 0;
	end
else
	begin
	if(gtype == 0)
		begin
		if(count >= in)
			out <= 0;
		else
			out <= 1;
		end
	else
		begin
		out[1] <= in[N-1];
		if((count > ~in[N-2:0]) & in[N-1])
			out[0] <= 0;
		else if((count >= in[N-2:0]) & ~in[N-1])
			out[0] <= 0;
		else
			out[0] <= 1;
		end
	end
endmodule

