module sync_fifo #(
        parameter DATA_WIDTH   = 8,
        parameter FIFO_DEPTH   = 8,
        parameter AFULL_DEPTH  = FIFO_DEPTH - 1,  //阈值
        parameter AEMPTY_DEPTH = 1,
        parameter RDATA_MODE   = 0
        )(
        input                       clk    ,
        input                       rst_n  ,
        input                       wr_en  ,
        input      [DATA_WIDTH-1:0] wr_data,
        input                       rd_en  ,
        output reg [DATA_WIDTH-1:0] rd_data,
        output                      full   ,
        output                      almost_full,
        output                      empty      ,
        output                      almost_empty,
        output reg                  overflow,  
        output reg                  underflow  
    );

//define localparam with $clog2
localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);

//--------internal signals define--------//
reg [ADDR_WIDTH-1:0] wr_ptr;
reg [ADDR_WIDTH-1:0] rd_ptr;
reg [ADDR_WIDTH:0]   fifo_cnt;
reg [DATA_WIDTH-1:0] buf_mem[FIFO_DEPTH-1:0];

integer I;

//fifo_cnt logic
always @ (posedge clk or negedge rst_n)
begin
    if(!rst_n)
        fifo_cnt <= {(ADDR_WIDTH+1){1'b0}};
    else begin
        if(wr_en && ~full && rd_en && ~empty)
            fifo_cnt <= fifo_cnt;
        else if(wr_en && ~full)
            fifo_cnt <= fifo_cnt + 1'b1;
        else if(rd_en && ~empty)
            fifo_cnt <= fifo_cnt - 1'b1;
    end     
end 
//wr_ptr logic
always @ (posedge clk or negedge rst_n)
begin
    if(!rst_n)
        wr_ptr <= {ADDR_WIDTH{1'b0}};
    else begin
        if(wr_en && ~full) begin
            if(wr_ptr == FIFO_DEPTH-1)
                wr_ptr <= {ADDR_WIDTH{1'b0}};
            else
                wr_ptr <= wr_ptr + 1'b1;    
        end
    end 
end 

always @ (posedge clk or negedge rst_n)
begin
    if(!rst_n)
        rd_ptr <= {ADDR_WIDTH{1'b0}};
    else begin
        if(rd_en && ~empty) begin
            if(rd_ptr == FIFO_DEPTH-1)
                rd_ptr <= {ADDR_WIDTH{1'b0}};
            else
                rd_ptr <= rd_ptr + 1'b1;    
        end
    end 
end 
//mem logic
always @ (posedge clk or negedge rst_n)
begin
    if(!rst_n)
        for(I = 0;I < FIFO_DEPTH; I = I+1)
            buf_mem[I] <= {DATA_WIDTH{1'b0}};
    else if(wr_en && ~full)
        buf_mem[wr_ptr] <= wr_data;
end



//generate
//genvar II;
//begin
//  for(II=0;II<FIFO_DEPTH;II=II+1)
//  begin
//      always @ (posedge clk or negedge rst_n)
//      begin
//          if(!rst_n)
//              buf_mem[II] <= {DATA_WIDTH{1'b0}};
//          else if(wr_en && ~full && wr_ptr==II)
//              buf_mem[II] <= wr_data;
//      end
//  end
//end 
//endgenerate



generate
    if(RDATA_MODE==1'b0)begin
        always @ (*)
            rd_data = buf_mem[rd_ptr];
    end
    else begin
        always @ (posedge clk or negedge rst_n)
        begin
            if(!rst_n)
                rd_data <= {DATA_WIDTH{1'b0}};
        else if(rd_en && ~empty)
                rd_data <= buf_mem[rd_ptr];
        end 
    end 
endgenerate


always @ (posedge clk or negedge rst_n)
begin
    if(!rst_n)  
        overflow <= 1'b0;
    else if(wr_en && full)
        overflow <= 1'b1;
end 

always @ (posedge clk or negedge rst_n)
begin
    if(!rst_n)
        underflow <= 1'b0;
    else if(rd_en && empty)
        underflow <= 1'b1;
end 

assign full = fifo_cnt==FIFO_DEPTH;

assign empty = fifo_cnt=={(ADDR_WIDTH+1){1'b0}};

assign almost_full = fifo_cnt>=AFULL_DEPTH;

assign almost_empty = fifo_cnt<=AEMPTY_DEPTH;

endmodule