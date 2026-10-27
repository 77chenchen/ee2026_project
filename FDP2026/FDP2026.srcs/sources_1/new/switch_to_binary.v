`timescale 1ns / 1ps

module switch_to_binary(
    input clk, 
    input reset, 
    input [7:0] sw,
    input save_first, 
    input save_second,
    output reg signed [7:0] saved_number_1 = 0,
    output reg signed [7:0] saved_number_2 = 0,
    output reg ready = 0
    );
    
    wire signed [7:0] number = sw[7] ? -$signed({1'b0,sw[6:0]}) : $signed({1'b0,sw[6:0]});   
    always @(posedge clk) begin
        if (reset) begin
            saved_number_1 <= 0;
            saved_number_2 <= 0;
            ready <= 0;
        end else if (save_first) begin
            saved_number_1 <= number;
            ready <= 0;
        end else if (save_second) begin
            saved_number_2 <= number;
            ready <= 1;
        end
    end
endmodule