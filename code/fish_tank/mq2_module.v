module mq2_module(
    input clk,              // System clock input
    input rst_n,           // Reset signal input, active low
    input mq2_data,        // MQ-2 sensor digital input (high: gas detected, low: normal)
    output reg buzzer      // Alert signal output (low: alert, high: normal)
);

    // Simple alert logic
    always @(posedge clk ) begin
        if (rst_n) begin
            buzzer <= 1'b1;    // Initialize to no alert (high)
        end
        else begin
            buzzer <= mq2_data;  // When input is high (gas detected), output low (alert)
        end
    end

endmodule