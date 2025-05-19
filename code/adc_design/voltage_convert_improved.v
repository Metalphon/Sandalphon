module voltage_convert_improved(
    input wire clk,                // 系统时钟
    input wire rst_n,              // 复位信号，低电平有效
    input wire [7:0] adc_data,     // ADC数据
    input wire adc_data_valid,     // ADC数据有效标志
    output reg [15:0] voltage      // 转换后的电压值（放大100倍用于显示）
);

    // PCF8591参数定义
    parameter REF_VOLTAGE = 5_00;   // 参考电压为5V（放大100倍为500）
    
    // 校准参数 - 根据实测数据点拟合
    // 测量点1: 5V实际显示3.76V，校准系数 = 5/3.76 ≈ 1.33
    // 测量点2: 3.3V实际显示2.5V，校准系数 = 3.3/2.5 = 1.32
    // 根据这两点分析，误差率基本成线性关系，但系数略有变化
    parameter K1 = 132;   // 低电压区域校准系数(放大100倍)
    parameter K2 = 133;   // 高电压区域校准系数(放大100倍)
    parameter V_THRESHOLD = 250; // 分段阈值，2.50V(放大100倍)
    
    // 内部信号定义
    reg [23:0] voltage_temp;      // 临时电压值，扩大位宽以防止计算溢出
    reg [15:0] voltage_raw;       // 原始电压值
    reg [15:0] calib_factor;      // 动态校准系数
    
    // 电压转换逻辑
    // 使用分段线性校准，根据电压大小动态调整校准系数
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            voltage <= 16'd0;
            voltage_temp <= 24'd0;
            voltage_raw <= 16'd0;
            calib_factor <= 16'd0;
        end
        else if (adc_data_valid) begin
            // 第一步：计算原始电压值，将ADC数值(0-255)映射到0-5V范围
            voltage_raw <= (adc_data * REF_VOLTAGE) / 8'd255;
            
            // 第二步：根据原始电压确定校准系数
            // 使用动态校准系数，随电压增大而略微增大
            if (voltage_raw <= V_THRESHOLD) begin
                calib_factor <= K1; // 低电压区域使用K1
            end else begin
                // 高电压区域使用K2，或者使用线性插值进一步平滑过渡
                calib_factor <= K2;
            end
            
            // 第三步：应用校准系数
            if (voltage_raw == 16'd0) begin
                voltage <= 16'd0; // 确保0输入显示为0V
            end
            else begin
                // 应用校准系数：voltage = voltage_raw * calib_factor / 100
                voltage_temp <= (voltage_raw * calib_factor) / 16'd100;
                voltage <= voltage_temp[15:0];
            end
        end
    end

endmodule 