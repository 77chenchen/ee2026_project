`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.10.2026 09:10:57
// Design Name: 
// Module Name: check_invalid
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
