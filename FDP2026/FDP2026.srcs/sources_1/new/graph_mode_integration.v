`timescale 1ns / 1ps

// Graph implementation connected at the placeholder in the project top level.
// It owns graph-only input synchronisation and freezes rendering parameters at
// frame_begin, so an input change never splits an OLED frame into two views.
module graph_mode_integration(
    input  wire CLOCK,
    input  wire active,
    input  wire btnU, btnD, btnL, btnR, btnC,
    input  wire [15:0] sw,
    input  wire frame_begin,
    input  wire [12:0] pixel_index,
    output wire [15:0] oled_data
    );

    wire reset = !active;
    wire signed [7:0] input_value;
    signed_switch_input input_synchroniser(
        .clk(CLOCK), .reset(reset), .switches(sw[7:0]), .value(input_value));

    wire [1:0] graph_count;
    wire graph1_type, graph2_type, cubic1, cubic2;
    wire signed [7:0] a1, b1, c1, d1, a2, b2, c2, d2;
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
        .btnR_pressed(btnR), .sw0(sw[0]), .sw1_cubic(sw[1]), .sw12_cursor(1'b0),
        .sw13_zoom(sw[13]), .sw14(sw[14]), .input_value(input_value),
        .mouse_zoom_in(1'b0), .mouse_zoom_out(1'b0),
        .mouse_recenter(1'b0), .mouse_reset_view(1'b0),
        .mouse_screen_x(7'd48), .mouse_screen_y(6'd32),
        .graph_count(graph_count), .graph1_type(graph1_type),
        .graph2_type(graph2_type), .cubic1(cubic1), .cubic2(cubic2),
        .a1(a1), .b1(b1), .c1(c1), .d1(d1),
        .a2(a2), .b2(b2), .c2(c2), .d2(d2), .state(state),
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

    // OLED pixel transmission lasts a whole frame.  Copying the controller
    // outputs at its frame boundary avoids mixed old/new coefficient images.
    reg signed [7:0] frame_input, frame_a1, frame_b1, frame_c1, frame_d1;
    reg signed [7:0] frame_a2, frame_b2, frame_c2, frame_d2;
    reg [1:0] frame_graph_count;
    reg frame_graph1_type, frame_graph2_type, frame_current_graph, frame_draw;
    reg frame_cubic1,frame_cubic2;
    reg [2:0] frame_state, frame_status;
    reg frame_intersection_valid;
    reg signed [15:0] frame_ix, frame_iy;
    reg frame_intersection2_valid;
    reg signed [15:0] frame_ix2,frame_iy2;
    reg [3:0] frame_scale;
    reg [6:0] frame_origin_x;
    reg [5:0] frame_origin_y;

    always @(posedge CLOCK) begin
        if (reset) begin
            frame_input <= 0; frame_graph_count <= 0;
            frame_graph1_type <= 0; frame_graph2_type <= 0;
            frame_cubic1<=0;frame_cubic2<=0;
            frame_a1 <= 0; frame_b1 <= 0; frame_c1 <= 0; frame_d1<=0;
            frame_a2 <= 0; frame_b2 <= 0; frame_c2 <= 0; frame_d2<=0;
            frame_state <= 0; frame_current_graph <= 0; frame_draw <= 0;
            frame_status <= 0; frame_intersection_valid <= 0;
            frame_ix <= 0; frame_iy <= 0; frame_scale <= 4;
            frame_intersection2_valid<=0;frame_ix2<=0;frame_iy2<=0;
            frame_origin_x <= 48; frame_origin_y <= 32;
        end else if (frame_begin) begin
            frame_input <= input_value; frame_graph_count <= graph_count;
            frame_graph1_type <= graph1_type; frame_graph2_type <= graph2_type;
            frame_cubic1<=cubic1;frame_cubic2<=cubic2;
            frame_a1 <= a1; frame_b1 <= b1; frame_c1 <= c1;frame_d1<=d1;
            frame_a2 <= a2; frame_b2 <= b2; frame_c2 <= c2;frame_d2<=d2;
            frame_state <= state; frame_current_graph <= current_graph;
            frame_draw <= draw; frame_status <= graph_status;
            frame_intersection_valid <= intersection_valid;
            frame_ix <= intersection_x_q4; frame_iy <= intersection_y_q4;
            frame_intersection2_valid<=intersection2_valid;
            frame_ix2<=intersection2_x_q4;frame_iy2<=intersection2_y_q4;
            frame_scale <= scale_px_per_unit;
            frame_origin_x <= origin_x; frame_origin_y <= origin_y;
        end
    end

    wire [6:0] unused_screen_x;
    wire [5:0] unused_screen_y;
    graph_renderer graph_view(
        .clk(CLOCK),
        .pixel_index(pixel_index), .graph_count(frame_graph_count),
        .graph1_type(frame_graph1_type), .graph2_type(frame_graph2_type),
        .cubic1(frame_cubic1),.cubic2(frame_cubic2),
        .a1(frame_a1), .b1(frame_b1), .c1(frame_c1),.d1(frame_d1),
        .a2(frame_a2), .b2(frame_b2), .c2(frame_c2),.d2(frame_d2),
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
        .pixel_data(oled_data)
    );
endmodule
