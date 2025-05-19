/*============================================================================
MAX30102
===========================================================================*/

module max30102_init_table
#(parameter DATA_WIDTH=16, parameter ADDR_WIDTH=8)
(
	input [(ADDR_WIDTH-1):0] addr,
	input clk, 
	input key_cnt,
	output reg [(DATA_WIDTH-1):0] q,
	output [7:0]dev_id,
	output [7:0]lut_size
);

	reg [DATA_WIDTH-1:0] rom[2**ADDR_WIDTH-1:0];
	
	assign dev_id = 8'hAE;		//MAX30102 IIC接口器件地址	//10101110
	assign lut_size = 8'd10;	//MAX30102 寄存器初始化数量

	//Line IN	
	always @ (*) begin
		rom[ 0][15:0] = {8'h02,8'hC0};  //  intr  MAX30102    
		rom[ 1][15:0] = {8'h03,8'h00};  
		rom[ 2][15:0] = {8'h04,8'h00};  
		rom[ 3][15:0] = {8'h05,8'h00};  
		rom[ 4][15:0] = {8'h06,8'h00};  
		rom[ 5][15:0] = {8'h08,8'h0f}; 
		if(key_cnt == 1'b0) begin
			rom[ 6][15:0] = {8'h09,8'h03};  // mode spO 03
		end
		else begin
			rom[ 6][15:0] = {8'h09,8'h02};  // mode hr 02 
		end
		rom[ 7][15:0] = {8'h0A,8'h27};  
		rom[ 8][15:0] = {8'h0C,8'h32};  
		rom[ 9][15:0] = {8'h0D,8'h32};  
	end

	always @ (posedge clk)
	begin
		q <= rom[addr];
	end

endmodule
