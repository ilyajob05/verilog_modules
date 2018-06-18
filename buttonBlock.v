// модуль работы с кнопкой

`timescale 1ns / 1ps


module buttonBlock(
    input in,
    output out,
    input clk,
    input rst
    );
	 
	 wire BtnSyncTick; // сигнал опроса кнопок
	 // тамер опроса кнопки
timer32 timerBtnSync(
		.clk(clk), 
		.rst(rst), 
		.period(4000_000), // период опроса кнопки в тактах, 40мсек
		.out(BtnSyncTick)
	);
	
	wire BtnSync; // синхронизированная кнопка
	// синхронизатор с тактовой частотой
syncLatch sync1(
    .in(in),
    .clk(clk),
	 .rst(rst),
    .out(BtnSync)
    );

	// блок подавления дребезга 
buttonCleaner btnClean(
    .in(BtnSync), // вход кнопки
    .sync(BtnSyncTick), // синхронизация с внешним таймером, определяет период работы схемы устранения "дребезга"
	 .clk(clk), //
	 .rst(rst),
    .out(out) // выход кнопки
    );


endmodule
