module voltage_convert(
    input wire clk,                // 系统时钟
    input wire rst_n,              // 复位信号，低电平有效
    input wire [7:0] adc_data,     // ADC数据
    input wire adc_data_valid,     // ADC数据有效标志
    output reg [15:0] voltage      // 转换后的电压值（放大100倍用于显示）
);

    // PCF8591参数定义
    parameter REF_VOLTAGE = 5_00;   // 参考电压为5V（放大100倍为500）
    
    // 内部信号定义
    reg [23:0] voltage_temp;       // 临时电压值，扩大位宽以防止计算溢出
    reg [7:0] adc_stable;          // 稳定的ADC值
    reg [7:0] adc_prev;            // 上一次ADC值
    reg [3:0] stable_count;        // 稳定计数器
    reg stable_flag;               // 稳定标志
    
    // 稳定性检测
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            adc_stable <= 8'd0;
            adc_prev <= 8'd0;
            stable_count <= 4'd0;
            stable_flag <= 1'b0;
        end
        else if (adc_data_valid) begin
            // 如果当前ADC值与上一次的值相同或相差很小
            if ((adc_data == adc_prev) || 
                (adc_data == adc_prev + 8'd1) || 
                (adc_data == adc_prev - 8'd1)) begin
                
                if (stable_count < 4'd4) begin
                    stable_count <= stable_count + 1'b1;
                end
                else begin
                    adc_stable <= adc_data;
                    stable_flag <= 1'b1;
                end
            end
            else begin
                stable_count <= 4'd0;
                stable_flag <= 1'b0;
            end
            
            adc_prev <= adc_data;
        end
    end
    
    // 电压转换逻辑 - 基于ADC实际特性优化
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            voltage <= 16'd0;
            voltage_temp <= 24'd0;
        end
        else if (adc_data_valid && stable_flag) begin
            // 基于ADC返回的特性值进行更精确的转换
            case(adc_stable)
                // 满量程校准点
                8'd255: voltage <= 16'd500;  // 5.00V
                8'd254: voltage <= 16'd498;  // 4.98V
                8'd253: voltage <= 16'd496;  // 4.96V
                8'd252: voltage <= 16'd494;  // 4.94V
                8'd251: voltage <= 16'd492;  // 4.92V
                8'd250: voltage <= 16'd490;  // 4.90V
                8'd249: voltage <= 16'd488;  // 4.88V
                8'd248: voltage <= 16'd486;  // 4.86V
                8'd247: voltage <= 16'd484;  // 4.84V
                8'd246: voltage <= 16'd482;  // 4.82V
                8'd245: voltage <= 16'd480;  // 4.80V
                8'd240: voltage <= 16'd470;  // 4.70V
                8'd235: voltage <= 16'd460;  // 4.60V
                8'd230: voltage <= 16'd451;  // 4.51V
                8'd225: voltage <= 16'd441;  // 4.41V
                8'd220: voltage <= 16'd431;  // 4.31V
                8'd215: voltage <= 16'd422;  // 4.22V
                8'd210: voltage <= 16'd412;  // 4.12V
                8'd205: voltage <= 16'd402;  // 4.02V
                8'd200: voltage <= 16'd392;  // 3.92V
                8'd195: voltage <= 16'd382;  // 3.82V
                8'd190: voltage <= 16'd373;  // 3.73V
                8'd185: voltage <= 16'd363;  // 3.63V
                8'd180: voltage <= 16'd353;  // 3.53V
                8'd175: voltage <= 16'd343;  // 3.43V
                8'd170: voltage <= 16'd333;  // 3.33V
                8'd165: voltage <= 16'd324;  // 3.24V
                8'd160: voltage <= 16'd314;  // 3.14V
                8'd155: voltage <= 16'd304;  // 3.04V
                8'd150: voltage <= 16'd294;  // 2.94V
                8'd145: voltage <= 16'd284;  // 2.84V
                8'd140: voltage <= 16'd275;  // 2.75V
                8'd135: voltage <= 16'd265;  // 2.65V
                
                // 中量程校准点
                8'd130: voltage <= 16'd255;  // 2.55V
                8'd129: voltage <= 16'd253;  // 2.53V
                8'd128: voltage <= 16'd251;  // 2.51V
                8'd127: voltage <= 16'd249;  // 2.49V
                8'd126: voltage <= 16'd247;  // 2.47V
                8'd125: voltage <= 16'd245;  // 2.45V
                8'd120: voltage <= 16'd235;  // 2.35V
                8'd115: voltage <= 16'd225;  // 2.25V
                8'd110: voltage <= 16'd216;  // 2.16V
                8'd105: voltage <= 16'd206;  // 2.06V
                8'd100: voltage <= 16'd196;  // 1.96V
                8'd95:  voltage <= 16'd186;  // 1.86V
                8'd90:  voltage <= 16'd176;  // 1.76V
                8'd85:  voltage <= 16'd167;  // 1.67V
                8'd80:  voltage <= 16'd157;  // 1.57V
                8'd75:  voltage <= 16'd147;  // 1.47V
                8'd70:  voltage <= 16'd137;  // 1.37V
                8'd65:  voltage <= 16'd127;  // 1.27V
                8'd60:  voltage <= 16'd118;  // 1.18V
                8'd55:  voltage <= 16'd108;  // 1.08V
                8'd50:  voltage <= 16'd98;   // 0.98V
                8'd45:  voltage <= 16'd88;   // 0.88V
                8'd40:  voltage <= 16'd78;   // 0.78V
                8'd35:  voltage <= 16'd69;   // 0.69V
                8'd30:  voltage <= 16'd59;   // 0.59V
                8'd25:  voltage <= 16'd49;   // 0.49V
                8'd20:  voltage <= 16'd39;   // 0.39V
                8'd15:  voltage <= 16'd29;   // 0.29V
                8'd10:  voltage <= 16'd20;   // 0.20V
                8'd5:   voltage <= 16'd10;   // 0.10V
                8'd3:   voltage <= 16'd6;    // 0.06V
                8'd2:   voltage <= 16'd4;    // 0.04V
                8'd1:   voltage <= 16'd2;    // 0.02V
                8'd0:   voltage <= 16'd0;    // 0.00V
                
                default: begin
                    // 在默认情况下使用两段非线性映射以匹配ADC实际特性
                    if (adc_stable > 8'd130) begin
                        // 高电压段：130-255 映射到 2.55V-5.00V
                        voltage_temp <= 16'd255 + ((adc_stable - 8'd130) * 16'd245) / 8'd125;
                    end
                    else if (adc_stable > 8'd30) begin
                        // 中电压段：30-130 映射到 0.59V-2.55V
                        voltage_temp <= 16'd59 + ((adc_stable - 8'd30) * 16'd196) / 8'd100;
                    end
                    else begin
                        // 低电压段：0-30 映射到 0.00V-0.59V
                        // 低电压段更加精细，因为电压表在低电压时需要更高精度
                        voltage_temp <= (adc_stable * 16'd59) / 8'd30;
                    end
                    voltage <= voltage_temp[15:0];
                end
            endcase
        end
    end

endmodule 