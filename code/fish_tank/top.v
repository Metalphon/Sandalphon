module top(
    input                               clk,                // 系统时钟
    input                               rst_n,              // 复位信号
    input                               key_in,             // 按键输入
    input                               mq2_data,           // MQ-2传感器数据输入
    inout                               dht11_data,         // DHT11传感器数据线
    inout                               max30102_sda,       // MAX30102 I2C数据线
    output                              max30102_scl,       // MAX30102 I2C时钟线
    input                               intr,               // MAX30102中断信号
    output                              uart_tx,            // UART发送引脚
    output                              buzzer,             // 蜂鸣器输出
    output                              wave_out,           // 风扇PWM输出
    output [3:0]                        led                 // LED指示灯
);

    // 内部信号定义
    wire [3:0] state;                // DHT11状态
    wire [7:0] device_id_out;        // MAX30102设备ID
    wire [15:0] spo2_data;           // 血氧数据
    wire spo2_data_valid;            // 血氧数据有效标志
    
    // 主模块实例化
    main main_inst(
        .clk(clk),
        .mq2_data(mq2_data),
        .dht11_data(dht11_data),
        .max30102_sda(max30102_sda),
        .max30102_scl(max30102_scl),
        .state(state),
        .buzzer(buzzer),
        .wave_out(wave_out),
        .device_id_out(device_id_out),
        .spo2_data(spo2_data),
        .spo2_data_valid(spo2_data_valid),
        .key_in(key_in),
        .intr(intr),
        .uart_tx(uart_tx)
    );
    
    // LED指示灯控制
    // LED[0]: 显示MAX30102设备ID是否正确(0x15)
    // LED[1]: 显示血氧数据有效标志
    // LED[2]: 显示MQ-2传感器状态
    // LED[3]: 显示DHT11传感器状态
    assign led[0] = (device_id_out == 8'h15);
    assign led[1] = spo2_data_valid;
    assign led[2] = ~mq2_data;  // MQ-2传感器低电平有效
    assign led[3] = (state != 4'd0);  // DHT11传感器工作状态

endmodule 