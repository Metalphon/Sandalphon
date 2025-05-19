// --------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
// --------------------------------------------------------------------
// Module: ADC_I2C
// 
// Author: Step
// 
// Description: ADC_I2C
// 
// Web: www.stepfpga.com
//
// --------------------------------------------------------------------
// Code Revision History :
// --------------------------------------------------------------------
// Version: |Mod. Date:   |Changes Made:
// V1.1     |2016/10/30   |Initial ver
// --------------------------------------------------------------------
module ADC_I2C
(
	input				clk_in,		//系统时钟
	input				rst_n_in,	//系统复位，低有效
	output				scl_out,	//I2C总线SCL
	inout				sda_out,	//I2C总线SDA
	output	reg			adc_done,	//ADC采样完成标志
	output	reg	[7:0]	adc_data	//ADC采样数据
);
 
	parameter	CNT_NUM	=	63;  // 修改为63，使I2C时钟频率降至约100kHz
 
	localparam	IDLE	=	3'd0;
	localparam	MAIN	=	3'd1;
	localparam	START	=	3'd2;
	localparam	WRITE	=	3'd3;
	localparam	READ	=	3'd4;
	localparam	STOP	=	3'd5;
 
	//根据PCF8591的datasheet，I2C的频率最高为100KHz，
	//我们准备使用4个节拍完成1bit数据的传输，所以需要400KHz的时钟触发完成该设计
	//使用计数器分频产生约100KHz的I2C时钟信号(400KHz/4)
	reg					clk_400khz;
	reg		[9:0]		cnt_400khz;
	always@(posedge clk_in or negedge rst_n_in) begin
		if(!rst_n_in) begin
			cnt_400khz <= 10'd0;
			clk_400khz <= 1'b0;
		end else if(cnt_400khz >= CNT_NUM-1) begin
			cnt_400khz <= 10'd0;
			clk_400khz <= ~clk_400khz;
		end else begin
			cnt_400khz <= cnt_400khz + 1'b1;
		end
	end
 
	reg		[7:0]		adc_data_r;        // ADC原始数据寄存器
	reg		[7:0]		adc_data_raw;      // 额外的ADC原始数据寄存器
	reg					scl_out_r;
	reg					sda_out_r;
	reg		[2:0]		cnt;
	reg		[3:0]		cnt_main;
	reg		[7:0]		data_wr;
	reg		[2:0]		cnt_start;
	reg		[2:0]		cnt_write;
	reg		[4:0]		cnt_read;
	reg		[2:0]		cnt_stop;
	reg		[2:0] 		state;
	reg                 sda_in;             // 用于采样SDA输入
	reg     [3:0]       read_retry_cnt;     // 读取重试计数器
	reg		[7:0]		address;
	reg		[3:0]		cnt_bit;
	reg		[1:0]		cnt_byte;
	reg		[4:0]		cnt_clk;
	reg		[7:0]		tx_data;
	reg		[7:0]		rx_data;
	reg					scl,sda_dir;
	reg     [1:0]       sda_sample;  // 用于采样并过滤SDA输入
	reg     [7:0]       stable_count; // 稳定性计数器
 
	assign scl_out = (state == STOP && cnt_clk == 5'd2) ? 1'b1 : 
	                 (state == STOP && cnt_clk == 5'd3) ? 1'b1 : 
					 (state == STOP && cnt_clk > 5'd3) ? 1'b1 : scl;
	assign sda_out = sda_dir ? sda_out_r : 1'bz;
	
	// 添加SDA采样逻辑，用于提高输入数据的稳定性
	always @(posedge clk_400khz or negedge rst_n_in) begin
		if(!rst_n_in) begin
			sda_sample <= 2'b00;
		end else begin
			sda_sample <= {sda_sample[0], sda_out};
		end
	end
	
	// 稳定性判断 - 连续两次采样值相同时认为稳定
	wire sda_stable = (sda_sample[1] == sda_sample[0]);
 
	always@(posedge clk_400khz or negedge rst_n_in) begin
		if(!rst_n_in) begin
			state <= IDLE;
			cnt_bit <= 4'd0;
			cnt_byte <= 2'd0;
			cnt_clk <= 5'd0;
			tx_data <= 8'd0;
			rx_data <= 8'd0;
			adc_data <= 8'd0;
			adc_done <= 1'b0;
			scl <= 1'b1;
			sda_dir <= 1'b1;
			sda_out_r <= 1'b1;
			address <= 8'h90; // PCF8591的地址是0x90(写)或0x91(读)
			stable_count <= 8'd0;
		end else begin
			case(state)
				IDLE: begin
					adc_done <= 1'b0;
					cnt_clk <= 5'd0;
					cnt_bit <= 4'd0;
					cnt_byte <= 2'd0;
					sda_dir <= 1'b1;
					sda_out_r <= 1'b1;
					scl <= 1'b1;
					state <= MAIN;
				end
				
				MAIN: begin
					case(cnt_byte)
						2'd0: begin // 第一个字节：写入操作，地址0x90
							tx_data <= 8'h90; // 写入设备地址
							cnt_byte <= 2'd1;
							state <= START;
						end
						2'd1: begin // 第二个字节：控制字节，0x00
							tx_data <= 8'h00; // 控制字节：单端输入、通道0
							cnt_byte <= 2'd2;
							state <= WRITE;
						end
						2'd2: begin // 第三个字节：再次发送起始位，准备读取数据
							tx_data <= 8'h91; // 设备地址 + 读取位
							cnt_byte <= 2'd3;
							state <= START;
						end
						2'd3: begin // 第四个字节：读取ADC数据
							state <= READ;
						end
					endcase
				end
				
				START: begin
					case(cnt_clk)
						5'd0: begin
							sda_dir <= 1'b1;
							sda_out_r <= 1'b1;
							scl <= 1'b1;
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd1: begin
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd2: begin
							sda_out_r <= 1'b0;
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd3: begin
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd4: begin
							scl <= 1'b0;
							cnt_clk <= 5'd0;
							state <= WRITE;
							cnt_bit <= 4'd0;
						end
						default: cnt_clk <= 5'd0;
					endcase
				end
				
				WRITE: begin
					case(cnt_clk)
						5'd0: begin
							sda_dir <= 1'b1;
							if(cnt_bit <= 4'd7) begin
								sda_out_r <= tx_data[7-cnt_bit]; // MSB到LSB的顺序发送
							end else begin
								sda_dir <= 1'b0; // 释放SDA总线，准备接收ACK
							end
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd1: begin
							scl <= 1'b0;
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd2: begin
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd3: begin
							scl <= 1'b1; // 产生时钟上升沿
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd4: begin
							// 如果是第9位(ACK位)且SDA稳定为低电平，或者还在发送数据位
							if((cnt_bit == 4'd8 && sda_stable && sda_sample[0] == 1'b0) || cnt_bit < 4'd8) begin
								cnt_clk <= cnt_clk + 1'b1;
							end else if(cnt_bit == 4'd8 && (!sda_stable || sda_sample[0] == 1'b1)) begin
								// ACK未收到或不稳定，重试当前字节
								cnt_bit <= 4'd0;
								cnt_clk <= 5'd0;
								stable_count <= stable_count + 1'b1;
								if(stable_count >= 8'd5) begin // 重试5次后放弃
									state <= STOP;
									stable_count <= 8'd0;
								end
							end
						end
						5'd5: begin
							scl <= 1'b0;
							cnt_clk <= 5'd0;
							
							if(cnt_bit == 4'd8) begin // 一个字节发送完成
								cnt_bit <= 4'd0;
								if(cnt_byte == 2'd1 || cnt_byte == 2'd3) begin
									state <= MAIN; // 继续下一个字节
								end else if(cnt_byte == 2'd2) begin
									state <= MAIN; // 发送读取指令
								end else begin
									state <= STOP; // 完成读写
								end
							end else begin // 继续发送下一位
								cnt_bit <= cnt_bit + 1'b1;
							end
						end
						default: cnt_clk <= 5'd0;
					endcase
				end
				
				READ: begin
					case(cnt_clk)
						5'd0: begin
							sda_dir <= 1'b0; // 释放SDA总线，准备读取数据
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd1: begin
							scl <= 1'b0;
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd2: begin
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd3: begin
							scl <= 1'b1; // 产生时钟上升沿
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd4: begin
							// 读取SDA数据
							if(cnt_bit <= 4'd7) begin
								if(sda_stable) begin // 确保读取的数据稳定
									rx_data[7-cnt_bit] <= sda_sample[0]; // MSB到LSB的顺序接收
									cnt_clk <= cnt_clk + 1'b1;
								end else begin
									// 数据不稳定，保持当前状态
									stable_count <= stable_count + 1'b1;
									if(stable_count >= 8'd10) begin // 等待较长时间后继续
										rx_data[7-cnt_bit] <= sda_sample[0];
										cnt_clk <= cnt_clk + 1'b1;
										stable_count <= 8'd0;
									end
								end
							end else begin // ACK位
								sda_dir <= 1'b1;
								sda_out_r <= 1'b1; // 发送NACK，表示读取结束
								cnt_clk <= cnt_clk + 1'b1;
							end
						end
						5'd5: begin
							scl <= 1'b0;
							cnt_clk <= 5'd0;
							
							if(cnt_bit == 4'd8) begin // 一个字节读取完成
								adc_data <= rx_data; // 将读取的数据保存到输出
								adc_done <= 1'b1;   // 设置完成标志
								state <= STOP;      // 进入停止状态
							end else begin // 继续读取下一位
								cnt_bit <= cnt_bit + 1'b1;
							end
						end
						default: cnt_clk <= 5'd0;
					endcase
				end
				
				STOP: begin
					case(cnt_clk)
						5'd0: begin
							sda_dir <= 1'b1;
							sda_out_r <= 1'b0;
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd1: begin
							scl <= 1'b0;
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd2: begin
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd3: begin
							scl <= 1'b1; // 产生时钟上升沿
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd4: begin
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd5: begin
							sda_out_r <= 1'b1; // 产生停止条件
							cnt_clk <= cnt_clk + 1'b1;
						end
						5'd15: begin // 延长停止状态的时间，确保I2C总线稳定
							cnt_clk <= 5'd0;
							state <= IDLE; // 回到空闲状态，准备下一次读取
						end
						default: cnt_clk <= cnt_clk + 1'b1;
					endcase
				end
				
				default: state <= IDLE;
			endcase
		end
	end
 
endmodule