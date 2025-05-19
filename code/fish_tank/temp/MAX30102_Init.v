module max30102_Init(
	input Clk,
	input Rst_n,
    input intr,
	input key_cnt,
	output [3:0]state_cnt,
	inout i2c_sdat,
	output i2c_sclk,
	output LRW_Done,
    output [35:0] l_rddata,
    output [3:0] led
);


    //

	//产生初始化使能信号
	reg [15:0]Delay_Cnt;
	reg Init_en;



	always@(posedge Clk or negedge Rst_n)
	begin
		if(!Rst_n)
			Delay_Cnt <= 16'd0;
		else if(Delay_Cnt < 16'd60000)
			Delay_Cnt <= Delay_Cnt + 8'd1;
		else
			Delay_Cnt <= Delay_Cnt;
	end	
	
	always@(posedge Clk or negedge Rst_n)
	begin
		if(!Rst_n)
			Init_en <= 1'b0;
		else if(Delay_Cnt == 16'd59999)
			Init_en <= 1'b1;
		else
			Init_en <= 1'b0;
	end

	


I2C_Init_Dev u_I2C_Init_Dev(
    .Clk                                (Clk                       ),
    .Rst_n                              (Rst_n                     ),
    .Go                                 (Init_en                        ),
    .intr                               (intr                      ),
    .l_rddata                           (l_rddata                  ),
    .LRW_Done                           (LRW_Done                  ),
    .led                                (led                       ),
	 .state_cnt(state_cnt),
	.key_cnt(key_cnt),
    .i2c_sclk                           (i2c_sclk                  ),
    .i2c_sdat                           (i2c_sdat                  )
);






endmodule
