`timescale 1ns / 1ps

// Eight restoring-division steps replace a 16-bit combinational divide.
// Operands are the calculator's signed 8-bit inputs; the 16-bit output keeps
// the exceptional -128 / -1 = 128 result available for overflow detection.
module calculator_signed_divider(
    input clk,
    input start,
    input signed [7:0] dividend,
    input signed [7:0] divisor,
    output reg busy = 1'b0,
    output reg done = 1'b0,
    output reg signed [15:0] quotient = 16'sd0
);
    reg [7:0] dividend_shift = 8'd0;
    reg [7:0] divisor_magnitude = 8'd0;
    reg [7:0] quotient_magnitude = 8'd0;
    reg [8:0] remainder = 9'd0;
    reg [3:0] steps_left = 4'd0;
    reg negate_result = 1'b0;

    wire [7:0] dividend_magnitude = dividend[7] ?
        (~dividend + 8'd1) : dividend;
    wire [7:0] divisor_input_magnitude = divisor[7] ?
        (~divisor + 8'd1) : divisor;
    wire [8:0] trial_remainder = {remainder[7:0], dividend_shift[7]};
    wire trial_bit = trial_remainder >= {1'b0, divisor_magnitude};
    wire [8:0] next_remainder = trial_bit ?
        (trial_remainder - {1'b0, divisor_magnitude}) : trial_remainder;
    wire [7:0] next_quotient = {quotient_magnitude[6:0], trial_bit};

    always @(posedge clk) begin
        done <= 1'b0;
        if (start && !busy) begin
            if (divisor == 0) begin
                // The caller marks divide-by-zero invalid; do not start work.
                quotient <= 16'sd0;
                done <= 1'b1;
            end else begin
                dividend_shift <= dividend_magnitude;
                divisor_magnitude <= divisor_input_magnitude;
                quotient_magnitude <= 8'd0;
                remainder <= 9'd0;
                steps_left <= 4'd8;
                negate_result <= dividend[7] ^ divisor[7];
                busy <= 1'b1;
            end
        end else if (busy) begin
            dividend_shift <= {dividend_shift[6:0], 1'b0};
            quotient_magnitude <= next_quotient;
            remainder <= next_remainder;
            steps_left <= steps_left - 1'b1;
            if (steps_left == 4'd1) begin
                quotient <= negate_result ?
                    -$signed({8'd0, next_quotient}) :
                     $signed({8'd0, next_quotient});
                busy <= 1'b0;
                done <= 1'b1;
            end
        end
    end
endmodule
