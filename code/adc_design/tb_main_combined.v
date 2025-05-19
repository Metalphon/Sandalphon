`timescale 1ns/1ps

module tb_main_combined();

    // 时钟和复位信号
    reg clk;
    reg rst_n;
    
    // IIC接口信号
    wire scl;
    wire sda;
    
    // LCD1602接口信号
    wire lcd_rs;
    wire lcd_rw;
    wire lcd_en;
    wire [7:0] lcd_data;
    
    // PCF8591模拟
    reg [7:0] pcf8591_data;
    reg pcf8591_ack;
    
    // IIC上拉电阻模拟
    pullup(scl);
    pullup(sda);
    
    // 初始化
    initial begin
        clk = 0;
        rst_n = 0;
        pcf8591_data = 8'h80; // 初始值，对应2.5V
        pcf8591_ack = 0;
        
        // 复位
        #100 rst_n = 1;
        
        // 模拟电压变化
        #10000000 pcf8591_data = 8'hA0; // 修改为3.13V
        #10000000 pcf8591_data = 8'h40; // 修改为1.25V
        #10000000 pcf8591_data = 8'hFF; // 修改为5.00V
        
        // 仿真足够长时间
        #10000000 $finish;
    end
    
    // 时钟生成
    always #10 clk = ~clk; // 50MHz时钟
    
    // PCF8591响应模拟
    reg [2:0] iic_state;
    reg [2:0] byte_cnt;
    reg [2:0] bit_cnt;
    reg sda_drive;
    reg sending;
    
    initial begin
        iic_state = 0;
        byte_cnt = 0;
        bit_cnt = 0;
        sda_drive = 0;
        sending = 0;
    end
    
    // SDA控制
    assign sda = (sda_drive) ? 1'b0 : 1'bz;
    
    // 监视IIC总线活动
    always @(negedge scl or negedge sda) begin
        // START条件检测：SCL为高时SDA由高变低
        if (scl && !sda) begin
            iic_state <= 1; // 地址接收状态
            byte_cnt <= 0;
            bit_cnt <= 0;
            sending <= 0;
        end
        // STOP条件由主机产生，不需要从机响应
    end
    
    // 监听SCL上升沿读取数据，下降沿发送数据
    always @(posedge scl) begin
        // 读取SDA线上的数据
        if (iic_state == 1) begin // 地址接收状态
            if (bit_cnt < 7) begin
                bit_cnt <= bit_cnt + 1;
            end
            else begin // 第8位是读/写位
                bit_cnt <= 0;
                if (sda == 1) begin // 读操作
                    sending <= 1;
                end
                sda_drive <= 1; // 准备发送ACK
                iic_state <= 2; // ACK状态
            end
        end
        else if (iic_state == 3) begin // 数据接收状态
            if (bit_cnt < 7) begin
                bit_cnt <= bit_cnt + 1;
            end
            else begin
                bit_cnt <= 0;
                sda_drive <= 1; // 准备发送ACK
                iic_state <= 2; // ACK状态
                byte_cnt <= byte_cnt + 1;
            end
        end
    end
    
    always @(negedge scl) begin
        // 发送数据和ACK
        if (iic_state == 2) begin // ACK状态
            if (sending) begin
                iic_state <= 4; // 数据发送状态
                bit_cnt <= 0;
                sda_drive <= (pcf8591_data[7] == 0); // 发送数据MSB
            end
            else begin
                iic_state <= 3; // 数据接收状态
            end
            // ACK后释放SDA线
            #1 sda_drive <= 0;
        end
        else if (iic_state == 4) begin // 数据发送状态
            if (bit_cnt < 7) begin
                sda_drive <= (pcf8591_data[6-bit_cnt] == 0);
                bit_cnt <= bit_cnt + 1;
            end
            else begin
                sda_drive <= 0; // 释放SDA线，等待主机ACK
                iic_state <= 5; // 等待主机ACK
            end
        end
    end
    
    // 顶层设计实例
    main_combined u_main(
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .lcd_rs(lcd_rs),
        .lcd_rw(lcd_rw),
        .lcd_en(lcd_en),
        .lcd_data(lcd_data)
    );
    
    // 仿真波形监测
    initial begin
        $monitor("Time=%t, Voltage=%h, LCD_RS=%b, LCD_RW=%b, LCD_EN=%b, LCD_DATA=%h",
                 $time, u_main.voltage, lcd_rs, lcd_rw, lcd_en, lcd_data);
    end
    
    // LCD1602状态监控
    reg [7:0] lcd_char;
    always @(posedge lcd_en) begin
        if (lcd_rs) begin // 数据模式
            lcd_char = lcd_data;
            $display("LCD显示字符: %c (0x%h)", lcd_char, lcd_char);
        end
        else begin // 命令模式
            $display("LCD命令: 0x%h", lcd_data);
        end
    end

endmodule 