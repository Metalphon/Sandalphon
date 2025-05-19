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
// Last modified Date:     2024/10/24 08:46:54
// Last Version:           V1.0
// Descriptions:           
//----------------------------------------------------------------------------------------
// Created by:             ff
// Created date:           2024/10/24 08:46:54
// mail      :             fyzhang1123@163.com
// Version:                V1.0
// TEXT NAME:              spo.v
// PATH:                   E:\post\fpga_compi\example\gowin\ch34_uart_ddr3_tft_hdmi\src\spo\spo.v
// Descriptions:           
//                         
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module spo(
    input                               clk                        ,
    input                               rst_n                      ,
    input [35:0] spodata ,
    input   spodata_de ,
    output  [15:0]spodata_out                ,
    output  spodata_out_en                 
    
);

reg [17:0] ratio_max;
reg [7:0] spodata_out_en_r ;
wire [17:0] ratio;
wire [17:0] ratio_final;
wire [17:0] red_32;
wire [17:0] ered_32;

wire [7:0] int_sp;
reg [7:0] flo_sp;

assign int_sp = 104 - ratio_final[7:4];
assign spodata_out = (spodata)? {int_sp,flo_sp} : 16'h0;
assign spodata_out_en = spodata_out_en_r[6];
assign red_32 = {ratio<<5};
assign ered_32 = {ratio_max>>3};

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        flo_sp <= 8'd0 ;
    end
    else begin
        case (ratio_final[3:0])
            8'd0: flo_sp <= 8'd0 ;
            8'd1: flo_sp <= 8'd6 ;
            8'd2: flo_sp <= 8'd18 ;
            8'd3: flo_sp <= 8'd25 ;
            8'd4: flo_sp <= 8'd31 ;
            8'd5: flo_sp <= 8'd37 ;
            8'd6: flo_sp <= 8'd44 ;
            8'd7: flo_sp <= 8'd50 ;
            8'd8: flo_sp <= 8'd56 ;
            8'd9: flo_sp <= 8'd62 ;
            8'd10: flo_sp <= 8'd69 ;
            8'd11: flo_sp <= 8'd75 ;
            8'd12: flo_sp <= 8'd81 ;
            8'd13: flo_sp <= 8'd87 ;
            8'd14: flo_sp <= 8'd94 ;
            8'd15: flo_sp <= 8'd99 ;
            default: flo_sp <= 8'd0 ;
        endcase
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        ratio_max <= 18'd0 ;
    end
    else if(ratio >= ratio_max)begin
        ratio_max <= ratio ;
    end
end

// 3clk
Integer_temp u_Integer_spo(
	.clk(clk), //input clk
	.rstn(rst_n), //input rstn
	.dividend(spodata[35:18]), //input [17:0] dividend
	.divisor(spodata[17:0]), //input [17:0] divisor
	.quotient(ratio) //output [17:0] quotient
);    

//3clk
Integer_temp u_Integer_ratio(
	.clk(clk), //input clk
	.rstn(rst_n), //input rstn
	.dividend(red_32), //input [17:0] dividend
	.divisor(ered_32), //input [17:0] divisor
	.quotient(ratio_final) //output [17:0] quotient
);  

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        spodata_out_en_r <= 8'd0 ;
    end
    else begin
        spodata_out_en_r <= {spodata_out_en_r[6:0],spodata_de} ;
    end
end
                                                                   
endmodule