`timescale 1ns / 1ps

// Main menu for the single integrated bitstream.
module menu_renderer(
    input  wire [12:0] pixel_index,
    output reg  [15:0] pixel_data
);
    wire [6:0] x = pixel_index % 13'd96;
    wire [5:0] y = pixel_index / 13'd96;

    function [4:0] glyph_row;
        input [7:0] ch; input [2:0] row;
        begin
            glyph_row=0;
            case(ch)
                "A":case(row)0:glyph_row=14;1:glyph_row=17;2:glyph_row=17;3:glyph_row=31;4:glyph_row=17;5:glyph_row=17;6:glyph_row=17;endcase
                "C":case(row)0:glyph_row=15;1:glyph_row=16;2:glyph_row=16;3:glyph_row=16;4:glyph_row=16;5:glyph_row=16;6:glyph_row=15;endcase
                "D":case(row)0:glyph_row=30;1:glyph_row=17;2:glyph_row=17;3:glyph_row=17;4:glyph_row=17;5:glyph_row=17;6:glyph_row=30;endcase
                "F":case(row)0:glyph_row=31;1:glyph_row=16;2:glyph_row=16;3:glyph_row=30;4:glyph_row=16;5:glyph_row=16;6:glyph_row=16;endcase
                "G":case(row)0:glyph_row=14;1:glyph_row=17;2:glyph_row=16;3:glyph_row=23;4:glyph_row=17;5:glyph_row=17;6:glyph_row=14;endcase
                "H":case(row)0:glyph_row=17;1:glyph_row=17;2:glyph_row=17;3:glyph_row=31;4:glyph_row=17;5:glyph_row=17;6:glyph_row=17;endcase
                "L":case(row)0:glyph_row=16;1:glyph_row=16;2:glyph_row=16;3:glyph_row=16;4:glyph_row=16;5:glyph_row=16;6:glyph_row=31;endcase
                "P":case(row)0:glyph_row=30;1:glyph_row=17;2:glyph_row=17;3:glyph_row=30;4:glyph_row=16;5:glyph_row=16;6:glyph_row=16;endcase
                "R":case(row)0:glyph_row=30;1:glyph_row=17;2:glyph_row=17;3:glyph_row=30;4:glyph_row=20;5:glyph_row=18;6:glyph_row=17;endcase
            endcase
        end
    endfunction

    function font_pixel;
        input [7:0] ch; input integer left,top;
        integer col,row; reg [4:0] bits;
        begin
            col=x-left; row=y-top; font_pixel=0;
            if(col>=0&&col<5&&row>=0&&row<7) begin
                bits=glyph_row(ch,row[2:0]); font_pixel=bits[4-col];
            end
        end
    endfunction

    reg title_pixel,calc_pixel,graph_pixel;
    always @* begin
        title_pixel=font_pixel("F",21,7)||font_pixel("P",27,7)||
                    font_pixel("G",33,7)||font_pixel("A",39,7)||
                    font_pixel("C",51,7)||font_pixel("A",57,7)||
                    font_pixel("L",63,7)||font_pixel("C",69,7);
        calc_pixel=font_pixel("L",20,27)||font_pixel("C",38,27)||
                   font_pixel("A",44,27)||font_pixel("L",50,27)||font_pixel("C",56,27);
        graph_pixel=font_pixel("D",20,45)||font_pixel("G",38,45)||
                    font_pixel("R",44,45)||font_pixel("A",50,45)||
                    font_pixel("P",56,45)||font_pixel("H",62,45);

        pixel_data=16'h0000;
        if((x==0)||(x==95)||(y==0)||(y==63)) pixel_data=16'h001F;
        if(((x==12||x==83)&&(y>=22&&y<=38))||((y==22||y==38)&&(x>=12&&x<=83))) pixel_data=16'h03EF;
        if(((x==12||x==83)&&(y>=40&&y<=56))||((y==40||y==56)&&(x>=12&&x<=83))) pixel_data=16'h780F;
        if(title_pixel) pixel_data=16'h07FF;
        if(calc_pixel) pixel_data=16'h07E0;
        if(graph_pixel) pixel_data=16'hFD20;
    end
endmodule
