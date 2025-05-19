module main(
    input wire clk,          // 系统时钟
    input wire rst_n,        // 复位信号，低电平有效
    
    // IIC接口信号
    inout wire scl,          // IIC时钟线
    inout wire sda,          // IIC数据线
    
    // LCD1602接口信号
    output wire lcd_rs,      // 寄存器选择信号
    output wire lcd_rw,      // 读/写选择信号
    output wire lcd_en,      // 使能信号
    output wire [7:0] lcd_data  // 数据总线
);

    // 内部信号定义
    wire [7:0] adc_data;     // ADC数据
    wire [15:0] voltage;     // 转换后的电压值（放大100倍用于显示）
    wire adc_data_valid;     // ADC数据有效标志
    
    // 模块实例化
    
    // IIC控制模块，用于从PCF8591读取ADC数据
    ADC_I2C u_adc_i2c(
        .clk_in(clk),
        .rst_n_in(rst_n),
        .scl_out(scl),
        .sda_out(sda),
        .adc_done(adc_data_valid),
        .adc_data(adc_data)
    );
    
    // 电压转换模块，将ADC数据转换为电压值并校正显示
    // 使用简单校准系数扩大识别尺度
    voltage_convert u_voltage_convert(
        .clk(clk),
        .rst_n(rst_n),
        .adc_data(adc_data),
        .adc_data_valid(adc_data_valid),
        .voltage(voltage)
    );
    
    // LCD1602显示模块，显示电压值
    lcd_1602 u_lcd1602_display(
        .clk(clk),
        .rst_n(rst_n),
        .voltage(voltage),
        .lcd_rs(lcd_rs),
        .lcd_rw(lcd_rw),
        .lcd_en(lcd_en),
        .lcd_data(lcd_data)
    );

endmodule
