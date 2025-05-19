// -----------------------------------------------------------------------------
// 文件名称: square_wave_gen.v
// 模块功能: 方波发生器，生成8位数字方波信号
// 创建日期: 2025-04-02
// -----------------------------------------------------------------------------

module square_wave_gen (
    input  wire        clk,         // 系统时钟输入，50MHz
    input  wire        rst_n,       // 低电平有效复位信号
    input  wire [7:0]  freq_ctrl,   // 频率控制值，值越大频率越高
    output reg  [7:0]  wave_data    // 方波数据输出，8位分辨率
);

    // 内部信号定义
    reg [15:0] div_cnt;             // 分频计数器
    reg        square_out;          // 方波输出
    
    // 分频计数和方波生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= 16'd0;
            square_out <= 1'b0;
        end
        else begin
            if (div_cnt >= {freq_ctrl, 8'd0} * 4) begin  // 增加分频系数，降低频率
                div_cnt <= 16'd0;                    // 计数器清零
                square_out <= ~square_out;           // 方波翻转
            end
            else begin
                div_cnt <= div_cnt + 1'b1;          // 计数器增加
            end
        end
    end

    // 方波数据输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wave_data <= 8'd128;  // 复位时输出中间值
        end
        else begin
            wave_data <= square_out ? 8'd255 : 8'd128;  // 高电平输出255，低电平输出128
        end
    end

endmodule 