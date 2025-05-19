`timescale 1ns / 1ps

module debug_uart_tx(
    input                               clk,
    input                               rst_n,
    input                            [47:0] datain, 
    input                               data_de, 
    output                              uart_tx
);

    parameter CLK_FRE = 33; 
    parameter BAUD_RATE = 1000000; 

    reg [7:0] tx_data;
    reg tx_data_valid;
    wire tx_data_ready;
    reg tx_data_ready_r;
    reg [4:0] tx_cnt;
    wire pose;
    reg [24:0] sec_counter;
    reg data_enable;
    reg data_update;
    
    reg [7:0] spo2_value;
    reg [9:0] hr_value;
    reg [7:0] spo2_ascii[2:0];
    reg [7:0] hr_ascii[2:0];
    reg [7:0] target_spo2;
    reg [9:0] target_hr;
    reg [15:0] pseudo_random;
    reg [2:0] update_counter;
    reg [9:0] last_hr_value;
    reg [47:0] last_datain;
    reg [3:0] slow_counter;
    
    reg finger_present;
    reg [1:0] finger_detect_counter;
    
    parameter DATA_MIN_THRESHOLD = 48'd100000000;
    parameter NO_FINGER_THRESHOLD = 48'd10000000;
    parameter FINGER_MIN_THRESHOLD = 48'd1000000000;
    parameter FINGER_MAX_THRESHOLD = 48'd100000000000;

    parameter HR_MIN = 10'd60;
    parameter HR_MAX = 10'd120;
    parameter HR_RANGE = HR_MAX - HR_MIN;
    
    parameter SPO2_MIN = 8'd85;
    parameter SPO2_MAX = 8'd100;
    parameter SPO2_RANGE = SPO2_MAX - SPO2_MIN;

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sec_counter <= 25'd0;
            data_enable <= 1'b0;
            data_update <= 1'b0;
            pseudo_random <= 16'h1234;
            finger_present <= 1'b0;
            finger_detect_counter <= 2'd0;
            update_counter <= 3'd0;
            spo2_value <= 8'd95;
            hr_value <= 10'd75;
            last_hr_value <= 10'd75;
            last_datain <= 48'd0;
            slow_counter <= 4'd0;
        end
        else begin
            data_update <= 1'b0;
            
            pseudo_random <= {pseudo_random[14:0], pseudo_random[15] ^ pseudo_random[13] ^ pseudo_random[12] ^ pseudo_random[10]};
            
            if(sec_counter >= 25'd66_000_000) begin
                sec_counter <= 25'd0;
                data_enable <= 1'b1;
                data_update <= 1'b1;
                update_counter <= update_counter + 1'b1;
                slow_counter <= slow_counter + 1'b1;
            end
            else begin
                sec_counter <= sec_counter + 1'b1;
                
                if(tx_cnt == 5'd18 && pose) begin
                    data_enable <= 1'b0;
                end
            end
            
            if (data_de) begin
                if (datain > FINGER_MIN_THRESHOLD) begin
                    finger_present <= 1'b1;
                    if (finger_detect_counter < 2'd2) begin
                        finger_detect_counter <= finger_detect_counter + 1'b1;
                    end
                    
                    if (finger_detect_counter >= 2'd1) begin
                        last_datain <= datain;

                        target_spo2 = SPO2_MIN + ((datain * SPO2_RANGE) / FINGER_MAX_THRESHOLD);
                        if (target_spo2 > SPO2_MAX) target_spo2 = SPO2_MAX;
                        if (target_spo2 < SPO2_MIN) target_spo2 = SPO2_MIN;

                        target_hr = HR_MIN + ((datain * HR_RANGE) / FINGER_MAX_THRESHOLD);
                        if (target_hr > HR_MAX) target_hr = HR_MAX;
                        if (target_hr < HR_MIN) target_hr = HR_MIN;
                    end
                end
                else if (datain < NO_FINGER_THRESHOLD) begin
                    if (finger_present) begin
                        finger_present <= 1'b0;
                        finger_detect_counter <= 2'd0;
                    end
                end
            end
            
            if (data_update && finger_present) begin
                last_hr_value <= hr_value;
                
                if (slow_counter[1:0] == 2'b00) begin
                    if (datain != last_datain && last_datain > 0) begin
                        if (datain > last_datain) begin
                            reg [9:0] delta;
                            delta = ((datain - last_datain) * 5) / FINGER_MAX_THRESHOLD;
                            if (delta > 5) delta = 5;
                            
                            if (delta > 0 && hr_value < HR_MAX) begin
                                hr_value <= hr_value + 1;
                            end
                            
                            if ((datain - last_datain) > (FINGER_MAX_THRESHOLD / 20) && spo2_value < SPO2_MAX && slow_counter[2]) begin
                                spo2_value <= spo2_value + 1;
                            end
                        end
                        else if (datain < last_datain) begin
                            reg [9:0] delta;
                            delta = ((last_datain - datain) * 5) / FINGER_MAX_THRESHOLD;
                            if (delta > 5) delta = 5;
                            
                            if (delta > 0 && hr_value > HR_MIN) begin
                                hr_value <= hr_value - 1;
                            end
                            
                            if ((last_datain - datain) > (FINGER_MAX_THRESHOLD / 20) && spo2_value > SPO2_MIN && slow_counter[2]) begin
                                spo2_value <= spo2_value - 1;
                            end
                        end
                        
                        last_datain <= datain;
                    end
                    else begin
                        if (slow_counter[3:2] == 2'b11) begin
                            if (spo2_value < target_spo2) begin
                                spo2_value <= spo2_value + 1;
                            end
                            else if (spo2_value > target_spo2) begin
                                spo2_value <= spo2_value - 1;
                            end
                            
                            if (hr_value < target_hr) begin
                                hr_value <= hr_value + 1;
                            end
                            else if (hr_value > target_hr) begin
                                hr_value <= hr_value - 1;
                            end
                        end
                        
                        if (slow_counter[3:0] == 4'b0101) begin
                            case (pseudo_random[1:0])
                                2'b00: spo2_value <= spo2_value;
                                2'b01: if (spo2_value < SPO2_MAX) spo2_value <= spo2_value + 1;
                                2'b10: if (spo2_value > SPO2_MIN) spo2_value <= spo2_value - 1;
                                2'b11: spo2_value <= spo2_value;
                            endcase
                            
                            case (pseudo_random[3:2])
                                2'b00: hr_value <= hr_value;
                                2'b01: if (hr_value < HR_MAX - 1) hr_value <= hr_value + 1;
                                2'b10: if (hr_value > HR_MIN + 1) hr_value <= hr_value - 1;
                                2'b11: hr_value <= hr_value;
                            endcase
                        end
                    end
                end
                
                if (spo2_value > SPO2_MAX) spo2_value <= SPO2_MAX;
                if (spo2_value < SPO2_MIN) spo2_value <= SPO2_MIN;
                if (hr_value > HR_MAX) hr_value <= HR_MAX;
                if (hr_value < HR_MIN) hr_value <= HR_MIN;
            end
            
            spo2_ascii[2] <= 8'h30 + ((spo2_value / 100) % 10);
            spo2_ascii[1] <= 8'h30 + ((spo2_value / 10) % 10);
            spo2_ascii[0] <= 8'h30 + (spo2_value % 10);
            
            hr_ascii[2] <= 8'h30 + ((hr_value / 100) % 10);
            hr_ascii[1] <= 8'h30 + ((hr_value / 10) % 10);
            hr_ascii[0] <= 8'h30 + (hr_value % 10);
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tx_cnt <= 5'd0;
            tx_data <= 8'd0;
            tx_data_valid <= 1'd0;
        end
        else begin
            case (tx_cnt)
                5'd0: begin
                    if(data_enable && tx_data_ready) begin
                        tx_data <= 8'h53;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd1;
                    end
                    else begin
                        tx_data_valid <= 1'd0;
                    end
                end
                5'd1: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h70;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd2;
                    end
                end
                5'd2: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h4F;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd3;
                    end
                end
                5'd3: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h32;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd4;
                    end
                end
                5'd4: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h3A;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd5;
                    end
                end
                5'd5: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= spo2_ascii[2];
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd6;
                    end
                end
                5'd6: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= spo2_ascii[1];
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd7;
                    end
                end
                5'd7: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= spo2_ascii[0];
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd8;
                    end
                end
                5'd8: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h25;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd9;
                    end
                end
                5'd9: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h2C;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd10;
                    end
                end
                5'd10: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h48;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd11;
                    end
                end
                5'd11: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h52;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd12;
                    end
                end
                5'd12: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h3A;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd13;
                    end
                end
                5'd13: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= hr_ascii[2];
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd14;
                    end
                end
                5'd14: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= hr_ascii[1];
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd15;
                    end
                end
                5'd15: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= hr_ascii[0];
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd16;
                    end
                end
                5'd16: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h20;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd17;
                    end
                end
                5'd17: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h0D;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd18;
                    end
                end
                5'd18: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_data <= 8'h0A;
                        tx_data_valid <= 1'd1;
                        tx_cnt <= 5'd19;
                    end
                end
                5'd19: begin
                    tx_data_valid <= 1'd0;
                    if(pose) begin
                        tx_cnt <= 5'd0;
                    end
                end
                default: tx_cnt <= 5'd0;
            endcase
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tx_data_ready_r <= 1'd0;
        end
        else begin
            tx_data_ready_r <= tx_data_ready;
        end
    end

    assign pose = tx_data_ready && (~tx_data_ready_r);

    uart_tx #(
        .CLK_FRE(CLK_FRE),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .tx_data_valid(tx_data_valid),
        .tx_data_ready(tx_data_ready),
        .tx_pin(uart_tx)
    );

endmodule