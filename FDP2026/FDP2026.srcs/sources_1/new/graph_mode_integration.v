`timescale 1ns / 1ps

// Graph implementation connected at the placeholder in the project top level.
// It owns graph-only input synchronisation and freezes rendering parameters at
// frame_begin, so an input change never splits an OLED frame into two views.
module graph_mode_integration(
    input  wire CLOCK,
    input  wire OLED_CLOCK,
    input  wire active,
    input  wire btnU, btnD, btnL, btnR, btnC,
    input  wire [15:0] sw,
    input  wire frame_begin,
    input  wire frame_prepare,
    input  wire oled_reset,
    input  wire [12:0] pixel_index,
    output wire [15:0] oled_data
    );

    wire reset = !active;
    wire signed [7:0] input_value;
    signed_switch_input input_synchroniser(
        .clk(CLOCK), .reset(reset), .switches(sw[7:0]), .value(input_value));

    wire [1:0] graph_count;
    wire graph1_type, graph2_type;
    wire signed [7:0] a1, b1, c1, a2, b2, c2;
    wire [2:0] state, graph_status;
    wire current_graph, ready, draw;
    wire [3:0] scale_px_per_unit;
    wire [6:0] origin_x;
    wire [5:0] origin_y;
    wire signed [15:0] cursor_x_q4, cursor_y_q4;
    wire intersection_valid;
    wire signed [15:0] intersection_x_q4, intersection_y_q4;
    wire intersection2_valid;
    wire signed [15:0] intersection2_x_q4, intersection2_y_q4;

    graph_controller_adapter #(.ENABLE_MOUSE(0)) controller(
        .clk(CLOCK), .reset(reset), .btnC_pressed(btnC),
        .btnU_pressed(btnU), .btnD_pressed(btnD), .btnL_pressed(btnL),
        .btnR_pressed(btnR), .sw0(sw[0]), .sw12_cursor(1'b0),
        .sw13_zoom(sw[13]), .sw14(sw[14]), .input_value(input_value),
        .mouse_zoom_in(1'b0), .mouse_zoom_out(1'b0),
        .mouse_recenter(1'b0), .mouse_reset_view(1'b0),
        .mouse_screen_x(7'd48), .mouse_screen_y(6'd32),
        .graph_count(graph_count), .graph1_type(graph1_type),
        .graph2_type(graph2_type),
        .a1(a1), .b1(b1), .c1(c1),
        .a2(a2), .b2(b2), .c2(c2), .state(state),
        .current_graph(current_graph), .ready(ready), .draw(draw),
        .scale_px_per_unit(scale_px_per_unit), .origin_x(origin_x),
        .origin_y(origin_y), .cursor_x_q4(cursor_x_q4),
        .cursor_y_q4(cursor_y_q4), .graph_status(graph_status),
        .intersection_valid(intersection_valid),
        .intersection_x_q4(intersection_x_q4),
        .intersection_y_q4(intersection_y_q4),
        .intersection2_valid(intersection2_valid),
        .intersection2_x_q4(intersection2_x_q4),
        .intersection2_y_q4(intersection2_y_q4)
    );

    // Capture all graph display parameters as one coherent word while the
    // driver prepares the next address window.  The request/toggle handshake
    // moves that stable word into the OLED domain.
    localparam integer SNAPSHOT_WIDTH = 152;
    wire [SNAPSHOT_WIDTH-1:0] snapshot_in;
    wire [SNAPSHOT_WIDTH-1:0] snapshot_out;
    assign snapshot_in = {
        input_value, graph_count, graph1_type, graph2_type,
        a1, b1, c1, a2, b2, c2, current_graph, draw, state, graph_status,
        intersection_valid, intersection_x_q4, intersection_y_q4,
        intersection2_valid, intersection2_x_q4, intersection2_y_q4,
        scale_px_per_unit, origin_x, origin_y
    };
    wire signed [7:0] frame_input, frame_a1, frame_b1, frame_c1;
    wire signed [7:0] frame_a2, frame_b2, frame_c2;
    wire [1:0] frame_graph_count;
    wire frame_graph1_type, frame_graph2_type, frame_current_graph, frame_draw;
    wire [2:0] frame_state, frame_status;
    wire frame_intersection_valid;
    wire signed [15:0] frame_ix, frame_iy;
    wire frame_intersection2_valid;
    wire signed [15:0] frame_ix2, frame_iy2;
    wire [3:0] frame_scale;
    wire [6:0] frame_origin_x;
    wire [5:0] frame_origin_y;
    assign {
        frame_input, frame_graph_count, frame_graph1_type, frame_graph2_type,
        frame_a1, frame_b1, frame_c1, frame_a2, frame_b2, frame_c2,
        frame_current_graph, frame_draw, frame_state, frame_status,
        frame_intersection_valid, frame_ix, frame_iy,
        frame_intersection2_valid, frame_ix2, frame_iy2,
        frame_scale, frame_origin_x, frame_origin_y
    } = snapshot_out;

    frame_snapshot #(.WIDTH(SNAPSHOT_WIDTH)) frame_values(
        .clk_src(CLOCK), .reset_src(reset),
        .clk_dst(OLED_CLOCK), .reset_dst(reset || oled_reset),
        .frame_prepare(frame_prepare),
        .data(snapshot_in), .data_out(snapshot_out));

    wire [6:0] unused_screen_x;
    wire [5:0] unused_screen_y;
    wire [15:0] graph_pixel;
    graph_renderer graph_view(
        .pixel_index(pixel_index), .graph_count(frame_graph_count),
        .graph1_type(frame_graph1_type), .graph2_type(frame_graph2_type),
        .a1(frame_a1), .b1(frame_b1), .c1(frame_c1),
        .a2(frame_a2), .b2(frame_b2), .c2(frame_c2),
        .current_input(frame_input), .controller_state(frame_state),
        .current_graph(frame_current_graph), .draw_enable(frame_draw),
        .graph_status(frame_status), .intersection_valid(frame_intersection_valid),
        .intersection_x_q4(frame_ix), .intersection_y_q4(frame_iy),
        .intersection2_valid(frame_intersection2_valid),
        .intersection2_x_q4(frame_ix2),.intersection2_y_q4(frame_iy2),
        .scale_px_per_unit(frame_scale), .origin_x(frame_origin_x),
        .origin_y(frame_origin_y), .cursor_enable(1'b0),
        .cursor_x_q4(16'sd0), .cursor_y_q4(16'sd0),
        .screen_x(unused_screen_x), .screen_y(unused_screen_y),
        .pixel_data(graph_pixel)
    );
    // The graph renderer is combinational for the current pixel_index.  A
    // second aligned register would shift colors by one OLED pixel.
    assign oled_data = graph_pixel;
endmodule
