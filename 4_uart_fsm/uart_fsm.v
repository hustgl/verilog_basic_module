module uart_fsm #(
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
	
reg  [CMD_WIDTH-1:0] cmd_buf       ;  // store the cmd temporarily


wire                 uart_bit_cnt_en  ;
wire                 uart_clk_cnt_en  ;
wire                 uart_delay_cnt_en;
reg  [8:0]           uart_clk_cnt     ;  
reg  [2:0]           uart_bit_cnt     ;
reg  [6:0]           uart_delay_cnt   ;

wire [7:0]           cmd_high_byte    ;
wire [7:0]           cmd_low_byte     ;

reg  [4:0]           fsm_cs           ;
reg  [4:0]           fsm_ns           ;

wire                 rx_sync          ;
reg  [3:0]           rx_delay         ;
reg  [7:0]           rx_data_buffer   ;
wire                 rx_nedge         ;
reg                  read_valid_buf   ;



assign {cmd_high_byte,cmd_low_byte} = cmd_buf;

localparam  IDLE            = 5'd0 ,
			RW_JUDGE        = 5'd1 ,
			W0_START_BIT    = 5'd2 ,
			W0_DATA_BIT     = 5'd3 ,
			W0_CHECK_BIT    = 5'd4 ,
			W0_STOP_BIT     = 5'd5 ,
			W_DELAY         = 5'd6 ,
			W1_START_BIT    = 5'd7 ,
			W1_DATA_BIT     = 5'd8 ,
			W1_CHECK_BIT    = 5'd9 ,
			W1_STOP_BIT     = 5'd10,
			R_CMD_START_BIT = 5'd11,
			R_CMD_DATA_BIT  = 5'd12,
			R_CMD_CHECK_BIT = 5'd13,
			R_CMD_STOP_BIT  = 5'd14,
			
			RCV_RX_WAIT     = 5'd15,

			RCV_RX_START_BIT= 5'd16,//RX
			RCV_RX_DATA_BIT = 5'd17,
			RCV_RX_CHECK_BIT= 5'd18,
			SEND_READ_DATA  = 5'd19;

always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		fsm_cs <= IDLE;
	else
		fsm_cs <= fsm_ns;
end 

