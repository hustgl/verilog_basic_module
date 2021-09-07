`timescale 1ns/1ns
module tb_ahb2apb ();

parameter AHB_DATA_WIDTH = 32;
parameter AHB_ADDR_WIDTH = 32;
parameter APB_DATA_WIDTH = 32;
parameter APB_ADDR_WIDTH = 32;

reg                       ahb_hclk   ;
reg                       ahb_hrstn  ;
reg                       ahb_hsel   ;
reg  [1:0]                ahb_htrans ; 
reg  [AHB_ADDR_WIDTH-1:0] ahb_haddr  ;
reg  [AHB_DATA_WIDTH-1:0] ahb_hdata  ;
reg                       ahb_hwrite ;
wire                      ahb_hready ;
wire [AHB_DATA_WIDTH-1:0] ahb_rdata  ;

reg                       apb_pclk   ;
reg                       apb_prstn  ;
wire                      apb_psel   ;
wire                      apb_pwrite ;
wire                      apb_penable;
wire [APB_ADDR_WIDTH-1:0] apb_paddr  ;
wire [APB_DATA_WIDTH-1:0] apb_wdata  ;
reg                       apb_pready ;
reg  [APB_DATA_WIDTH-1:0] apb_prdata ;

ahb2apb u_ahb2apb0(
    .ahb_hclk   (ahb_hclk   ), 
    .ahb_hrstn  (ahb_hrstn  ), 
    .ahb_hsel   (ahb_hsel   ), 
    .ahb_htrans (ahb_htrans ), 
    .ahb_haddr  (ahb_haddr  ), 
    .ahb_hdata  (ahb_hdata  ), 
    .ahb_hwrite (ahb_hwrite ), 
    .ahb_hready (ahb_hready ), 
    .ahb_rdata  (ahb_rdata  ), 
    .apb_pclk   (apb_pclk   ), 
    .apb_prstn  (apb_prstn  ), 
    .apb_psel   (apb_psel   ), 
    .apb_pwrite (apb_pwrite ), 
    .apb_penable(apb_penable),
    .apb_paddr  (apb_paddr  ),
    .apb_wdata  (apb_wdata  ),
    .apb_pready (apb_pready ),
    .apb_prdata (apb_prdata )
);

initial begin
ahb_hclk = 0; ahb_hrstn = 0;
apb_pclk = 0; apb_prstn = 0;
#50 ahb_hrstn = 1; apb_prstn = 1;    
end

initial begin
ahb_hsel = 0; ahb_htrans = 0;
ahb_haddr = 0; ahb_hwdata = 0;
ahb_hwrite = 0; 
apb_pready = 0; apb_prdata = 0;    
end

always #5 ahb_hclk = ~ahb_hclk;
always #10 apb_pclk = ~apb_pclk;

initial begin
#100 send_write;
repeat(200) @(posedge ahb_hclk);
send_read;
repeat(200) @(posedge ahb_hclk);
$finish;    
end

task send_write;
begin
    fork
    begin
        @(posedge ahb_hclk) begin
            ahb_hsel   <= 1'b1;
            ahb_hwrite <= 1'b1;
            ahb_htrans <= 2'b10;
            ahb_haddr  <= 32'd100;
        end 
        #1 wait(ahb_hready == 1'b1);
        @(posedge ahb_hclk) begin
            ahb_htrans <= 2'b11;
            ahb_haddr  <= 32'd104;
            ahb_hwdata <= 32'h200;
        end 
        #1 wait(ahb_hready == 1'b1);
        @(posedge ahb_hclk) begin
            ahb_htrans <= 2'b11;
            ahb_haddr  <= 32'd108;
            ahb_hwdata <= 32'h300;
        end 
        #1 wait(ahb_hready == 1'b1);
        @(posedge ahb_hclk) begin
            ahb_htrans <= 2'b11;
            ahb_haddr  <= 32'd112;
            ahb_hwdata <= 32'h400;
        end 
        #1 wait(ahb_hready == 1'b1);   
        @(posedge ahb_hclk) begin
            ahb_hsel   <= 1'b1;
            ahb_htrans <= 2'b00;
            ahb_haddr  <= 32'd100;
            ahb_hwdata <= 32'h500;
        end  
        #1 wait(ahb_hready == 1'b1);
        @(posedge ahb_hclk) begin
            ahb_hwdata <= 32'h500;    
        end      
    end
    begin
        @(posedge apb_pclk)
            apb_pready <= 1'b1;
    end    
    join
end
endtask

task send_read;
begin
    fork
    begin
        @(posedge ahb_hclk) begin
            ahb_hsel   <= 1'b1;
            ahb_hwrite <= 1'b0;
            ahb_htrans <= 2'b10;
            ahb_haddr  <= 32'd100;
        end 
        #1 wait(ahb_hready == 1'b1);
        @(posedge ahb_hclk) begin
            ahb_htrans <= 2'b00;
            ahb_hsel   <= 1'b0;
        end   
    end
    begin
        @(posedge apb_pclk) begin
            apb_pready <= 1'b1;    
            apb_prdata <= 32'd200;        
        end
    end    
    join
end
endtask
    
endmodule