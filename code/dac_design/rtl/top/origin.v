// -----------------------------------------------------------------------------
// 文件名称: origin.v
// 模块功能: 波形发生器顶层模块，通过两个电平输入选择输出不同的波形，通过按钮控制频率
// 创建日期: 2025-04-02
// -----------------------------------------------------------------------------

module origin (
    input  wire        clk,         // 系统时钟输入，50MHz
    input  wire        rst_n,       // 低电平有效复位信号
    input  wire        key,         // 按钮输入，低电平有效
    input  wire        sel1,        // 波形选择输入1
    input  wire        sel2,        // 波形选择输入2
    output wire [7:0]  wave_data,   // 波形数据输出，8位分辨率
    output wire        scl,         // I2C时钟线
    inout  wire        sda,         // I2C数据线
    
    // 调试输出
    output wire [7:0]  square_wave_data,    // 方波数据
    output wire [7:0]  sine_wave_data,      // 正弦波数据
    output wire [7:0]  triangle_wave_data,  // 三角波数据
    output wire [7:0]  freq_ctrl            // 频率控制值
);

    // 参数定义
    parameter FREQ_LOW  = 8'b0000_0010;  // 低频率值
    parameter FREQ_HIGH = 8'b0000_0100;  // 高频率值
    
    // 内部信号定义
    wire [7:0] square_wave_data_internal;    // 方波数据
    wire [7:0] sine_wave_data_internal;      // 正弦波数据
    wire [7:0] triangle_wave_data_internal;  // 三角波数据
    wire [7:0] freq_ctrl_internal;           // 频率控制值
    wire        dac_done;                    // DAC数据发送完成信号
    
    // 按钮消抖和频率控制
    reg key_r1, key_r2;             // 按钮同步寄存器
    reg [7:0] freq_val;             // 频率值寄存器
    
    // 按钮消抖
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_r1 <= 1'b1;
            key_r2 <= 1'b1;
            freq_val <= FREQ_LOW;   // 复位时使用低频率
        end
        else begin
            key_r1 <= key;
            key_r2 <= key_r1;
            
            // 检测按钮下降沿，切换频率
            if (key_r2 && !key_r1) begin
                freq_val <= (freq_val == FREQ_LOW) ? FREQ_HIGH : FREQ_LOW;
            end
        end
    end
    
    // 频率控制值分配
    assign freq_ctrl_internal = freq_val;
    
    // 方波生成模块
    square_wave_gen square_wave_inst (
        .clk(clk),
        .rst_n(rst_n),
        .freq_ctrl(freq_ctrl_internal),
        .wave_data(square_wave_data_internal)
    );
    
    // 正弦波生成模块
    sine_wave_gen sine_wave_inst (
        .clk(clk),
        .rst_n(rst_n),
        .freq_ctrl(freq_ctrl_internal),
        .wave_data(sine_wave_data_internal)
    );
    
    // 三角波生成模块
    triangle_wave_gen triangle_wave_inst (
        .clk(clk),
        .rst_n(rst_n),
        .freq_ctrl(freq_ctrl_internal),
        .wave_data(triangle_wave_data_internal)
    );
    
    // 波形选择逻辑（优先级方式）
    // sel1为高时，无论sel2如何，输出方波
    // sel1为低且sel2为高时，输出三角波
    // sel1为低且sel2为低时，输出正弦波
    assign wave_data = sel1 ? square_wave_data_internal :
                      (!sel1 && sel2) ? triangle_wave_data_internal :
                      sine_wave_data_internal;
                      
    // 调试输出
    assign square_wave_data = square_wave_data_internal;
    assign sine_wave_data = sine_wave_data_internal;
    assign triangle_wave_data = triangle_wave_data_internal;
    assign freq_ctrl = freq_ctrl_internal;
    
    // DAC I2C接口模块
    DAC_I2C #(
        .CNT_NUM(125)                    // 50MHz/(125*2)=200kHz
    ) dac_i2c_inst (
        .clk_in(clk),
        .rst_n_in(rst_n),
        .dac_data(wave_data),            // 输入波形数据
        .dac_done(dac_done),
        .scl_out(scl),
        .sda_out(sda)
    );

endmodule 