always @ (*)
begin
	case(fsm_cs)
		IDLE:
			begin
				if(cmd_valid)
					fsm_ns = RW_JUDGE;
				else
					fsm_ns = IDLE;
			end 
		RW_JUDGE:  
			begin
				fsm_ns = cmd_buf[CMD_WIDTH-1] ? W0_START_BIT : R_CMD_START_BIT;
			end 
		W0_START_BIT:
			begin
				if(uart_clk_cnt==9'd433)
					fsm_ns = W0_DATA_BIT;
				else
					fsm_ns = W0_START_BIT;
			end 
		W0_DATA_BIT:
			begin
				if(uart_clk_cnt==9'd433 && uart_bit_cnt==3'd7)
					fsm_ns = W0_CHECK_BIT;
				else
					fsm_ns = W0_DATA_BIT;
			end 
		W0_CHECK_BIT:
			begin
				if(uart_clk_cnt==9'd433)
					fsm_ns = W0_STOP_BIT;
				else
					fsm_ns = W0_CHECK_BIT;
			end：
		W0_STOP_BIT:
			begin
				if(uart_clk_cnt==9'd433)
					fsm_ns = W_DELAY;
				else
					fsm_ns = W0_STOP_BIT;
			end				   
		W_DELAY:	
			if(uart_delay_cnt==7'd99)
				fsm_ns = W1_START_BIT;
			else
				fsm_ns = W_DELAY;
		W1_START_BIT:
			begin
				if(uart_clk_cnt==9'd433)
					fsm_ns = W1_DATA_BIT;
				else
					fsm_ns = W1_START_BIT;
			end 			   
		W1_DATA_BIT:
			begin
				if(uart_clk_cnt==9'd433 && uart_bit_cnt==3'd7)
					fsm_ns = W1_CHECK_BIT;
				else
					fsm_ns = W1_DATA_BIT;	
			end
		W1_CHECK_BIT:
			begin
				if(uart_clk_cnt==9'd433)
					fsm_ns = W1_STOP_BIT;
				else
					fsm_ns = W1_CHECK_BIT;				
			end    
		W1_STOP_BIT:
			begin
				if(uart_clk_cnt==9'd433)
					fsm_ns = IDLE;
				else
					fsm_ns = W1_STOP_BIT;				
			end  		     
		R_CMD_START_BIT:
			if(uart_clk_cnt==9'd433)
				fsm_ns = R_CMD_DATA_BIT;
			else	
				fsm_ns = R_CMD_START_BIT;
		R_CMD_DATA_BIT:
			if(uart_clk_cnt==9'd433 && uart_bit_cnt==3'd7)
				fsm_ns = R_CMD_CHECK_BIT;
			else
				fsm_ns = R_CMD_DATA_BIT;
		R_CMD_CHECK_BIT:
			if(uart_clk_cnt==9'd433)
				fsm_ns = R_CMD_STOP_BIT;
			else
				fsm_ns = R_CMD_CHECK_BIT;
		R_CMD_STOP_BIT:
			if(uart_clk_cnt==9'd433)
				fsm_ns = RX_WAIT;
			else	
				fsm_ns = R_CMD_STOP_BIT;
		RCV_RX_WAIT:
			if(rx_nedge)
				fsm_ns = RCV_RX_START_BIT;
			else
				fsm_ns = RCV_RX_WAIT;
		RCV_RX_START_BIT:
			if(uart_clk_cnt==9'd433)
				fsm_ns = RCV_RX_DATA_BIT;
			else:
				fsm_ns = RCV_RX_START_BIT;
		RCV_RX_DATA_BIT:
			if(uart_clk_cnt==9'd433 && uart_bit_cnt==3'd7)
				fsm_ns = RCV_RX_CHECK_BIT;
			else
				fsm_ns = RCV_RX_DATA_BIT;
		RCV_RX_CHECK_BIT:
			if(uart_clk_cnt==9'd433)
				fsm_ns = SEND_READ_DATA;
			else:
				fsm_ns = RCV_RX_CHECK_BIT;			
		SEND_READ_DATA:
				fsm_ns = IDLE;
		default: fsm_ns = IDLE;
	endcase 
end 

assign cmd_ready = fsm_cs==IDLE;
assign uart_clk_cnt_en = fsm_cs==W0_START_BIT || fsm_cs==W0_DATA_BIT || fsm_cs==W0_CHECK_BIT || fsm_cs==W0_STOP_BIT 
|| fsm_cs==W1_START_BIT || fsm_cs==W1_DATA_BIT || fsm_cs==W1_CHECK_BIT || fsm_cs==W1_STOP_BIT
|| fsm_cs==R_CMD_START_BIT || fsm_cs==R_CMD_DATA_BIT || fsm_cs==R_CMD_CHECK_BIT || fsm_cs==R_CMD_STOP_BIT
|| fsm_cs==RCV_RX_START_BIT || fsm_cs==RCV_RX_DATA_BIT || fsm_cs==RCV_RX_CHECK_BIT;

assign uart_bit_cnt_en = fsm_cs==W0_DATA_BIT || fsm_cs==W1_DATA_BIT || fsm_cs==R_CMD_DATA_BIT || fsm_cs==RCV_RX_DATA_BIT ;
assign uart_delay_cnt_en = fsm_cs==W_DELAY;

always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		cmd_buf <= {CMD_WIDTH{1'b0}};
	else if(fsm_cs==IDLE && cmd_valid)
		cmd_buf <= cmd_data;
end 

always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		uart_clk_cnt <= 9'd0;
	else if(uart_clk_cnt_en)begin
		if(uart_clk_cnt==9'd433)
			uart_clk_cnt <= 9'd0;
		else
			uart_clk_cnt <= uart_clk_cnt + 1'b1;
	end
	else
		uart_clk_cnt <= 9'd0;
end 

always @ (posedge clk or negedge rst_n)
begin
	if(!rst_n)
		uart_bit_cnt <= 3'd0;
	else if(uart_bit_cnt_en)begin
		if(uart_clk_cnt==9'd433)
			uart_bit_cnt <= uart_bit_cnt + 1'b1;
	end
	else
		uart_bit_cnt <= 3'd0;
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		uart_delay_cnt <= 7'd0;
	else if(uart_delay_cnt_en)
		if(uart_delay_cnt == 7'd99)
			uart_delay_cnt <= 7'd0;
		else
			uart_delay_cnt <= uart_delay_cnt + 1'b1;
	else
		uart_delay_cnt <= 7'd0;		
end

always @ (*)
begin
	if(fsm_cs==W0_START_BIT|| fsm_cs==W1_START_BIT || fsm_cs==R_CMD_START_BIT)
		tx = 1'b0;
	else if(fsm_cs==W0_DATA_BIT || fsm_cs==R_CMD_DATA_BIT)
		tx = cmd_high_byte[uart_bit_cnt];
	else if(fsm_cs==W1_DATA_BIT)
		tx = cmd_low_byte[uart_bit_cnt];
	else if(fsm_cs==W0_CHECK_BIT || fsm_cs==R_CMD_CHECK_BIT)
		tx = ~^cmd_high_byte;
	else if(fsm_cs==W1_CHECK_BIT)
		tx = ~^cmd_low_byte;
	else
		tx = 1'b1;
end

always@(posedge clk or negedge rst_n) 
begin
	if(!rst_n)
		rx_delay <= 3'd0;
	else
	    rx_delay <= {rx_delay[1:0],rx};
end

assign rx_nedge = rx_delay[2:1] == 2'b10;
assign rx_sync  = rx_delay[2];

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		rx_data_buffer <= 8'd0;
	else if(fsm_cs == RCV_RX_DATA_BIT && uart_clk_cnt == 9'd216)
		rx_data_buffer <= {rx_sync,rx_data_buffer[7:1]};	
end

always @(posedge clk or negedge rst_n) begin
if(!rst_n)
	read_valid_buf <= 1'b0;
else if(fsm_cs == SEND_READ_DATA)
	read_valid_buf <= 1'b0;
else if(fsm_cs==RCV_RX_CHECK_BIT && uart_clk_cnt==9'd216 && rx_sync==~^rx_data_buffer)	
	read_valid_buf <= 1'b1;		
end

assign read_valid = (fsm_cs==SEND_READ_DATA && read_valid_buf)? 1'b1:1'b0;
assign read_data = rx_data_buffer;


endmodule