`timescale 1ns / 1ps

// Project integration layer around Oskar's unmodified graph_controller.
// Oskar handles the original linear/quadratic input flow. Only selecting a
// cubic transfers control to our separate FSM; neither original is edited.
// The adapter also owns view state and the shared intersection solver.
module graph_controller_adapter #(
    parameter integer ENABLE_MOUSE = 0
) (
    input  wire clk,
    input  wire reset,
    input  wire btnC_pressed,
    input  wire btnU_pressed,
    input  wire btnD_pressed,
    input  wire btnL_pressed,
    input  wire btnR_pressed,
    input  wire sw0,
    input  wire sw1_cubic,
    input  wire sw12_cursor,
    input  wire sw13_zoom,
    input  wire sw14,
    input  wire signed [7:0] input_value,
    input  wire mouse_zoom_in,
    input  wire mouse_zoom_out,
    input  wire mouse_recenter,
    input  wire mouse_reset_view,
    input  wire [6:0] mouse_screen_x,
    input  wire [5:0] mouse_screen_y,

    output wire [1:0] graph_count,
    output wire graph1_type, graph2_type, cubic1, cubic2,
    output wire signed [7:0] a1,b1,c1,d1,a2,b2,c2,d2,
    output wire [2:0] state,
    output wire current_graph,
    output wire ready, draw,
    output reg [3:0] scale_px_per_unit,
    output reg [6:0] origin_x,
    output reg [5:0] origin_y,
    output reg signed [15:0] cursor_x_q4,
    output reg signed [15:0] cursor_y_q4,
    output wire [2:0] graph_status,
    output wire intersection_valid,
    output wire signed [15:0] intersection_x_q4,
    output wire signed [15:0] intersection_y_q4,
    output wire intersection2_valid,
    output wire signed [15:0] intersection2_x_q4,
    output wire signed [15:0] intersection2_y_q4
);
    localparam [2:0] NEXT_GRAPH = 3'd5;
    localparam [2:0] VIEW_GRAPH = 3'd7;
    localparam [2:0] STATUS_OK=0, STATUS_PAR=1, STATUS_SAME=2,
                     STATUS_OUT=3, STATUS_ERR=4;
    localparam [6:0] DEFAULT_ORIGIN_X=48, MIN_ORIGIN_X=8, MAX_ORIGIN_X=87;
    localparam [5:0] DEFAULT_ORIGIN_Y=32, MIN_ORIGIN_Y=8, MAX_ORIGIN_Y=55;

    reg sw14_previous;
    wire sw14_rising = sw14 && !sw14_previous;
    wire [1:0] oskar_count;
    wire oskar_type1, oskar_type2, oskar_ready, oskar_draw;
    wire signed [7:0] oskar_a1,oskar_b1,oskar_c1,oskar_a2,oskar_b2,oskar_c2;
    wire [2:0] oskar_state;
    reg oskar_current_graph;
    reg extended_active;
    wire start_extended = !extended_active && (oskar_state==3'd1) &&
                          btnC_pressed && sw1_cubic;
    wire [1:0] extended_count;
    wire extended_type1,extended_type2,extended_cubic1,extended_cubic2;
    wire signed [7:0] extended_a1,extended_b1,extended_c1,extended_d1;
    wire signed [7:0] extended_a2,extended_b2,extended_c2,extended_d2;
    wire [2:0] extended_state;
    wire extended_current,extended_ready,extended_draw;

    // The raw controller is intentionally instantiated without modifications.
    graph_controller oskar_controller(
        .clk(clk), .reset(reset || extended_active), .btnC_pressed(btnC_pressed),
        .sw0(sw0), .sw14(sw14_rising), .input_value(input_value),
        .graph_count(oskar_count), .graph1_type(oskar_type1),
        .graph2_type(oskar_type2), .a1(oskar_a1), .b1(oskar_b1), .c1(oskar_c1),
        .a2(oskar_a2), .b2(oskar_b2), .c2(oskar_c2),
        .state(oskar_state), .ready(oskar_ready), .draw(oskar_draw)
    );

    graph_cubic_input cubic_input(
        .clk(clk), .reset(reset), .start(start_extended),
        .btnC_pressed(btnC_pressed), .sw0(sw0), .sw1(sw1_cubic), .sw14(sw14),
        .start_count(oskar_count), .start_second(oskar_current_graph),
        .start_graph1_type(oskar_type1),
        .start_a1(oskar_a1), .start_b1(oskar_b1), .start_c1(oskar_c1),
        .input_value(input_value), .graph_count(extended_count),
        .graph1_type(extended_type1), .graph2_type(extended_type2),
        .cubic1(extended_cubic1), .cubic2(extended_cubic2),
        .a1(extended_a1), .b1(extended_b1), .c1(extended_c1), .d1(extended_d1),
        .a2(extended_a2), .b2(extended_b2), .c2(extended_c2), .d2(extended_d2),
        .state(extended_state), .current_graph(extended_current),
        .ready(extended_ready), .draw(extended_draw)
    );
    assign graph_count=extended_active?extended_count:oskar_count;
    assign graph1_type=extended_active?extended_type1:oskar_type1;
    assign graph2_type=extended_active?extended_type2:oskar_type2;
    assign cubic1=extended_active && extended_cubic1;
    assign cubic2=extended_active && extended_cubic2;
    assign a1=extended_active?extended_a1:oskar_a1;
    assign b1=extended_active?extended_b1:oskar_b1;
    assign c1=extended_active?extended_c1:oskar_c1;
    assign d1=extended_active?extended_d1:8'sd0;
    assign a2=extended_active?extended_a2:oskar_a2;
    assign b2=extended_active?extended_b2:oskar_b2;
    assign c2=extended_active?extended_c2:oskar_c2;
    assign d2=extended_active?extended_d2:8'sd0;
    assign state=extended_active?extended_state:oskar_state;
    assign current_graph=extended_active?extended_current:oskar_current_graph;
    assign ready=extended_active?extended_ready:oskar_ready;
    assign draw=extended_active?extended_draw:oskar_draw;

    wire signed [8:0] recenter_x = $signed({2'b00, origin_x}) + 9'sd48 -
                                    $signed({3'b000, mouse_screen_x});
    wire signed [8:0] recenter_y = $signed({3'b000, origin_y}) + 9'sd32 -
                                    $signed({2'b00, mouse_screen_y});

    always @(posedge clk) begin
        sw14_previous <= sw14;
        if (reset) begin
            oskar_current_graph <= 0;
            extended_active <= 0;
            scale_px_per_unit <= 4;
            origin_x <= DEFAULT_ORIGIN_X;
            origin_y <= DEFAULT_ORIGIN_Y;
            cursor_x_q4 <= 0;
            cursor_y_q4 <= 0;
            sw14_previous <= sw14;
        end else begin
            // Oskar keeps this state internally; reproduce it only as an
            // output for setup labels in the renderer.
            if (start_extended) extended_active <= 1'b1;
            if ((oskar_state == NEXT_GRAPH) && (oskar_count == 2) && !oskar_current_graph)
                oskar_current_graph <= 1'b1;

            if (state == VIEW_GRAPH) begin
                if (ENABLE_MOUSE && mouse_reset_view) begin
                    scale_px_per_unit <= 4;
                    origin_x <= DEFAULT_ORIGIN_X;
                    origin_y <= DEFAULT_ORIGIN_Y;
                end else if (ENABLE_MOUSE && mouse_recenter) begin
                    if (recenter_x < MIN_ORIGIN_X) origin_x <= MIN_ORIGIN_X;
                    else if (recenter_x > MAX_ORIGIN_X) origin_x <= MAX_ORIGIN_X;
                    else origin_x <= recenter_x[6:0];
                    if (recenter_y < MIN_ORIGIN_Y) origin_y <= MIN_ORIGIN_Y;
                    else if (recenter_y > MAX_ORIGIN_Y) origin_y <= MAX_ORIGIN_Y;
                    else origin_y <= recenter_y[5:0];
                end else if (ENABLE_MOUSE && mouse_zoom_in && (scale_px_per_unit < 8))
                    scale_px_per_unit <= scale_px_per_unit << 1;
                else if (ENABLE_MOUSE && mouse_zoom_out && (scale_px_per_unit > 1))
                    scale_px_per_unit <= scale_px_per_unit >> 1;
                else if (sw12_cursor) begin
                    if (btnL_pressed) cursor_x_q4 <= cursor_x_q4 - ((scale_px_per_unit==1)?16:8);
                    if (btnR_pressed) cursor_x_q4 <= cursor_x_q4 + ((scale_px_per_unit==1)?16:8);
                    if (btnU_pressed) cursor_y_q4 <= cursor_y_q4 + ((scale_px_per_unit==1)?16:8);
                    if (btnD_pressed) cursor_y_q4 <= cursor_y_q4 - ((scale_px_per_unit==1)?16:8);
                end else if (sw13_zoom) begin
                    if (btnU_pressed && (scale_px_per_unit < 8)) scale_px_per_unit <= scale_px_per_unit << 1;
                    if (btnD_pressed && (scale_px_per_unit > 1)) scale_px_per_unit <= scale_px_per_unit >> 1;
                    if (btnL_pressed && (origin_x > MIN_ORIGIN_X)) origin_x <= origin_x - 4;
                    if (btnR_pressed && (origin_x < MAX_ORIGIN_X)) origin_x <= origin_x + 4;
                end else begin
                    if (btnL_pressed && (origin_x > MIN_ORIGIN_X)) origin_x <= origin_x - 4;
                    if (btnR_pressed && (origin_x < MAX_ORIGIN_X)) origin_x <= origin_x + 4;
                    if (btnU_pressed && (origin_y > MIN_ORIGIN_Y)) origin_y <= origin_y - 4;
                    if (btnD_pressed && (origin_y < MAX_ORIGIN_Y)) origin_y <= origin_y + 4;
                end
            end
        end
    end

    wire solve_intersection = (graph_count==2) && !cubic1 && !cubic2;
    wire [2:0] quadratic_status;
    wire quadratic_valid1,quadratic_valid2;
    wire signed [15:0] quadratic_x1,quadratic_y1,quadratic_x2,quadratic_y2;
    graph_quadratic_intersections quadratic_solver(
        .clk(clk),.reset(reset),.enable(solve_intersection),
        .graph1_quadratic(graph1_type),.graph2_quadratic(graph2_type),
        .a1(a1),.b1(b1),.c1(c1),.a2(a2),.b2(b2),.c2(c2),
        .scale(scale_px_per_unit),.origin_x(origin_x),.origin_y(origin_y),
        .status(quadratic_status),.valid1(quadratic_valid1),.valid2(quadratic_valid2),
        .x1_q4(quadratic_x1),.y1_q4(quadratic_y1),
        .x2_q4(quadratic_x2),.y2_q4(quadratic_y2)
    );
    assign graph_status=solve_intersection?quadratic_status:STATUS_OK;
    assign intersection_valid=solve_intersection && quadratic_valid1;
    assign intersection_x_q4=quadratic_x1;
    assign intersection_y_q4=quadratic_y1;
    assign intersection2_valid=solve_intersection && quadratic_valid2;
    assign intersection2_x_q4=quadratic_x2;
    assign intersection2_y_q4=quadratic_y2;
endmodule
