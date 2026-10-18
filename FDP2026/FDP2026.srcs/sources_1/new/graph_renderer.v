`timescale 1ns / 1ps

// Combinational 96x64 RGB565 graph renderer.
module graph_renderer (
    input  wire [12:0] pixel_index,
    input  wire [1:0]  graph_count,
    input  wire        graph1_type,
    input  wire        graph2_type,
    input  wire signed [7:0] a1,
    input  wire signed [7:0] b1,
    input  wire signed [7:0] c1,
    input  wire signed [7:0] a2,
    input  wire signed [7:0] b2,
    input  wire signed [7:0] c2,
    input  wire signed [7:0] current_input,
    input  wire [2:0]  controller_state,
    input  wire        current_graph,
    input  wire        draw_enable,
    input  wire [2:0]  graph_status,
    input  wire        intersection_valid,
    input  wire signed [15:0] intersection_x_q4,
    input  wire signed [15:0] intersection_y_q4,
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
    localparam [2:0] READY        = 3'd6;
    localparam [2:0] VIEW_GRAPH   = 3'd7;

    localparam [2:0] STATUS_OK   = 3'd0;
    localparam [2:0] STATUS_PAR  = 3'd1;
    localparam [2:0] STATUS_SAME = 3'd2;
    localparam [2:0] STATUS_OUT  = 3'd3;
    localparam [2:0] STATUS_ERR  = 3'd4;

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
        input integer digit;
        begin
            case (digit)
                0:digit_character="0"; 1:digit_character="1"; 2:digit_character="2";
                3:digit_character="3"; 4:digit_character="4"; 5:digit_character="5";
                6:digit_character="6"; 7:digit_character="7"; 8:digit_character="8";
                default:digit_character="9";
            endcase
        end
    endfunction

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
    integer scale_shift;
    integer dx;
    integer dy;
    integer curve1_y;
    integer curve2_y;
    integer curve1_y_previous;
    integer curve2_y_previous;
    integer curve1_screen;
    integer curve2_screen;
    integer curve1_screen_previous;
    integer curve2_screen_previous;
    integer curve1_min;
    integer curve1_max;
    integer curve2_min;
    integer curve2_max;
    integer abs_dx;
    integer abs_dy;
    integer grid_mask;
    integer marker_x;
    integer marker_y;
    integer cursor_x;
    integer cursor_y;
    integer cursor_abs_x_q4;
    integer cursor_abs_y_q4;
    integer cursor_x_integer;
    integer cursor_y_integer;
    integer cursor_x_fraction;
    integer cursor_y_fraction;
    integer input_abs;
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
        case(scale)
            2: scale_shift=1;
            4: scale_shift=2;
            8: scale_shift=3;
            default: scale_shift=0;
        endcase
        dx = px - ox;
        dy = oy - py;

        curve1_y = ($signed(b1) * dx) + ($signed(c1) * scale);
        curve2_y = ($signed(b2) * dx) + ($signed(c2) * scale);
        curve1_y_previous = ($signed(b1) * (dx-1)) + ($signed(c1) * scale);
        curve2_y_previous = ($signed(b2) * (dx-1)) + ($signed(c2) * scale);
        if (graph1_type) curve1_y = curve1_y + (($signed(a1) * dx * dx) >>> scale_shift);
        if (graph2_type) curve2_y = curve2_y + (($signed(a2) * dx * dx) >>> scale_shift);
        if (graph1_type) curve1_y_previous = curve1_y_previous +
            (($signed(a1) * (dx-1) * (dx-1)) >>> scale_shift);
        if (graph2_type) curve2_y_previous = curve2_y_previous +
            (($signed(a2) * (dx-1) * (dx-1)) >>> scale_shift);
        curve1_screen = oy-curve1_y;
        curve2_screen = oy-curve2_y;
        curve1_screen_previous = oy-curve1_y_previous;
        curve2_screen_previous = oy-curve2_y_previous;
        curve1_min = (curve1_screen<curve1_screen_previous)?curve1_screen:curve1_screen_previous;
        curve1_max = (curve1_screen>curve1_screen_previous)?curve1_screen:curve1_screen_previous;
        curve2_min = (curve2_screen<curve2_screen_previous)?curve2_screen:curve2_screen_previous;
        curve2_max = (curve2_screen>curve2_screen_previous)?curve2_screen:curve2_screen_previous;

        abs_dx = dx;
        abs_dy = dy;
        if (abs_dx < 0) abs_dx = -abs_dx;
        if (abs_dy < 0) abs_dy = -abs_dy;
        grid_mask = (scale*2)-1;
        grid_pixel = draw_enable &&
                     (((abs_dx & grid_mask) == 0) ||
                      ((abs_dy & grid_mask) == 0));
        axis_pixel = draw_enable && ((px == ox) || (py == oy));
        // Join adjacent x-column samples.  This keeps steep lines continuous
        // without turning them into the wide bands produced by slope-sized
        // vertical tolerances.
        graph1_pixel = draw_enable && (py >= curve1_min-1) && (py <= curve1_max+1);
        graph2_pixel = draw_enable && (graph_count == 2) &&
                       (py >= curve2_min-1) && (py <= curve2_max+1);

        marker_x = ox + (($signed(intersection_x_q4) * scale) >>> 4);
        marker_y = oy - (($signed(intersection_y_q4) * scale) >>> 4);
        marker_pixel = draw_enable && intersection_valid &&
                       (graph_status == STATUS_OK) &&
                       ((((px == marker_x) || (py == marker_y)) &&
                         (px-marker_x <= 3) && (px-marker_x >= -3) &&
                         (py-marker_y <= 3) && (py-marker_y >= -3)));

        cursor_x = ox + (($signed(cursor_x_q4) * scale) >>> 4);
        cursor_y = oy - (($signed(cursor_y_q4) * scale) >>> 4);
        cursor_pixel = draw_enable && cursor_enable &&
                       (((px == cursor_x) && (py-cursor_y <= 4) && (py-cursor_y >= -4)) ||
                        ((py == cursor_y) && (px-cursor_x <= 4) && (px-cursor_x >= -4)));

        cursor_abs_x_q4 = (cursor_x_q4 < 0) ? -cursor_x_q4 : cursor_x_q4;
        cursor_abs_y_q4 = (cursor_y_q4 < 0) ? -cursor_y_q4 : cursor_y_q4;
        cursor_x_integer = (cursor_abs_x_q4 / 16) % 100;
        cursor_y_integer = (cursor_abs_y_q4 / 16) % 100;
        cursor_x_fraction = ((cursor_abs_x_q4 % 16) >= 8) ? 5 : 0;
        cursor_y_fraction = ((cursor_abs_y_q4 % 16) >= 8) ? 5 : 0;
        coordinate_pixel = 1'b0;
        if (draw_enable && cursor_enable) begin
            coordinate_pixel =
                font_pixel("X",px,py,52,38) ||
                ((cursor_x_q4 < 0) && font_pixel("-",px,py,58,38)) ||
                font_pixel(digit_character(cursor_x_integer/10),px,py,64,38) ||
                font_pixel(digit_character(cursor_x_integer%10),px,py,70,38) ||
                font_pixel(".",px,py,76,38) ||
                font_pixel(digit_character(cursor_x_fraction),px,py,82,38) ||
                font_pixel("Y",px,py,52,46) ||
                ((cursor_y_q4 < 0) && font_pixel("-",px,py,58,46)) ||
                font_pixel(digit_character(cursor_y_integer/10),px,py,64,46) ||
                font_pixel(digit_character(cursor_y_integer%10),px,py,70,46) ||
                font_pixel(".",px,py,76,46) ||
                font_pixel(digit_character(cursor_y_fraction),px,py,82,46);
        end

        input_abs = (current_input < 0) ? -current_input : current_input;
        input_pixel = 1'b0;
        if (!draw_enable) begin
            if (controller_state == SELECT_COUNT)
                input_pixel = font_pixel(current_input[0]?"2":"1",px,py,42,20);
            else if (controller_state == SELECT_TYPE) begin
                if (current_input[0])
                    input_pixel=font_pixel("Q",px,py,34,20)||font_pixel("U",px,py,40,20)||
                                font_pixel("A",px,py,46,20)||font_pixel("D",px,py,52,20);
                else
                    input_pixel=font_pixel("L",px,py,37,20)||font_pixel("I",px,py,43,20)||font_pixel("N",px,py,49,20);
            end else if ((controller_state==ENTER_A)||(controller_state==ENTER_B)||(controller_state==ENTER_C)) begin
                input_pixel=((current_input<0)&&font_pixel("-",px,py,34,20))||
                            ((input_abs>=100)&&font_pixel(digit_character((input_abs/100)%10),px,py,40,20))||
                            ((input_abs>=10)&&font_pixel(digit_character((input_abs/10)%10),px,py,46,20))||
                            font_pixel(digit_character(input_abs%10),px,py,52,20);
            end
        end

        title_pixel = 1'b0;
        if (controller_state == SELECT_COUNT) begin
            title_pixel = font_pixel("C",px,py,2,2)||font_pixel("O",px,py,8,2)||
                          font_pixel("U",px,py,14,2)||font_pixel("N",px,py,20,2)||font_pixel("T",px,py,26,2);
        end else if (controller_state == SELECT_TYPE) begin
            title_pixel = font_pixel("T",px,py,2,2)||font_pixel("Y",px,py,8,2)||
                          font_pixel("P",px,py,14,2)||font_pixel("E",px,py,20,2)||
                          font_pixel(current_graph ? "2":"1",px,py,26,2);
        end else if (controller_state == ENTER_A) begin
            title_pixel = font_pixel("A",px,py,2,2)||font_pixel(current_graph ? "2":"1",px,py,8,2);
        end else if (controller_state == ENTER_B) begin
            title_pixel = font_pixel("B",px,py,2,2)||font_pixel(current_graph ? "2":"1",px,py,8,2);
        end else if (controller_state == ENTER_C) begin
            title_pixel = font_pixel("C",px,py,2,2)||font_pixel(current_graph ? "2":"1",px,py,8,2);
        end else if (controller_state == READY) begin
            title_pixel = font_pixel("R",px,py,2,2)||font_pixel("E",px,py,8,2)||font_pixel("A",px,py,14,2)||
                          font_pixel("D",px,py,20,2)||font_pixel("Y",px,py,26,2);
        end else if (controller_state == VIEW_GRAPH) begin
            title_pixel = font_pixel("D",px,py,2,2)||font_pixel("R",px,py,8,2)||
                          font_pixel("A",px,py,14,2)||font_pixel("W",px,py,20,2);
        end

        action_pixel = 1'b0;
        if (controller_state <= ENTER_C) begin
            action_pixel = font_pixel("C",px,py,2,55)||font_pixel("S",px,py,14,55)||
                           font_pixel("A",px,py,20,55)||font_pixel("V",px,py,26,55)||font_pixel("E",px,py,32,55);
        end else if (controller_state == READY) begin
            action_pixel = font_pixel("1",px,py,2,55)||font_pixel("4",px,py,8,55)||
                           font_pixel("D",px,py,20,55)||font_pixel("R",px,py,26,55)||
                           font_pixel("A",px,py,32,55)||font_pixel("W",px,py,38,55);
        end else begin
            action_pixel = font_pixel("1",px,py,2,55)||font_pixel("5",px,py,8,55)||
                           font_pixel("B",px,py,20,55)||font_pixel("A",px,py,26,55)||
                           font_pixel("C",px,py,32,55)||font_pixel("K",px,py,38,55);
        end

        status_pixel = 1'b0;
        case (graph_status)
            STATUS_PAR: status_pixel=font_pixel("P",px,py,72,2)||font_pixel("A",px,py,78,2)||font_pixel("R",px,py,84,2);
            STATUS_SAME:status_pixel=font_pixel("S",px,py,66,2)||font_pixel("A",px,py,72,2)||font_pixel("M",px,py,78,2)||font_pixel("E",px,py,84,2);
            STATUS_OUT: status_pixel=font_pixel("O",px,py,72,2)||font_pixel("U",px,py,78,2)||font_pixel("T",px,py,84,2);
            STATUS_ERR: status_pixel=font_pixel("E",px,py,72,2)||font_pixel("R",px,py,78,2)||font_pixel("R",px,py,84,2);
            default: status_pixel=1'b0;
        endcase

        legend1_pixel=draw_enable&&font_pixel("1",px,py,30,2);
        legend2_pixel=draw_enable&&(graph_count==2)&&font_pixel("2",px,py,38,2);

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
