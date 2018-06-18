`timescale 1ns / 1ps

module devider
(
	input clk,
	input rst,
	input [31:0]dev,
	output reg out
);


reg [31:0]count = 0;

always @(posedge clk, posedge rst)
// при загрузке отнимать 1
if(rst)
	count <= dev - 1;
else
	begin
		count <= count - 1;
		if(count == 0)
		begin
			count <= dev - 1;
			out <= 1;
		end
		else
			out <= 0;
	end

endmodule
