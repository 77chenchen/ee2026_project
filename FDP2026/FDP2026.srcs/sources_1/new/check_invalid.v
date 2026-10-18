`timescale 1ns / 1ps

// Calculator input validation.  All four operations are valid except division
// by zero; ready allows the caller to distinguish preview from execution.
module check_invalid (
    input  wire signed [7:0] operand_b,
    input  wire              ready,
    input  wire [1:0]        operation,
    output wire              invalid
);
    localparam [1:0] DIV = 2'd3;
    assign invalid = !ready || ((operation == DIV) && (operand_b == 0));
endmodule
