`timescale 1ns / 1ps

module calculation_history(
    input clk,
    input reset,
    input save, //save a new reslut
   
    //information about the calculation
    input signed [7:0] operand_a,
    input signed [7:0] operand_b,
    input [1:0] operation,
    input signed [15:0] result,
   
    //number of saved caluculations
    output reg [1:0] count,
   
    //save our 3 latest results
    output reg signed [15:0] history_0,
    output reg signed [15:0] history_1,
    output reg signed [15:0] history_2,
   
    //store the first number of each calculation
    output reg signed [7:0] history_a0,
    output reg signed [7:0] history_a1,
    output reg signed [7:0] history_a2,
   
    //store the second number of each calculation
    output reg signed [7:0] history_b0,
    output reg signed [7:0] history_b1,
    output reg signed [7:0] history_b2,
   
    //store the operation of each calculation
    output reg [1:0] history_op0,
    output reg [1:0] history_op1,
    output reg [1:0] history_op2
    );
   
    always @(posedge clk) begin
        if (reset == 1) begin //reset all saved results
            history_a0 <= 0;
            history_a1 <= 0;
            history_a2 <= 0;
           
            history_b0 <= 0;
            history_b1 <= 0;
            history_b2 <= 0;
           
            history_op0 <= 0;
            history_op1 <= 0;
            history_op2 <= 0;  
           
            history_0 <= 0;
            history_1 <= 0;
            history_2 <= 0;
            count <= 0;  
        end
       
        //save a new result
        else if (save == 1) begin
            //save the first number
            history_a2 <= history_a1;
            history_a1 <= history_a0;
            history_a0 <= operand_a;  
           
             //save the second number
            history_b2 <= history_b1;
            history_b1 <= history_b0;
            history_b0 <= operand_b;  
           
            //save the operation
            history_op2 <= history_op1;
            history_op1 <= history_op0;
            history_op0 <= operation;

            //save the result
            history_2 <= history_1;
            history_1 <= history_0;
            history_0 <= result;
           
            //count saved results, maximum 3
            if (count < 3) begin
                count <= count + 1;
            end
        end
    end
endmodule
