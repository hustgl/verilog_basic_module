module ahb2apb #(
	parameter AHB_DATA_WIDTH = 32,
	parameter AHB_ADDR_WIDTH = 32,
	parameter APB_DATA_WIDTH = 32,
	parameter APB_ADDR_WIDTH = 32
)(
	input                       ahb_hclk  ,
	input                       ahb_hrstn ,
	input                       ahb_hsel  ,
	input  [1:0]                ahb_htrans, // hburst hsize are not considered
	input  [AHB_ADDR_WIDTH-1:0] ahb_haddr ,
	input  [AHB_DATA_WIDTH-1:0] ahb_hdata ,
	input                       ahb_hwrite,
	output                      ahb_hready,
	output [AHB_DATA_WIDTH-1:0] ahb_rdata ,
	
	input                       apb_pclk   ,
	input                       apb_prstn  ,
	output                      apb_psel   ,
	output                      apb_pwrite ,
	output                      apb_penable,
	output [APB_ADDR_WIDTH-1:0] apb_paddr  ,
	output [APB_DATA_WIDTH-1:0] apb_wdata  ,
	input                       apb_pready ,
	input  [APB_DATA_WIDTH-1:0] apb_prdata
);	

wire                     ahb_wr_en    ;
wire                     ahb_rd_en    ;

reg                      ahb_wr_en_dly;
reg                      ahb_rd_en_dly;
reg [AHB_ADDR_WIDTH-1:0] ahb_haddr_reg;

wire                                   async_fifo_cmd_wr_en;
wire [AHB_ADDR_WIDTH+AHB_DATA_WIDTH:0] async_fifo_cmd_wdata;
wire                                   async_fifo_cmd_rd_en;
wire [AHB_ADDR_WIDTH+AHB_DATA_WIDTH:0] async_fifo_cmd_rdata;
wire                                   async_fifo_cmd_full ;
wire                                   async_fifo_cmd_empty;

wire                      async_fifo_recv_wr_en;
wire [APB_DATA_WIDTH-1:0] async_fifo_recv_wdata;
wire                      async_fifo_recv_rd_en;
wire [APB_DATA_WIDTH-1:0] async_fifo_recv_rdata;
wire                      async_fifo_recv_full ;
wire                      async_fifo_recv_empty;

reg  apb_cmd_flag ;
wire ahb_wr_hready;
reg  ahb_rd_hready;

assign ahb_wr_en = ahb_hsel && ahb_hwrite  && ahb_htrans[1] && ahb_hready;
assign ahb_rd_en = ahb_hsel && ~ahb_hwrite && ahb_htrans[1] && ahb_hready;

always@(posedge ahb_hclk or negedge ahb_hrstn) begin
if(!rst_n) begin
	ahb_wr_en_dly <= 1'b0;
	ahb_rd_en_dly <= 1'b0;
	ahb_haddr_reg <= {AHB_ADDR_WIDTH{1'b0}};
end
else begin
	ahb_wr_en_dly <= ahb_wr_en;
	ahb_rd_en_dly <= ahb_rd_en;
	ahb_haddr_reg <= ahb_haddr;
end	
end

assign async_fifo_cmd_wr_en = ahb_wr_en_dly || ahb_rd_en_dly;
assign aysnc_fifo_cmd_data  = {ahb_hwrite, ahb_haddr_reg, ahb_hwdata};

// rw_flag addr wdata
async_fifo #(
	.DATA_WIDTH(AHB_DATA_WIDTH+AHB_ADDR_WIDTH+1),
	.FIFO_DEPTH(16),
	.FIFO_AFULL(15),
	.FIFO_AEMPTY(1)
) async_fifo_cmd_u0(
	.wr_clk(ahb_hclk),
	.wr_rst_n(ahb_hrstn),
	.wr_en(async_fifo_cmd_wr_en),
	.wr_data(async_fifo_cmd_wdata),
	.rd_clk(apb_pclk),
	.rd_rst_n(apb_prstn),
	.rd_en(async_fifo_cmd_rd_en),
	.rd_data(async_fifo_cmd_rdata),
	.full(async_fifo_cmd_full),
	.afull(),
	.empty(async_fifo_cmd_empty),
	.aempty()
);

async_fifo #(
	.DATA_WIDTH(APB_DATA_WIDTH),
	.FIFO_DEPTH(16),
	.FIFO_AFULL(15),
	.FIFO_AEMPTY(1)
)async_fifo_rdata_u0(
	.wr_clk(apb_pclk),
	.wr_rst_n(apb_prstn),
	.wr_en(async_fifo_recv_wr_en),
	.wr_data(async_fifo_recv_wdata),
	.rd_clk(ahb_hclk),
	.rd_rst_n(ahb_hrstn),
	.rd_en(async_fifo_recv_rd_en),
	.rd_data(async_fifo_recv_rdata),
	.full(async_fifo_recv_full),
	.afull(),
	.empty(async_fifo_recv_empty),
	.aempty()
);

