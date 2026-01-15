module fifo #(
parameter data_width=8,
parameter data_length=16)
(
input clk,
input rst_n,
input wr_en,
input rd_en,
input[data_width-1:0]din,
output reg[data_width-1:0]dout,
output wire empty,
output wire full
);
localparam ADD_WIDTH=$clog2(data_length);
reg[ADD_WIDTH:0]wr_ptr;
reg[ADD_WIDTH:0]rd_ptr;
reg[data_width-1:0]mem[0:data_length-1];
assign empty=(wr_ptr==rd_ptr);
assign full=(wr_ptr[ADD_WIDTH]!==wr_ptr[ADD_WIDTH] &&rd_ptr[ADD_WIDTH-1:0]);
always@(posedge clk or negedge rst_n)
begin
if(!rst_n)
begin
wr_ptr<=0;
end
else if(wr_en &&!full)
begin
mem[wr_ptr[ADD_WIDTH-1:0]]<=din;
wr_ptr<=wr_ptr+1'b1;
end
end
always@(posedge clk or negedge rst_n)
begin
if(!rst_n)
begin
rd_ptr<=0;
end
else if(rd_en &&!empty)
begin
dout<=mem[rd_ptr[ADD_WIDTH-1:0]];
rd_ptr<=rd_ptr+1'b1;
end
end
endmodule
