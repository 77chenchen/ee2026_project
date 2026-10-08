`timescale 1ns / 1ps

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
