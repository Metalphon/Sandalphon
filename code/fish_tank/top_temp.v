`timescale 1ns / 1ps
//****************************************VSCODE PLUG-IN**********************************//
//----------------------------------------------------------------------------------------
// IDE :                   VSCODE     
// VSCODE plug-in version: Verilog-Hdl-Format-2.8.20240817
// VSCODE plug-in author : Jiang Percy
//----------------------------------------------------------------------------------------
//****************************************Copyright (c)***********************************//
// Copyright(C)            vscode
// All rights reserved     
// File name:              
// Last modified Date:     2024/10/18 15:57:12
// Last Version:           V1.0
// Descriptions:           
//----------------------------------------------------------------------------------------
// Created by:             ff
// Created date:           2024/10/18 15:57:12
// mail      :             fyzhang1123@163.com
// Version:                V1.0
// TEXT NAME:              top_temp.v
// PATH:                   E:\post\fpga_compi\temp\top_temp.v
// Descriptions:           
//                         
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module top_temp(
    input                               clk                        ,
    input                               rst_n                      ,

	output  [35:0] temp_data , 
	output reg temp_data_de,
	
    inout iic_0_scl,              
	inout iic_0_sda,  
    input intr    
);


	wire [35:0] l_rddata;

    wire LRW_Done;
	wire pose;

reg [7:0] data_buffer[0:3]; // 创建一个4个元素的移位寄存器
reg [11:0] data_sum;        // 用于存储求和的变量
reg [7:0] data_filtered;    // 存储滤波后的结果

assign temp_data = {l_rddata[35:32],data_filtered,l_rddata[23:0]};

// 第一阶段：数据输入
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_buffer[0] <= 8'd0;                 
        data_buffer[1] <= 8'd0;
        data_buffer[2] <= 8'd0;
        data_buffer[3] <= 8'd0;
    end else begin
        if (LRW_Done) begin
            // 移位寄存器
            data_buffer[3] <= data_buffer[2];
            data_buffer[2] <= data_buffer[1];
            data_buffer[1] <= data_buffer[0];
            data_buffer[0] <= l_rddata[31:24];  
        end
    end
end

// 第二阶段：计算平均值
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_sum <= 12'd0; // 初始化求和变量
    end else begin
        if (LRW_Done) begin
            // 计算平均值
            data_sum <= data_buffer[3] + data_buffer[2] + 
                        data_buffer[1] + data_buffer[0];
        end
    end
end

// 第三阶段：更新滤波后的数据
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_filtered <= 36'd0; // 初始化输出数据
        temp_data_de <= 1'b0;    // 初始化有效信号
    end else begin
        if (LRW_Done) begin
            data_filtered <=  data_sum[11:2];// 更新高8位为滤波后的数据
            temp_data_de <= 1'b1;                  // 设置有效信号
        end 
		else begin
            temp_data_de <= 1'b0;                  // 清除有效信号
        end
    end
end

	

max30102_Init u_max30102_Init(
		.Clk(clk),
		.Rst_n(rst_n),
		.intr(intr),
        .led(led),
		.LRW_Done(LRW_Done),
		.i2c_sclk(iic_0_scl),
        .l_rddata(l_rddata),
		.key_cnt (1'b0 ),			//change mode 00: SPO,01: HR
		.i2c_sdat(iic_0_sda)
	);


                                                                   
                                                                   
endmodule