`timescale 1ns / 1ps

// Reports whether a full signed 16-bit result can be recalled as an 8-bit
// operand.  The calculator still displays and stores the complete result.
module check_overflow (
    input  wire signed [15:0] result,
    output wire               overflow
);
    assign overflow = (result > 16'sd127) || (result < -16'sd128);
endmodule
