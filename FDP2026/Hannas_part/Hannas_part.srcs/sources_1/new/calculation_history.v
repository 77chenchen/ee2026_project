`timescale 1ns / 1ps

module calculation_history(
    input clk,
    input save, //save a new reslut
    input [7:0] result,
    //save our 3 latest results
    output reg [7:0] history_1, 
    output reg [7:0] history_2,
    output reg [7:0] history_3
    );
    
    reg save_old = 0; //remembers save old value in the latest posedge
    
    always @(posedge clk) begin
        if (save == 1 && save_old == 0) begin //just save new result when save go from 0 to 1
            history_3 <= history_2; //hist 3 get old value from hist 2
            history_2 <= history_1; //hist 2 get old value from hist 1
            history_1 <= result;    //hist 1 get the new result
        end
        save_old <= save;
    end
endmodule
