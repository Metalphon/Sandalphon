// -----------------------------------------------------------------------------
// 文件名称: tb_origin.v
// 模块功能: 顶层模块测试台，测试正弦波生成和DAC输出
// 创建日期: 2025-04-02
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_origin();

    // 测试信号定义
    reg        clk;
    reg        rst_n;
    wire       scl;
    wire       sda;
    
    // 时钟生成 (50MHz)
    parameter CLK_PERIOD = 20; // 50MHz -> 20ns周期
    
    // 产生时钟
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // 施加复位
    initial begin
        rst_n = 1'b0;
        #200; // 复位持续200ns
        rst_n = 1'b1;
        
        // 测试运行20ms
        #20_000_000;
        
        $display("Simulation finished!");
        $finish;
    end
    
    // 监控I2C总线活动
    integer i;
    initial begin
        $display("Simulation started...");
        $display("Monitoring I2C bus activity:");
        
        wait(rst_n == 1'b1); // 等待复位结束
        
        for (i = 0; i < 10; i = i + 1) begin
            @(negedge scl); // 等待SCL下降沿
            $display("Time: %0t - I2C SCL falling edge detected", $time);
        end
    end
    
    // 实例化被测设计
    origin u_origin (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda)
    );
    
    // 添加波形转储以便查看波形
    initial begin
        $dumpfile("tb_origin.vcd");
        $dumpvars(0, tb_origin);
    end

endmodule 