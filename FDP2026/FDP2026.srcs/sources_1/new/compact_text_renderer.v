`timescale 1ns / 1ps

// Shared 16x8 character plane for every application mode.  Only one 5x7
// glyph ROM and one binary-to-BCD converter are synthesized for the complete
// design; the previous implementation expanded both for every printed glyph.
module compact_text_renderer (
    input  wire [1:0] mode,
    input  wire [6:0] screen_x,
    input  wire [5:0] screen_y,

    input  wire signed [7:0] input_value,
    input  wire signed [7:0] calc_a,
    input  wire [2:0] calc_state,
    input  wire signed [15:0] calc_result,
    input  wire calc_result_valid,
    input  wire calc_div0,
    input  wire calc_overflow,
    input  wire calc_busy,
    input  wire history_view,
    input  wire [1:0] history_count,
    input  wire signed [15:0] history_0,
    input  wire signed [15:0] history_1,
    input  wire signed [15:0] history_2,
    input  wire recall_error,

    input  wire [1:0] graph_count,
    input  wire [2:0] graph_state,
    input  wire current_graph,
    input  wire graph_draw,
    input  wire [2:0] graph_status,
    input  wire cursor_enable,
    input  wire signed [15:0] cursor_x_q4,
    input  wire signed [15:0] cursor_y_q4,

    output reg text_on,
    output reg [15:0] text_pixel_data
);
    localparam [1:0] MODE_MENU=2'd0, MODE_CALC=2'd1, MODE_GRAPH=2'd2;
    localparam [2:0] INPUT_A=3'd0, SELECT_OP=3'd1, INPUT_B=3'd2,
                     EXECUTE=3'd3, RESULT=3'd4;
    localparam [2:0] SELECT_COUNT=3'd0, SELECT_TYPE=3'd1, ENTER_A=3'd2,
                     ENTER_B=3'd3, ENTER_C=3'd4, READY=3'd6,
                     VIEW_GRAPH=3'd7;
    localparam [2:0] STATUS_PAR=3'd1, STATUS_SAME=3'd2,
                     STATUS_OUT=3'd3, STATUS_ERR=3'd4;
    localparam [15:0] WHITE=16'hFFFF, GREEN=16'h07E0, CYAN=16'h07FF,
                      YELLOW=16'hFFE0, ORANGE=16'hFD20, RED=16'hF800;

    function [4:0] glyph_row;
        input [7:0] ch;
        input [2:0] row;
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
                "M":case(row)0:glyph_row=17;1:glyph_row=27;2:glyph_row=21;3:glyph_row=21;4:glyph_row=17;5:glyph_row=17;6:glyph_row=17;endcase
                "N":case(row)0:glyph_row=17;1:glyph_row=25;2:glyph_row=25;3:glyph_row=21;4:glyph_row=19;5:glyph_row=19;6:glyph_row=17;endcase
                "O":case(row)0:glyph_row=14;1:glyph_row=17;2:glyph_row=17;3:glyph_row=17;4:glyph_row=17;5:glyph_row=17;6:glyph_row=14;endcase
                "P":case(row)0:glyph_row=30;1:glyph_row=17;2:glyph_row=17;3:glyph_row=30;4:glyph_row=16;5:glyph_row=16;6:glyph_row=16;endcase
                "Q":case(row)0:glyph_row=14;1:glyph_row=17;2:glyph_row=17;3:glyph_row=17;4:glyph_row=21;5:glyph_row=18;6:glyph_row=13;endcase
                "R":case(row)0:glyph_row=30;1:glyph_row=17;2:glyph_row=17;3:glyph_row=30;4:glyph_row=20;5:glyph_row=18;6:glyph_row=17;endcase
                "S":case(row)0:glyph_row=15;1:glyph_row=16;2:glyph_row=16;3:glyph_row=14;4:glyph_row=1;5:glyph_row=1;6:glyph_row=30;endcase
                "T":case(row)0:glyph_row=31;1:glyph_row=4;2:glyph_row=4;3:glyph_row=4;4:glyph_row=4;5:glyph_row=4;6:glyph_row=4;endcase
                "U":case(row)0:glyph_row=17;1:glyph_row=17;2:glyph_row=17;3:glyph_row=17;4:glyph_row=17;5:glyph_row=17;6:glyph_row=14;endcase
                "V":case(row)0:glyph_row=17;1:glyph_row=17;2:glyph_row=17;3:glyph_row=17;4:glyph_row=17;5:glyph_row=10;6:glyph_row=4;endcase
                "W":case(row)0:glyph_row=17;1:glyph_row=17;2:glyph_row=17;3:glyph_row=21;4:glyph_row=21;5:glyph_row=27;6:glyph_row=17;endcase
                "X":case(row)0:glyph_row=17;1:glyph_row=17;2:glyph_row=10;3:glyph_row=4;4:glyph_row=10;5:glyph_row=17;6:glyph_row=17;endcase
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
                ".":if(row==6)glyph_row=4;
            endcase
        end
    endfunction

    function [7:0] digit_char;
        input [3:0] digit;
        begin digit_char = "0" + digit; end
    endfunction

    function [19:0] binary_to_bcd;
        input [15:0] binary;
        integer i;
        reg [35:0] shift;
        begin
            shift=0;
            shift[15:0]=binary;
            for(i=0;i<16;i=i+1) begin
                if(shift[19:16]>=5) shift[19:16]=shift[19:16]+3;
                if(shift[23:20]>=5) shift[23:20]=shift[23:20]+3;
                if(shift[27:24]>=5) shift[27:24]=shift[27:24]+3;
                if(shift[31:28]>=5) shift[31:28]=shift[31:28]+3;
                if(shift[35:32]>=5) shift[35:32]=shift[35:32]+3;
                shift=shift<<1;
            end
            binary_to_bcd=shift[35:16];
        end
    endfunction

    reg [3:0] char_col;
    reg [2:0] pixel_col;
    reg [2:0] char_row;
    reg [2:0] pixel_row;
    reg [7:0] selected_char;
    reg [15:0] selected_color;
    reg selected_cell;
    reg [4:0] selected_glyph_row;

    reg show_number;
    reg [2:0] number_row;
    reg [3:0] number_start_col;
    reg signed [15:0] number_value;
    reg [15:0] number_magnitude;
    reg [19:0] number_bcd;
    reg [15:0] number_color;

    reg coordinate_mode;
    reg coordinate_negative;
    reg [3:0] coordinate_fraction;
    reg signed [15:0] selected_coordinate_q4;
    reg [15:0] coordinate_abs_q4;

    always @* begin
        char_col=screen_x/7'd6;
        pixel_col=screen_x-(char_col*6);
        char_row=screen_y[5:3];
        pixel_row=screen_y[2:0];

        selected_char=0;
        selected_color=WHITE;
        selected_cell=0;
        show_number=0;
        number_row=0;
        number_start_col=0;
        number_value=0;
        number_color=GREEN;
        coordinate_mode=0;
        selected_coordinate_q4=0;
        coordinate_negative=0;
        coordinate_fraction=0;
        coordinate_abs_q4=0;

        if(mode==MODE_MENU) begin
            if(char_row==0) begin
                selected_color=CYAN;
                case(char_col)
                    3:selected_char="F";4:selected_char="P";5:selected_char="G";6:selected_char="A";
                    8:selected_char="C";9:selected_char="A";10:selected_char="L";11:selected_char="C";
                endcase
            end else if(char_row==3) begin
                selected_color=GREEN;
                case(char_col)3:selected_char="L";6:selected_char="C";7:selected_char="A";8:selected_char="L";9:selected_char="C";endcase
            end else if(char_row==5) begin
                selected_color=ORANGE;
                case(char_col)3:selected_char="D";6:selected_char="G";7:selected_char="R";8:selected_char="A";9:selected_char="P";10:selected_char="H";endcase
            end
        end else if(mode==MODE_CALC) begin
            if(char_row==0) begin
                selected_color=CYAN;
                case(char_col)5:selected_char="C";6:selected_char="A";7:selected_char="L";8:selected_char="C";endcase
            end

            if(history_view) begin
                if(char_row==1) begin
                    selected_color=recall_error?RED:WHITE;
                    if(recall_error) begin
                        case(char_col)11:selected_char="O";12:selected_char="V";13:selected_char="F";endcase
                    end else begin
                        case(char_col)0:selected_char="H";1:selected_char="I";2:selected_char="S";3:selected_char="T";endcase
                    end
                end
                if((char_row==3)&&(history_count>0)) begin show_number=1;number_row=3;number_value=history_0;end
                if((char_row==4)&&(history_count>1)) begin show_number=1;number_row=4;number_value=history_1;end
                if((char_row==5)&&(history_count>2)) begin show_number=1;number_row=5;number_value=history_2;end
                number_start_col=2;
                if(char_row==7) begin
                    selected_color=YELLOW;
                    case(char_col)0:selected_char="U";1:selected_char="D";3:selected_char="S";4:selected_char="E";5:selected_char="L";7:selected_char="C";8:selected_char="U";9:selected_char="S";10:selected_char="E";endcase
                end
            end else begin
                case(calc_state)
                    INPUT_A: begin
                        if(char_row==1) begin case(char_col)0:selected_char="I";1:selected_char="N";2:selected_char="A";3:selected_char="=";endcase end
                        show_number=1;number_row=3;number_start_col=4;number_value={{8{input_value[7]}},input_value};
                        if(char_row==7) begin selected_color=YELLOW;case(char_col)0:selected_char="C";2:selected_char="S";3:selected_char="A";4:selected_char="V";5:selected_char="E";endcase end
                    end
                    SELECT_OP: begin
                        if(char_row==1) begin case(char_col)0:selected_char="O";1:selected_char="P";endcase end
                        show_number=1;number_row=1;number_start_col=9;number_value={{8{calc_a[7]}},calc_a};
                        if(char_row==3) begin case(char_col)0:selected_char="U";1:selected_char="+";3:selected_char="D";4:selected_char="-";6:selected_char="L";7:selected_char="*";9:selected_char="R";10:selected_char="/";endcase end
                        if(char_row==7) begin selected_color=YELLOW;case(char_col)0:selected_char="C";2:selected_char="O";3:selected_char="K";endcase end
                    end
                    INPUT_B: begin
                        if(char_row==1) begin case(char_col)0:selected_char="I";1:selected_char="N";2:selected_char="B";3:selected_char="=";endcase end
                        show_number=1;number_row=3;number_start_col=4;number_value={{8{input_value[7]}},input_value};
                        if(char_row==7) begin selected_color=YELLOW;case(char_col)0:selected_char="C";2:selected_char="R";3:selected_char="U";4:selected_char="N";endcase end
                    end
                    EXECUTE: if(char_row==3) begin case(char_col)5:selected_char="W";6:selected_char="O";7:selected_char="R";8:selected_char="K";endcase end
                    default: begin
                        if(char_row==1) begin
                            case(char_col)0:selected_char="R";1:selected_char="E";2:selected_char="S";endcase
                            if(calc_div0) begin selected_color=RED;case(char_col)10:selected_char="D";11:selected_char="I";12:selected_char="V";13:selected_char="0";endcase end
                            else if(calc_overflow) begin selected_color=RED;case(char_col)11:selected_char="O";12:selected_char="V";13:selected_char="F";endcase end
                        end
                        if(calc_result_valid) begin show_number=1;number_row=3;number_start_col=4;number_value=calc_result;end
                        if(char_row==7) begin selected_color=YELLOW;case(char_col)0:selected_char="1";1:selected_char="4";3:selected_char="N";4:selected_char="E";5:selected_char="W";endcase end
                    end
                endcase
                if(calc_busy&&(char_row==6)) begin selected_color=ORANGE; selected_char="."; end
            end
        end else if(mode==MODE_GRAPH) begin
            if(char_row==0) begin
                selected_color=YELLOW;
                case(graph_state)
                    SELECT_COUNT:case(char_col)0:selected_char="C";1:selected_char="O";2:selected_char="U";3:selected_char="N";4:selected_char="T";endcase
                    SELECT_TYPE:begin case(char_col)0:selected_char="T";1:selected_char="Y";2:selected_char="P";3:selected_char="E";4:selected_char=current_graph?"2":"1";endcase end
                    ENTER_A:begin if(char_col==0)selected_char="A";if(char_col==1)selected_char=current_graph?"2":"1";end
                    ENTER_B:begin if(char_col==0)selected_char="B";if(char_col==1)selected_char=current_graph?"2":"1";end
                    ENTER_C:begin if(char_col==0)selected_char="C";if(char_col==1)selected_char=current_graph?"2":"1";end
                    READY:case(char_col)0:selected_char="R";1:selected_char="E";2:selected_char="A";3:selected_char="D";4:selected_char="Y";endcase
                    default:case(char_col)0:selected_char="D";1:selected_char="R";2:selected_char="A";3:selected_char="W";endcase
                endcase
                if(graph_draw&&(char_col==5)) begin selected_char="1";selected_color=GREEN;end
                if(graph_draw&&(graph_count==2)&&(char_col==6)) begin selected_char="2";selected_color=ORANGE;end
                case(graph_status)
                    STATUS_PAR:begin selected_color=RED;case(char_col)12:selected_char="P";13:selected_char="A";14:selected_char="R";endcase end
                    STATUS_SAME:begin selected_color=RED;case(char_col)11:selected_char="S";12:selected_char="A";13:selected_char="M";14:selected_char="E";endcase end
                    STATUS_OUT:begin selected_color=RED;case(char_col)12:selected_char="O";13:selected_char="U";14:selected_char="T";endcase end
                    STATUS_ERR:begin selected_color=RED;case(char_col)12:selected_char="E";13:selected_char="R";14:selected_char="R";endcase end
                endcase
            end

            if(!graph_draw&&(char_row==2)) begin
                selected_color=WHITE;
                if(graph_state==SELECT_COUNT) begin if(char_col==7)selected_char=input_value[0]?"2":"1";end
                else if(graph_state==SELECT_TYPE) begin
                    if(input_value[0]) begin case(char_col)6:selected_char="Q";7:selected_char="U";8:selected_char="A";9:selected_char="D";endcase end
                    else begin case(char_col)6:selected_char="L";7:selected_char="I";8:selected_char="N";9:selected_char="E";endcase end
                end else if((graph_state==ENTER_A)||(graph_state==ENTER_B)||(graph_state==ENTER_C)) begin
                    show_number=1;number_row=2;number_start_col=5;number_value={{8{input_value[7]}},input_value};number_color=WHITE;
                end
            end

            if(graph_draw&&cursor_enable&&((char_row==4)||(char_row==5))) begin
                coordinate_mode=1;
                selected_coordinate_q4=(char_row==4)?cursor_x_q4:cursor_y_q4;
                coordinate_negative=selected_coordinate_q4[15];
                coordinate_abs_q4=coordinate_negative ? -selected_coordinate_q4 : selected_coordinate_q4;
                number_value={4'd0,coordinate_abs_q4[15:4]};
                if(number_value>99)number_value=99;
                coordinate_fraction=(coordinate_abs_q4[3:0]>=8)?5:0;
                selected_color=CYAN;
            end

            if(char_row==7) begin
                selected_color=YELLOW;
                if(graph_state<=ENTER_C) begin case(char_col)0:selected_char="C";2:selected_char="S";3:selected_char="A";4:selected_char="V";5:selected_char="E";endcase end
                else if(graph_state==READY) begin case(char_col)0:selected_char="1";1:selected_char="4";3:selected_char="D";4:selected_char="R";5:selected_char="A";6:selected_char="W";endcase end
                else begin case(char_col)0:selected_char="1";1:selected_char="5";3:selected_char="B";4:selected_char="A";5:selected_char="C";6:selected_char="K";endcase end
            end
        end

        number_magnitude=number_value[15]?(~number_value+1'b1):number_value;
        number_bcd=binary_to_bcd(number_magnitude);

        if(show_number&&(char_row==number_row)) begin
            selected_color=number_color;
            case(char_col-number_start_col)
                0:if(number_value[15])selected_char="-";
                1:if(number_magnitude>=10000)selected_char=digit_char(number_bcd[19:16]);
                2:if(number_magnitude>=1000)selected_char=digit_char(number_bcd[15:12]);
                3:if(number_magnitude>=100)selected_char=digit_char(number_bcd[11:8]);
                4:if(number_magnitude>=10)selected_char=digit_char(number_bcd[7:4]);
                5:selected_char=digit_char(number_bcd[3:0]);
            endcase
        end

        if(coordinate_mode) begin
            case(char_col)
                9:selected_char=(char_row==4)?"X":"Y";
                10:if(coordinate_negative)selected_char="-";
                11:selected_char=digit_char(number_bcd[7:4]);
                12:selected_char=digit_char(number_bcd[3:0]);
                13:selected_char=".";
                14:selected_char=digit_char(coordinate_fraction);
            endcase
        end

        selected_cell=(selected_char!=0);
        selected_glyph_row=glyph_row(selected_char,pixel_row);
        text_on=selected_cell&&(pixel_col<5)&&(pixel_row<7)&&
                selected_glyph_row[4-pixel_col];
        text_pixel_data=selected_color;
    end
endmodule
