// -----------------------------------------------------------------------------
// 文件名称: triangle_wave_gen.v
// 模块功能: 三角波发生器，使用查找表生成8位数字三角波信号
// 创建日期: 2025-04-02
// -----------------------------------------------------------------------------

module triangle_wave_gen (
    input  wire        clk,         // 系统时钟输入，50MHz
    input  wire        rst_n,       // 低电平有效复位信号
    input  wire [7:0]  freq_ctrl,   // 频率控制值，值越大频率越高
    output reg  [7:0]  wave_data    // 三角波数据输出，8位分辨率
);

    // 参数定义
    parameter ADDR_WIDTH = 8;                    // 地址位宽
    parameter POINTS = 256;                      // 采样点数
    
    // 内部信号定义
    reg [15:0] div_cnt;                         // 分频计数器
    reg [ADDR_WIDTH-1:0] addr;                  // 查找表地址
    
    // ROM存储波形数据
    reg [7:0] tri_rom [0:POINTS-1];             // 三角波查找表
    
    // 初始化波形查找表
    integer i;
    initial begin
        // 生成三角波数据（使用线性插值）
        for(i = 0; i < 256; i = i + 1) begin
            if (i < 128) begin
                // 前半周期：128 -> 255
                tri_rom[i] = 128 + i;
            end
            else begin
                // 后半周期：255 -> 128
                tri_rom[i] = 255 - (i - 128);
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
            wave_data <= tri_rom[addr];  // 输出查找表中的数据
        end
    end

endmodule 