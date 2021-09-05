module uart2apb #(
	parameter APB_ADDR_WIDTH = 16,
	parameter APB_DATA_WIDTH = 32
)(
	input                clk,
	input              rst_n，
	
	input                 rx,
	output                tx,
	
	output          apb_psel,
	output [15:0]  apb_paddr,
	output [31:0] apb_pwdata,
	output        apb_pwrite,
	output       apb_penable,
	
	input         apb_pready,
	input  [31:0] apb_prdata	
);
/*
always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
	
end*/

localparam  IDLE            = 5'd0,
            RCV_CMD         = 5'd1,
            RCV_ADDR_LOW    = 5'd2,
            RCV_ADDR_HIGH   = 5'd3,
            RCV_WDATA_BYTE0 = 5'd4,
            RCV_WDATA_BYTE1 = 5'd5,
            RCV_WDATA_BYTE2 = 5'd6,
            RCV_WDATA_BYTE3 = 5'd7,
            APB_W_SEL       = 5'd8,
            APB_W_EN        = 5'd9,
            APB_R_SEL       = 5'd10,
            APB_R_EN        = 5'd11,
            APB_TX_BYTE0    = 5'd12,
            APB_TX_DELAY0   = 5'd13,
            APB_TX_BYTE1    = 5'd14,
            APB_TX_DELAY1   = 5'd15,
            APB_TX_BYTE2    = 5'd16,
            APB_TX_DELAY2   = 5'd17,
            APB_TX_BYTE3    = 5'd18;

reg [4:0] fsm_cs;
reg [4:0] fsm_ns;

//negedge detection
wire      rx_nedge;
reg [2:0] rx_delay;
wire       rx_sync;

//uart flag and buffer
reg                  uart_flag; // the flag of receiving a byte
reg [7:0]             uart_buf; // store the byte received temporarily
wire      uart_recv_state_flag; // the states of receving uart bytes

//classify the bytes received
reg        uart_addr_flag;
reg [1:0]  uart_wdata_cnt;
reg [7:0]    uart_cmd_buf;
reg [15:0]  uart_addr_buf;
reg [31:0] uart_wdata_buf;

//uart cnt
reg [3:0]    uart_bit_cnt;
reg [8:0]    uart_clk_cnt;
wire      uart_clk_cnt_en;


//APB buffer
reg [31:0]  apb_prdata_buf;
//uart tx buffer and cnt
wire [7:0] uart_tx_buf;
reg  [1:0] uart_rdata_cnt;
wire       uart_tx_state;
reg  [6:0] uart_delay_cnt;

