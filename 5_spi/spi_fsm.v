//clk 100M sclk 10M
module spi_fsm #(
  parameter RW_FLAG    = 1,
  parameter ADDR_WIDTH = 3,
  parameter DATA_WIDTH = 8,
  parameter CMD_WIDTH  = RW_FLAG + ADDR_WIDTH + DATA_WIDTH
)(
    input                         clk,
    input                       rst_n,
    input                   cmd_valid,
    output                  cmd_ready,
    input  [CMD_WIDTH-1:0]   cmd_data,
    output                 read_valid,
    output [DATA_WIDTH-1:0] read_data,
    output reg                   sclk,
    output reg                     cs,
    output reg                   mosi,
    input                        miso
);

reg [CMD_WIDTH-1:0]  cmd_data_buffer;
reg [3:0]            spi_clk_cnt    ;
reg [3:0]            spi_bit_cnt    ;
reg [DATA_WIDTH-1:0] miso_buffer    ;
reg [6:0]            delay_cnt      ;

reg [2:0] fsm_cs;
reg [2:0] fsm_ns;

localparam IDLE           = 4'd0,
           W_SEND         = 4'd1,
           R_SEND_CMD     = 4'd2,
           R_DELAY        = 4'd3,
           R_REV_DATA     = 4'd4,
           SEND_READ_DATA = 4'd5;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)   
        fsm_cs <= IDLE;
    else
        fsm_cs <= fsm_ns;     
end

always@(*) begin
case(fsm_cs)
    IDLE:
        if(cmd_valid) 
            fsm_ns = cmd_data[11]? W_SEND : R_SEND_CMD;
        else
            fsm_ns = IDLE;        
    W_SEND:
        if(spi_clk_cnt == 4'd9 && spi_bit_cnt == 4'd11)
            fsm_ns = IDLE;
        else
            fsm_ns = W_SEND;    
    R_SEND_CMD:
        if(spi_clk_cnt == 4'd9 && spi_bit_cnt == 4'd11)
            fsm_ns = R_DELAY;
        else
            fsm_ns = R_SEND_CMD;    
    R_DELAY:
        if(delay_cnt == 7'd99)
            fsm_ns = R_REV_DATA;
        else
            fsm_ns = R_DELAY;    
    R_REV_DATA:
        if(spi_clk_cnt == 4'd9 && spi_bit_cnt == 4'd7)
            fsm_ns = SEND_READ_DATA;
        else
            fsm_ns = R_REV_DATA;    
    SEND_READ_DATA:
        fsm_ns = IDLE;
    default: fsm_ns = IDLE;
endcase
end
/*
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)    
end*/
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)    
        cmd_data_buffer <= {DATA_WIDTH{1'b0}};
    else if(cmd_valid && cmd_ready)
        cmd_data_buffer <= cmd_data;
end

assign cmd_ready = fsm_cs == IDLE ;
assign spi_clk_cnt_en = fsm_cs==W_SEND || fsm_cs == R_SEND_CMD || fsm_cs == R_REV_DATA;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        spi_clk_cnt <= 4'd0;
    else if(spi_clk_cnt_en) begin
        if(spi_clk_cnt == 4'd9)
            spi_clk_cnt <= 4'd0;
        else
            spi_clk_cnt <= spi_bit_cnt + 1'b1;    
    end
    else
        spi_clk_cnt <= 4'd0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        spi_bit_cnt <= 4'd0;
    else if(spi_clk_cnt_en) begin
        if(spi_clk_cnt == 4'd9)
            spi_bit_cnt <= spi_bit_cnt + 1'b1;
    end
    else
        spi_bit_cnt <= 4'd0;        
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)  
        delay_cnt <= 7'd0;
    else if(fsm_cs == R_DELAY)
        delay_cnt <= delay_cnt + 1'b1;
    else
        delay_cnt <= 7'd0;          
end

assign cs = (fsm_cs == IDLE)? 1:0;
assign sclk = (spi_clk_cnt >= 4'd5)? 1:0;

always @(*) begin
    if(fsm_cs == W_SEND || fsm_cs == R_SEND_CMD)
        mosi = cmd_data_buffer[CMD_WIDTH-1 - spi_bit_cnt];
    else
        mosi = 1'b0;        
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)    
        miso_buffer <= {DATA_WIDTH{1'b0}};
    else if(fsm_cs == R_REV_DATA && spi_clk_cnt == 4'd5)
        miso_buffer <= {miso_buffer[DATA_WIDTH-2:0],miso};
end

assign read_valid = fsm_cs==SEND_READ_DATA;
assign read_data  = miso_buffer           ;

endmodule