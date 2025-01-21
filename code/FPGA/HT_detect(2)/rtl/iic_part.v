module iic_part
(
	input clk,//系统时钟
	input clk_400k,//I2C时钟
	input reset,
	output trans_en,
	output scl,
	inout sda,
	output rck,
	output sck,
	output din,
	output [15:0]temp1,
	output [15:0]final_h
	
	) ;


/* pll pll(
	.clk(clk),
	.rst_n(reset),
	.clk_400k(clk_400k)
); */


iic iic(
	.clk(clk_400k),
	.rst_n(reset),	//系统复位，低有效
	.trans_en(trans_en),
	.i2c_scl(scl),	//I2C总线SCL
	.i2c_sda(sda),	//I2C总线SDA
	.T_code(T_code),	//温度码值
	.H_code(H_code)	//湿度码值
	);

bcd bcd(
	.rst_n(reset),	
	.T_code(T_code),
	.H_code(H_code),
	.t_data(temp1),
	.h_data(final_h),
	.T_data(T_data),
	.H_data(H_data),
	.dat_en(dat_en),
	.dot_en(dot_en)
);
wire [15:0] T_code,H_code;
wire [ 7: 0] dat_en, dot_en;
wire [15: 0] T_data, H_data;

display display(
		.clk(clk),	//系统时钟
		.rst_n(reset),	//系统复位，低有效
		.dat_1(T_data[15:12]),	//SEG1 显示温度百位
		.dat_2(T_data[11:8]),	//SEG2 显示温度十位
		.dat_3(T_data[7:4]),	//SEG3 显示温度个位
		.dat_4(T_data[3:0]),	//SEG4 显示温度小数位
		.dat_5(H_data[15:12]),	//SEG5 显示湿度百位
		.dat_6(H_data[11:8]),	//SEG6 显示湿度十位
		.dat_7(H_data[7:4]),	//SEG7 显示湿度个位
		.dat_8(H_data[3:0]),	//SEG8 显示湿度小数位
		.dat_en(dat_en),	//各位数码管数据显示使能，[MSB~LSB]=[SEG1~SEG8]
		.dot_en(dot_en),	//各位数码管小数点显示使能，[MSB~LSB]=[SEG1~SEG8]
		.rck(rck),	
		.sck(sck),	
		.din(din)	
	);
		
	
	
	
	
endmodule