//must handle uart datas byte by byte
always @(*) begin
    case(fsm_cs)
        IDLE:begin
            if(rx_nedge)
                fsm_ns = RCV_CMD;
            else
                fsm_ns = IDLE;        
        end
        RCV_CMD:begin
            // the negedge here means the start of RCV_ADDR_LOW
            if(rx_nedge && uart_flag) 
                fsm_ns = RCV_ADDR_LOW;
            else 
                fsm_ns = RCV_CMD;       
        end
        RCV_ADDR_LOW:begin
            if(rx_nedge && uart_flag)
                fsm_ns = RCV_ADDR_HIGH;
            else
                fsm_ns = RCV_ADDR_LOW; 
        end
        RCV_ADDR_HIGH:begin
            if(rx_nedge && uart_flag) begin
                if(uart_cmd_buf == 8'ha5)//a5 and 5a is user-defined
                    fsm_ns = RCV_WDATA_BYTE0;
                else if(uart_cmd_buf == 8'h5a)
                    fsm_ns = APB_R_SEL;
                else
                    fsm_ns = IDLE; //cmd error            
            end               
        end
        RCV_WDATA_BYTE0:begin
            if(rx_nedge && uart_flag)
                fsm_ns = RCV_WDATA_BYTE1;
            else
                fsm_ns = RCV_WDATA_BYTE0;        
        end
        RCV_WDATA_BYTE1:begin
            if(rx_nedge && uart_flag)
                fsm_ns = RCV_WDATA_BYTE2;
            else
                fsm_ns = RCV_WDATA_BYTE1;        
        end 
        RCV_WDATA_BYTE2:begin
            if(rx_nedge && uart_flag)
                fsm_ns = RCV_WDATA_BYTE3;
            else
                fsm_ns = RCV_WDATA_BYTE2;        
        end
        RCV_WDATA_BYTE3:begin
            if(uart_bit_cnt == 4'd10 && uart_clk_cnt == 9'd433)
                fsm_ns = APB_W_SEL;
            else
                fsm_ns = RCV_WDATA_BYTE3;        
        end
        APB_W_SEL:
            fsm_ns = APB_W_EN;
        APB_W_EN:begin
            if(apb_pready) 
                fsm_ns = IDLE;
            else
                fsm_ns = APB_W_EN;    
        end
        APB_R_SEL:begin
            fsm_ns = APB_R_EN;
        end
        APB_R_EN:begin
            if(apb_pready)
                fsm_ns = SEND_TX_BYTE0;
            else
                fsm_ns = APB_R_EN;    
        end
        SEND_TX_BYTE0:begin
            if(uart_bit_cnt==4'd10 && uart_clk_cnt==9'd433)
                fsm_ns = SEND_TX_DELAY0;
            else
                fsm_ns = SEND_TX_BYTE0;        
        end
        SEND_TX_DELAY0:begin
            if(uart_delay_cnt == 7'd99)
                fsm_ns = SEND_TX_BYTE1;
            else
                fsm_ns = SEND_TX_DELAY0;    
        end
        SEND_TX_BYTE1:begin
            if(uart_bit_cnt==4'd10 && uart_clk_cnt==9'd433)
                fsm_ns = SEND_TX_DELAY1;
            else
                fsm_ns = SEND_TX_BYTE1;              
        end
        SEND_TX_DELAY1:begin
            if(uart_delay_cnt == 7'd99)
                fsm_ns = SEND_TX_BYTE2;
            else
                fsm_ns = SEND_TX_DELAY1;    
        end
        SEND_TX_BYTE2:begin
            if(uart_bit_cnt==4'd10 && uart_clk_cnt==9'd433)
                fsm_ns = SEND_TX_DELAY2;
            else
                fsm_ns = SEND_TX_BYTE2;              
        end 
        SEND_TX_DELAY2:begin
            if(uart_delay_cnt == 7'd99)
                fsm_ns = SEND_TX_BYTE3;
            else
                fsm_ns = SEND_TX_DELAY2;    
        end
        SEND_TX_BYTE3:begin
            if(uart_bit_cnt==4'd10 && uart_clk_cnt==9'd433)
                fsm_ns = IDLE;
            else
                fsm_ns = SEND_TX_BYTE3;              
        end
        default: fsm_ns = IDLE;                                
    endcase    
end

//uart recv logic
always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
	rx_delay <= 3'b000;
else
	rx_delay <= {rx_delay[1:0], rx};	
end

assign rx_nedge = rx_delay[2:1]==2'b10;
assign rx_sync  = rx_delay[2];

//receive a byte
assign uart_recv_state_flag = (fsm_cs==RCV_CMD || fsm_cs==RCV_ADDR_LOW || fsm_cs==RCV_ADDR_HIGH 
|| fsm_cs==RCV_WDATA_BYTE0 || fsm_cs==RCV_WDATA_BYTE1 || fsm_cs==RCV_WDATA_BYTE2 || fsm_cs==RCV_WDATA_BYTE3);

always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
	uart_flag <= 1'b0;
else if(rx_nedge)	
	uart_flag <= 1'b0;
else if(fsm_cs==SEND_TX_BYTE0 || fsm_cs==SEND_TX_BYTE1 || fsm_cs==SEND_TX_BYTE2 || fsm_cs==SEND_TX_BYTE3)    
    uart_flag <= 1'b0;
else if(uart_recv_state_flag && uart_bit_cnt == 4'd10 && uart_clk_cnt== 9'd433)	
	uart_flag <= 1'b1;//There may be a delay between bytes, pulled up after a byte
end

assign uart_clk_cnt_en = (fsm==RCV_CMD || fsm==RCV_ADDR_LOW || fsm==RCV_ADDR_HIGH 
|| fsm==RCV_WDATA_BYTE0 || fsm==RCV_WDATA_BYTE1 || fsm==RCV_WDATA_BYTE2 || fsm==RCV_WDATA_BYTE3
|| fsm==APB_TX_BYTE0 || fsm==APB_TX_BYTE1 || fsm==APB_TX_BYTE2 || fsm==APB_TX_BYTE3);

//~uart_flag is essential, cnt should be forbidden while uart delay
always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
	uart_clk_cnt <= 9'd0;
else if(uart_clk_cnt_en && ~uart_flag)	
	if(uart_clk_cnt == 9'd433)
		uart_clk_cnt <= 9'd0;
	else
		uart_clk_cnt <= uart_clk_cnt + 9'd1;
end

always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
	uart_bit_cnt <= 4'd0;
else if(uart_clk_cnt_en && ~uart_flag) begin
		if(uart_clk_cnt == 9'd433)
			uart_bit_cnt <= uart_bit_cnt + 4'd1;
end			
else
	uart_bit_cnt <= 4'd0;
end

always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
	uart_buf <= 8'd0;
else
	if(uart_clk_cnt == 9'd216 && uart_bit_cnt >= 4'd1 && uart_bit_cnt <=4'd9 && uart_recv_state_flag)
	uart_buf <= {rx_sync,uart_buf[7:1]};	
end

always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
	uart_cmd_buf <= 8'd0;
else if(fsm_cs==RCV_CMD && uart_clk_cnt==9'd216 && uart_bit_cnt==4'd9 && rx_sync==~^uart_buf)
	uart_cmd_buf <= uart_buf;	
end

always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
    uart_addr_flag <= 1'B0;
else if(fsm_cs == RCV_ADDR_LOW && uart_bit_cnt==4'd10 && uart_clk_cnt==9'd433)
	uart_addr_flag <= 1'b1;
else if(fsm_cs==IDLE || fsm_cs==APB_W_SEL || fsm_cs==APB_R_SEL)
	uart_addr_flag <= 1'b0;
end

always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
    uart_addr_buf <= 16'd0;
else if((fsm_cs==RCV_ADDR_LOW || fsm_cs==RCV_ADDR_HIGH) && uart_bit_cnt==4'd9 && uart_clk_cnt==9'd216 && ~^uart_buf==rx_sync)
    uart_addr_buf[uart_addr_flag*8+:8] <= uart_buf;        
end

always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
    uart_wdata_cnt <= 2'd0;
else if(fsm_cs == RCV_WDATA_BYTE0 && uart_bit_cnt==4'd10 && uart_clk_cnt==9'd433)  
    uart_wdata_cnt <= 2'd1;
else if(fsm_cs == RCV_WDATA_BYTE1 && uart_bit_cnt==4'd10 && uart_clk_cnt==9'd433) 
    uart_wdata_cnt <= 2'd2;
else if(fsm_cs == RCV_WDATA_BYTE2 && uart_bit_cnt==4'd10 && uart_clk_cnt==9'd433) 
    uart_wdata_cnt <= 2'd3; 
else if(fsm_cs==IDLE || fsm_cs==APB_W_SEL || fsm_cs==APB_R_SEL)
    uart_wdata_cnt <= 2'd0;           
end

always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
    uart_wdata_buf <= 31'd0;
else if((fsm_cs==RCV_WDATA_BYTE0 || fsm_cs==RCV_WDATA_BYTE1 || fsm_cs==RCV_WDATA_BYTE2 || fsm_cs==RCV_WDATA_BYTE3) && uart_bit_cnt==4'd9 && uart_clk_cnt==9'd216 && ~^uart_buf==rx_sync)
    uart_wdata_buf[uart_wdata_cnt*8+:8] <= uart_buf;        
end

assign apb_pwrite  = fsm_cs==APB_W_SEL|| fsm_cs==APB_W_EN;
assign apb_psel    = fsm_cs==APB_W_SEL|| fsm_cs==APB_W_EN || fsm_cs==APB_R_SEL || fsm_cs==APB_R_EN;
assign apb_penable = fsm_cs==APB_W_EN || fsm_cs==APB_R_EN;
assign apb_paddr   = uart_addr_buf;
assign apb_pwdata  = uart_wdata_buf;

always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
	apb_prdata_buf <= 32'd0;
else if(apb_psel && apb_penable && apb_pready)
	apb_prdata_buf <= apb_prdata;¸		
end

always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
    uart_rdata_cnt <= 2'd0;
else if(fsm_cs == SEND_TX_BYTE0 && uart_bit_cnt==4'd10 && uart_clk_cnt==9'd433)  
    uart_rdata_cnt <= 2'd1;
else if(fsm_cs == SEND_TX_BYTE1 && uart_bit_cnt==4'd10 && uart_clk_cnt==9'd433) 
    uart_rdata_cnt <= 2'd2;
else if(fsm_cs == SEND_TX_BYTE2 && uart_bit_cnt==4'd10 && uart_clk_cnt==9'd433) 
    uart_rdata_cnt <= 2'd3; 
else if(fsm_cs==IDLE || fsm_cs==APB_W_SEL || fsm_cs==APB_R_SEL)
    uart_rdata_cnt <= 2'd0;            
end

assign uart_tx_buf = apb_prdata_buf[uart_wdata_cnt*8+:8];
assign uart_tx_state = fsm_cs==SEND_TX_BYTE1 || fsm_cs==SEND_TX_BYTE1 || fsm_cs==SEND_TX_BYTE2 || fsm_cs==SEND_TX_BYTE3;

always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
    tx <= 1'b1;
else if(uart_tx_state && uart_bit_cnt==4'd0)
    tx <= 1'b0;
else if(uart_tx_state && uart_bit_cnt>=4'd1 && uart_bit_cnt<=4'd8)
    tx <= uart_tx_buf[uart_bit_cnt - 4'd1];
else if(uart_tx_state && uart_bit_cnt==4'd9)
    tx <= ~^uart_tx_buf;     
else
    tx <= 1'b1;      
end

assign uart_delay_cnt_en = fsm_cs==SEND_TX_DELAY0 || fsm_cs==SEND_TX_DELAY1 || fsm_cs==SEND_TX_DELAY2;
always@(posedge clk or negedge rst_n) 
begin
if(!rst_n)
    uart_delay_cnt <= 7'd0;
else if(uart_delay_cnt_en) begin
    if(uart_delay_cnt == 7'd99)
        uart_delay_cnt <= 7'd0;
    else
        uart_delay_cnt <= uart_delay_cnt + 7'd1;     
end
end
endmodule