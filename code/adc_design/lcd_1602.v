module lcd_1602(clk,rst_n,voltage,lcd_en,lcd_rw,lcd_rs,lcd_data);
input clk;
input rst_n;
input [15:0] voltage;     // 电压值(放大100倍)
output lcd_en;      //使能端
output lcd_rw;      //读、写选择端
output lcd_rs;      //指令和数据寄存器选择端
output [7:0]lcd_data;  //数据端

wire clk;
wire rst_n;
wire lcd_en;
wire lcd_rw;
reg lcd_rs;
reg [7:0]lcd_data;

// 上电显示的固定字符串
wire [127:0] row_1;  //第一行地址，16x8=128
wire [127:0] row_2;  //第二行地址

//LCD1602需要显示的字符
assign row_1 = "Voltage:       ";   //第一行显示的内容，可以显示16个字符
assign row_2 = "ADC PCF8591    ";   //第二行显示的内容，空格也算字符

parameter TIME_20MS = 1000_000;  //等待20ms，系统上电稳定
parameter TIME_500HZ = 100_000;  //LCD1602的工作频率为500HZ

//模块工作采用状态机驱动
//因为此状态机一共有40个状态，这里用了格雷码，一次只有1位发生改变
parameter IDLE = 8'h00;
parameter SET_FUNCTION = 8'h01;
parameter DISP_OFF = 8'h03;
parameter DISP_CLEAR = 8'h02;
parameter ENTRY_MODE = 8'h06;
parameter DISP_ON = 8'h07;
parameter ROW1_ADDR = 8'h05;  //第一行地址状态
parameter ROW1_0 = 8'h04;
parameter ROW1_1 = 8'h0C;
parameter ROW1_2 = 8'h0D;
parameter ROW1_3 = 8'h0F;
parameter ROW1_4 = 8'h0E;
parameter ROW1_5 = 8'h0A;
parameter ROW1_6 = 8'h0B;
parameter ROW1_7 = 8'h09;
parameter ROW1_8 = 8'h08;  // 用于显示电压值(空格)
parameter ROW1_9 = 8'h18;  // 整数部分
parameter ROW1_A = 8'h19;  // 小数点
parameter ROW1_B = 8'h1B;  // 小数第一位
parameter ROW1_C = 8'h1A;  // 小数第二位
parameter ROW1_D = 8'h1E;  // V (单位)
parameter ROW1_E = 8'h1F;  // 空格
parameter ROW1_F = 8'h1D;  // 空格

parameter ROW2_ADDR = 8'h1C;  //第二行地址状态
parameter ROW2_0 = 8'h14;
parameter ROW2_1 = 8'h15;
parameter ROW2_2 = 8'h17;
parameter ROW2_3 = 8'h16;
parameter ROW2_4 = 8'h12;
parameter ROW2_5 = 8'h13;
parameter ROW2_6 = 8'h11;
parameter ROW2_7 = 8'h10;
parameter ROW2_8 = 8'h30;
parameter ROW2_9 = 8'h31;
parameter ROW2_A = 8'h33;
parameter ROW2_B = 8'h32;
parameter ROW2_C = 8'h36;
parameter ROW2_D = 8'h37;
parameter ROW2_E = 8'h35;
parameter ROW2_F = 8'h34;

// 电压显示用字符常量
parameter [7:0] CHAR_V = 8'h56;   // 字符 'V'
parameter [7:0] CHAR_DOT = 8'h2E; // 字符 '.'
parameter [7:0] CHAR_SPACE = 8'h20; // 空格
parameter [7:0] CHAR_0 = 8'h30;   // 字符 '0'

// 电压值分解寄存器
reg [15:0] voltage_reg;        // 电压值寄存器
reg [3:0] volt_int;            // 电压整数部分
reg [7:0] volt_dec;            // 电压小数部分

// 初始化标志
reg init_done;                 // 初始化完成标志

