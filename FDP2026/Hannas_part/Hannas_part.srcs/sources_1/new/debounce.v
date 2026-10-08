`timescale 1ns / 1ps

module debounce(
    input clk,
    input btn,
    output reg btn_pressed = 0
    );
    
    reg [24:0] debounce_counter = 0; //ignore new btn pushes within 200ms
    reg wait_release = 0; //=0 we can have a new btn, =1 we wait for the btn to be realesed
    
    always @(posedge clk) begin
        //default: no new button pressed
        btn_pressed <= 0;
        
        //count down
        if (debounce_counter > 0) begin
            debounce_counter <= debounce_counter - 1;
        end
        
        //wait for button to be realesed, already a btn registered
        else if (wait_release == 1) begin
            if (btn == 0) begin //btn not pressed, the user have released the btn
                wait_release <= 0; //now we can register a new btn
            end
        end
        
        //check button pressed, check counter, check wait_release
        else if (btn == 1 && debounce_counter == 0 && wait_release == 0) begin //btn is pressed
            btn_pressed <= 1; //btn_pressed changed to yes pressed
            wait_release <= 1;
            debounce_counter <= 20000000;
        end
    end
endmodule
