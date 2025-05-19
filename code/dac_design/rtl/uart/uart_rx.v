// -----------------------------------------------------------------------------
// 文件名称: uart_rx.v
// 模块功能: 串口接收模块，用于接收串口数据
// 创建日期: 2025-04-02
// -----------------------------------------------------------------------------

module uart_rx #(
    parameter CLK_FREQ   = 50_000_000,  // 系统时钟频率
    parameter BAUD_RATE  = 115200       // 串口波特率
)(
    input  wire       clk,          // 系统时钟
    input  wire       rst_n,        // 低电平有效复位信号
    input  wire       rx_pin,       // 串口接收引脚
    
    output reg [7:0]  rx_data,      // 接收到的数据
    output reg        rx_valid      // 数据有效标志
);

    // 计算波特率分频系数
    localparam BAUD_DIV  = CLK_FREQ / BAUD_RATE;
    localparam BAUD_HALF = BAUD_DIV / 2;
    
    // 状态机状态定义
    localparam IDLE    = 2'b00;     // 空闲状态
    localparam START   = 2'b01;     // 检测到起始位
    localparam DATA    = 2'b10;     // 接收数据位
    localparam STOP    = 2'b11;     // 接收停止位
    
    // 内部寄存器
    reg [1:0]  state;               // 当前状态
    reg [15:0] baud_cnt;            // 波特率计数器
    reg [2:0]  bit_cnt;             // 数据位计数器
    reg [7:0]  rx_shift;            // 数据接收移位寄存器
    reg        rx_d1, rx_d2;        // 输入同步与边沿检测
    
    // 输入同步，防止亚稳态
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_d1 <= 1'b1;
            rx_d2 <= 1'b1;
        end
        else begin
            rx_d1 <= rx_pin;
            rx_d2 <= rx_d1;
        end
    end
    
    // 串口接收状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            baud_cnt  <= 16'd0;
            bit_cnt   <= 3'd0;
            rx_shift  <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end
        else begin
            // 默认每个时钟周期复位valid信号
            rx_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    // 检测下降沿，起始位
                    if (rx_d2 == 1'b1 && rx_d1 == 1'b0) begin
                        state    <= START;
                        baud_cnt <= 16'd0;
                    end
                end
                
                START: begin
                    // 采样在起始位中间点，确认是否为有效起始位
                    if (baud_cnt == BAUD_HALF - 1) begin
                        if (rx_d2 == 1'b0) begin  // 确认为低电平
                            state    <= DATA;
                            bit_cnt  <= 3'd0;
                            baud_cnt <= 16'd0;
                        end
                        else begin
                            state <= IDLE;  // 不是有效起始位
                        end
                    end
                    else begin
                        baud_cnt <= baud_cnt + 16'd1;
                    end
                end
                
                DATA: begin
                    // 在每个波特率周期中间点采样
                    if (baud_cnt == BAUD_DIV - 1) begin
                        baud_cnt <= 16'd0;
                        
                        // 接收数据位，LSB优先
                        rx_shift <= {rx_d2, rx_shift[7:1]};
                        
                        // 检查是否接收完全部8位数据
                        if (bit_cnt == 3'd7) begin
                            state <= STOP;
                        end
                        else begin
                            bit_cnt <= bit_cnt + 3'd1;
                        end
                    end
                    else begin
                        baud_cnt <= baud_cnt + 16'd1;
                    end
                end
                
                STOP: begin
                    // 在停止位中间点检查
                    if (baud_cnt == BAUD_DIV - 1) begin
                        if (rx_d2 == 1'b1) begin  // 确认为高电平停止位
                            rx_data  <= rx_shift;
                            rx_valid <= 1'b1;
                        end
                        
                        state    <= IDLE;
                        baud_cnt <= 16'd0;
                    end
                    else begin
                        baud_cnt <= baud_cnt + 16'd1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule 