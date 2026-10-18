`timescale 1ns / 1ps

// Convert MouseCtl position/button events into graph-controller controls.
// MouseCtl already stores positions with an upper-left origin.
module mouse_graph_adapter (
    input  wire        clk,
    input  wire        reset,
    input  wire        mouse_enable,
    input  wire        view_graph,
    input  wire        new_event,
    input  wire [11:0] xpos,
    input  wire [11:0] ypos,
    input  wire [3:0]  zpos,
    input  wire        left,
    input  wire        right,
    input  wire [3:0]  scale,
    input  wire [6:0]  origin_x,
    input  wire [5:0]  origin_y,

    output wire        setup_done,
    output reg  [11:0] setup_value,
    output wire        setup_setx,
    output wire        setup_sety,
    output wire        setup_setmax_x,
    output wire        setup_setmax_y,
    output wire        mouse_zoom_in,
    output wire        mouse_zoom_out,
    output wire        mouse_recenter,
    output wire        mouse_reset_view,
    output reg  [6:0]  mouse_screen_x,
    output reg  [5:0]  mouse_screen_y,
    output reg signed [15:0] cursor_x_q4,
    output reg signed [15:0] cursor_y_q4
);

    localparam [2:0] SETUP_IDLE      = 3'd0;
    localparam [2:0] SETUP_MAX_X     = 3'd1;
    localparam [2:0] SETUP_MAX_Y     = 3'd2;
    localparam [2:0] SETUP_SET_X     = 3'd3;
    localparam [2:0] SETUP_SET_Y     = 3'd4;
    localparam [2:0] SETUP_DONE      = 3'd5;

    localparam [11:0] SETUP_MAX_X_VALUE = 12'd95;
    localparam [11:0] SETUP_MAX_Y_VALUE = 12'd63;
    localparam [11:0] SETUP_X_VALUE     = 12'd48;
    localparam [11:0] SETUP_Y_VALUE     = 12'd32;

    reg [2:0] setup_state;
    reg       previous_left;
    reg       previous_right;

    wire [11:0] clipped_x = (xpos > 12'd95) ? 12'd95 : xpos;
    wire [11:0] clipped_y = (ypos > 12'd63) ? 12'd63 : ypos;
    wire signed [8:0] delta_x = $signed({2'b00, clipped_x[6:0]}) -
                                $signed({2'b00, origin_x});
    // OLED rows increase downwards, whereas graph Y increases upwards.
    wire signed [8:0] delta_y = $signed({3'b000, origin_y}) -
                                $signed({3'b000, clipped_y[5:0]});
    wire operation_allowed = mouse_enable && view_graph && setup_done;

    reg signed [19:0] scaled_x;
    reg signed [19:0] scaled_y;
    always @* begin
        case (scale)
            4'd1: begin scaled_x = $signed(delta_x) <<< 4; scaled_y = $signed(delta_y) <<< 4; end
            4'd2: begin scaled_x = $signed(delta_x) <<< 3; scaled_y = $signed(delta_y) <<< 3; end
            4'd4: begin scaled_x = $signed(delta_x) <<< 2; scaled_y = $signed(delta_y) <<< 2; end
            4'd8: begin scaled_x = $signed(delta_x) <<< 1; scaled_y = $signed(delta_y) <<< 1; end
            default: begin scaled_x = $signed(delta_x) <<< 2; scaled_y = $signed(delta_y) <<< 2; end
        endcase
    end

    assign mouse_zoom_in     = operation_allowed && new_event && ($signed(zpos) > 0);
    assign mouse_zoom_out    = operation_allowed && new_event && ($signed(zpos) < 0);
    assign mouse_recenter    = operation_allowed && new_event && left && !previous_left;
    assign mouse_reset_view  = operation_allowed && new_event && right && !previous_right;
    assign setup_done        = (setup_state == SETUP_DONE);
    assign setup_setmax_x    = (setup_state == SETUP_MAX_X);
    assign setup_setmax_y    = (setup_state == SETUP_MAX_Y);
    assign setup_setx        = (setup_state == SETUP_SET_X);
    assign setup_sety        = (setup_state == SETUP_SET_Y);

    always @* begin
        case (setup_state)
            SETUP_MAX_X: setup_value = SETUP_MAX_X_VALUE;
            SETUP_MAX_Y: setup_value = SETUP_MAX_Y_VALUE;
            SETUP_SET_X: setup_value = SETUP_X_VALUE;
            SETUP_SET_Y: setup_value = SETUP_Y_VALUE;
            default:     setup_value = 12'd0;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            setup_state <= SETUP_IDLE;
            mouse_screen_x <= 7'd48;
            mouse_screen_y <= 6'd32;
            cursor_x_q4 <= 16'sd0;
            cursor_y_q4 <= 16'sd0;
            previous_left <= left;
            previous_right <= right;
        end else begin
            case (setup_state)
                SETUP_IDLE: setup_state <= SETUP_MAX_X;
                SETUP_MAX_X: begin setup_state <= SETUP_MAX_Y; end
                SETUP_MAX_Y: begin setup_state <= SETUP_SET_X; end
                SETUP_SET_X: begin setup_state <= SETUP_SET_Y; end
                SETUP_SET_Y: setup_state <= SETUP_DONE;
                SETUP_DONE: setup_state <= SETUP_DONE;
                default: setup_state <= SETUP_IDLE;
            endcase

            if (new_event) begin
                mouse_screen_x <= clipped_x[6:0];
                mouse_screen_y <= clipped_y[5:0];
                cursor_x_q4 <= scaled_x;
                cursor_y_q4 <= scaled_y;
                previous_left <= left;
                previous_right <= right;
            end
        end
    end
endmodule
