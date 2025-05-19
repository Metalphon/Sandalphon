module voltage_convert_dynamic(
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
    // 可以发现，电压越大，校准系数越大，但变化很小
    
    // 校准值参数定义
    parameter SCALE_BASE = 100;    // 校准系数基础值(100表示1.00)
    parameter SCALE_MIN = 132;     // 最小校准系数(132表示1.32)
    parameter SCALE_MAX = 133;     // 最大校准系数(133表示1.33)
    parameter V_MIN = 100;         // 最小参考电压点(1.00V)
    parameter V_MAX = 500;         // 最大参考电压点(5.00V)
    
    // 内部信号定义
    reg [23:0] voltage_temp;       // 临时电压值，扩大位宽以防止计算溢出
    reg [15:0] voltage_raw;        // 原始电压值
    reg [15:0] calib_scale;        // 动态校准系数
    
    // 电压转换逻辑
    // 使用动态校准系数，随电压增大而渐进增大
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            voltage <= 16'd0;
            voltage_temp <= 24'd0;
            voltage_raw <= 16'd0;
            calib_scale <= SCALE_MIN;
        end
        else if (adc_data_valid) begin
            // 第一步：计算原始电压值，将ADC数值(0-255)映射到0-5V范围
            voltage_raw <= (adc_data * REF_VOLTAGE) / 8'd255;
            
            // 第二步：根据电压值动态计算校准系数
            // 使用线性插值：scale = SCALE_MIN + (voltage_raw - V_MIN) * (SCALE_MAX - SCALE_MIN) / (V_MAX - V_MIN)
            if (voltage_raw <= V_MIN) begin
                calib_scale <= SCALE_MIN;
            end 
            else if (voltage_raw >= V_MAX) begin
                calib_scale <= SCALE_MAX;
            end
            else begin
                // 线性插值计算动态校准系数
                calib_scale <= SCALE_MIN + 
                              ((voltage_raw - V_MIN) * (SCALE_MAX - SCALE_MIN)) / 
                              (V_MAX - V_MIN);
            end
            
            // 第三步：应用校准系数
            if (voltage_raw == 16'd0) begin
                voltage <= 16'd0; // 确保0输入显示为0V
            end
            else begin
                // 应用校准系数：voltage = voltage_raw * calib_scale / SCALE_BASE
                voltage_temp <= (voltage_raw * calib_scale) / SCALE_BASE;
                voltage <= voltage_temp[15:0];
            end
        end
    end

endmodule 