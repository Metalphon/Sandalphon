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
// Last modified Date:     2024/10/28 17:30:27
// Last Version:           V1.0
// Descriptions:           
//----------------------------------------------------------------------------------------
// Created by:             ff
// Created date:           2024/10/28 17:30:27
// mail      :             fyzhang1123@163.com
// Version:                V1.0
// TEXT NAME:              debug_uart_tx.v
// PATH:                   E:\post\fpga_compi\example\gowin\ch34_uart_ddr3_tft_hdmi\src\debug_uart_tx.v
// Descriptions:           
//                         
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module debug_uart_tx(
    input                               clk                        ,
    input                               rst_n                      ,
    input                            [47:0] datain  , 
    input                               data_de  , 
    output                              uart_tx
);

    parameter CLK_FRE = 33; 
	parameter BAUD_RATE = 1000000; 

    reg [7:0] tx_data;
    reg tx_data_valid;
    wire tx_data_ready;
    reg tx_data_ready_r;
    reg [3:0] tx_cnt;
    wire pose;

	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			tx_data_ready_r <= 1'd0 ;
		end
		else begin
			tx_data_ready_r <= tx_data_ready ;
		end
	end

	assign pose = tx_data_ready && (~tx_data_ready_r);

	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			tx_cnt <= 4'd0 ;
			tx_data<= 8'd0 ;
			tx_data_valid<= 1'd0 ;
		end
		else begin
			case (tx_cnt)
				4'd0 :begin
					tx_cnt <= 4'd1 ;
				end 
				4'd1 : begin
					if(data_de && tx_data_ready) begin
						tx_data <= datain[47:40];
						tx_data_valid <= 1'd1 ;
						tx_cnt <= 4'd2 ;
                	end
				end
				4'd2 : begin
					tx_data_valid <= 1'd0 ;
					if(pose) begin
						tx_data <= datain[39:32];
						tx_data_valid <= 1'd1 ;
						tx_cnt <= 4'd3 ;
                	end
				end
				4'd3 : begin
					tx_data_valid <= 1'd0 ;
					if(pose) begin
						tx_data <= datain[31:24];
						tx_data_valid <= 1'd1 ;
						tx_cnt <= 4'd4 ;
                	end
				end
				4'd4 : begin
					tx_data_valid <= 1'd0 ;
					if(pose) begin
						tx_data <= datain[23:16];
						tx_data_valid <= 1'd1 ;
						tx_cnt <= 4'd5 ;
                	end
				end
				4'd5 : begin
					tx_data_valid <= 1'd0 ;
					if(pose) begin
						tx_data <= datain[15:8];
						tx_data_valid <= 1'd1 ;
						tx_cnt <= 4'd6 ;
                	end
				end
				4'd6 : begin
					tx_data_valid <= 1'd0 ;
					if(pose) begin
						tx_data <= datain[7:0];
						tx_data_valid <= 1'd1 ;
						tx_cnt <= 4'd7 ;
                	end
				end
				4'd7 : begin
					tx_data_valid <= 1'd0 ;
					tx_cnt <= 4'd0 ;
				end
			default: ;
			endcase
		end
	end
    
uart_tx#(
	.CLK_FRE        (CLK_FRE        ),
	.BAUD_RATE      (BAUD_RATE      )
)
 u_uart_tx(
    .clk                                (clk                       ), // clock input
    .rst_n                              (rst_n                     ), // asynchronous reset input, low active
    .tx_data                            (tx_data                   ), // data to send
    .tx_data_valid                      (tx_data_valid             ), // data to be sent is valid
    .tx_data_ready                      (tx_data_ready             ), // send ready
    .tx_pin                             (uart_tx             ) // serial data output
);


                                                                   
endmodule