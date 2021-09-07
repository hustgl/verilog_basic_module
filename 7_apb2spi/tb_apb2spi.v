`timescale 1ns/1ns

module tb_apb2spi();

parameter APB_ADDR_WIDTH = 16;
parameter APB_DATA_WIDTH = 32;

reg                       clk        ;
reg                       rst_n      ;
reg                       apb_sel    ;
reg                       apb_penable;
reg                       apb_pwrite ;

reg  [APB_ADDR_WIDTH-1:0] apb_paddr  ;
reg  [APB_DATA_WIDTH-1:0] apb_pwdata ;
wire                      apb_pready ;
wire [APB_DATA_WIDTH-1:0] apb_prdata ;

wire                      sclk       ;
wire                      cs         ;
wire                      mosi       ; 
reg                       miso       ;

integer I;

apb2spi apb2spi_u0(
    .clk        (clk        ),
    .rst_n      (rst_n      ),
    .apb_sel    (apb_sel    ),
    .apb_penable(apb_penable),
    .apb_pwrite (apb_pwrite ),
    .apb_paddr  (apb_paddr  ),
    .apb_pwdata (apb_pwdata ),
    .apb_pready (apb_pready ),
    .apb_prdata (apb_prdata ),
    .sclk       (sclk       ),
    .cs         (cs         ),
    .mosi       (mosi       ),
    .miso       (miso       )
);

initial begin
clk = 0; rst_n = 0;
miso = 0; apb_psel = 0;
apb_penable = 0; apb_pwrite = 0;
#50 rst_n = 1;    
end

initial begin
#100 apb_w_send;
apb_r_send(16'hb843,32'h6547c3d5);
repeat(100) @(posedge clk);    
end

always #5 clk = ~clk;

task apb_w_send;
begin
    @(posedge clk) begin
        apb_psel   <= 1'b1;
        apb_paddr  <= 16'ha579;
        apb_pwrite <= 1'b1;
        apb_pwdata <= {8'ha3, 8'h77, 8'h43, 8'hf3};    
    end
    @(posedge clk) begin
        apb_penable <= 1'b1;
    end
    @(posedge clk) begin
        apb_psel    <= 1'b0;
        apb_paddr   <= 16'd0;
        apb_pwrite  <= 1'b0;
        apb_pwdata  <= 32'd0;    
        apb_penable <= 1'b0;        
    end
    repeat(600) @(posedge clk);
end
endtask

task apb_r_send;
input [15:0] apb_paddr1;
input [31:0] spi_rdata ;
begin
    @(posedge clk) begin
        apb_psel   <= 1'b1;
        apb_paddr  <= apb_paddr1;
        apb_pwrite <= 1'b0;
    end
    @(posedge clk) begin
        apb_penable <= 1'b1;
    end
    repeat(170+50) @(posedge clk); 
    for(I = 0; I < 32; I = I+1) begin
        @(posedge clk)
            miso <= spi_rdata[31-I];
        repeat(9) @(posedge clk);     
    end
    wait(apb_pready == 1'b1);
    @(posedge clk) begin
        apb_psel    <= 1'b0;
        apb_penable <= 1'b0;
        apb_paddr   <= 16'd0;
    end
end
endtask

endmodule