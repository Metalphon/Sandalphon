module voltage_convert_table(
    input wire clk,                // 系统时钟
    input wire rst_n,              // 复位信号，低电平有效
    input wire [7:0] adc_data,     // ADC数据
    input wire adc_data_valid,     // ADC数据有效标志
    output reg [15:0] voltage      // 转换后的电压值（放大100倍用于显示）
);

    // 电压校准表 - 针对特定范围的ADC值进行特定校准
    // ADC数据范围在0-255，对应0-5V，这里我们设置几个关键点进行校准
    // 格式：{ADC值, 校准后的电压值(放大100倍)}
    // 例如：ADC=128(约2.5V原始值)应该显示为3.3V，所以设置为{8'd128, 16'd330}
    reg [23:0] calib_table [0:7];
    
    // 内部信号定义
    reg [7:0] lower_idx;   // 查找表下边界索引
    reg [7:0] upper_idx;   // 查找表上边界索引
    reg [7:0] adc_lower;   // 下边界ADC值
    reg [7:0] adc_upper;   // 上边界ADC值
    reg [15:0] volt_lower; // 下边界电压值
    reg [15:0] volt_upper; // 上边界电压值
    reg [23:0] voltage_temp; // 临时电压值计算
    
    // 初始化校准表
    initial begin
        // 配置校准表，可以根据实际测量结果调整
        // {ADC值, 校准后的电压值(放大100倍)}
        calib_table[0] = {8'd0,   16'd0};   // 0V
        calib_table[1] = {8'd51,  16'd100};  // 1V
        calib_table[2] = {8'd102, 16'd200};  // 2V
        calib_table[3] = {8'd128, 16'd250};  // 2.5V应显示为2.5V
        calib_table[4] = {8'd153, 16'd300};  // 3V
        calib_table[5] = {8'd179, 16'd350};  // 3.5V
        calib_table[6] = {8'd192, 16'd376};  // 3.76V应显示为3.76V
        calib_table[7] = {8'd255, 16'd500};  // 5V
    end
    
    // 电压转换逻辑 - 使用线性插值法
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            voltage <= 16'd0;
            lower_idx <= 8'd0;
            upper_idx <= 8'd0;
            adc_lower <= 8'd0;
            adc_upper <= 8'd0;
            volt_lower <= 16'd0;
            volt_upper <= 16'd0;
            voltage_temp <= 24'd0;
        end
        else if (adc_data_valid) begin
            // 首先找到ADC值在校准表中的位置
            if (adc_data <= calib_table[0][23:16]) begin
                // 小于最小值，直接使用第一个校准点
                voltage <= calib_table[0][15:0];
            end
            else if (adc_data >= calib_table[7][23:16]) begin
                // 大于最大值，直接使用最后一个校准点
                voltage <= calib_table[7][15:0];
            end
            else begin
                // 查找ADC值所在的区间
                if (adc_data > calib_table[0][23:16] && adc_data <= calib_table[1][23:16]) begin
                    lower_idx <= 8'd0;
                    upper_idx <= 8'd1;
                end 
                else if (adc_data > calib_table[1][23:16] && adc_data <= calib_table[2][23:16]) begin
                    lower_idx <= 8'd1;
                    upper_idx <= 8'd2;
                end
                else if (adc_data > calib_table[2][23:16] && adc_data <= calib_table[3][23:16]) begin
                    lower_idx <= 8'd2;
                    upper_idx <= 8'd3;
                end
                else if (adc_data > calib_table[3][23:16] && adc_data <= calib_table[4][23:16]) begin
                    lower_idx <= 8'd3;
                    upper_idx <= 8'd4;
                end
                else if (adc_data > calib_table[4][23:16] && adc_data <= calib_table[5][23:16]) begin
                    lower_idx <= 8'd4;
                    upper_idx <= 8'd5;
                end
                else if (adc_data > calib_table[5][23:16] && adc_data <= calib_table[6][23:16]) begin
                    lower_idx <= 8'd5;
                    upper_idx <= 8'd6;
                end
                else if (adc_data > calib_table[6][23:16] && adc_data <= calib_table[7][23:16]) begin
                    lower_idx <= 8'd6;
                    upper_idx <= 8'd7;
                end
                
                // 获取边界值
                adc_lower <= calib_table[lower_idx][23:16];
                adc_upper <= calib_table[upper_idx][23:16];
                volt_lower <= calib_table[lower_idx][15:0];
                volt_upper <= calib_table[upper_idx][15:0];
                
                // 线性插值计算
                // 公式: volt = volt_lower + (adc - adc_lower) * (volt_upper - volt_lower) / (adc_upper - adc_lower)
                voltage_temp <= volt_lower + ((adc_data - adc_lower) * (volt_upper - volt_lower)) / (adc_upper - adc_lower);
                voltage <= voltage_temp[15:0];
            end
        end
    end

endmodule 