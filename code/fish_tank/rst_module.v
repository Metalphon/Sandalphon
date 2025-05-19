module rst_module(
    input clk,          // System clock input
    output reg rst_n    // Reset signal output, active low
);

    // Counter for reset delay
    reg [31:0] rst_cnt;
    
    // Reset generation logic
    always @(posedge clk) begin
        if (rst_cnt == 32'd0) begin    // Initial state
            rst_cnt <= rst_cnt + 1'b1;
            rst_n <= 1'b1;             // Start with reset inactive (high)
        end
        else if (rst_cnt < 32'h8F0D180) begin  // Count phase
            rst_cnt <= rst_cnt + 1'b1;
            rst_n <= 1'b1;             // Keep reset inactive during count
        end
        else begin                     // Final state
            rst_n <= 1'b0;             // Assert reset (active low)
        end
    end

    // Initialize counter and reset
    initial begin
        rst_cnt = 32'd0;
        rst_n = 1'b1;    // Start with reset inactive (high)
    end

endmodule