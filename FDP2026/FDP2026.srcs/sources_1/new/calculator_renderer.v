`timescale 1ns / 1ps

// Combinational 96x64 calculator UI.  It deliberately shares the same
// pixel_index/RGB565 contract as graph_renderer and the supplied OLED core.
module calculator_renderer #(
    parameter INCLUDE_TEXT = 1
) (
    input  wire [12:0] pixel_index,
    input  wire signed [7:0] input_value,
    input  wire signed [7:0] operand_a,
    input  wire signed [7:0] operand_b,
    input  wire [2:0] state,
    input  wire [1:0] operation,
    input  wire operation_valid,
    input  wire signed [15:0] result,
    input  wire result_valid,
    input  wire divide_by_zero,
    input  wire overflow,
    input  wire busy,
    input  wire sw13_history,
    input  wire [1:0] history_count,
    input  wire [1:0] history_select,
    input  wire signed [15:0] history_0,
    input  wire signed [15:0] history_1,
    input  wire signed [15:0] history_2,
    input  wire recall_error,
    output reg  [15:0] pixel_data
);
    localparam [2:0] INPUT_A=0, SELECT_OP=1, INPUT_B=2, EXECUTE=3, RESULT=4;
    localparam [1:0] ADD=0, SUB=1, MUL=2, DIV=3;
    localparam [15:0] BLACK=16'h0000, WHITE=16'hFFFF, GREEN=16'h07E0;
    localparam [15:0] CYAN=16'h07FF, YELLOW=16'hFFE0, ORANGE=16'hFD20;
    localparam [15:0] RED=16'hF800, BLUE=16'h001F, PANEL=16'h1082;

    wire [6:0] x = pixel_index % 13'd96;
    wire [5:0] y = pixel_index / 13'd96;

    function [4:0] glyph_row;
        input [7:0] ch; input [2:0] row;
        begin
            glyph_row=0;
            case(ch)
                "A":case(row)0:glyph_row=14;1:glyph_row=17;2:glyph_row=17;3:glyph_row=31;4:glyph_row=17;5:glyph_row=17;6:glyph_row=17;endcase
                "B":case(row)0:glyph_row=30;1:glyph_row=17;2:glyph_row=17;3:glyph_row=30;4:glyph_row=17;5:glyph_row=17;6:glyph_row=30;endcase
                "C":case(row)0:glyph_row=15;1:glyph_row=16;2:glyph_row=16;3:glyph_row=16;4:glyph_row=16;5:glyph_row=16;6:glyph_row=15;endcase
                "D":case(row)0:glyph_row=30;1:glyph_row=17;2:glyph_row=17;3:glyph_row=17;4:glyph_row=17;5:glyph_row=17;6:glyph_row=30;endcase
                "E":case(row)0:glyph_row=31;1:glyph_row=16;2:glyph_row=16;3:glyph_row=30;4:glyph_row=16;5:glyph_row=16;6:glyph_row=31;endcase
                "F":case(row)0:glyph_row=31;1:glyph_row=16;2:glyph_row=16;3:glyph_row=30;4:glyph_row=16;5:glyph_row=16;6:glyph_row=16;endcase
                "G":case(row)0:glyph_row=14;1:glyph_row=17;2:glyph_row=16;3:glyph_row=23;4:glyph_row=17;5:glyph_row=17;6:glyph_row=14;endcase
                "H":case(row)0:glyph_row=17;1:glyph_row=17;2:glyph_row=17;3:glyph_row=31;4:glyph_row=17;5:glyph_row=17;6:glyph_row=17;endcase
                "I":case(row)0:glyph_row=31;1:glyph_row=4;2:glyph_row=4;3:glyph_row=4;4:glyph_row=4;5:glyph_row=4;6:glyph_row=31;endcase
                "K":case(row)0:glyph_row=17;1:glyph_row=18;2:glyph_row=20;3:glyph_row=24;4:glyph_row=20;5:glyph_row=18;6:glyph_row=17;endcase
                "L":case(row)0:glyph_row=16;1:glyph_row=16;2:glyph_row=16;3:glyph_row=16;4:glyph_row=16;5:glyph_row=16;6:glyph_row=31;endcase
                "N":case(row)0:glyph_row=17;1:glyph_row=25;2:glyph_row=25;3:glyph_row=21;4:glyph_row=19;5:glyph_row=19;6:glyph_row=17;endcase
                "O":case(row)0:glyph_row=14;1:glyph_row=17;2:glyph_row=17;3:glyph_row=17;4:glyph_row=17;5:glyph_row=17;6:glyph_row=14;endcase
                "P":case(row)0:glyph_row=30;1:glyph_row=17;2:glyph_row=17;3:glyph_row=30;4:glyph_row=16;5:glyph_row=16;6:glyph_row=16;endcase
                "R":case(row)0:glyph_row=30;1:glyph_row=17;2:glyph_row=17;3:glyph_row=30;4:glyph_row=20;5:glyph_row=18;6:glyph_row=17;endcase
                "S":case(row)0:glyph_row=15;1:glyph_row=16;2:glyph_row=16;3:glyph_row=14;4:glyph_row=1;5:glyph_row=1;6:glyph_row=30;endcase
                "T":case(row)0:glyph_row=31;1:glyph_row=4;2:glyph_row=4;3:glyph_row=4;4:glyph_row=4;5:glyph_row=4;6:glyph_row=4;endcase
                "U":case(row)0:glyph_row=17;1:glyph_row=17;2:glyph_row=17;3:glyph_row=17;4:glyph_row=17;5:glyph_row=17;6:glyph_row=14;endcase
                "V":case(row)0:glyph_row=17;1:glyph_row=17;2:glyph_row=17;3:glyph_row=17;4:glyph_row=17;5:glyph_row=10;6:glyph_row=4;endcase
                "W":case(row)0:glyph_row=17;1:glyph_row=17;2:glyph_row=17;3:glyph_row=21;4:glyph_row=21;5:glyph_row=27;6:glyph_row=17;endcase
                "Y":case(row)0:glyph_row=17;1:glyph_row=17;2:glyph_row=10;3:glyph_row=4;4:glyph_row=4;5:glyph_row=4;6:glyph_row=4;endcase
                "0":case(row)0:glyph_row=14;1:glyph_row=17;2:glyph_row=19;3:glyph_row=21;4:glyph_row=25;5:glyph_row=17;6:glyph_row=14;endcase
                "1":case(row)0:glyph_row=4;1:glyph_row=12;2:glyph_row=4;3:glyph_row=4;4:glyph_row=4;5:glyph_row=4;6:glyph_row=14;endcase
                "2":case(row)0:glyph_row=14;1:glyph_row=17;2:glyph_row=1;3:glyph_row=2;4:glyph_row=4;5:glyph_row=8;6:glyph_row=31;endcase
                "3":case(row)0:glyph_row=30;1:glyph_row=1;2:glyph_row=1;3:glyph_row=14;4:glyph_row=1;5:glyph_row=1;6:glyph_row=30;endcase
                "4":case(row)0:glyph_row=2;1:glyph_row=6;2:glyph_row=10;3:glyph_row=18;4:glyph_row=31;5:glyph_row=2;6:glyph_row=2;endcase
                "5":case(row)0:glyph_row=31;1:glyph_row=16;2:glyph_row=16;3:glyph_row=30;4:glyph_row=1;5:glyph_row=1;6:glyph_row=30;endcase
                "6":case(row)0:glyph_row=14;1:glyph_row=16;2:glyph_row=16;3:glyph_row=30;4:glyph_row=17;5:glyph_row=17;6:glyph_row=14;endcase
                "7":case(row)0:glyph_row=31;1:glyph_row=1;2:glyph_row=2;3:glyph_row=4;4:glyph_row=8;5:glyph_row=8;6:glyph_row=8;endcase
                "8":case(row)0:glyph_row=14;1:glyph_row=17;2:glyph_row=17;3:glyph_row=14;4:glyph_row=17;5:glyph_row=17;6:glyph_row=14;endcase
                "9":case(row)0:glyph_row=14;1:glyph_row=17;2:glyph_row=17;3:glyph_row=15;4:glyph_row=1;5:glyph_row=1;6:glyph_row=14;endcase
                "-":if(row==3)glyph_row=14;
                "+":case(row)2:glyph_row=4;3:glyph_row=14;4:glyph_row=4;endcase
                "*":case(row)1:glyph_row=17;2:glyph_row=10;3:glyph_row=4;4:glyph_row=10;5:glyph_row=17;endcase
                "/":case(row)0:glyph_row=1;1:glyph_row=2;2:glyph_row=2;3:glyph_row=4;4:glyph_row=8;5:glyph_row=8;6:glyph_row=16;endcase
                "=":case(row)2:glyph_row=14;4:glyph_row=14;endcase
            endcase
        end
    endfunction

    function font_pixel;
        input [7:0] ch; input integer px,py,left,top;
        integer col,row; reg [4:0] bits;
        begin
            col=px-left; row=py-top; font_pixel=0;
            if(col>=0 && col<5 && row>=0 && row<7) begin
                bits=glyph_row(ch,row[2:0]); font_pixel=bits[4-col];
            end
        end
    endfunction

    function [7:0] digit_char;
        input integer digit;
        begin digit_char = "0" + digit[7:0]; end
    endfunction

    function signed_number_pixel;
        input signed [15:0] value; input integer px,py,left,top;
        integer mag,start;
        begin
            mag=value; if(mag<0) mag=-mag;
            start=left + (value<0 ? 6 : 0);
            signed_number_pixel =
                ((value<0) && font_pixel("-",px,py,left,top)) ||
                ((mag>=10000) && font_pixel(digit_char((mag/10000)%10),px,py,start,top)) ||
                ((mag>=1000) && font_pixel(digit_char((mag/1000)%10),px,py,start+6,top)) ||
                ((mag>=100) && font_pixel(digit_char((mag/100)%10),px,py,start+12,top)) ||
                ((mag>=10) && font_pixel(digit_char((mag/10)%10),px,py,start+18,top)) ||
                font_pixel(digit_char(mag%10),px,py,start+24,top);
        end
    endfunction

    reg header_pixel, label_pixel, value_pixel, action_pixel, error_pixel;
    reg selected_row;
    integer px,py;
    always @* begin
        px=x; py=y;
        header_pixel = INCLUDE_TEXT &&
                       (font_pixel("C",px,py,28,2)||font_pixel("A",px,py,34,2)||
                        font_pixel("L",px,py,40,2)||font_pixel("C",px,py,46,2));
        label_pixel=0; value_pixel=0; action_pixel=0; error_pixel=0;
        selected_row=0;

        if(INCLUDE_TEXT && sw13_history) begin
            label_pixel=font_pixel("H",px,py,2,12)||font_pixel("I",px,py,8,12)||
                        font_pixel("S",px,py,14,12)||font_pixel("T",px,py,20,12);
            selected_row=((history_select==0)&&(py>=21)&&(py<=29))||
                         ((history_select==1)&&(py>=31)&&(py<=39))||
                         ((history_select==2)&&(py>=41)&&(py<=49));
            value_pixel=((history_count>0)&&signed_number_pixel(history_0,px,py,10,22))||
                        ((history_count>1)&&signed_number_pixel(history_1,px,py,10,32))||
                        ((history_count>2)&&signed_number_pixel(history_2,px,py,10,42));
            action_pixel=font_pixel("U",px,py,2,55)||font_pixel("D",px,py,8,55)||
                         font_pixel("S",px,py,20,55)||font_pixel("E",px,py,26,55)||
                         font_pixel("L",px,py,32,55)||font_pixel("C",px,py,44,55)||
                         font_pixel("U",px,py,50,55)||font_pixel("S",px,py,56,55)||
                         font_pixel("E",px,py,62,55);
            error_pixel=recall_error && (font_pixel("O",px,py,66,12)||
                         font_pixel("V",px,py,72,12)||font_pixel("F",px,py,78,12));
        end else if(INCLUDE_TEXT) begin
            case(state)
                INPUT_A: begin
                    label_pixel=font_pixel("I",px,py,2,13)||font_pixel("N",px,py,8,13)||
                                font_pixel("A",px,py,14,13)||font_pixel("=",px,py,20,13);
                    value_pixel=signed_number_pixel({{8{input_value[7]}},input_value},px,py,25,25);
                    action_pixel=font_pixel("C",px,py,2,55)||font_pixel("S",px,py,14,55)||
                                 font_pixel("A",px,py,20,55)||font_pixel("V",px,py,26,55)||font_pixel("E",px,py,32,55);
                end
                SELECT_OP: begin
                    label_pixel=font_pixel("O",px,py,2,13)||font_pixel("P",px,py,8,13)||
                                font_pixel("U",px,py,2,27)||font_pixel("+",px,py,8,27)||
                                font_pixel("D",px,py,20,27)||font_pixel("-",px,py,26,27)||
                                font_pixel("L",px,py,38,27)||font_pixel("*",px,py,44,27)||
                                font_pixel("R",px,py,56,27)||font_pixel("/",px,py,62,27);
                    value_pixel=signed_number_pixel({{8{operand_a[7]}},operand_a},px,py,62,12);
                    action_pixel=font_pixel("C",px,py,2,55)||font_pixel("O",px,py,14,55)||font_pixel("K",px,py,20,55);
                end
                INPUT_B: begin
                    label_pixel=font_pixel("I",px,py,2,13)||font_pixel("N",px,py,8,13)||
                                font_pixel("B",px,py,14,13)||font_pixel("=",px,py,20,13);
                    value_pixel=signed_number_pixel({{8{input_value[7]}},input_value},px,py,25,25);
                    action_pixel=font_pixel("C",px,py,2,55)||font_pixel("R",px,py,14,55)||
                                 font_pixel("U",px,py,20,55)||font_pixel("N",px,py,26,55);
                end
                EXECUTE: begin
                    label_pixel=font_pixel("W",px,py,30,27)||font_pixel("O",px,py,36,27)||
                                font_pixel("R",px,py,42,27)||font_pixel("K",px,py,48,27);
                end
                default: begin
                    label_pixel=font_pixel("R",px,py,2,13)||font_pixel("E",px,py,8,13)||font_pixel("S",px,py,14,13);
                    value_pixel=result_valid && signed_number_pixel(result,px,py,25,27);
                    action_pixel=font_pixel("1",px,py,2,55)||font_pixel("4",px,py,8,55)||
                                 font_pixel("N",px,py,20,55)||font_pixel("E",px,py,26,55)||font_pixel("W",px,py,32,55)||
                                 font_pixel("1",px,py,50,55)||font_pixel("3",px,py,56,55)||font_pixel("H",px,py,68,55)||font_pixel("I",px,py,74,55);
                    error_pixel=divide_by_zero ?
                        (font_pixel("D",px,py,60,13)||font_pixel("I",px,py,66,13)||font_pixel("V",px,py,72,13)||font_pixel("0",px,py,78,13)) :
                        (overflow && (font_pixel("O",px,py,66,13)||font_pixel("V",px,py,72,13)||font_pixel("F",px,py,78,13)));
                end
            endcase
        end

        pixel_data=BLACK;
        if((x==0)||(x==95)||(y==0)||(y==63)) pixel_data=BLUE;
        if(y>=1 && y<=9) pixel_data=PANEL;
        if(selected_row) pixel_data=PANEL;
        if(header_pixel) pixel_data=CYAN;
        if(label_pixel) pixel_data=WHITE;
        if(value_pixel) pixel_data=GREEN;
        if(action_pixel) pixel_data=YELLOW;
        if(error_pixel) pixel_data=RED;
        if(busy && ((x+y)&7)==0 && y>=48 && y<=51) pixel_data=ORANGE;
    end
endmodule
