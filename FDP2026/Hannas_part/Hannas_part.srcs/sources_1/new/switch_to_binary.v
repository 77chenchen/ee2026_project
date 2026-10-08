`timescale 1ns / 1ps

module switch_to_binary(
    input clk,
    input btnC,
    input [7:0] sw,
    input btn_pressed,
    output reg [7:0] saved_number_1,
    output reg [7:0] saved_number_2,
    output reg ready = 0 //variable to say that all numbers are saved                        
    );
       
    reg [7:0] number; //signed numbers, 7 bit with numbers, 1 bit with sign, take the value from sw 0-6 and send to number
    reg witch_number = 0; //know witch number of 1 or 2 we chould save, =0 save nr1
    reg btnC_old = 0; //btnC_old=0, then btnC was not pressed previous posedge
   
    //read the switches 
    always @(*) begin
        if (sw[7] == 1) begin //negative number
            number = -sw[6:0];
        end
        else begin
            number = sw[6:0]; //positive number
        end
    end
    
    //save number when btnC is pressed
    always @(posedge clk) begin //in very posedge we controll if btnC is pressed again or not
        if (btn_pressed == 1) begin //if btnC is pressed 
            if (witch_number == 0) begin
                saved_number_1 <= number;
                witch_number <= 1; //change to save nr2 next time
                ready <= 0; //both nr are not saved yet
            end
            else begin
                saved_number_2 <= number;
                witch_number <= 0;
                ready <= 1; //both nr are saved
            end
        end
        btnC_old <= btnC; //update the old value
    end
endmodule