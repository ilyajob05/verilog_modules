// таймер выдает единичный импульс по окончании заданного периода

`timescale 1ns / 1ps


module timer #(parameter period = 10) // period-период работы таймера
(
input clk,
input rst,
output reg out); // выход таймера
	
function integer log2;
input integer value;
begin
	for (log2=0; value>0; log2=log2+1)
		value = value>>1;
end
endfunction

parameter N = log2(period);

reg [N-1:0]counter;

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

