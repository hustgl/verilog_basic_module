//baud rate: 115200;
//check bit: odd
//stop bit : 1
//clk      : 50MHz
//clk num of uart 1bit: 434

module uart #(
		parameter CMD_ADDR_WIDTH = 7,
		parameter CMD_DATA_WIDTH = 8,
		parameter CMD_RW_FLAG    = 1,
		parameter CMD_WIDTH      = CMD_RW_FLAG + CMD_ADDR_WIDTH + CMD_DATA_WIDTH
	)(
		input                           clk       ,
		input                           rst_n     ,
		input                           cmd_valid ,
		input      [CMD_WIDTH-1:0]      cmd_data  ,
		output reg                      cmd_ready ,
		output                          read_valid,
		output     [CMD_DATA_WIDTH-1:0] read_data ,
		output reg                      tx        ,
		input                           rx
	);

wire                     work_done;
reg  [CMD_WIDTH-1:0]     cmd_buf  ;

reg                   work_en     ; //count enable
reg  [8:0]            uart_bit_cnt; //count 434 clk 
reg  [3:0]            uart_bit_num; //uart bit index 11bit in all

wire                 rw_flag      ;
wire [7:0]           cmd_data_high;
wire [7:0]           cmd_data_low ;
reg                  wr_data_flag ;

reg  [6:0]           delay_cnt    ; //delay 100 clks
reg                  delay_en     ;

//read delay: send high 8 bits, the next stage return datas after a while
//read delay isn't controlled by master, but by slave
reg  [2:0]             rx_dly      ;
wire                   nedge_rx    ;
wire                   rx_work_done;  
reg                    rx_work_en  ;
reg  [7:0]             rx_data_buf ;
reg  [8:0]             rx_bit_cnt  ;
reg  [3:0]             rx_bit_num  ;
wire                   rx_sync     ;
wire                   check_finish;

//if cmd_valid, cmd_ready pull down first
//wait for workdone, cmd_ready pull up again
always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		cmd_ready <= 1'b1;
	else if(work_done)
		cmd_ready <= 1'b1;
	else if(cmd_valid)
		cmd_ready <= 1'b0;
end 

