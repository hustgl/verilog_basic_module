module apb2spi #(
    parameter APB_ADDR_WIDTH = 16,
    parameter APB_DATA_WIDTH = 32
)(
    input                       clk        ,
    input                       rst_n      ,
    input                       apb_sel    ,
    input                       apb_penable,
    input                       apb_pwrite ,

    input  [APB_ADDR_WIDTH-1:0] apb_paddr  ,
    input  [APB_DATA_WIDTH-1:0] apb_pwdata ,
    output                      apb_pready ,
    output [APB_DATA_WIDTH-1:0] apb_prdata ,

    output                      sclk       ,
    output                      cs         ,
    output                      mosi       , 
    input                       miso
);

parameter IDLE           = 3'd0,
          W_WAIT         = 3'd1,
          W_CMD_SEND     = 3'd2,
          R_CMD_SEND     = 3'd3,
          R_DELAY        = 3'd4,
          R_RCV_DATA     = 3'd5,
          APB_RDATA_SEND = 3'd6;

reg [2:0] fsm_cs;
reg [2:0] fsm_ns;

reg [3:0] spi_clk_cnt   ;
reg [5:0] spi_bit_cnt   ;
reg [5:0] delay_cnt     ;
wire      spi_clk_cnt_en;  
wire      delay_cnt_en  ;

reg  [48:0] cmd_buf   ;
wire [16:0] r_cmd     ;
reg  [31:0] prdata_buf;

always @(posedge clk or negedge rst_n) begin
if(!rst_n)    
    fsm_cs <= 3'd0;
else
    fsm_cs <= fsm_ns;    
end

always @(*) begin
case(fsm_cs)
    IDLE:begin
        if(apb_psel)
            fsm_ns = apb_pwrite? W_WAIT:R_CMD_SEND;
        else
            fsm_ns = IDLE;   
    end
    W_WAIT:
        fsm_ns = W_CMD_SEND;
    W_CMD_SEND:begin
        if(spi_clk_cnt==4'd9 && spi_bit_cnt==6'd48)
            fsm_ns = IDLE；
        else
            fsm_ns = W_CMD_SEND;    
    end
    R_CMD_SEND:begin
        if(spi_clk_cnt==4'd9 && spi_bit_cnt==6'd16)
            fsm_ns = R_DELAY;
        else
            fsm_ns = R_CMD_SEND;        
    end
    R_DELAY:begin
        if(delay_cnt == 6'd49)
            fsm_ns = R_RCV_DATA;
        else
            fsm_ns = R_DELAY;
    end
    R_RCV_DATA:begin
        if(spi_clk_cnt==4'd9 && spi_bit_cnt==6'd31)
            fsm_ns = APB_RDATA_SEND;
        else
            fsm_ns = R_RCV_DATA;    
    end
    APB_RDATA_SEND:
        fsm_ns = IDLE;
endcase    
end

assign spi_clk_cnt_en = fsm_cs==W_CMD_SEND || fsm_cs==R_CMD_SEND 
|| fsm_cs==R_RCV_DATA;

always @(posedge clk or negedge rst_n) begin
if(!rst_n)
    spi_clk_cnt <= 4'd0;
else if(spi_clk_cnt_en)begin
    if(spi_clk_cnt == 4'd9)
        spi_clk_cnt <= 4'd0;
    else
        spi_clk_cnt <= spi_clk_cnt + 4'd1;     
end        
end

always @(posedge clk or negedge rst_n) begin
if(!rst_n)  
    spi_bit_cnt <= 6'd0;
else if(spi_clk_cnt_en)begin
    if(spi_clk_cnt == 4'd9)
        spi_bit_cnt <= spi_bit_cnt + 6'd1; 
end    
else
    spi_bit_cnt <= 6'd0;
end

always @(posedge clk or negedge rst_n) begin
if(!rst_n)  
    cmd_buf <= 49'd0;
else if(fsm_cs == W_WAIT)
    cmd_buf <= {1'b1,apb_paddr,apb_pwdata};    
end

assign r_cmd = {1'b0, apb_paddr};

assign sclk = (spi_clk_cnt >= 6'd5)? 1'b1:1'b0;
assign cs   = spi_clk_cnt_en || fsm_cs==R_DELAY;
assign miso = (fsm_cs == W_CMD_SEND)? cmd_buf[6'd48-spi_bit_cnt]:
              (fsm_cs == R_CMD_SEND)? r_cmd[6'd16-spi_bit_cnt]:1'b0;

assign apb_pready = fsm_cs==W_WAIT || fsm_cs==APB_RDATA_SEND;

always @(posedge clk or negedge rst_n) begin
if(!rst_n)
    prdata_buf <= 32'd0;
else if(fsm_cs==R_RCV_DATA && spi_clk_cnt==6'd5) 
    prdata_buf <= {prdata_buf[30:0],miso};      
end

assign apb_prdata = prdata_buf;

assign delay_cnt_en = fsm_cs==R_DELAY;

always @(posedge clk or negedge rst_n) begin
if(!rst_n)    
    delay_cnt <= 6'd0;
else if(delay_cnt_en)begin
    if(delay_cnt == 6'd49)
        delay_cnt <= 6'd0;
    else
        delay_cnt <= delay_cnt + 6'd1;    
end    
end
     
endmodule