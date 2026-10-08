`timescale 1ns / 1ps


module clock_hz(input [31:0] HZ,
                input CLOCK,
                output reg SLOW_CLOCK = 0);
    
    reg [27:0] COUNT = 0; 
    
    always @(posedge CLOCK) begin
        COUNT <= (COUNT == (100_000_000 / (2 * HZ)) - 1) ? 0 : COUNT + 1;
        SLOW_CLOCK <= (COUNT == (100_000_000 / (2 * HZ)) - 1) ? ~SLOW_CLOCK : SLOW_CLOCK;
    end
endmodule