//set a buffer to store the cmd_data temporaily
//otherwise the cmd_data may be lost
always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		cmd_buf <= {CMD_WIDTH{1'b0}};
	else if(cmd_valid && cmd_ready)
		cmd_buf <= cmd_data;    // the datas can be stored only when the handshake is successful 
end 

assign {cmd_data_high,cmd_data_low} = cmd_buf; // split cmd_buf
assign rw_flag = cmd_buf[CMD_WIDTH-1];//extract rw flag

//pay attention to the priority
always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		work_en <= 1'b0;
	else if(work_done)
		work_en <= 1'b0;
	else if(cmd_valid)
		work_en <= 1'b1;
end 

//cnt 0~433
//here without else uart_bit_cnt <= 9'd0 is OK
//the last time  uart_bit_cnt counts to 433, then it turns into 0 and work_en pulled down
always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		uart_bit_cnt <= 9'd0;
	else if(work_en && ~delay_en)begin
		if(uart_bit_cnt==9'd433)
			uart_bit_cnt <= 9'd0;
		else	
			uart_bit_cnt <= uart_bit_cnt + 1'b1;
	end 
end 	

//uart bit index 
//if uart bit cnt == 433 a bit has been sent
always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		uart_bit_num <= 4'd0;
	else if(work_en && ~delay_en)begin
		if(uart_bit_cnt==9'd433)
			uart_bit_num <= uart_bit_num + 1'b1;
	end 
	else
		uart_bit_num <= 4'd0;
end 

//uart_bit_num == 10 means high 8 bits has been sent
//workdone wr_data_flag pull down again
always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		wr_data_flag <= 1'b0;
	else if(work_done)
		wr_data_flag <= 1'b0;
	else if(rw_flag && uart_bit_num==4'd10 && uart_bit_cnt==9'd433)
		wr_data_flag <= 1'b1;   //wr_data_flag==1 means to send the second byte
end 

//tx send process
//0 read 1 write
//read send once  write send twice 
//a delay between two send
//uart data lower bit first 
//control uart_bit_cnt and uart_bit_num
always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		tx <= 1'b1;
	else if(work_en)begin
		if(uart_bit_num==4'd0)
			tx <= 1'b0;
		else if(uart_bit_num>=4'd1 && uart_bit_num<=4'd8) begin
			if(~rw_flag)
				tx <= cmd_data_high[uart_bit_num - 1'b1];
			else
				tx <= wr_data_flag ? cmd_data_low[uart_bit_num-1'b1] : cmd_data_high[uart_bit_num-1'b1];
		end
		else if(uart_bit_num==4'd9)begin
			if(~rw_flag)
				tx <= ~^cmd_data_high;
			else
				tx <= wr_data_flag : ~^cmd_data_low : ~^cmd_data_high;
		end
        else
            tx <= 1'b1; // without this code is wrong, the stop bit may be 0 without it
	end
	else
		tx <= 1'b1;
end 

// delay 100 clks
always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		delay_en <= 1'b0;
	else if(delay_cnt==7'd99)
		delay_en <= 1'b0;
	else if(rw_flag && uart_bit_num==4'd10 && uart_bit_cnt==9'd433)
		delay_en <= 1'b1;
end 

always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		delay_cnt <= 7'd0;
	else if(delay_en)
		delay_cnt <= delay_cnt + 1'b1;
	else
		delay_cnt <= 7'd0;
end 
/*
work_done = ~rw_flag && uart_bit_num == 4'd10 && uart_bit_cnt==9'd433 ||
rw_flag && uart_bit_num == 4'd10 && uart_bit_cnt==9'd433 && wr_data_flag
= (~A)B + ABC = B(~A+C)
*/ 
assign work_done =  (~rw_flag || wr_data_flag) && uart_bit_num==4'd10 && uart_bit_cnt==9'd433;



//detect negedge using a shift register 
always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		rx_dly <= 3'b000;
	else
		rx_dly <= {rx_dly[1:0],rx};
end 

assign nedge_rx = rx_dly[2:1]==2'b10; 

assign rx_sync  = rx_dly[2];

always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		rx_work_en <= 1'b0;
	else if(rx_work_done)
		rx_work_en <= 1'b0;
	else if(nedge_rx)
		rx_work_en <= 1'b1;
end 

alway@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        rx_bit_cnt <= 9'd0;
    else if(rx_work_en) begin
        if(rx_bit_cnt == 9'd433)
            rx_bit_cnt <= 9'd0;
        else
            rx_bit_cnt <= rx_bit_cnt + 1'b1;    
    end
end

alway@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        rx_bit_num <= 4'd0;
    else if(rx_work_en) begin
        if(rx_bit_cnt == 9'd433)
            rx_bit_num <= rx_bit_num + 1'b1;
    end
    else
        rx_bit_num <= 4'd0; // reset rx_bit_num
end

//serial to parallel,lower bit first, put rx_sync at the top, then right shift
//sample the medium value
//rx is async with clk, delay 2 beats
always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		rx_data_buf <= 8'h0;
	else if(rx_bit_cnt==9'd216 && rx_bit_num>=4'd1 && rx_bit_num<=4'd8)
		rx_data_buf <= {rx_sync,rx_data_buf[7:1]}; 
end 

assign rx_work_done = rx_bit_cnt==9'd433 && rx_bit_num==4'd9;

// check the checkbit
assign check_finish = rx_bit_cnt==9'd216 && rx_bit_num==4'd9 && rx_sync==~^rx_data_buf;

assign read_valid = check_finish;

assign read_data  = rx_data_buf ;

endmodule
