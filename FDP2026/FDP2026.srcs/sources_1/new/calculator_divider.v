`timescale 1ns / 1ps

// Eight-bit signed restoring divider.  One quotient bit is produced per
// 100 MHz clock so no divider is placed on a single-cycle timing path.
module calculator_divider(
    input  wire              clk,
    input  wire              start,
    input  wire signed [7:0] dividend,
    input  wire signed [7:0] divisor,
    output reg               busy,
    output reg               done,
    output reg  signed [15:0] quotient
);
    reg [7:0] dividend_shift;
    reg [7:0] divisor_magnitude;
    reg [7:0] quotient_magnitude;
    reg [8:0] remainder;
    reg [3:0] bit_index;
    reg quotient_negative;

    wire [8:0] trial = {remainder[7:0], dividend_shift[7]};
    wire take = trial >= {1'b0, divisor_magnitude};
    wire [8:0] remainder_next = take ?
        trial - {1'b0, divisor_magnitude} : trial;
    wire [7:0] quotient_next = {quotient_magnitude[6:0], take};
    wire signed [16:0] signed_quotient = quotient_negative ?
        -$signed({1'b0, quotient_next}) : $signed({1'b0, quotient_next});

    always @(posedge clk) begin
        done <= 1'b0;
        if (start) begin
            dividend_shift <= dividend[7] ? (~dividend + 8'd1) : dividend;
            divisor_magnitude <= divisor[7] ?
                (~divisor + 8'd1) : divisor;
            quotient_magnitude <= 8'd0;
            remainder <= 9'd0;
            bit_index <= 4'd7;
            quotient_negative <= dividend[7] ^ divisor[7];
            busy <= 1'b1;
        end else if (busy) begin
            dividend_shift <= {dividend_shift[6:0], 1'b0};
            remainder <= remainder_next;
            quotient_magnitude <= quotient_next;
            if (bit_index == 4'd0) begin
                busy <= 1'b0;
                done <= 1'b1;
                quotient <= signed_quotient[15:0];
            end else begin
                bit_index <= bit_index - 1'b1;
            end
        end
    end
endmodule