//20ms的计数器，即初始化第一步
reg [19:0]cnt_20ms;
always @(posedge clk or negedge rst_n)
  begin
    if(rst_n == 1'b0)
      cnt_20ms <= 0;
    else if(cnt_20ms == TIME_20MS - 1)
      cnt_20ms <= cnt_20ms;
    else
      cnt_20ms <= cnt_20ms + 1;
  end
  
wire delay_done = (cnt_20ms == TIME_20MS-1)? 1'b1 : 1'b0;  //上电延时完成
reg [19:0] cnt_500hz;
always @(posedge clk or negedge rst_n)
  begin
    if(rst_n == 1'b0)
      cnt_500hz <= 0;
    else if(delay_done == 1)
      begin
        if(cnt_500hz == TIME_500HZ - 1)
          cnt_500hz <= 0;
        else
          cnt_500hz <= cnt_500hz + 1;
      end
    else
      cnt_500hz <= 0;
  end

//使能端，下降沿执行命令
assign lcd_en = (cnt_500hz > (TIME_500HZ-1)/2)? 1'b0 : 1'b1;
//write_flag置高一周期
wire write_flag = (cnt_500hz == TIME_500HZ - 1)? 1'b1 : 1'b0;

// 初始化完成标志设置
always @(posedge clk or negedge rst_n)
  begin
    if(rst_n == 1'b0)
      init_done <= 1'b0;
    else if(c_state == DISP_ON && write_flag)
      init_done <= 1'b1;
    else
      init_done <= init_done;
  end

//状态机控制LCD1602的显示过程
reg [5:0] c_state;  //当前状态
reg [5:0] n_state;  //下一个状态

always @(posedge clk or negedge rst_n)
  begin
    if(rst_n == 1'b0)
      c_state <= IDLE;
    else if(write_flag == 1)  //每一个工作周期改变一次状态
      c_state <= n_state;
    else
      c_state <= c_state;
  end

always @(*)
  begin
    case(c_state)
    IDLE:n_state = SET_FUNCTION;
    SET_FUNCTION:n_state = DISP_OFF;
    DISP_OFF:n_state = DISP_CLEAR;
    DISP_CLEAR:n_state = ENTRY_MODE;
    ENTRY_MODE:n_state = DISP_ON;
    DISP_ON:n_state = ROW1_ADDR;
    ROW1_ADDR:n_state = ROW1_0;
    ROW1_0:n_state = ROW1_1;
    ROW1_1:n_state = ROW1_2;
    ROW1_2:n_state = ROW1_3;
    ROW1_3:n_state = ROW1_4;
    ROW1_4:n_state = ROW1_5;
    ROW1_5:n_state = ROW1_6;
    ROW1_6:n_state = ROW1_7;
    ROW1_7:n_state = ROW1_8;
    ROW1_8:n_state = ROW1_9;
    ROW1_9:n_state = ROW1_A;
    ROW1_A:n_state = ROW1_B;
    ROW1_B:n_state = ROW1_C;
    ROW1_C:n_state = ROW1_D;
    ROW1_D:n_state = ROW1_E;
    ROW1_E:n_state = ROW1_F;
    
    ROW1_F:n_state = ROW2_ADDR;
    ROW2_ADDR:n_state = ROW2_0;
    ROW2_0:n_state = ROW2_1;
    ROW2_1:n_state = ROW2_2;
    ROW2_2:n_state = ROW2_3;
    ROW2_3:n_state = ROW2_4;
    ROW2_4:n_state = ROW2_5;
    ROW2_5:n_state = ROW2_6;
    ROW2_6:n_state = ROW2_7;
    ROW2_7:n_state = ROW2_8;
    ROW2_8:n_state = ROW2_9;
    ROW2_9:n_state = ROW2_A;
    ROW2_A:n_state = ROW2_B;
    ROW2_B:n_state = ROW2_C;
    ROW2_C:n_state = ROW2_D;
    ROW2_D:n_state = ROW2_E;
    ROW2_E:n_state = ROW2_F;
    ROW2_F:n_state = ROW1_ADDR;
    default:n_state = n_state;
    endcase 
  end

assign lcd_rw = 0;  //写状态
always @(posedge clk or negedge rst_n)
  begin
    if(rst_n == 1'b0)
      lcd_rs <= 0;            //0表示命令，1表示数据
    else if(write_flag == 1)  //当前状态为7个指令中任意一个时，将RS置0
      begin  //初始化指令，写地址指令（第一行、第二行）
        if((n_state == SET_FUNCTION)||(n_state == DISP_OFF)||(n_state == DISP_CLEAR)||(n_state == ENTRY_MODE)||(n_state == DISP_ON)||(n_state == ROW1_ADDR)||(n_state == ROW2_ADDR))
          lcd_rs <= 0;  //写指令
        else
          lcd_rs <= 1;  //写数据
      end
    else
      lcd_rs <= lcd_rs;
  end

// 电压值处理 - 上电立即设置初始值，且在每次轮询时更新
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        voltage_reg <= 16'd0;
        volt_int <= 4'd0;
        volt_dec <= 8'd0;
    end
    else if(c_state == ROW1_ADDR && write_flag) begin
        // 更新电压值和分离整数、小数部分
        voltage_reg <= voltage;
        volt_int <= voltage / 100;
        volt_dec <= voltage % 100;
    end
    // 上电初始显示0.00V
    else if(delay_done && !init_done) begin
        voltage_reg <= 16'd0;
        volt_int <= 4'd0;
        volt_dec <= 8'd0;
    end
end

//各状态数据
always @(posedge clk or negedge rst_n)
  begin
    if(rst_n == 1'b0)
      lcd_data <= 0;
    else if(write_flag)
      begin
        case(n_state)
        IDLE:lcd_data <= 8'hxx;
        SET_FUNCTION:lcd_data <= 8'h38;  //设置显示两行，5x7点阵
        DISP_OFF:lcd_data <= 8'h08;      //不显示
        DISP_CLEAR:lcd_data <= 8'h01;    //清屏
        ENTRY_MODE:lcd_data <= 8'h06;    //地址加1
        DISP_ON:lcd_data <= 8'h0C;       //开始显示，没有光标，不闪烁
        
        ROW1_ADDR:lcd_data <= 8'h80; //设置DDRAM地址，从第一行开始，将输入的row_1分配给对应的显示位
        ROW1_0:lcd_data <= row_1[127:120];
        ROW1_1:lcd_data <= row_1[119:112];
        ROW1_2:lcd_data <= row_1[111:104];
        ROW1_3:lcd_data <= row_1[103:96];
        ROW1_4:lcd_data <= row_1[95:88];
        ROW1_5:lcd_data <= row_1[87:80];
        ROW1_6:lcd_data <= row_1[79:72];
        ROW1_7:lcd_data <= row_1[71:64];
        
        // 显示电压值部分，即使上电时也能显示0.00V
        ROW1_8:lcd_data <= CHAR_SPACE;
        ROW1_9:lcd_data <= CHAR_0 + volt_int;        // 整数部分
        ROW1_A:lcd_data <= CHAR_DOT;                 // 小数点
        ROW1_B:lcd_data <= CHAR_0 + volt_dec/10;     // 小数第一位
        ROW1_C:lcd_data <= CHAR_0 + volt_dec%10;     // 小数第二位
        ROW1_D:lcd_data <= CHAR_V;                   // 单位V
        ROW1_E:lcd_data <= CHAR_SPACE;               // 空格
        ROW1_F:lcd_data <= CHAR_SPACE;               // 空格
        
        ROW2_ADDR:lcd_data <= 8'hC0;  //设置DDRAM，从第二行开始
        ROW2_0:lcd_data <= row_2[127:120];
        ROW2_1:lcd_data <= row_2[119:112];
        ROW2_2:lcd_data <= row_2[111:104];
        ROW2_3:lcd_data <= row_2[103:96];
        ROW2_4:lcd_data <= row_2[95:88];
        ROW2_5:lcd_data <= row_2[87:80];
        ROW2_6:lcd_data <= row_2[79:72];
        ROW2_7:lcd_data <= row_2[71:64];
        ROW2_8:lcd_data <= row_2[63:56];
        ROW2_9:lcd_data <= row_2[55:48];
        ROW2_A:lcd_data <= row_2[47:40];
        ROW2_B:lcd_data <= row_2[39:32];
        ROW2_C:lcd_data <= row_2[31:24];
        ROW2_D:lcd_data <= row_2[23:16];
        ROW2_E:lcd_data <= row_2[15:8];
        ROW2_F:lcd_data <= row_2[7:0];
      endcase
    end
  else
    lcd_data <= lcd_data;
  end

endmodule 