`timescale 1ns / 1ps

// Graph-mode state machine and mathematics.
// Coefficients describe y = a*x^2 + b*x + c.  Linear graphs use a=0.
module graph_controller (
    input  wire clk,
    input  wire reset,
    input  wire btnC_pressed,
    input  wire btnU_pressed,
    input  wire btnD_pressed,
    input  wire btnL_pressed,
    input  wire btnR_pressed,
    input  wire sw0,
    input  wire sw12_cursor,
    input  wire sw13_zoom,
    input  wire sw14,
    input  wire signed [7:0] input_value,
    input  wire        mouse_zoom_in,
    input  wire        mouse_zoom_out,
    input  wire        mouse_recenter,
    input  wire        mouse_reset_view,
    input  wire [6:0]  mouse_screen_x,
    input  wire [5:0]  mouse_screen_y,

    output reg  [1:0] graph_count,
    output reg        graph1_type,
    output reg        graph2_type,
    output reg signed [7:0] a1,
    output reg signed [7:0] b1,
    output reg signed [7:0] c1,
    output reg signed [7:0] a2,
    output reg signed [7:0] b2,
    output reg signed [7:0] c2,
    output reg  [2:0] state,
    output reg        current_graph,
    output reg        ready,
    output reg        draw,

    output reg  [3:0] scale_px_per_unit,
    output reg  [6:0] origin_x,
    output reg  [5:0] origin_y,
    output reg signed [15:0] cursor_x_q4,
    output reg signed [15:0] cursor_y_q4,

    output reg  [2:0] graph_status,
    output reg        intersection_valid,
    output reg signed [15:0] intersection_x_q4,
    output reg signed [15:0] intersection_y_q4
);

    localparam [2:0] SELECT_COUNT = 3'd0;
    localparam [2:0] SELECT_TYPE  = 3'd1;
    localparam [2:0] ENTER_A      = 3'd2;
    localparam [2:0] ENTER_B      = 3'd3;
    localparam [2:0] ENTER_C      = 3'd4;
    localparam [2:0] NEXT_GRAPH   = 3'd5;
    localparam [2:0] READY        = 3'd6;
    localparam [2:0] VIEW_GRAPH   = 3'd7;

    localparam [2:0] STATUS_OK   = 3'd0;
    localparam [2:0] STATUS_PAR  = 3'd1;
    localparam [2:0] STATUS_SAME = 3'd2;
    localparam [2:0] STATUS_OUT  = 3'd3;
    localparam [2:0] STATUS_ERR  = 3'd4;

    localparam [6:0] DEFAULT_ORIGIN_X = 7'd48;
    localparam [5:0] DEFAULT_ORIGIN_Y = 6'd32;
    localparam [6:0] MIN_ORIGIN_X     = 7'd8;
    localparam [6:0] MAX_ORIGIN_X     = 7'd87;
    localparam [5:0] MIN_ORIGIN_Y     = 6'd8;
    localparam [5:0] MAX_ORIGIN_Y     = 6'd55;

    reg sw14_previous;
    wire sw14_rising = sw14 && !sw14_previous;
    wire signed [8:0] recenter_x = $signed({2'b00, origin_x}) + $signed(9'sd48) -
                                   $signed({3'b000, mouse_screen_x});
    wire signed [8:0] recenter_y = $signed({3'b000, origin_y}) + $signed(9'sd32) -
                                   $signed({2'b00, mouse_screen_y});

    // Keep the datapath at the widths required by the coefficient ranges.
    // Using Verilog `integer` here made Vivado build a 32-by-32 divider and
    // several 32-bit multipliers, even though the inputs are only eight bits.
    reg signed [8:0]  coefficient_difference;
    reg signed [8:0]  slope_difference;
    reg signed [12:0] numerator_q4;
    reg signed [12:0] x_calculated_q4;
    reg signed [20:0] y_calculated_q4;
    reg signed [25:0] intersection_screen_x;
    reg signed [25:0] intersection_screen_y;
    reg signed [4:0]  scale_integer;

    // Linear intersection calculation. Quadratic intersections are deliberately
    // not guessed: the renderer draws them, but no invalid marker is displayed.
    always @* begin
        graph_status = STATUS_OK;
        intersection_valid = 1'b0;
        intersection_x_q4 = 16'sd0;
        intersection_y_q4 = 16'sd0;
        coefficient_difference = 0;
        slope_difference = 0;
        numerator_q4 = 0;
        x_calculated_q4 = 0;
        y_calculated_q4 = 0;
        intersection_screen_x = 0;
        intersection_screen_y = 0;
        scale_integer = $signed({1'b0, scale_px_per_unit});

        if ((graph_count == 2) && !graph1_type && !graph2_type) begin
            coefficient_difference = $signed(c2) - $signed(c1);
            slope_difference = $signed(b1) - $signed(b2);

            if (slope_difference == 0) begin
                graph_status = (coefficient_difference == 0) ? STATUS_SAME : STATUS_PAR;
            end else begin
                numerator_q4 = {coefficient_difference, 4'b0000};
                x_calculated_q4 = numerator_q4 / slope_difference;
                y_calculated_q4 = ($signed(b1) * $signed(x_calculated_q4)) +
                                  ($signed(c1) * 6'sd16);

                if ((x_calculated_q4 < -32768) || (x_calculated_q4 > 32767) ||
                    (y_calculated_q4 < -32768) || (y_calculated_q4 > 32767)) begin
                    graph_status = STATUS_ERR;
                end else begin
                    intersection_x_q4 = {{3{x_calculated_q4[12]}}, x_calculated_q4};
                    intersection_y_q4 = y_calculated_q4[15:0];
                    intersection_screen_x = $signed({18'd0, origin_x}) +
                                            (($signed(x_calculated_q4) * scale_integer) >>> 4);
                    intersection_screen_y = $signed({19'd0, origin_y}) -
                                            (($signed(y_calculated_q4) * scale_integer) >>> 4);
                    if ((intersection_screen_x < 0) || (intersection_screen_x > 95) ||
                        (intersection_screen_y < 0) || (intersection_screen_y > 63)) begin
                        graph_status = STATUS_OUT;
                    end else begin
                        intersection_valid = 1'b1;
                    end
                end
            end
        end
    end

    always @(posedge clk) begin
        sw14_previous <= sw14;

        if (reset) begin
            state <= SELECT_COUNT;
            graph_count <= 2'd1;
            graph1_type <= 1'b0;
            graph2_type <= 1'b0;
            current_graph <= 1'b0;
            a1 <= 8'sd0; b1 <= 8'sd0; c1 <= 8'sd0;
            a2 <= 8'sd0; b2 <= 8'sd0; c2 <= 8'sd0;
            ready <= 1'b0;
            draw <= 1'b0;
            scale_px_per_unit <= 4'd4;
            origin_x <= DEFAULT_ORIGIN_X;
            origin_y <= DEFAULT_ORIGIN_Y;
            cursor_x_q4 <= 16'sd0;
            cursor_y_q4 <= 16'sd0;
            sw14_previous <= sw14;
        end else begin
            case (state)
                SELECT_COUNT: begin
                    ready <= 1'b0;
                    draw <= 1'b0;
                    if (btnC_pressed) begin
                        graph_count <= sw0 ? 2'd2 : 2'd1;
                        current_graph <= 1'b0;
                        state <= SELECT_TYPE;
                    end
                end

                SELECT_TYPE: begin
                    if (btnC_pressed) begin
                        if (!current_graph) graph1_type <= sw0;
                        else                graph2_type <= sw0;

                        if (sw0) begin
                            state <= ENTER_A;
                        end else begin
                            if (!current_graph) a1 <= 8'sd0;
                            else                a2 <= 8'sd0;
                            state <= ENTER_B;
                        end
                    end
                end

                ENTER_A: if (btnC_pressed) begin
                    if (!current_graph) a1 <= input_value;
                    else                a2 <= input_value;
                    state <= ENTER_B;
                end

                ENTER_B: if (btnC_pressed) begin
                    if (!current_graph) b1 <= input_value;
                    else                b2 <= input_value;
                    state <= ENTER_C;
                end

                ENTER_C: if (btnC_pressed) begin
                    if (!current_graph) c1 <= input_value;
                    else                c2 <= input_value;
                    state <= NEXT_GRAPH;
                end

                NEXT_GRAPH: begin
                    if ((graph_count == 2) && !current_graph) begin
                        current_graph <= 1'b1;
                        state <= SELECT_TYPE;
                    end else begin
                        ready <= 1'b1;
                        state <= READY;
                    end
                end

                READY: begin
                    if (sw14_rising) begin
                        draw <= 1'b1;
                        state <= VIEW_GRAPH;
                    end
                end

                VIEW_GRAPH: begin
                    if (mouse_reset_view) begin
                        scale_px_per_unit <= 4'd4;
                        origin_x <= DEFAULT_ORIGIN_X;
                        origin_y <= DEFAULT_ORIGIN_Y;
                    end else if (mouse_recenter) begin
                        if (recenter_x < $signed({2'b0, MIN_ORIGIN_X}))
                            origin_x <= MIN_ORIGIN_X;
                        else if (recenter_x > $signed({2'b0, MAX_ORIGIN_X}))
                            origin_x <= MAX_ORIGIN_X;
                        else
                            origin_x <= recenter_x[6:0];

                        if (recenter_y < $signed({3'b0, MIN_ORIGIN_Y}))
                            origin_y <= MIN_ORIGIN_Y;
                        else if (recenter_y > $signed({3'b0, MAX_ORIGIN_Y}))
                            origin_y <= MAX_ORIGIN_Y;
                        else
                            origin_y <= recenter_y[5:0];
                    end else if (mouse_zoom_in && (scale_px_per_unit < 8)) begin
                        scale_px_per_unit <= scale_px_per_unit << 1;
                    end else if (mouse_zoom_out && (scale_px_per_unit > 1)) begin
                        scale_px_per_unit <= scale_px_per_unit >> 1;
                    end else if (sw12_cursor) begin
                        // SW12 selects cursor movement. SW13 selects zoom mode.
                        // At the 1 px/unit zoom, half a unit would round to
                        // zero in one direction.  Use a full-unit step there.
                        if (btnL_pressed) cursor_x_q4 <= cursor_x_q4 -
                            ((scale_px_per_unit==1)?16'sd16:16'sd8);
                        if (btnR_pressed) cursor_x_q4 <= cursor_x_q4 +
                            ((scale_px_per_unit==1)?16'sd16:16'sd8);
                        if (btnU_pressed) cursor_y_q4 <= cursor_y_q4 +
                            ((scale_px_per_unit==1)?16'sd16:16'sd8);
                        if (btnD_pressed) cursor_y_q4 <= cursor_y_q4 -
                            ((scale_px_per_unit==1)?16'sd16:16'sd8);
                    end else if (sw13_zoom) begin
                        if (btnU_pressed && (scale_px_per_unit < 8))
                            scale_px_per_unit <= scale_px_per_unit << 1;
                        if (btnD_pressed && (scale_px_per_unit > 1))
                            scale_px_per_unit <= scale_px_per_unit >> 1;
                        if (btnL_pressed && (origin_x > 8)) origin_x <= origin_x - 4;
                        if (btnR_pressed && (origin_x < 87)) origin_x <= origin_x + 4;
                    end else begin
                        if (btnL_pressed && (origin_x > 8)) origin_x <= origin_x - 4;
                        if (btnR_pressed && (origin_x < 87)) origin_x <= origin_x + 4;
                        if (btnU_pressed && (origin_y > 8)) origin_y <= origin_y - 4;
                        if (btnD_pressed && (origin_y < 55)) origin_y <= origin_y + 4;
                    end
                end

                default: begin
                    state <= SELECT_COUNT;
                    ready <= 1'b0;
                    draw <= 1'b0;
                end
            endcase
        end
    end

endmodule
