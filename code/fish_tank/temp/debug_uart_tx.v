`timescale 1ns / 1ps

module debug_uart_tx(
    input                               clk,
    input                               rst_n,
    input                            [47:0] datain,
    input                               data_de,
    output                              uart_tx
);

    parameter CLK_FRE = 50;
    parameter BAUD_RATE = 115200;

    localparam STATE_BITS = 3;
    localparam S_IDLE            = 3'd0;
    localparam S_INIT_MUX        = 3'd1;
    localparam S_DELAY_AFTER_MUX = 3'd2;
    localparam S_INIT_SERVER     = 3'd3;
    localparam S_WAIT_TRIGGER    = 3'd4;
    localparam S_SEND_CIPSEND    = 3'd5;
    localparam S_SEND_DATA       = 3'd6;

    reg [STATE_BITS-1:0] current_state, next_state;

    localparam [8*13-1:0] STR_INIT_MUX = "AT+CIPMUX=1\r\n";
    localparam [4:0] LEN_INIT_MUX = 13;
    localparam [8*23-1:0] STR_INIT_SERVER = "AT+CIPSERVER=1,8081\r\n";
    localparam [4:0] LEN_INIT_SERVER = 23;
    localparam DATA_STRING_LEN = 30;
    localparam [8*18-1:0] STR_CIPSEND = "AT+CIPSEND=0,46\r\n";
    localparam [4:0] LEN_CIPSEND = 18;

    reg [7:0] tx_data;
    reg tx_data_valid;
    wire tx_data_ready;
    reg tx_data_ready_r;
    wire pose;
    reg tx_sending; // Latched tx_data_valid && tx_data_ready

    reg [4:0] string_idx;
    reg [4:0] data_tx_cnt;
    reg [26:0] sec_counter;
    reg cycle_trigger;
    reg data_update;

    localparam DELAY_1S_COUNT = (CLK_FRE * 1_000_000 * 1) - 1;
    localparam DELAY_BITS = 26;
    reg [DELAY_BITS-1:0] delay_counter;

    reg [7:0] spo2_value;
    reg [9:0] hr_value;
    wire [7:0] dht11_temp;
    wire [7:0] dht11_humi;
    reg [7:0] spo2_ascii[2:0];
    reg [7:0] hr_ascii[2:0];
    reg [7:0] temp_ascii[2:0];
    reg [7:0] humi_ascii[2:0];
    reg [15:0] pseudo_random;
    reg [2:0] update_counter;
    reg [47:0] last_datain;
    reg [3:0] slow_counter;
    reg finger_present;
    reg [1:0] finger_detect_counter;

    parameter DATA_MIN_THRESHOLD = 48'd100000000;
    parameter NO_FINGER_THRESHOLD = 48'd10000000;
    parameter FINGER_MIN_THRESHOLD = 48'd1000000000;
    parameter FINGER_MAX_THRESHOLD = 48'd100000000000;
    parameter HR_MIN = 10'd40;
    parameter HR_MAX = 10'd120;
    parameter SPO2_MIN = 8'd65;
    parameter SPO2_MAX = 8'd100;

    assign dht11_temp = datain[15:8];
    assign dht11_humi = datain[7:0];

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sec_counter <= 27'd0; cycle_trigger <= 1'b0; data_update <= 1'b0;
            pseudo_random <= 16'h1234; finger_present <= 1'b1; finger_detect_counter <= 2'd0;
            update_counter <= 3'd0;
            spo2_value <= SPO2_MIN + 5;
            hr_value <= HR_MIN + 10;
            last_datain <= 48'd0; slow_counter <= 4'd0;
        end else begin
            data_update <= 1'b0; cycle_trigger <= 1'b0;
            pseudo_random <= {pseudo_random[14:0], pseudo_random[15] ^ pseudo_random[13] ^ pseudo_random[12] ^ pseudo_random[10]};
            if(sec_counter >= (CLK_FRE * 1_000_000 * 2) - 1) begin
                sec_counter <= 27'd0; cycle_trigger <= 1'b1; data_update <= 1'b1;
                slow_counter <= slow_counter + 1'b1;
            end else begin
                sec_counter <= sec_counter + 1'b1;
            end

            if (data_de) begin
                if (datain > FINGER_MIN_THRESHOLD && datain < FINGER_MAX_THRESHOLD) begin
                    if (!finger_present) begin
                         finger_present <= 1'b1; finger_detect_counter <= 2'd1;
                    end else if (finger_detect_counter < 2'd2) begin
                         finger_detect_counter <= finger_detect_counter + 1;
                    end
                    if (finger_detect_counter >= 2'd1) begin
                        if (last_datain > NO_FINGER_THRESHOLD) begin
                            if (datain > last_datain + (last_datain >> 4)) begin
                                if (hr_value < HR_MAX - 1) hr_value <= hr_value + 1;
                                if (spo2_value < SPO2_MAX) spo2_value <= spo2_value + 1;
                            end else if (datain < last_datain - (last_datain >> 4)) begin
                                if (hr_value > HR_MIN + 1) hr_value <= hr_value - 1;
                                if (spo2_value > SPO2_MIN) spo2_value <= spo2_value - 1;
                            end
                        end
                        last_datain <= datain;
                    end
                end else if (datain < NO_FINGER_THRESHOLD) begin
                    finger_present <= 1'b0; finger_detect_counter <= 2'd0; last_datain <= datain;
                end else begin
                   last_datain <= datain;
                end
            end
            if (finger_present && slow_counter[3:0] == 4'b0000) begin
                 case (pseudo_random[1:0])
                    2'b00: spo2_value <= spo2_value;
                    2'b01: if (spo2_value < SPO2_MAX) spo2_value <= spo2_value + 1; else spo2_value <= SPO2_MAX;
                    2'b10: if (spo2_value > SPO2_MIN) spo2_value <= spo2_value - 1; else spo2_value <= SPO2_MIN;
                    2'b11: spo2_value <= spo2_value;
                 endcase
                 case (pseudo_random[3:2])
                    2'b00: hr_value <= hr_value;
                    2'b01: if (hr_value < HR_MAX) hr_value <= hr_value + 1; else hr_value <= HR_MAX;
                    2'b10: if (hr_value > HR_MIN) hr_value <= hr_value - 1; else hr_value <= HR_MIN;
                    2'b11: hr_value <= hr_value;
                 endcase
            end else if (!finger_present && slow_counter[3:0] == 4'b0000) begin
                 if (spo2_value > SPO2_MIN) spo2_value <= spo2_value - 1;
                 if (hr_value > HR_MIN) hr_value <= hr_value - 1;
            end
            spo2_ascii[2] <= 8'h30 + ((spo2_value / 100) % 10); spo2_ascii[1] <= 8'h30 + ((spo2_value / 10) % 10); spo2_ascii[0] <= 8'h30 + (spo2_value % 10);
            hr_ascii[2] <= 8'h30 + ((hr_value / 100) % 10); hr_ascii[1] <= 8'h30 + ((hr_value / 10) % 10); hr_ascii[0] <= 8'h30 + (hr_value % 10);
            temp_ascii[2] <= 8'h30 + ((dht11_temp / 100) % 10); temp_ascii[1] <= 8'h30 + ((dht11_temp / 10) % 10); temp_ascii[0] <= 8'h30 + (dht11_temp % 10);
            humi_ascii[2] <= 8'h30 + ((dht11_humi / 100) % 10); humi_ascii[1] <= 8'h30 + ((dht11_humi / 10) % 10); humi_ascii[0] <= 8'h30 + (dht11_humi % 10);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            string_idx <= 5'd0;
            data_tx_cnt <= 5'd0;
            delay_counter <= {DELAY_BITS{1'b0}};
            tx_sending <= 1'b0;
        end else begin
            current_state <= next_state;
            tx_sending <= tx_data_valid && tx_data_ready; // Capture if send was successful last cycle

            // Reset counters on state *entry* or specific conditions
            if (next_state != current_state) begin
                 if (next_state == S_INIT_SERVER || next_state == S_SEND_CIPSEND) begin
                     string_idx <= 5'd0; // Reset for next AT command
                 end
                 if (next_state == S_SEND_DATA) begin
                     data_tx_cnt <= 5'd0; // Reset for data sending
                 end
                 if (next_state == S_DELAY_AFTER_MUX) begin
                     delay_counter <= {DELAY_BITS{1'b0}}; // Reset delay timer on entry
                 end
            end

            // Increment counters based on current state and tx_sending flag
            if (tx_sending) begin // Increment only if last cycle's send was successful
                 case(current_state) // Use current state to decide which counter to increment
                    S_INIT_MUX:     if (string_idx < LEN_INIT_MUX) string_idx <= string_idx + 1'b1;
                    S_INIT_SERVER:  if (string_idx < LEN_INIT_SERVER) string_idx <= string_idx + 1'b1;
                    S_SEND_CIPSEND: if (string_idx < LEN_CIPSEND) string_idx <= string_idx + 1'b1;
                    S_SEND_DATA:    if (data_tx_cnt < DATA_STRING_LEN) data_tx_cnt <= data_tx_cnt + 1'b1;
                    default: ; // Do nothing for other states
                 endcase
            end

            // Increment delay counter specifically when in the delay state
            if (current_state == S_DELAY_AFTER_MUX) begin
                if (delay_counter < DELAY_1S_COUNT) begin
                    delay_counter <= delay_counter + 1'b1;
                end
            end
        end
    end

    always @(*) begin
        next_state = current_state;
        tx_data = 8'd0;
        tx_data_valid = 1'b0;

        case (current_state)
            S_IDLE: begin
                 next_state = S_INIT_MUX;
            end

            S_INIT_MUX: begin
                if (string_idx < LEN_INIT_MUX) begin
                    tx_data = STR_INIT_MUX >> ((LEN_INIT_MUX - 1 - string_idx) * 8);
                    tx_data_valid = tx_data_ready; // Assert valid only if ready
                    next_state = S_INIT_MUX; // Stay until counter reaches limit
                end else begin // string_idx has reached the limit
                    next_state = S_DELAY_AFTER_MUX; // Transition determined by counter
                end
            end

            S_DELAY_AFTER_MUX: begin
                tx_data_valid = 1'b0; // Ensure no data is sent
                if (delay_counter == DELAY_1S_COUNT) begin
                    next_state = S_INIT_SERVER; // Transition when delay done
                end else begin
                    next_state = S_DELAY_AFTER_MUX; // Stay while delaying
                end
            end

            S_INIT_SERVER: begin
                 if (string_idx < LEN_INIT_SERVER) begin
                    tx_data = STR_INIT_SERVER >> ((LEN_INIT_SERVER - 1 - string_idx) * 8);
                    tx_data_valid = tx_data_ready;
                    next_state = S_INIT_SERVER;
                end else begin
                    next_state = S_WAIT_TRIGGER; // Transition determined by counter
                end
            end

            S_WAIT_TRIGGER: begin
                if (cycle_trigger) begin
                    next_state = S_SEND_CIPSEND;
                end else begin
                    next_state = S_WAIT_TRIGGER;
                end
            end

            S_SEND_CIPSEND: begin
                 if (string_idx < LEN_CIPSEND) begin
                    tx_data = STR_CIPSEND >> ((LEN_CIPSEND - 1 - string_idx) * 8);
                    tx_data_valid = tx_data_ready;
                    next_state = S_SEND_CIPSEND;
                 end else begin
                     next_state = S_SEND_DATA; // Transition determined by counter
                 end
            end

            S_SEND_DATA: begin
                if (data_tx_cnt < DATA_STRING_LEN) begin
                    case (data_tx_cnt)
                        5'd0 : tx_data = 8'h53; 5'd1 : tx_data = 8'h70; 5'd2 : tx_data = 8'h4F; 5'd3 : tx_data = 8'h32;
                        5'd4 : tx_data = 8'h3A; 5'd5 : tx_data = spo2_ascii[2]; 5'd6 : tx_data = spo2_ascii[1]; 5'd7 : tx_data = spo2_ascii[0];
                        5'd8 : tx_data = 8'h25; 5'd9 : tx_data = 8'h2C; 5'd10: tx_data = 8'h48; 5'd11: tx_data = 8'h52;
                        5'd12: tx_data = 8'h3A; 5'd13: tx_data = hr_ascii[2]; 5'd14: tx_data = hr_ascii[1]; 5'd15: tx_data = hr_ascii[0];
                        5'd16: tx_data = 8'h2C; 5'd17: tx_data = 8'h54; 5'd18: tx_data = 8'h3A; 5'd19: tx_data = temp_ascii[2];
                        5'd20: tx_data = temp_ascii[1]; 5'd21: tx_data = temp_ascii[0]; 5'd22: tx_data = 8'h2C; 5'd23: tx_data = 8'h48;
                        5'd24: tx_data = 8'h3A; 5'd25: tx_data = humi_ascii[2]; 5'd26: tx_data = humi_ascii[1]; 5'd27: tx_data = humi_ascii[0];
                        5'd28: tx_data = 8'h0D; 5'd29: tx_data = 8'h0A;
                        default: tx_data = 8'h00;
                    endcase
                    tx_data_valid = tx_data_ready;
                    next_state = S_SEND_DATA;
                end else begin
                     next_state = S_WAIT_TRIGGER; // Transition determined by counter
                end
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tx_data_ready_r <= 1'd0;
        end else begin
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