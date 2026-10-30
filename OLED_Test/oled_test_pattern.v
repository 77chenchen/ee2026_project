`timescale 1ns / 1ps

// Small, direct RGB565 test generator. There are no fonts, multipliers,
// graph controllers, frame RAMs or extra pixel pipeline stages.
module oled_test_pattern(
    input wire [12:0] pixel_index,
    input wire [2:0] pattern,
    input wire [6:0] bar_x,
    output reg [15:0] pixel_data
);
    wire [6:0] x=pixel_index%13'd96;
    wire [5:0] y=pixel_index/13'd96;
    localparam RED=16'hF800,GREEN=16'h07E0,BLUE=16'h001F,
               WHITE=16'hFFFF,BLACK=16'h0000,YELLOW=16'hFFE0;
    always @* begin
        case(pattern)
            0: pixel_data=RED;
            1: pixel_data=GREEN;
            2: pixel_data=BLUE;
            3: pixel_data=WHITE;
            4: pixel_data=(x[3]^y[3])?WHITE:BLACK;
            5: begin
                pixel_data=(x==0 || x==95 || y==0 || y==63)?WHITE:BLACK;
                // Orientation: upper-left red, upper-right green,
                // lower-left blue and lower-right yellow.
                if(x<4 && y<4) pixel_data=RED;
                else if(x>=92 && y<4) pixel_data=GREEN;
                else if(x<4 && y>=60) pixel_data=BLUE;
                else if(x>=92 && y>=60) pixel_data=YELLOW;
            end
            6: pixel_data=(x==48 || y==32)?WHITE:BLACK;
            7: begin
                pixel_data=(x<32)?RED:(x<64)?GREEN:BLUE;
                if(x>=bar_x && {1'b0,x}<({1'b0,bar_x}+8'd4)) pixel_data=WHITE;
            end
            default: pixel_data=16'hF81F;
        endcase
    end
endmodule
