`timescale 1ns / 1ps

// 96x64 RGB565 renderer: 100 MHz curve calculation, OLED-clock column read,
// then combinational overlays before the OLED falling-edge pixel sample.
module graph_renderer #(
    parameter INCLUDE_TEXT = 1
) (
    input  wire clk, pixel_clk,
    input  wire [12:0] pixel_index,
    input  wire [1:0]  graph_count,
    input  wire        graph1_type,
    input  wire        graph2_type,
    input  wire        cubic1, cubic2,
    input  wire signed [7:0] a1,
    input  wire signed [7:0] b1,
    input  wire signed [7:0] c1,
    input  wire signed [7:0] d1,
    input  wire signed [7:0] a2,
    input  wire signed [7:0] b2,
    input  wire signed [7:0] c2,
    input  wire signed [7:0] d2,
    input  wire signed [7:0] current_input,
    input  wire [2:0]  controller_state,
    input  wire        current_graph,
    input  wire        draw_enable,
    input  wire [2:0]  graph_status,
    input  wire        intersection_valid,
    input  wire signed [15:0] intersection_x_q4,
    input  wire signed [15:0] intersection_y_q4,
    input  wire intersection2_valid,
    input  wire signed [15:0] intersection2_x_q4,
    input  wire signed [15:0] intersection2_y_q4,
    input  wire [3:0]  scale_px_per_unit,
    input  wire [6:0]  origin_x,
    input  wire [5:0]  origin_y,
    input  wire        cursor_enable,
    input  wire signed [15:0] cursor_x_q4,
    input  wire signed [15:0] cursor_y_q4,
    output wire [6:0] screen_x,
    output wire [5:0] screen_y,
    output reg  [15:0] pixel_data
);

    localparam [2:0] SELECT_COUNT = 3'd0;
    localparam [2:0] SELECT_TYPE  = 3'd1;
    localparam [2:0] ENTER_A      = 3'd2;
    localparam [2:0] ENTER_B      = 3'd3;
    localparam [2:0] ENTER_C      = 3'd4;
    localparam [2:0] ENTER_D      = 3'd5;
    localparam [2:0] READY        = 3'd6;
    localparam [2:0] VIEW_GRAPH   = 3'd7;

    localparam [2:0] STATUS_OK   = 3'd0;
    localparam [2:0] STATUS_PAR  = 3'd1;
    localparam [2:0] STATUS_SAME = 3'd2;
    localparam [2:0] STATUS_OUT  = 3'd3;
    localparam [2:0] STATUS_ERR  = 3'd4;
    localparam [2:0] STATUS_NONE = 3'd5;

    localparam [15:0] BLACK  = 16'h0000;
    localparam [15:0] GRID   = 16'h2104;
    localparam [15:0] AXIS   = 16'h7BEF;
    localparam [15:0] GREEN  = 16'h07E0;
    localparam [15:0] ORANGE = 16'hFD20;
    localparam [15:0] WHITE  = 16'hFFFF;
    localparam [15:0] CYAN   = 16'h07FF;
    localparam [15:0] YELLOW = 16'hFFE0;
    localparam [15:0] RED    = 16'hF800;

    assign screen_x = pixel_index % 13'd96;
    assign screen_y = pixel_index / 13'd96;

    wire signed [4:0] graph_scale_signed =
        $signed({1'b0, scale_px_per_unit});
    wire cache_ready;
    wire [13:0] bounds1,bounds2;
    reg [5:0] curve_screen_y=0;
    // The RAM read and row belong to the same requested pixel. The OLED
    // changes pixel_index on falling edges and samples on a later falling
    // edge, leaving this rising-edge stage half a cycle to settle.
    always @(posedge pixel_clk) curve_screen_y<=screen_y;
    graph_curve_cache curve_cache(
        .clk(clk),.pixel_clk(pixel_clk),.enable(draw_enable),.screen_x(screen_x),
        .origin_x(origin_x),.origin_y(origin_y),.scale(scale_px_per_unit),
        .graph1_type(graph1_type),.graph2_type(graph2_type),
        .cubic1(cubic1),.cubic2(cubic2),
        .a1(a1),.b1(b1),.c1(c1),.d1(d1),
        .a2(a2),.b2(b2),.c2(c2),.d2(d2),
        .ready(cache_ready),.bounds1(bounds1),.bounds2(bounds2)
    );
    wire signed [20:0] intersection_x_scaled =
        $signed(intersection_x_q4) * graph_scale_signed;
    wire signed [20:0] intersection_y_scaled =
        $signed(intersection_y_q4) * graph_scale_signed;
    wire signed [20:0] intersection2_x_scaled =
        $signed(intersection2_x_q4) * graph_scale_signed;
    wire signed [20:0] intersection2_y_scaled =
        $signed(intersection2_y_q4) * graph_scale_signed;
    wire signed [20:0] cursor_x_scaled =
        $signed(cursor_x_q4) * graph_scale_signed;
    wire signed [20:0] cursor_y_scaled =
        $signed(cursor_y_q4) * graph_scale_signed;

    function [4:0] glyph_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            glyph_row = 5'b00000;
            case (ch)
                "A": case(row) 0:glyph_row=5'b01110;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b11111;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b10001;endcase
                "B": case(row) 0:glyph_row=5'b11110;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b11110;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b11110;endcase
                "C": case(row) 0:glyph_row=5'b01111;1:glyph_row=5'b10000;2:glyph_row=5'b10000;3:glyph_row=5'b10000;4:glyph_row=5'b10000;5:glyph_row=5'b10000;6:glyph_row=5'b01111;endcase
                "D": case(row) 0:glyph_row=5'b11110;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b10001;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b11110;endcase
                "E": case(row) 0:glyph_row=5'b11111;1:glyph_row=5'b10000;2:glyph_row=5'b10000;3:glyph_row=5'b11110;4:glyph_row=5'b10000;5:glyph_row=5'b10000;6:glyph_row=5'b11111;endcase
                "K": case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b10010;2:glyph_row=5'b10100;3:glyph_row=5'b11000;4:glyph_row=5'b10100;5:glyph_row=5'b10010;6:glyph_row=5'b10001;endcase
                "I": case(row) 0:glyph_row=5'b11111;1:glyph_row=5'b00100;2:glyph_row=5'b00100;3:glyph_row=5'b00100;4:glyph_row=5'b00100;5:glyph_row=5'b00100;6:glyph_row=5'b11111;endcase
                "L": case(row) 0:glyph_row=5'b10000;1:glyph_row=5'b10000;2:glyph_row=5'b10000;3:glyph_row=5'b10000;4:glyph_row=5'b10000;5:glyph_row=5'b10000;6:glyph_row=5'b11111;endcase
                "M": case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b11011;2:glyph_row=5'b10101;3:glyph_row=5'b10101;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b10001;endcase
                "N": case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b11001;2:glyph_row=5'b11001;3:glyph_row=5'b10101;4:glyph_row=5'b10011;5:glyph_row=5'b10011;6:glyph_row=5'b10001;endcase
                "O": case(row) 0:glyph_row=5'b01110;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b10001;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "P": case(row) 0:glyph_row=5'b11110;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b11110;4:glyph_row=5'b10000;5:glyph_row=5'b10000;6:glyph_row=5'b10000;endcase
                "Q": case(row) 0:glyph_row=5'b01110;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b10001;4:glyph_row=5'b10101;5:glyph_row=5'b10010;6:glyph_row=5'b01101;endcase
                "R": case(row) 0:glyph_row=5'b11110;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b11110;4:glyph_row=5'b10100;5:glyph_row=5'b10010;6:glyph_row=5'b10001;endcase
                "S": case(row) 0:glyph_row=5'b01111;1:glyph_row=5'b10000;2:glyph_row=5'b10000;3:glyph_row=5'b01110;4:glyph_row=5'b00001;5:glyph_row=5'b00001;6:glyph_row=5'b11110;endcase
                "T": case(row) 0:glyph_row=5'b11111;1:glyph_row=5'b00100;2:glyph_row=5'b00100;3:glyph_row=5'b00100;4:glyph_row=5'b00100;5:glyph_row=5'b00100;6:glyph_row=5'b00100;endcase
                "U": case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b10001;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "V": case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b10001;4:glyph_row=5'b10001;5:glyph_row=5'b01010;6:glyph_row=5'b00100;endcase
                "W": case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b10101;4:glyph_row=5'b10101;5:glyph_row=5'b11011;6:glyph_row=5'b10001;endcase
                "X": case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b10001;2:glyph_row=5'b01010;3:glyph_row=5'b00100;4:glyph_row=5'b01010;5:glyph_row=5'b10001;6:glyph_row=5'b10001;endcase
                "Y": case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b10001;2:glyph_row=5'b01010;3:glyph_row=5'b00100;4:glyph_row=5'b00100;5:glyph_row=5'b00100;6:glyph_row=5'b00100;endcase
                "0": case(row) 0:glyph_row=5'b01110;1:glyph_row=5'b10001;2:glyph_row=5'b10011;3:glyph_row=5'b10101;4:glyph_row=5'b11001;5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "1": case(row) 0:glyph_row=5'b00100;1:glyph_row=5'b01100;2:glyph_row=5'b00100;3:glyph_row=5'b00100;4:glyph_row=5'b00100;5:glyph_row=5'b00100;6:glyph_row=5'b01110;endcase
                "2": case(row) 0:glyph_row=5'b01110;1:glyph_row=5'b10001;2:glyph_row=5'b00001;3:glyph_row=5'b00010;4:glyph_row=5'b00100;5:glyph_row=5'b01000;6:glyph_row=5'b11111;endcase
                "3": case(row) 0:glyph_row=5'b11110;1:glyph_row=5'b00001;2:glyph_row=5'b00001;3:glyph_row=5'b01110;4:glyph_row=5'b00001;5:glyph_row=5'b00001;6:glyph_row=5'b11110;endcase
                "4": case(row) 0:glyph_row=5'b00010;1:glyph_row=5'b00110;2:glyph_row=5'b01010;3:glyph_row=5'b10010;4:glyph_row=5'b11111;5:glyph_row=5'b00010;6:glyph_row=5'b00010;endcase
                "5": case(row) 0:glyph_row=5'b11111;1:glyph_row=5'b10000;2:glyph_row=5'b10000;3:glyph_row=5'b11110;4:glyph_row=5'b00001;5:glyph_row=5'b00001;6:glyph_row=5'b11110;endcase
                "6": case(row) 0:glyph_row=5'b01110;1:glyph_row=5'b10000;2:glyph_row=5'b10000;3:glyph_row=5'b11110;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "7": case(row) 0:glyph_row=5'b11111;1:glyph_row=5'b00001;2:glyph_row=5'b00010;3:glyph_row=5'b00100;4:glyph_row=5'b01000;5:glyph_row=5'b01000;6:glyph_row=5'b01000;endcase
                "8": case(row) 0:glyph_row=5'b01110;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b01110;4:glyph_row=5'b10001;5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "9": case(row) 0:glyph_row=5'b01110;1:glyph_row=5'b10001;2:glyph_row=5'b10001;3:glyph_row=5'b01111;4:glyph_row=5'b00001;5:glyph_row=5'b00001;6:glyph_row=5'b01110;endcase
                "-": case(row) 3:glyph_row=5'b01110; default:glyph_row=5'b00000; endcase
                ".": case(row) 6:glyph_row=5'b00100; default:glyph_row=5'b00000; endcase
                default: glyph_row=5'b00000;
            endcase
        end
    endfunction

    function [7:0] digit_character;
        input [3:0] digit;
        begin
            case (digit)
                0:digit_character="0"; 1:digit_character="1"; 2:digit_character="2";
                3:digit_character="3"; 4:digit_character="4"; 5:digit_character="5";
                6:digit_character="6"; 7:digit_character="7"; 8:digit_character="8";
                default:digit_character="9";
            endcase
        end
    endfunction

    // Keep decimal formatting eight bits wide. Signed integer / and % here
    // put a long chain of 32-bit arithmetic in the OLED pixel path.
    function [11:0] decimal_digits;
        input [7:0] magnitude;
        reg [7:0] remainder;
        reg [3:0] hundreds, tens;
        begin
            if (magnitude >= 8'd200) begin
                hundreds=2; remainder=magnitude-8'd200;
            end else if (magnitude >= 8'd100) begin
                hundreds=1; remainder=magnitude-8'd100;
            end else begin
                hundreds=0; remainder=magnitude;
            end
            if      (remainder >= 8'd90) begin tens=9; remainder=remainder-8'd90; end
            else if (remainder >= 8'd80) begin tens=8; remainder=remainder-8'd80; end
            else if (remainder >= 8'd70) begin tens=7; remainder=remainder-8'd70; end
            else if (remainder >= 8'd60) begin tens=6; remainder=remainder-8'd60; end
            else if (remainder >= 8'd50) begin tens=5; remainder=remainder-8'd50; end
            else if (remainder >= 8'd40) begin tens=4; remainder=remainder-8'd40; end
            else if (remainder >= 8'd30) begin tens=3; remainder=remainder-8'd30; end
            else if (remainder >= 8'd20) begin tens=2; remainder=remainder-8'd20; end
            else if (remainder >= 8'd10) begin tens=1; remainder=remainder-8'd10; end
            else tens=0;
            decimal_digits={hundreds,tens,remainder[3:0]};
        end
    endfunction

    // Unsigned magnitudes retain abs(-128) and abs(-32768) without overflow.
    wire [7:0] input_magnitude = current_input[7] ?
        (~current_input + 8'd1) : current_input;
    wire [11:0] input_digits = decimal_digits(input_magnitude);
    wire [15:0] cursor_abs_x_q4 = cursor_x_q4[15] ?
        (~cursor_x_q4 + 16'd1) : cursor_x_q4;
    wire [15:0] cursor_abs_y_q4 = cursor_y_q4[15] ?
        (~cursor_y_q4 + 16'd1) : cursor_y_q4;
    wire [7:0] cursor_x_integer = (cursor_abs_x_q4[15:4] > 12'd99) ?
        8'd99 : cursor_abs_x_q4[11:4];
    wire [7:0] cursor_y_integer = (cursor_abs_y_q4[15:4] > 12'd99) ?
        8'd99 : cursor_abs_y_q4[11:4];
    wire [11:0] cursor_x_digits = decimal_digits(cursor_x_integer);
    wire [11:0] cursor_y_digits = decimal_digits(cursor_y_integer);
    wire [3:0] cursor_x_fraction = (cursor_abs_x_q4[3:0] >= 4'd8) ? 4'd5 : 4'd0;
    wire [3:0] cursor_y_fraction = (cursor_abs_y_q4[3:0] >= 4'd8) ? 4'd5 : 4'd0;

    function font_pixel;
        input [7:0] ch;
        input integer px_in;
        input integer py_in;
        input integer left;
        input integer top;
        integer column;
        integer row_number;
        reg [4:0] row_bits;
        begin
            font_pixel = 1'b0;
            column = px_in - left;
            row_number = py_in - top;
            if ((column >= 0) && (column < 5) &&
                (row_number >= 0) && (row_number < 7)) begin
                row_bits = glyph_row(ch, row_number[2:0]);
                font_pixel = row_bits[4-column];
            end
        end
    endfunction

    integer px;
    integer py;
    integer ox;
    integer oy;
    integer scale;
    integer dx;
    integer dy;
    integer abs_dx;
    integer abs_dy;
    integer grid_mask;
    integer marker_x;
    integer marker_y;
    integer marker2_x;
    integer marker2_y;
    integer cursor_x;
    integer cursor_y;
    reg grid_pixel;
    reg axis_pixel;
    reg graph1_pixel;
    reg graph2_pixel;
    reg marker_pixel;
    reg cursor_pixel;
    reg title_pixel;
    reg action_pixel;
    reg status_pixel;
    reg coordinate_pixel;
    reg input_pixel;
    reg legend1_pixel;
    reg legend2_pixel;

    always @* begin
        px = screen_x;
        py = screen_y;
        ox = origin_x;
        oy = origin_y;
        scale = (scale_px_per_unit == 0) ? 1 : scale_px_per_unit;
        dx = px - ox;
        dy = oy - py;

        abs_dx = dx;
        abs_dy = dy;
        if (abs_dx < 0) abs_dx = -abs_dx;
        if (abs_dy < 0) abs_dy = -abs_dy;
        // A two-pixel grid at zoom-out=1 obscured almost the whole image.
        grid_mask = ((scale < 4) ? 8 : scale*2)-1;
        grid_pixel = draw_enable &&
                     (((abs_dx & grid_mask) == 0) ||
                      ((abs_dy & grid_mask) == 0));
        axis_pixel = draw_enable && ((px == ox) || (py == oy));
        // Join adjacent x-column samples.  This keeps steep lines continuous
        // without turning them into the wide bands produced by slope-sized
        // vertical tolerances.
        graph1_pixel = draw_enable && cache_ready && bounds1[13:7]!=7'd127 &&
                       (({1'b0,curve_screen_y}+1) >= bounds1[13:7]) &&
                       (curve_screen_y <= (bounds1[6:0]+1));
        graph2_pixel = draw_enable && cache_ready && (graph_count == 2) &&
                       bounds2[13:7]!=7'd127 &&
                       (({1'b0,curve_screen_y}+1) >= bounds2[13:7]) &&
                       (curve_screen_y <= (bounds2[6:0]+1));

        marker_x = ox + (intersection_x_scaled >>> 4);
        marker_y = oy - (intersection_y_scaled >>> 4);
        marker_pixel = draw_enable && intersection_valid &&
                       (graph_status == STATUS_OK) &&
                       ((((px == marker_x) || (py == marker_y)) &&
                         (px-marker_x <= 3) && (px-marker_x >= -3) &&
                         (py-marker_y <= 3) && (py-marker_y >= -3)));
        marker2_x = ox + (intersection2_x_scaled >>> 4);
        marker2_y = oy - (intersection2_y_scaled >>> 4);
        marker_pixel = marker_pixel ||
                       (draw_enable && intersection2_valid &&
                        (graph_status == STATUS_OK) &&
                        ((((px == marker2_x) || (py == marker2_y)) &&
                          (px-marker2_x <= 3) && (px-marker2_x >= -3) &&
                          (py-marker2_y <= 3) && (py-marker2_y >= -3))));

        cursor_x = ox + (cursor_x_scaled >>> 4);
        cursor_y = oy - (cursor_y_scaled >>> 4);
        cursor_pixel = draw_enable && cursor_enable &&
                       (((px == cursor_x) && (py-cursor_y <= 4) && (py-cursor_y >= -4)) ||
                        ((py == cursor_y) && (px-cursor_x <= 4) && (px-cursor_x >= -4)));

        coordinate_pixel = 1'b0;
        if (INCLUDE_TEXT && draw_enable && cursor_enable) begin
            coordinate_pixel =
                font_pixel("X",px,py,52,38) ||
                ((cursor_x_q4 < 0) && font_pixel("-",px,py,58,38)) ||
                font_pixel(digit_character(cursor_x_digits[7:4]),px,py,64,38) ||
                font_pixel(digit_character(cursor_x_digits[3:0]),px,py,70,38) ||
                font_pixel(".",px,py,76,38) ||
                font_pixel(digit_character(cursor_x_fraction),px,py,82,38) ||
                font_pixel("Y",px,py,52,46) ||
                ((cursor_y_q4 < 0) && font_pixel("-",px,py,58,46)) ||
                font_pixel(digit_character(cursor_y_digits[7:4]),px,py,64,46) ||
                font_pixel(digit_character(cursor_y_digits[3:0]),px,py,70,46) ||
                font_pixel(".",px,py,76,46) ||
                font_pixel(digit_character(cursor_y_fraction),px,py,82,46);
        end

        input_pixel = 1'b0;
        if (INCLUDE_TEXT && !draw_enable) begin
            if (controller_state == SELECT_COUNT)
                input_pixel = font_pixel(current_input[0]?"2":"1",px,py,42,20);
            else if (controller_state == SELECT_TYPE) begin
                if (current_input[1])
                    input_pixel=font_pixel("C",px,py,34,20)||font_pixel("U",px,py,40,20)||
                                font_pixel("B",px,py,46,20)||font_pixel("I",px,py,52,20)||
                                font_pixel("C",px,py,58,20);
                else if (current_input[0])
                    input_pixel=font_pixel("Q",px,py,34,20)||font_pixel("U",px,py,40,20)||
                                font_pixel("A",px,py,46,20)||font_pixel("D",px,py,52,20);
                else
                    input_pixel=font_pixel("L",px,py,37,20)||font_pixel("I",px,py,43,20)||font_pixel("N",px,py,49,20);
            end else if ((controller_state==ENTER_A)||(controller_state==ENTER_B)||
                         (controller_state==ENTER_C)||(controller_state==ENTER_D)) begin
                input_pixel=((current_input<0)&&font_pixel("-",px,py,34,20))||
                            ((input_magnitude>=8'd100)&&font_pixel(digit_character(input_digits[11:8]),px,py,40,20))||
                            ((input_magnitude>=8'd10)&&font_pixel(digit_character(input_digits[7:4]),px,py,46,20))||
                            font_pixel(digit_character(input_digits[3:0]),px,py,52,20);
            end
        end

        title_pixel = 1'b0;
        if (INCLUDE_TEXT && (controller_state == SELECT_COUNT)) begin
            title_pixel = font_pixel("C",px,py,2,2)||font_pixel("O",px,py,8,2)||
                          font_pixel("U",px,py,14,2)||font_pixel("N",px,py,20,2)||font_pixel("T",px,py,26,2);
        end else if (INCLUDE_TEXT && (controller_state == SELECT_TYPE)) begin
            title_pixel = font_pixel("T",px,py,2,2)||font_pixel("Y",px,py,8,2)||
                          font_pixel("P",px,py,14,2)||font_pixel("E",px,py,20,2)||
                          font_pixel(current_graph ? "2":"1",px,py,26,2);
        end else if (INCLUDE_TEXT && (controller_state == ENTER_A)) begin
            title_pixel = font_pixel("A",px,py,2,2)||font_pixel(current_graph ? "2":"1",px,py,8,2);
        end else if (INCLUDE_TEXT && (controller_state == ENTER_B)) begin
            title_pixel = font_pixel("B",px,py,2,2)||font_pixel(current_graph ? "2":"1",px,py,8,2);
        end else if (INCLUDE_TEXT && (controller_state == ENTER_C)) begin
            title_pixel = font_pixel("C",px,py,2,2)||font_pixel(current_graph ? "2":"1",px,py,8,2);
        end else if (INCLUDE_TEXT && (controller_state == ENTER_D)) begin
            title_pixel = font_pixel("D",px,py,2,2)||font_pixel(current_graph ? "2":"1",px,py,8,2);
        end else if (INCLUDE_TEXT && (controller_state == READY)) begin
            title_pixel = font_pixel("R",px,py,2,2)||font_pixel("E",px,py,8,2)||font_pixel("A",px,py,14,2)||
                          font_pixel("D",px,py,20,2)||font_pixel("Y",px,py,26,2);
        end else if (INCLUDE_TEXT && (controller_state == VIEW_GRAPH)) begin
            title_pixel = font_pixel("D",px,py,2,2)||font_pixel("R",px,py,8,2)||
                          font_pixel("A",px,py,14,2)||font_pixel("W",px,py,20,2);
        end

        action_pixel = 1'b0;
        if (INCLUDE_TEXT && (controller_state <= ENTER_D)) begin
            action_pixel = font_pixel("C",px,py,2,55)||font_pixel("S",px,py,14,55)||
                           font_pixel("A",px,py,20,55)||font_pixel("V",px,py,26,55)||font_pixel("E",px,py,32,55);
        end else if (INCLUDE_TEXT && (controller_state == READY)) begin
            action_pixel = font_pixel("1",px,py,2,55)||font_pixel("4",px,py,8,55)||
                           font_pixel("D",px,py,20,55)||font_pixel("R",px,py,26,55)||
                           font_pixel("A",px,py,32,55)||font_pixel("W",px,py,38,55);
        end else if (INCLUDE_TEXT) begin
            action_pixel = font_pixel("1",px,py,2,55)||font_pixel("5",px,py,8,55)||
                           font_pixel("B",px,py,20,55)||font_pixel("A",px,py,26,55)||
                           font_pixel("C",px,py,32,55)||font_pixel("K",px,py,38,55);
        end

        status_pixel = 1'b0;
        if (INCLUDE_TEXT) begin
            case (graph_status)
                STATUS_PAR: status_pixel=font_pixel("P",px,py,72,2)||font_pixel("A",px,py,78,2)||font_pixel("R",px,py,84,2);
                STATUS_SAME:status_pixel=font_pixel("S",px,py,66,2)||font_pixel("A",px,py,72,2)||font_pixel("M",px,py,78,2)||font_pixel("E",px,py,84,2);
                STATUS_OUT: status_pixel=font_pixel("O",px,py,72,2)||font_pixel("U",px,py,78,2)||font_pixel("T",px,py,84,2);
                STATUS_ERR: status_pixel=font_pixel("E",px,py,72,2)||font_pixel("R",px,py,78,2)||font_pixel("R",px,py,84,2);
                STATUS_NONE:status_pixel=font_pixel("N",px,py,72,2)||font_pixel("O",px,py,78,2);
                default: status_pixel=1'b0;
            endcase
        end

        legend1_pixel=INCLUDE_TEXT&&draw_enable&&font_pixel("1",px,py,30,2);
        legend2_pixel=INCLUDE_TEXT&&draw_enable&&(graph_count==2)&&font_pixel("2",px,py,38,2);

        pixel_data = BLACK;
        if (grid_pixel) pixel_data = GRID;
        if (axis_pixel) pixel_data = AXIS;
        if (graph2_pixel) pixel_data = ORANGE;
        if (graph1_pixel) pixel_data = GREEN;
        if (cursor_pixel) pixel_data = CYAN;
        if (marker_pixel) pixel_data = WHITE;
        if (coordinate_pixel) pixel_data = CYAN;
        if (input_pixel) pixel_data = WHITE;
        if (title_pixel || action_pixel) pixel_data = YELLOW;
        if (legend1_pixel) pixel_data = GREEN;
        if (legend2_pixel) pixel_data = ORANGE;
        if (draw_enable && status_pixel) pixel_data = RED;
    end
endmodule
