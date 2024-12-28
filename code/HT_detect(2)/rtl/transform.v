module transform(
		input					rst_n,	//系统复位，低有效
		input		[15:0]	bin_code,//需要进行BCD转码的二进制数据
		output reg	[19:0]bcd_code	//转码后的BCD码型数据输出
	);


	

reg		[35:0]		shift_reg; 
always@(bin_code or rst_n)begin
	shift_reg = {20'h0,bin_code};
	if(!rst_n) 
		bcd_code = 0; 
	else begin 
		repeat(16) begin //循环16次  
			//BCD码各位数据作满5加3操作，
			if (shift_reg[19:16] >= 5) shift_reg[19:16] = shift_reg[19:16] + 2'b11;
			if (shift_reg[23:20] >= 5) shift_reg[23:20] = shift_reg[23:20] + 2'b11;
			if (shift_reg[27:24] >= 5) shift_reg[27:24] = shift_reg[27:24] + 2'b11;
			if (shift_reg[31:28] >= 5) shift_reg[31:28] = shift_reg[31:28] + 2'b11;
			if (shift_reg[35:32] >= 5) shift_reg[35:32] = shift_reg[35:32] + 2'b11;
			shift_reg = shift_reg << 1; 
		end
		bcd_code = shift_reg[35:16];   
	end  
end

endmodule
