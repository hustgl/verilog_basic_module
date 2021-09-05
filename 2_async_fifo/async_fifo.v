module async_fifo #(
		parameter	DATA_WIDTH = 4,
		parameter	FIFO_DEPTH = 16,
		parameter	FIFO_AFULL = FIFO_DEPTH-1,
		parameter	FIFO_AEMPTY = 1
		)(
		input wr_clk,
		input wr_rst_n,
		input wr_en,
		input [DATA_WIDTH-1:0] wr_data,
		input rd_clk,
		input rd_rst_n,
		input rd_en,
		output [DATA_WIDTH-1:0] rd_data,
		output reg full,
		output reg afull,
		output reg aempty,
		output reg empty
	);
	

localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);

reg [ADDR_WIDTH:0] rd_addr;
reg [ADDR_WIDTH:0] rd_addr_nxt;

reg [ADDR_WIDTH:0] wr_addr;
reg [ADDR_WIDTH:0] wr_addr_nxt;

wire [ADDR_WIDTH:0] wr_addr_gray_nxt;
reg  [ADDR_WIDTH:0] wr_addr_gray;
reg  [ADDR_WIDTH:0] wr_addr_gray_rsyn1;
reg  [ADDR_WIDTH:0] wr_addr_gray_rsyn2;
wire [ADDR_WIDTH:0] wr_addr_gray_rsyn;

wire [ADDR_WIDTH:0] rd_addr_gray_nxt;
reg  [ADDR_WIDTH:0] rd_addr_gray;
reg  [ADDR_WIDTH:0] rd_addr_gray_wsyn1;
reg  [ADDR_WIDTH:0] rd_addr_gray_wsyn2;
wire [ADDR_WIDTH:0] rd_addr_gray_wsyn;

wire [ADDR_WIDTH:0] rd_addr_gray_wsyn_bin;
wire [ADDR_WIDTH:0] fifo_used_wr;
wire [ADDR_WIDTH:0] wr_addr_gray_rsyn_bin;

wire                wr_vld;
wire                rd_vld;

wire                full_comb;
wire                empty_comb;

assign wr_vld = (wr_en & (~full);
assign rd_vld = (rd_en & (~empty);

dualport_ram_async #(
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH)
	)dualport_ram_inst(
		.wr_clk  (wr_clk  ),
		.wr_rst_n(wr_rst_n),
		.wr_en   (wr_vld  ),
		.wr_addr (wr_addr[ADDR_WIDTH-1:0]),
		.wr_data (wr_data ),
		.rd_clk  (rd_clk  ),
		.rd_rst_n(rd_rst_n),
		.rd_en   (rd_vld  ),
		.rd_addr (rd_addr[ADDR_WIDTH-1:0]),
		.rd_data (rd_data )
	);

always @ (*)
begin
	if(wr_vld)
		wr_addr_nxt = wr_addr + 1'b1;
	else
		wr_addr_nxt = wr_addr;
end 

