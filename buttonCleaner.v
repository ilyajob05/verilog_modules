// модуль подавления дребезга котактов
// период гашения дребезга определяется периодом работы внешнего таймера - сигнал sync

`timescale 1ns / 1ps


module buttonCleaner(
    input in, // вход кнопки
    input sync, // синхронизация с внешним таймером, определяет период работы схемы устранения "дребезга"
	 input clk, //
	 input rst,
    output reg out // выход кнопки
    );
	
	reg [1:0]count;

always @(posedge clk, posedge rst)
begin
	if(rst)
	begin
		count <= 0;
		out <= 0;
	end
	else
	begin
		if(sync)
		begin
			count <= {count[0], in}; // сохранение текущего состояния и сохранение состояния кнопки (сдвиговый регистр)
			if(count >= 2'b11) // если кнопка нажата два цикла таймера - активировать выход
				out <= 1;
			else
				out <= 0;
		end
	end
end

endmodule