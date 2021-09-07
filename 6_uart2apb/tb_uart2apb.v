`timescale 1ns/1ns

module tb_uart2apb();

reg                clk;
reg              rst_n;

reg                 rx;
wire                tx;

wire          apb_psel;
wire [15:0]  apb_paddr;
wire [31:0] apb_pwdata;
wire        apb_pwrite;
wire       apb_penable;

reg         apb_pready;
reg  [31:0] apb_prdata;	

integer I,J;

uart2apb u_uart2apb0(
        .clk(        clk),
      .rst_n(      rst_n),
         .rx(         rx),
         .tx(         tx),
   .apb_psel(   apb_psel),
  .apb_paddr(  apb_paddr),
 .apb_pwdata( apb_pwdata),
 .apb_pwrite( apb_pwrite),
.apb_penable(apb_penable),
 .apb_pready( apb_pready),
 .apb_prdata( apb_prdata)    
);

initial begin
    clk = 0; rst_n = 0;
    rx = 1; apb_pready = 1;
    apb_prdata = 32'd0;
    #50 rst_n = 1;
end

always #5 clk = ~clk;

initial begin
    #100 uart2apb_rx({8'hff, 8'h05, 8'h50, 8'h77, 8'ha4, 8'hc5, 8'ha5});
    #100 apb2uart_tx({8'h55, 8'h67, 8'ha9, 8'hcf});
end

task send_uart_byte;
input [7:0] din;
begin
    for(I = 0; I < 11; I = I+1)begin
    if(I == 0) begin
        rx <= 1'b0;
        repeat(433) @(posedge clk);
    end 
    else if(I >= 1 && I <= 8) begin
        rx <= din[I-1];
        repeat(433) @(posedge clk);
    end
    else if(I == 9) begin
        rx <= ~^din;
        repeat(433) @(posedge clk);
    end
    else begin
        rx <= 1'b1;
        repeat(433) @(posedge clk);
    end
    end
end
endtask

task uart2apb_rx;
input [55:0] data;
begin
    for(J = 0; J <= 6; J = J+1) begin
        send_uart_byte(data[J*8+:8]);
        repeat(50) @(posedge clk);
    end
    repeat(1000) @(posedge clk);
end
endtask

task apb2uart_tx;
input [31:0] prdata;
begin
    @(posedge clk) apb_pready <= 1'b0;
    send_uart_byte(8'h5a);
    repeat(50) @(posedge clk);
    send_uart_byte(8'h17);
    repeat(50) @(posedge clk);
    send_uart_byte(8'h71);
    repeat(50) @(posedge clk);
    @(posedge clk) begin
        apb_prdata <= prdata;
        apb_pready <= 1'b1;
    end
    @(posedge clk) begin
        apb_prdata <= 32'd0;
        apb_pready <= 1'b0;
    end
    repeat(30000) @(posedge clk);
end
endtask

endmodule