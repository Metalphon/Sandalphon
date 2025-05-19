module lcd1602_display(
    input wire clk,               // 系统时钟
    input wire rst_n,             // 复位信号，低电平有效
    input wire [15:0] voltage,    // 电压值(放大100倍)
    output reg lcd_rs,            // 寄存器选择信号
    output reg lcd_rw,            // 读/写选择信号
    output reg lcd_en,            // 使能信号
    output reg [7:0] lcd_data     // 数据总线
);

    // LCD1602命令定义
    parameter CMD_CLEAR          = 8'h01; // 清屏
    parameter CMD_RETURN_HOME    = 8'h02; // 返回首位
    parameter CMD_ENTRY_MODE_SET = 8'h06; // 设置输入模式
    parameter CMD_DISP_SWITCH    = 8'h0C; // 显示开，光标关，闪烁关
    parameter CMD_FUNCTION_SET   = 8'h38; // 8位数据接口，2行显示，5x7点阵
    parameter CMD_SET_DDRAM_ADDR = 8'h80; // 设置DDRAM地址
    
    // 时钟分频参数
    parameter SYS_CLK = 50_000_000;   // 系统时钟频率：50MHz
    parameter LCD_CLK = 100_000;      // LCD时钟频率：100KHz
    parameter CLK_DIV = SYS_CLK / LCD_CLK - 1; // 时钟分频系数
    
    // 电压显示用字符常量
    parameter [7:0] CHAR_V = 8'h56;   // 字符 'V'
    parameter [7:0] CHAR_DOT = 8'h2E; // 字符 '.'
    parameter [7:0] CHAR_SPACE = 8'h20; // 空格
    parameter [7:0] CHAR_0 = 8'h30;   // 字符 '0'
    
    // 显示标题
    parameter [127:0] TITLE_STR = "Voltage:       "; // 16个字符的标题
    
    // LCD操作状态机定义
    localparam IDLE         = 5'd0;  // 空闲状态
    localparam INIT_START   = 5'd1;  // 初始化开始
    localparam INIT_FUNSET  = 5'd2;  // 功能设置
    localparam INIT_DISPON  = 5'd3;  // 显示开
    localparam INIT_DISPCLEAR = 5'd4; // 显示清除
    localparam INIT_ENTMODE = 5'd5;  // 进入模式设置
    localparam DISP_ROW1    = 5'd6;  // 显示第一行
    localparam DISP_ROW2    = 5'd7;  // 显示第二行
    localparam WRITE_TITLE  = 5'd8;  // 写标题
    localparam WRITE_CHAR   = 5'd9;  // 写字符
    localparam DISP_VOLTAGE = 5'd10; // 显示电压值
    localparam WAIT_UPDATE  = 5'd11; // 等待更新
    
    // 内部寄存器和信号
    reg [15:0] clk_cnt;            // 时钟计数器
    reg lcd_clk;                   // LCD时钟
    reg [4:0] state;               // 状态机当前状态
    reg [4:0] next_state;          // 状态机下一状态
    reg [4:0] return_state;        // 返回状态
    reg [7:0] disp_data;           // 显示数据
    reg [3:0] char_cnt;            // 字符计数器
    reg [3:0] init_cnt;            // 初始化计数器
    reg [19:0] wait_cnt;           // 等待计数器
    reg [15:0] voltage_reg;        // 电压值寄存器
    reg [3:0] volt_int;            // 电压整数部分
    reg [7:0] volt_dec;            // 电压小数部分
    reg [3:0] dec_cnt;             // 小数点位数计数器
    
    // LCD时钟生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            lcd_clk <= 0;
        end
        else begin
            if (clk_cnt == CLK_DIV) begin
                clk_cnt <= 0;
                lcd_clk <= ~lcd_clk;
            end
            else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end
    end
    
    // 状态机状态转换
    always @(posedge lcd_clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    
    // 状态机逻辑控制
    always @(posedge lcd_clk or negedge rst_n) begin
        if (!rst_n) begin
            next_state <= IDLE;
            lcd_rs <= 1'b0;
            lcd_rw <= 1'b0;
            lcd_en <= 1'b0;
            lcd_data <= 8'h00;
            char_cnt <= 4'd0;
            init_cnt <= 4'd0;
            wait_cnt <= 20'd0;
            voltage_reg <= 16'd0;
            volt_int <= 4'd0;
            volt_dec <= 8'd0;
            dec_cnt <= 4'd0;
            return_state <= IDLE;
        end
        else begin
            case (state)
                IDLE: begin
                    lcd_en <= 1'b0;
                    lcd_rs <= 1'b0;
                    lcd_rw <= 1'b0;
                    lcd_data <= 8'h00;
                    next_state <= INIT_START;
                end
                
                // LCD初始化序列
                INIT_START: begin
                    lcd_en <= 1'b0;
                    if (wait_cnt < 20'd50000) begin // 等待大约50ms
                        wait_cnt <= wait_cnt + 1'b1;
                        next_state <= INIT_START;
                    end
                    else begin
                        wait_cnt <= 20'd0;
                        next_state <= INIT_FUNSET;
                    end
                end
                
                INIT_FUNSET: begin
                    lcd_rs <= 1'b0; // 命令
                    lcd_rw <= 1'b0; // 写
                    lcd_data <= CMD_FUNCTION_SET;
                    
                    if (lcd_en) begin
                        lcd_en <= 1'b0;
                        if (wait_cnt < 20'd100) begin // 等待100个时钟周期
                            wait_cnt <= wait_cnt + 1'b1;
                            next_state <= INIT_FUNSET;
                        end
                        else begin
                            wait_cnt <= 20'd0;
                            next_state <= INIT_DISPON;
                        end
                    end
                    else begin
                        lcd_en <= 1'b1;
                        next_state <= INIT_FUNSET;
                    end
                end
                
                INIT_DISPON: begin
                    lcd_rs <= 1'b0;
                    lcd_rw <= 1'b0;
                    lcd_data <= CMD_DISP_SWITCH;
                    
                    if (lcd_en) begin
                        lcd_en <= 1'b0;
                        if (wait_cnt < 20'd100) begin
                            wait_cnt <= wait_cnt + 1'b1;
                            next_state <= INIT_DISPON;
                        end
                        else begin
                            wait_cnt <= 20'd0;
                            next_state <= INIT_DISPCLEAR;
                        end
                    end
                    else begin
                        lcd_en <= 1'b1;
                        next_state <= INIT_DISPON;
                    end
                end
                
                INIT_DISPCLEAR: begin
                    lcd_rs <= 1'b0;
                    lcd_rw <= 1'b0;
                    lcd_data <= CMD_CLEAR;
                    
                    if (lcd_en) begin
                        lcd_en <= 1'b0;
                        if (wait_cnt < 20'd2000) begin // 清屏需要更长时间
                            wait_cnt <= wait_cnt + 1'b1;
                            next_state <= INIT_DISPCLEAR;
                        end
                        else begin
                            wait_cnt <= 20'd0;
                            next_state <= INIT_ENTMODE;
                        end
                    end
                    else begin
                        lcd_en <= 1'b1;
                        next_state <= INIT_DISPCLEAR;
                    end
                end
                
                INIT_ENTMODE: begin
                    lcd_rs <= 1'b0;
                    lcd_rw <= 1'b0;
                    lcd_data <= CMD_ENTRY_MODE_SET;
                    
                    if (lcd_en) begin
                        lcd_en <= 1'b0;
                        if (wait_cnt < 20'd100) begin
                            wait_cnt <= wait_cnt + 1'b1;
                            next_state <= INIT_ENTMODE;
                        end
                        else begin
                            wait_cnt <= 20'd0;
                            next_state <= DISP_ROW1;
                        end
                    end
                    else begin
                        lcd_en <= 1'b1;
                        next_state <= INIT_ENTMODE;
                    end
                end
                
                // 设置显示位置到第一行开始
                DISP_ROW1: begin
                    lcd_rs <= 1'b0; // 命令
                    lcd_rw <= 1'b0; // 写
                    lcd_data <= CMD_SET_DDRAM_ADDR; // 设置DDRAM地址为0x00
                    
                    if (lcd_en) begin
                        lcd_en <= 1'b0;
                        if (wait_cnt < 20'd100) begin
                            wait_cnt <= wait_cnt + 1'b1;
                            next_state <= DISP_ROW1;
                        end
                        else begin
                            wait_cnt <= 20'd0;
                            char_cnt <= 4'd0;
                            next_state <= WRITE_TITLE;
                        end
                    end
                    else begin
                        lcd_en <= 1'b1;
                        next_state <= DISP_ROW1;
                    end
                end
                
                // 写入标题字符串
                WRITE_TITLE: begin
                    lcd_rs <= 1'b1; // 数据
                    lcd_rw <= 1'b0; // 写
                    
                    case (char_cnt)
                        4'd0: lcd_data <= TITLE_STR[127:120]; // V
                        4'd1: lcd_data <= TITLE_STR[119:112]; // o
                        4'd2: lcd_data <= TITLE_STR[111:104]; // l
                        4'd3: lcd_data <= TITLE_STR[103:96];  // t
                        4'd4: lcd_data <= TITLE_STR[95:88];   // a
                        4'd5: lcd_data <= TITLE_STR[87:80];   // g
                        4'd6: lcd_data <= TITLE_STR[79:72];   // e
                        4'd7: lcd_data <= TITLE_STR[71:64];   // :
                        default: lcd_data <= CHAR_SPACE;      // 空格
                    endcase
                    
                    if (lcd_en) begin
                        lcd_en <= 1'b0;
                        if (wait_cnt < 20'd100) begin
                            wait_cnt <= wait_cnt + 1'b1;
                            next_state <= WRITE_TITLE;
                        end
                        else begin
                            wait_cnt <= 20'd0;
                            if (char_cnt == 4'd8) begin // 标题写完后
                                char_cnt <= 4'd0;
                                voltage_reg <= voltage; // 保存当前电压值
                                next_state <= DISP_VOLTAGE;
                            end
                            else begin
                                char_cnt <= char_cnt + 1'b1;
                                next_state <= WRITE_TITLE;
                            end
                        end
                    end
                    else begin
                        lcd_en <= 1'b1;
                        next_state <= WRITE_TITLE;
                    end
                end
                
                // 显示电压值
                DISP_VOLTAGE: begin
                    lcd_rs <= 1'b1; // 数据
                    lcd_rw <= 1'b0; // 写
                    
                    // 分离整数和小数部分
                    // 电压被放大了100倍，所以/100得到整数部分，%100得到小数部分
                    if (char_cnt == 4'd0) begin
                        volt_int <= voltage_reg / 100;
                        volt_dec <= voltage_reg % 100;
                    end
                    
                    case (char_cnt)
                        4'd0: lcd_data <= CHAR_SPACE;
                        4'd1: lcd_data <= CHAR_0 + volt_int; // 整数部分
                        4'd2: lcd_data <= CHAR_DOT;          // 小数点
                        4'd3: lcd_data <= CHAR_0 + volt_dec/10; // 小数第一位
                        4'd4: lcd_data <= CHAR_0 + volt_dec%10; // 小数第二位
                        4'd5: lcd_data <= CHAR_V;           // 单位V
                        default: lcd_data <= CHAR_SPACE;    // 空格
                    endcase
                    
                    if (lcd_en) begin
                        lcd_en <= 1'b0;
                        if (wait_cnt < 20'd100) begin
                            wait_cnt <= wait_cnt + 1'b1;
                            next_state <= DISP_VOLTAGE;
                        end
                        else begin
                            wait_cnt <= 20'd0;
                            if (char_cnt == 4'd6) begin
                                char_cnt <= 4'd0;
                                next_state <= WAIT_UPDATE;
                            end
                            else begin
                                char_cnt <= char_cnt + 1'b1;
                                next_state <= DISP_VOLTAGE;
                            end
                        end
                    end
                    else begin
                        lcd_en <= 1'b1;
                        next_state <= DISP_VOLTAGE;
                    end
                end
                
                // 等待更新电压值
                WAIT_UPDATE: begin
                    lcd_en <= 1'b0;
                    
                    if (wait_cnt < 20'd100000) begin // 大约0.1秒更新一次
                        wait_cnt <= wait_cnt + 1'b1;
                        next_state <= WAIT_UPDATE;
                    end
                    else begin
                        wait_cnt <= 20'd0;
                        
                        // 检测电压是否变化
                        if (voltage_reg != voltage) begin
                            next_state <= DISP_ROW1; // 更新显示
                        end
                        else begin
                            next_state <= WAIT_UPDATE; // 继续等待
                        end
                    end
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule 