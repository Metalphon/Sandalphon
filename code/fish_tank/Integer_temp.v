module Integer_temp(
    input clk,                  // 系统时钟
    input rstn,                 // 复位信号，低电平有效
    input [17:0] dividend,      // 被除数
    input [17:0] divisor,       // 除数
    output reg [17:0] quotient  // 商
);

    // 内部信号定义
    reg [17:0] dividend_reg;    // 被除数寄存器
    reg [17:0] divisor_reg;     // 除数寄存器
    reg [17:0] quotient_temp;   // 临时商寄存器
    reg [17:0] remainder;       // 余数寄存器
    reg [4:0] count;            // 计数器，最多需要18次迭代
    reg calculating;            // 计算状态标志
    
    // 除法状态机
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // 复位所有寄存器
            dividend_reg <= 18'd0;
            divisor_reg <= 18'd0;
            quotient_temp <= 18'd0;
            remainder <= 18'd0;
            quotient <= 18'd0;
            count <= 5'd0;
            calculating <= 1'b0;
        end
        else begin
            // 检测新的除法操作
            if (!calculating && divisor != 18'd0) begin
                // 初始化除法操作
                dividend_reg <= dividend;
                divisor_reg <= divisor;
                quotient_temp <= 18'd0;
                remainder <= 18'd0;
                count <= 5'd18;  // 18位需要18次迭代
                calculating <= 1'b1;
            end
            // 除法计算过程
            else if (calculating) begin
                if (count > 5'd0) begin
                    // 移位除法算法
                    remainder <= {remainder[16:0], dividend_reg[17]};
                    dividend_reg <= {dividend_reg[16:0], 1'b0};
                    
                    // 比较余数和除数
                    if ({remainder[16:0], dividend_reg[17]} >= divisor_reg) begin
                        remainder <= {remainder[16:0], dividend_reg[17]} - divisor_reg;
                        quotient_temp <= {quotient_temp[16:0], 1'b1};
                    end
                    else begin
                        quotient_temp <= {quotient_temp[16:0], 1'b0};
                    end
                    
                    count <= count - 5'd1;
                end
                else begin
                    // 除法完成
                    quotient <= quotient_temp;
                    calculating <= 1'b0;
                end
            end
            // 处理除数为0的情况
            else if (divisor == 18'd0) begin
                quotient <= 18'hFFFFF;  // 除数为0时返回最大值
            end
        end
    end

endmodule 