always @ (posedge wr_clk or negedge wr_rst_n)
begin
	if(!wr_rst_n)
		wr_addr <= {(ADDR_WIDTH+1){1'b0}};
	else
		wr_addr <= wr_addr_nxt;
end 

always @ (*)
begin
	if(rd_vld)
		rd_addr_nxt = rd_addr + 1'b1;
	else
		rd_addr_nxt = rd_addr;
end 

always @ (posedge rd_clk or negedge wr_rst_n)
begin
	if(!wr_rst_n)
		rd_addr <= {(ADDR_WIDTH+1){1'b0}};
	else
		rd_addr <= rd_addr_nxt;
end 


//------wr_addr to gray--------//
assign wr_addr_gray_nxt = (wr_addr_nxt>>1) ^ wr_addr_nxt;

always @ (posedge wr_clk or negedge wr_rst_n)
begin
	if(!wr_rst_n)
		wr_addr_gray <= {(ADDR_WIDTH+1){1'b0}};
	else
		wr_addr_gray <= wr_addr_gray_nxt;
end 

//------rd_addr to gray--------//
assign rd_addr_gray_nxt = (rd_addr_nxt>>1) ^ rd_addr_nxt;

always @ (posedge rd_clk or negedge rd_rst_n)
begin
	if(!rd_rst_n)
		rd_addr_gray <= {(ADDR_WIDTH+1){1'b0}};
	else
		rd_addr_gray <= rd_addr_gray_nxt;
end


//use write clock to sync read addr
always @ (posedge wr_clk or negedge wr_rst_n)
begin
	if(!wr_rst_n)begin
		rd_addr_gray_wsyn1 <= {(ADDR_WIDTH+1){1'b0}};
		rd_addr_gray_wsyn2 <= {(ADDR_WIDTH+1){1'b0}};
	end
	else begin
		rd_addr_gray_wsyn1 <= rd_addr_gray;
		rd_addr_gray_wsyn2 <= rd_addr_gray_wsyn1;
	end
end 

//use read clock to sync write addr, delay 2 clock
always @ (posedge rd_clk or negedge rd_rst_n)
begin
	if(!rd_rst_n)begin
		wr_addr_gray_rsyn1 <= {(ADDR_WIDTH+1){1'b0}};
		wr_addr_gray_rsyn2 <= {(ADDR_WIDTH+1){1'b0}};
	end
	else begin
		wr_addr_gray_rsyn1 <= wr_addr_gray;
		wr_addr_gray_rsyn2 <= wr_addr_gray_rsyn1;
	end
end

assign wr_addr_gray_rsyn = wr_addr_gray_rsyn2;
assign rd_addr_gray_wsyn = rd_addr_gray_wsyn2;

//generate full
assign full_comb = (wr_addr_gray_nxt=={~rd_addr_gray_wsyn[ADDR_WIDTH:ADDR_WIDTH-1],rd_addr_gray_wsyn[ADDR_WIDTH-2:0]});

always @ (posedge wr_clk or negedge wr_rst_n)
begin
	if(!wr_rst_n)
		full <= 1'b0;
	else
		full <= full_comb;
end 

//generate empty
assign empty_comb = rd_addr_gray_nxt[ADDR_WIDTH:0]==wr_addr_gray_rsyn[ADDR_WIDTH:0];

always @ (posedge rd_clk or negedge rd_rst_n)
begin
	if(!rd_rst_n)
		empty <= 1'b1;
	else
		empty <= empty_comb;
end 


generate
genvar i;
	for(i=ADDR_WIDTH;i>=0;i=i-1)begin
		if(i==ADDR_WIDTH)
			assign rd_addr_gray_wsyn_bin[i] = rd_addr_gray_wsyn[i];
		else
			assign rd_addr_gray_wsyn_bin[i] = rd_addr_gray_wsyn[i] ^ rd_addr_gray_wsyn[i+1];
	end 
endgenerate


assign fifo_used_wr = wr_addr_nxt - rd_addr_gray_wsyn_bin;

wire afull_comb;
assign afull_comb = (fifo_used_wr>=FIFO_AFULL);

always @ (posedge wr_clk or negedge wr_rst_n)
begin
	if(!wr_rst_n)
		afull <= 1'b0;
	else
		afull <= afull_comb;
end 

generate
genvar j;
	for(j=ADDR_WIDTH;j>=0;j=j-1)begin
		if(i==ADDR_WIDTH)
			assign wr_addr_gray_rsyn_bin[j] = wr_addr_gray_rsyn[j];
		else
			assign wr_addr_gray_rsyn_bin[j] = wr_addr_gray_rsyn[j] ^ wr_addr_gray_rsyn[j+1];
	end 
endgenerate

wire [ADDR_WIDTH:0] fifo_used_rd;
assign fifo_used_rd = wr_addr_gray_rsyn_bin - rd_addr_nxt;

wire aempty_comb;
assign aempty_comb = (fifo_used_rd<=FIFO_AEMPTY);

always @ (posedge rd_clk or negedge rd_rst_n)
begin
	if(!rd_rst_n)
		aempty <= 1'b1;
	else
		aempty <= aempty_comb;
end 


endmodule
