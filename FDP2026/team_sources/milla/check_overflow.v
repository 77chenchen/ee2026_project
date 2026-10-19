`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.10.2026 09:05:23
// Design Name: 
// Module Name: check_overflow
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module check_overflow(
    input signed [8:0] result,
    output reg overflow
    );
    
    always @(*) begin
        if (result > 127 || result < -128) begin
            overflow = 1;
        end
        else begin
            overflow = 0;
        end
    end
endmodule
