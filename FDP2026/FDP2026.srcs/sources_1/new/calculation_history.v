`timescale 1ns / 1ps

// Three-entry signed result history, newest first.
module calculation_history (
    input  wire               clk,
    input  wire               reset,
    input  wire               save,
    input  wire signed [15:0] result,
    output reg  [1:0]         count,
    output reg  signed [15:0] history_0,
    output reg  signed [15:0] history_1,
    output reg  signed [15:0] history_2
);
    always @(posedge clk) begin
        if (reset) begin
            count <= 2'd0;
            history_0 <= 16'sd0;
            history_1 <= 16'sd0;
            history_2 <= 16'sd0;
        end else if (save) begin
            history_2 <= history_1;
            history_1 <= history_0;
            history_0 <= result;
            if (count < 2'd3)
                count <= count + 1'b1;
        end
    end
endmodule
