// Модуль приема байта по протоколу RMII

module rmii_rx_byte
(
	input rst,					// аснихронный сброс
	input clk,					// тактовый генератор 100 МГц
	input rmii_clk,				// синхронный с clk тактовый генератор 50 МГц
	input fast_eth,				// переключатель скорости передачи 0 - 10 Мбит/с, 1 - 100 Мбит/с
	input [1:0]rm_rx_data,		// данные, полученные по Phy
	input rm_crs_dv,			// сигнал Phy о наличии принимаемого пакета от приёмника заводится rm_tx_en если 1 - принимаем данные
	output reg [7:0]data,		// данные, полученные по сети
	output reg rdy,             // сигнал готовности очередного байта
	output reg busy				// 1 - осуществляется приём пакета, 0 - свободен 
);

// стробирование входных сигналов
reg [1:0]s_rm_rx_data;
reg s_rm_crs_dv;
reg s_rmii_clk;

always @(posedge rst, posedge clk)
	if(rst)
		{s_rm_rx_data, s_rm_crs_dv, s_rmii_clk} <= 0;
	else
		{s_rm_rx_data, s_rm_crs_dv, s_rmii_clk} <= {rm_rx_data, rm_crs_dv, rmii_clk};

reg [4:0]wait_cnt;	// счётчик ожидания для передачи со скоростью 10 Мбит/с
reg [7:0]rx_data;	// регистр принятых байт

reg [1:0]stop;     //нужен для приёма на +1 последний байт

// Основная логика приёма
always @(posedge rst, posedge clk)
    begin
	if(rst)
		begin
			data <= 0;
			rx_data <= 0;
			wait_cnt <= 0;
			rdy <= 0;
			busy <= 0;
			stop <= 0;  //до 32 бит можно обнулять не указывая размера ,больше нужно указывать размер 33''b
		end	
	else
        begin
            if(rdy)					// автоматически сбрасываем сигнал rdy, чтобы он не длился более 1 такта
                rdy <= 0;
            if(wait_cnt == 0)//сторожевой таймер
                begin
                    if(!busy)
                    begin
                        stop <= 0;				// снимаем флаг до прихода пакета
                            if(s_rm_crs_dv)			// если на выходе Phy валидные данные
                            begin
                                if(s_rmii_clk)
                                begin
                                    if(rx_data == 8'hD5)		// если обнаружили конец преамбулы
                                        begin
                                            busy <= 1;			// выставляем сигнал принятия пакета
                                            rx_data <= {s_rm_rx_data, 6'b11_0000};	// сохраняем новые данные //маркер приёма сигнала когда 11 сдвинется до 0000_0011 значит конец передачи - байт передан
                                        end
                                    else
                                        rx_data <= {s_rm_rx_data, rx_data[7:2]};	// пишем кольцом новые данные
                                    if(!fast_eth)			// в случаем 10 Мбитного eth запускаем сторожевой таймер
                                        wait_cnt <= 18;
                                end
                            end
                            else
                                rx_data <= 0;		// обнуляем rx_data, чтобы быть уверенным, что сигнал валидный						
                    end							
                    else
                        begin
                            if((s_rm_crs_dv) | (stop == 2'b01))//(s_rm_crs_dv | stop[0])		// если идут валидные данные при принима...
                                begin
                                    if(s_rmii_clk)
                                        begin
                                            if(rx_data[1:0] == 2'b11)		// если принят целый байт , т.е. сдвинули до конца
                                                begin
                                                    data <= {s_rm_rx_data, rx_data[7:2]};	// выводим результат из младших пар бит
                                                    rx_data <= 8'b11_00_0000;				// переагружаем rx_data
                                                    if(stop==2'b01)//(stop[0])
                                                        stop <= 2'b10;
                                                    rdy <= 1;
                                                end
                                                    else
                                                        rx_data <= {s_rm_rx_data, rx_data[7:2]}; //вдвигаем в rx_data данные со входа s_rm_rx_data
                                                    if(!fast_eth)
                                                        wait_cnt <= 18;
                                        end
                                end
                            else
                                begin							// если прервался сигнал валидности, то считаем, что пакет
                                    if((fast_eth )|(stop == 2'b10))	//stop[1])	// если используется 100 Мбитная сеть
                                        begin					// оканчиваем приём пакета
                                            stop <= 0;			
                                            busy <= 0;
                                            rx_data <= 0;
                                        end 
                                    else
                                        stop <= 2'b01;			// иначе переходим в режим приёма посл...
                                end
                        end							
                end
    
				else
					wait_cnt <= wait_cnt - 1;
			end
		end	
endmodule

		