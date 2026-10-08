`timescale 1ns / 1ps

module check_invalid(
    input [7:0] saved_number_2,
    input ready,
    input [1:0] operation, //00=0=+, 01=1=-, 10=2=*, 11=3=/
    output reg invalid
    );
    
    always @(*) begin
        //check if both numbers are saved
        if (ready == 0) begin //=0 not ready
            invalid = 1; //invalid
        end
        
        //check if division by zero
        else if (operation == 3 && saved_number_2 == 0) begin //if we choose / and nr 2 = 0
            invalid = 1; //invalid
        end
        
        //valid calculation
        else begin
            invalid = 0;
        end
    end
endmodule
