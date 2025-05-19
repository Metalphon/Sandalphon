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
// Last modified Date:     2024/12/29 16:18:20
// Last Version:           V1.0
// Descriptions:           
//----------------------------------------------------------------------------------------
// Created by:             ff
// Created date:           2024/12/29 16:18:20
// mail      :             fyzhang1123@163.com
// Version:                V1.0
// TEXT NAME:              top.v
// PATH:                   E:\post\fpga_compi\example\temp\temp\src\top.v
// Descriptions:           
//                         
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module test(
    input clk,
    input rst_n,
    input key_in, 
    input fire_detect,
    inout iic_0_scl,              
    inout iic_0_sda,  
    output uart_tx, 
    output [3:0] led,
    input intr,
    inout dht11_data,
    output wire [7:0] temp_value,
    output wire [7:0] humi_value,
    output wire [3:0] state,
	 output reg fan_control,
    output wire data_valid,
    inout reg fire_alarm_out,
    output reg fire_level_out                
);

  wire [35:0] temp_data;
  wire temp_data_de;
  wire dht11_data_valid;
  reg [47:0] all_data;
  reg data_valid_all;
  reg [7:0] update_cnt;
  reg [19:0] freq_cnt_fan;
  reg [10:0] freq_cnt;
  
  parameter FREQ_DIV = 8333;  // 50MHz / 30kHz / 2 = 833
always@(posedge clk)
	begin
		if(freq_cnt_fan >= FREQ_DIV - 1) begin
          freq_cnt_fan <= 11'd0;
          fire_alarm_out <= ~fire_alarm_out;
        end
        else begin
          freq_cnt_fan <= freq_cnt_fan + 1'b1;
        end
	end
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      freq_cnt <= 11'd0;
		fan_control<=1'd0;
      //fire_alarm_out <= 1'b0;
      fire_level_out <= 1'b0;
    end
    else begin
      if(!fire_detect) begin
        fire_level_out <= fire_alarm_out;
		  fan_control<=1'd1;
      end
      else begin
        freq_cnt <= 11'd0;
        //fire_alarm_out <= 1'b0;
		  fan_control<=1'd0;
        fire_level_out <= 1'b0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      all_data <= 48'd0;
      data_valid_all <= 1'b0;
      update_cnt <= 8'd0;
    end
    else begin
      if(update_cnt > 8'd0) begin
        update_cnt <= update_cnt - 1'b1;
        data_valid_all <= 1'b0;
      end

      if(temp_data_de) begin
        all_data[47:0] <= {12'd0, temp_data};
        
        if(update_cnt == 8'd0) begin
          data_valid_all <= 1'b1;
          update_cnt <= 8'd100;
        end
      end

      if(dht11_data_valid) begin
        all_data[15:0] <= {temp_value, humi_value};
        if(update_cnt == 8'd0) begin
          data_valid_all <= 1'b1;
          update_cnt <= 8'd100;
        end
      end
    end
  end

  dht11_module dht11_inst(
    .sys_clk(clk),
    .rst_n(rst_n),
    .dht11(dht11_data),
    .state(state),
    .temp_value(temp_value),
    .humi_value(humi_value),
    .data_valid(dht11_data_valid)
  );

  top_temp u_top_temp(
    .clk(clk),
    .rst_n(rst_n),
    .temp_data(temp_data),
    .temp_data_de(temp_data_de),
    .iic_0_scl(iic_0_scl),
    .iic_0_sda(iic_0_sda),
    .intr(intr)
  );   

  debug_uart_tx #(
    .CLK_FRE(50),
    .BAUD_RATE(115200)
  ) u_temp_uart_tx(
    .clk(clk),
    .rst_n(rst_n),
    .datain(all_data),     
    .data_de(data_valid_all),
    .uart_tx(uart_tx)
  );

endmodule