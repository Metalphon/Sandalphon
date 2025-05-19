// -----------------------------------------------------------------------------
// 文件名称: sine_wave_gen.v
// 模块功能: 正弦波发生器，使用查找表生成8位数字正弦波信号
// 创建日期: 2025-04-02
// -----------------------------------------------------------------------------

module sine_wave_gen (
    input  wire        clk,         // 系统时钟输入，50MHz
    input  wire        rst_n,       // 低电平有效复位信号
    input  wire [7:0]  freq_ctrl,   // 频率控制值，值越大频率越高
    output reg  [7:0]  wave_data    // 正弦波数据输出，8位分辨率
);

    // 参数定义
    parameter ADDR_WIDTH = 8;                    // 地址位宽
    parameter POINTS = 256;                      // 采样点数
    
    // 内部信号定义
    reg [15:0] div_cnt;                         // 分频计数器
    reg [ADDR_WIDTH-1:0] addr;                  // 查找表地址
    
    // ROM存储波形数据
    reg [7:0] sine_rom [0:POINTS-1];            // 正弦波查找表
    
    // 初始化波形查找表
    integer i;
    initial begin
        // 生成正弦波数据（使用查找表方式）
        for(i = 0; i < 256; i = i + 1) begin
            if (i < 64) begin
                // 第一个1/4周期：128 -> 255
                sine_rom[i] = 128 + (i * 2);
            end
            else if (i < 128) begin
                // 第二个1/4周期：255 -> 128
                sine_rom[i] = 255 - ((i - 64) * 2);
            end
            else if (i < 192) begin
                // 第三个1/4周期：128 -> 0
                sine_rom[i] = 128 - ((i - 128) * 2);
            end
            else begin
                // 第四个1/4周期：0 -> 128
                sine_rom[i] = (i - 192) * 2;
            end
        end
    end

    // 分频计数和地址更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= 16'd0;
            addr <= {ADDR_WIDTH{1'b0}};
        end
        else begin
            if (div_cnt >= {freq_ctrl, 8'd0} * 4) begin  // 增加分频系数，降低频率
                div_cnt <= 16'd0;                    // 计数器清零
                if (addr == POINTS - 1)              // 检查是否到达表尾
                    addr <= {ADDR_WIDTH{1'b0}};      // 回到表头
                else
                    addr <= addr + 1'b1;             // 地址增加
            end
            else begin
                div_cnt <= div_cnt + 1'b1;          // 计数器增加
            end
        end
    end

    // 波形数据输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wave_data <= 8'd128;  // 复位时输出中间值
        end
        else begin
            wave_data <= sine_rom[addr];  // 输出查找表中的数据
        end
    end

endmodule 