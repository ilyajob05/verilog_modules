// синхронизатор сигнала с тактовым сигналом

`timescale 1ns / 1ps


module syncLatch(
    input in,
    input clk,
	 input rst,
    output reg out
    );

// триггер
always @(posedge clk, posedge rst)
if(rst)
	out <= 0;
else
	out <= in;

endmodule