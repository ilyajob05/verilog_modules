// таймер выдает единичный импульс по окончании заданного периода
// значение таймера загружается по окнчании каждого периода

`timescale 1ns / 1ps


module timer32(
	input clk,
	input rst,
	input [31:0]period, // период таймера
	output reg out); // выход таймера
	
	reg [31:0]counter;
	
	always @(posedge clk, posedge rst)
	if(rst)
		begin
		// загрузка значения периода
		counter <= 0;
		end
	else
		// окончание периода, перезагрузка таймера
		if(counter == 0)
			begin
				counter <= period - 1; // поправка +1
				out <= 1;
			end
		else
			// рабочий цикл таймера
			begin
				counter <= counter - 1;
				out <= 0;
			end

endmodule