assign ahb_wr_hready = ~async_fifo_cmd_full;
assign async_fifo_cmd_rd_en = ~async_fifo_cmd_empty && ~apb_cmd_flag;

always@(posedge apb_pclk or negedge apb_prstn) begin
if(!apb_rst_n)
	apb_cmd_flag <= 1'b0;
else if(apb_penable && apb_pready)
	apb_cmd_flag <= 1'b0;
else if(async_fifo_cmd_rd_en)
	apb_cmd_flag <= 1'b1; 
end

always@(posedge apb_pclk or negedge apb_prstn) begin
if(!apb_prstn) begin
	apb_psel   <= 1'b0;
 	apb_pwrite <= 1'b0;
	apb_paddr  <= {APB_ADDR_WIDTH{1'b0}};
end
//auto refresh paddr and pwdata
else if(apb_penable && apb_pready) begin
	apb_psel   <= 1'b0;
 	apb_pwrite <= 1'b0;
end
else if(async_fifo_cmd_rd_en) begin
	apb_psel   <= 1'b1;
	apb_pwrite <= async_fifo_cmd_rdata[64];
	apb_paddr  <= async_fifo_cmd_rdata[63:62];
end
end

always@(posedge apb_pclk or negedge apb_prstn) begin
if(!apb_prstn)
	apb_pwdata <= {APB_DATA_WIDTH{1'b0}};
else if(async_fifo_cmd_rd_en) begin
	if(async_fifo_cmd_rdata[64]) 
		apb_pwdata <= async_fifo_cmd_rdata[31:0];
	else
		apb_pwdata <= 32'd0;		
end
end

always@(posedge apb_pclk or negedge apb_prstn) begin
if(!apb_prstn)
	apb_penable <= 1'b0;
//auto refresh paddr and pwdata
else if(apb_penable && apb_pready) 
	apb_penable <= 1'b0;
else if(apb_psel) 
	apb_enable <= 1'b1;
end

assign async_fifo_recv_wr_en = ~apb_pwrite && apb_penable && apb_pready;
assign async_fifo_recv_rd_en = ~async_fifo_recv_empty;
assign async_fifo_recv_wdata = apb_prdata;

always@(posedge ahb_hclk or negedge ahb_hrstn) begin
if(!ahb_hrstn)
	ahb_rd_hready <= 1'b1;
else if(async_fifo_recv_rd_en)
	ahb_rd_hready <= 1'b1;
else if(ahb_rd_en)
	ahb_rd_hready <= 1'b0; 
end

assign ahb_hready = ahb_wr_hready && ahb_rd_hready;

always @(posedge ahb_hclk or negedge ahb_hrstn) begin
if(!ahb_hrstn)
	ahb_hrdata <= {AHB_DATA_WIDTH{1'b0}};
else
	ahb_hrdata <= async_fifo_recv_rdata;		
end

endmodule