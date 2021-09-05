//-----------------------------------------------------------
// FileName: async_fifo_tb.v
// Creator : kinglin
// E-mail  : service@eecourse.com
// Function: async fifo testbench
// Update  :
// Coryright: www.eecourse.com @ 2018-09-14
//-----------------------------------------------------------

`timescale 10ns/1ns

module async_fifo_tb;
  reg rst,rclk,wclk,rd_en,wr_en;
  reg [7:0] data_in;
  wire [7:0] data_out;
  wire full,empty;
  async_fifo u_async_fifo ( rclk,wclk,rst,wr_en,rd_en,data_in,data_out,empty,full);
  initial 
    begin
      rst=1;
      rclk=0;
      wclk=0;    
      #1 rst=0;
      #5 rst=1;
    end
  
  initial
    begin 
     wr_en=0;
      #1 wr_en=1;  
    end
    
    
  initial
    begin    
     rd_en=0;
     #650 rd_en=1;
          wr_en=0;  
    end
  
  a_to_b_chk:
  assert property
  (@(posedge wclk) $rose(wr_en) |-> ##[1:3] $rose(rd_en));
    
  always #30 rclk=~rclk;
  always #20 wclk=~wclk;
  initial
    begin
      data_in=8'h0;
      #40 data_in=8'h1;
      #40 data_in=8'h2;
      #40 data_in=8'h3;
      #40 data_in=8'h4;
      #40 data_in=8'h5;
      #40 data_in=8'h6;
      #40 data_in=8'h7;
      #40 data_in=8'h8;
      #40 data_in=8'h9;
      #40 data_in=8'ha;
      #40 data_in=8'hb;
      #40 data_in=8'hc;
      #40 data_in=8'hd;
      #40 data_in=8'he;
      #40 data_in=8'hf;
      #1600 $finish;
    end
  
    `ifdef VCS_DUMP
      initial begin
        $vcdpluson();
      end
    `endif
endmodule
