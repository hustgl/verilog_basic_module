`timescale 1ns/1ns
module tb_uart();

parameter CMD_ADDR_WIDTH = 7;
parameter CMD_DATA_WIDTH = 8;
parameter CMD_RW_FLAG    = 1;
parameter CMD_WIDTH      = CMD_ADDR_WIDTH + CMD_DATA_WIDTH + CMD_RW_FLAG;

reg                             clk;
reg                           rst_n;

reg                       cmd_valid;
reg  [CMD_WIDTH-1:0]       cmd_data;
wire                      cmd_ready;

wire                     read_valid;
wire [CMD_DATA_WIDTH-1:0] read_data;

wire                             tx;
reg                              rx;

integer II;

uart #(
    .CMD_ADDR_WIDTH(CMD_ADDR_WIDTH),
    .CMD_DATA_WIDTH(CMD_DATA_WIDTH),
    .CMD_RW_FLAG(CMD_RW_FLAG)      ,
    .CMD_WIDTH(CMD_WIDTH)
)u_uart0(
    .clk(clk)              ,
    .rst_n(rst_n)          ,
    .cmd_valid(cmd_valid)  ,
    .cmd_data(cmd_data)    ,
    .cmd_ready(cmd_ready)  ,
    .read_valid(read_valid),
    .read_data(read_data)  ,
    .tx(tx)                ,
    .rx(rx)
);

initial begin
    clk = 0; rst_n = 0; #50 rst_n = 1;
end

always #5 clk = ~clk;

initial begin
    cmd_valid = 1'b0;
    cmd_data  = {CMD_WIDTH{1'b0}};
    rx        = 1'b1;
end

initial begin
    $fsdbDumpfile("uart_fsm.fsdb");
    $fsdbDumpvars;
end

initial begin
    #100 send_tx;
    #100 send_rx(8'h35);
    $finish;
end

task send_tx;
begin
    @(posedge clk) begin
        cmd_valid <= 1'b1;
        cmd_data  <= {1'b1,7'd100,8'hab};
    end
    @(posedge clk) begin
        cmd_valid <= 1'b0;
        cmd_data  <= {CMD_WIDTH{1'b0}};
    end
    repeat(10000) @(posedge clk);  // >2*11*434
end
end
endtask

task send_rx;
input [7:0] data_in;
begin
    fork
        begin
            @(posedge clk) begin
                cmd_valid <= 1'b1;
                cmd_data  <= {1'b0,7'd100,8'h00};
            end
            @(posedge clk) begin
                cmd_valid <= 1'b0;
                cmd_data  <= 16'h0000;
            end            
        end
        begin
            repeat(5000) @(posedge clk); //wait for command to be sent
            @(posedge clk) rx <= 1'b1;
            repeat(100) @(posedge clk);  //generate a negedge 
            @(posedge clk) rx <= 1'b0;
            repeat(437) @(posedge clk);
            for(II = 0; II < 8; II = II + 1)begin
                @(posedge clk) rx <= data_in[II];
                repeat(434) @(posedge clk);
            end
            @(posedge clk) rx = ~^data_in;
            repeat(434) @(posedge clk);
            @(posedge clk) rx = 1'b1;
            repeat(434) @(posedge clk);
            repeat(100) @(posedge clk);
        end
    join
end
end
endtask

endmodule