`timescale 1ns / 1ps

// Hardware diagnostic only. Reuses the exact graph text glyphs and locations
// from graph_renderer.v, but feeds them directly to Oled_Display. This
// distinguishes a rendering-data error in graph_mode_integration/main mux
// from implementation-dependent text generation. SW0 selects DRAW instead of
// the COUNT title; SW1 selects the lower-left SAVE prompt.
module OLED_Text_Direct_Test(
    input  wire       CLOCK,
    input  wire [1:0] sw,
    output wire [7:0] JB
);
    wire oled_clk;
    wire [12:0] pixel_index;
    wire frame_begin, sending_pixels, sample_pixel;
    wire cs, sdin, sclk, d_cn, resn, vccen, pmoden;
    reg [1:0] startup_count = 2'd0;
    wire oled_reset = (startup_count != 2'd2);
    reg [6:0] render_x;
    reg [5:0] render_y;

    clock_hz clk_6_25(
        .HZ(32'd6250000), .CLOCK(CLOCK), .SLOW_CLOCK(oled_clk)
    );

    always @(posedge oled_clk) begin
        if (startup_count != 2'd2)
            startup_count <= startup_count + 1'b1;
    end

    Oled_Display #(.ClkFreq(6250000)) oled(
        .clk(oled_clk), .reset(oled_reset),
        .frame_begin(frame_begin), .sending_pixels(sending_pixels),
        .sample_pixel(sample_pixel), .pixel_index(pixel_index),
        .pixel_data(pixel_data),
        .cs(cs), .sdin(sdin), .sclk(sclk), .d_cn(d_cn),
        .resn(resn), .vccen(vccen), .pmoden(pmoden)
    );

    wire [6:0] screen_x = pixel_index % 13'd96;
    wire [5:0] screen_y = pixel_index / 13'd96;
    always @(posedge oled_clk) begin
        render_x <= screen_x;
        render_y <= screen_y;
    end

    function font_pixel;
        input [7:0] ch;
        input [6:0] x;
        input [5:0] y;
        input [6:0] left;
        input [5:0] top;
        reg [4:0] row_bits;
        begin
            font_pixel = 0;
            row_bits = glyph_row(ch, y-top);
            if (x >= left && x < left+5 && y >= top && y < top+7)
                font_pixel = row_bits[4-(x-left)];
        end
    endfunction

    function [4:0] glyph_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            case (ch)
                "C": case(row) 0:glyph_row=5'b01111;1:glyph_row=5'b10000;2:glyph_row=5'b10000;3:glyph_row=5'b10000;4:glyph_row=5'b10000;5:glyph_row=5'b10000;6:glyph_row=5'b01111;endcase
                "O": case(row) 0:glyph_row=5'b01110;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b10001;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "U": case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b10001;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "N": case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b11001;2:glyph_row=5'b10101;3:glyph_row=5'b10011;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b10001;endcase
                "T": case(row) 0:glyph_row=5'b11111;1:glyph_row=5'b00100;2:glyph_row=5'b00100;3:glyph_row=5'b00100;4:glyph_row=5'b00100;5:glyph_row=5'b00100;6:glyph_row=5'b00100;endcase
                "S": case(row) 0:glyph_row=5'b01111;1:glyph_row=5'b10000;2:glyph_row=5'b10000;3:glyph_row=5'b01110;4:glyph_row=5'b00001;5:glyph_row=5'b00001;6:glyph_row=5'b11110;endcase
                "A": case(row) 0:glyph_row=5'b01110;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b11111;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b10001;endcase
                "V": case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b10001;4:glyph_row=5'b10001;5:glyph_row=5'b01010;6:glyph_row=5'b00100;endcase
                "E": case(row) 0:glyph_row=5'b11111;1:glyph_row=5'b10000;2:glyph_row=5'b10000;3:glyph_row=5'b11110;4:glyph_row=5'b10000;5:glyph_row=5'b10000;6:glyph_row=5'b11111;endcase
                default: glyph_row=0;
            endcase
        end
    endfunction

    // Select the exact Graph text regions with board switches. The glyph
    // data intentionally matches graph_renderer.v.
    wire show_draw = sw[0];
    wire show_save = sw[1];
    reg text_pixel;

    always @* begin
        text_pixel = 0;
        if (!show_draw) begin
            text_pixel =
                font_pixel("C",render_x,render_y,2,2) ||
                font_pixel("O",render_x,render_y,8,2) ||
                font_pixel("U",render_x,render_y,14,2) ||
                font_pixel("N",render_x,render_y,20,2) ||
                font_pixel("T",render_x,render_y,26,2);
        end else if (!show_save) begin
            text_pixel =
                font_pixel("S",render_x,render_y,2,55) ||
                font_pixel("A",render_x,render_y,14,55) ||
                font_pixel("V",render_x,render_y,26,55) ||
                font_pixel("E",render_x,render_y,32,55);
        end else begin
            text_pixel =
                font_pixel("C",render_x,render_y,2,2) ||
                font_pixel("O",render_x,render_y,8,2) ||
                font_pixel("U",render_x,render_y,14,2) ||
                font_pixel("N",render_x,render_y,20,2) ||
                font_pixel("T",render_x,render_y,26,2) ||
                font_pixel("S",render_x,render_y,2,55) ||
                font_pixel("A",render_x,render_y,14,55) ||
                font_pixel("V",render_x,render_y,26,55) ||
                font_pixel("E",render_x,render_y,32,55);
        end
    end

    reg [15:0] pixel_data;
    always @(posedge oled_clk)
        pixel_data <= text_pixel ? 16'hFFE0 : 16'h0000;

endmodule
