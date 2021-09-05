`timescale 1ns/1ns
module tb_spi_fsm();

parameter RW_FLAG    = 1;
parameter ADDR_WIDTH = 3;
parameter DATA_WIDTH = 8;
parameter CMD_WIDTH  = RW_FLAG + ADDR_WIDTH + DATA_WIDTH;

reg                         clk;
reg                       rst_n;
reg                   cmd_valid;
wire                  cmd_ready;
reg  [CMD_WIDTH-1:0]   cmd_data;
wire                 read_valid;
wire [DATA_WIDTH-1:0] read_data;
wire                       sclk;
wire                         cs;
wire                       mosi;
reg                        miso;

localparam IDLE           = 4'd0,
           W_SEND         = 4'd1,
           R_SEND_CMD     = 4'd2,
           R_DELAY        = 4'd3,
           R_REV_DATA     = 4'd4,
           SEND_READ_DATA = 4'd5;

spi_fsm #(
    .RW_FLAG(RW_FLAG),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .CMD_WIDTH(CMD_WIDTH)
) u_spi_fsm0(
    .clk(clk),
    .rst_n（rst_n),
    .cmd_valid(cmd_valid),
    .cmd_ready(cmd_ready),
    .cmd_data(cmd_data),
    .read_valid(read_valid),
    .read_data(read_data),
    .sclk(sclk),
    .cs(cs),
    .mosi(mosi),
    .miso(miso)
);

integer I;

initial begin
    clk = 0; rst_n = 0；
    miso = 0; cmd_valid = 0;
    cmd_data = {CMD_WIDTH{1'b0}};
    #50 rst_n = 1;
end

always #5 clk = ~clk;

initial begin
    #100 spi_send;
    #100 spi_recv(8'b01011101);
    $finish;
end

task spi_send;
begin
    @(posedge clk) begin
        cmd_data  <= {1'b1,3'b101,8'b11101010};
        cmd_valid <= 1'b1;
    end
    @(posedge clk) begin
        cmd_data  <= {CMD_WIDTH{1'b0}};
        cmd_valid <= 1'b0;        
    end
    repeat(150) @(posedge clk); // delay enough clks >10*12
end
endtask

task spi_recv;
input [DATA_WIDTH-1:0] miso_data;
begin
    @(posedge clk) begin
        cmd_data  <= {1'b0,3'b101,8'b00000000};
        cmd_valid <= 1'b1;
    end
    @(posedge clk) begin
        cmd_data  <= {CMD_WIDTH{1'b0}};
        cmd_valid <= 1'b0;        
    end
    repeat(220) @(posedge clk);
    for(I = 0; I < DATA_WIDTH; I = I+1) begin
        miso <= miso_data[DATA_WIDTH-1 - I];
        repeat(10) @(posedge clk);
    end
    repeat(10) @(posedge clk);
end
endtask


endmodule