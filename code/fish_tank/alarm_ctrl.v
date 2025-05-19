module alarm_ctrl(
    input clk,                  // System clock input
    input rst_n,               // Reset signal input, active low
    input mq2_data,            // MQ-2 sensor digital input (low: gas detected, high: normal)
    input [7:0] temperature,   // Temperature value from DHT11
    output reg buzzer_out,     // Buzzer control (active low)
    output reg wave_out        // Fan PWM output (25kHz)
);

    // Parameters
    parameter TEMP_THRESHOLD = 8'd40;   // Temperature threshold (40°C)
    parameter HALF_PERIOD = 10'd840;    // For 25kHz wave generation
    parameter DEBOUNCE_TIME = 10'd500;  // 10us debounce time (50MHz clock -> 500 cycles)
    
    // Internal registers
    reg [9:0] wave_counter;     // Counter for wave generation
    reg [9:0] debounce_cnt;    // Debounce counter for mq2_data
    reg mq2_state;             // Debounced mq2 state
    reg alarm_condition;        // Combined alarm status

    // Alarm and wave generation logic
    always @(posedge clk) begin
        if (rst_n) begin
            buzzer_out <= 1'b1;      // Buzzer off (high)
            wave_out <= 1'b0;        // Wave output low
            wave_counter <= 10'd0;
            debounce_cnt <= 10'd0;
            mq2_state <= 1'b1;       // Initialize to normal state (high)
            alarm_condition <= 1'b0;  // No alarm
        end
        else begin
            // MQ2 signal debounce logic
            if (mq2_data != mq2_state) begin
                if (debounce_cnt >= DEBOUNCE_TIME) begin
                    mq2_state <= mq2_data;
                    debounce_cnt <= 10'd0;
                end
                else begin
                    debounce_cnt <= debounce_cnt + 1'b1;
                end
            end
            else begin
                debounce_cnt <= 10'd0;
            end

            // Check alarm condition using debounced mq2_state (active low)
            alarm_condition <= !mq2_state;  // Alarm when mq2_state is low
            
            // Control outputs based on alarm condition
            buzzer_out <= ~alarm_condition;  // Active low buzzer
            
            // Wave generation for fan PWM
            if (alarm_condition) begin       // Generate PWM when alarm is active
                if (wave_counter >= HALF_PERIOD - 1) begin
                    wave_counter <= 10'd0;
                    wave_out <= ~wave_out;   // Toggle output for PWM
                end
                else begin
                    wave_counter <= wave_counter + 1'b1;
                end
            end
            else begin                      // Stop PWM when no alarm
                wave_out <= 1'b0;
                wave_counter <= 10'd0;
            end
        end
    end

endmodule 