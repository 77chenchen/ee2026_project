`timescale 1ns / 1ps

// Group 06 integrated graphical-calculator top level.
//
// The port list, menu navigation and JB OLED connection follow Hanna's
// 2026-10-17 archive.  The calculator uses Hanna's interface but the verified
// signed-arithmetic core, and the graph view uses the main-project renderer.
module My_Top_Module #(
    parameter integer BUTTON_COUNTER_BITS = 19,
    parameter integer SWITCH_COUNTER_BITS = 18,
    parameter integer ENABLE_CALCULATOR = 1,
    parameter integer ENABLE_GRAPH = 1
) (
    input  wire        CLOCK,
    input  wire [15:0] sw,
    input  wire        btnU,
    input  wire        btnD,
    input  wire        btnC,
    input  wire        btnL,
    input  wire        btnR,
    output wire [7:0]  JB
);
    localparam [1:0] MODE_MENU=2'd0, MODE_CALC=2'd1, MODE_GRAPH=2'd2;

    reg [5:0] power_on_reset_count = 6'd63;
    always @(posedge CLOCK)
        if(power_on_reset_count!=0) power_on_reset_count<=power_on_reset_count-1'b1;
    wire system_reset=(power_on_reset_count!=0);

    // CLOCK is the 100 MHz Basys3 oscillator.  Divide by 16 to retain the
    // 6.25 MHz OLED timing used by Hanna's clock_hz instance.
    reg [3:0] oled_clock_divider=4'd0;
    always @(posedge CLOCK) oled_clock_divider<=oled_clock_divider+1'b1;
    wire clk6p25m=oled_clock_divider[3];

    wire btnU_pressed,btnD_pressed,btnL_pressed,btnR_pressed,btnC_pressed;
    button_onepulse #(.COUNTER_BITS(BUTTON_COUNTER_BITS)) db_u(.clk(CLOCK),.reset(system_reset),.button_in(btnU),.pressed(btnU_pressed));
    button_onepulse #(.COUNTER_BITS(BUTTON_COUNTER_BITS)) db_d(.clk(CLOCK),.reset(system_reset),.button_in(btnD),.pressed(btnD_pressed));
    button_onepulse #(.COUNTER_BITS(BUTTON_COUNTER_BITS)) db_l(.clk(CLOCK),.reset(system_reset),.button_in(btnL),.pressed(btnL_pressed));
    button_onepulse #(.COUNTER_BITS(BUTTON_COUNTER_BITS)) db_r(.clk(CLOCK),.reset(system_reset),.button_in(btnR),.pressed(btnR_pressed));
    button_onepulse #(.COUNTER_BITS(BUTTON_COUNTER_BITS)) db_c(.clk(CLOCK),.reset(system_reset),.button_in(btnC),.pressed(btnC_pressed));

    wire sw13_level,sw14_level,sw15_level;
    wire unused_r13,unused_f13,unused_r14,unused_f14,unused_r15,unused_f15;
    switch_sync #(.COUNTER_BITS(SWITCH_COUNTER_BITS)) ss13(.clk(CLOCK),.reset(system_reset),.async_in(sw[13]),.level(sw13_level),.rising(unused_r13),.falling(unused_f13));
    switch_sync #(.COUNTER_BITS(SWITCH_COUNTER_BITS)) ss14(.clk(CLOCK),.reset(system_reset),.async_in(sw[14]),.level(sw14_level),.rising(unused_r14),.falling(unused_f14));
    switch_sync #(.COUNTER_BITS(SWITCH_COUNTER_BITS)) ss15(.clk(CLOCK),.reset(system_reset),.async_in(sw[15]),.level(sw15_level),.rising(unused_r15),.falling(unused_f15));
    wire signed [7:0] signed_switch_value;
    signed_switch_input signed_input(.clk(CLOCK),.reset(system_reset),.switches(sw[7:0]),.value(signed_switch_value));

    reg [1:0] mode=MODE_MENU;
    reg [1:0] menu_arrow=2'd0;
    reg system_reset_meta=1'b1;
    reg system_reset_stable=1'b1;
    always @(posedge CLOCK) begin
        system_reset_meta<=1'b0;
        system_reset_stable<=system_reset_meta;
    end
    always @(posedge CLOCK) begin
        if(system_reset) begin
            mode<=MODE_MENU;
            menu_arrow<=2'd0;
        end else if(system_reset_stable) begin
            mode<=mode;
        end else if(sw15_level) begin
            mode<=MODE_MENU;
            menu_arrow<=2'd0;
        end else if(mode==MODE_MENU) begin
            if(btnU_pressed)
                menu_arrow<=2'd0;
            else if(btnD_pressed)
                menu_arrow<=2'd1;
            else if(btnC_pressed) begin
                if(menu_arrow==2'd0) mode<=MODE_CALC;
                else                mode<=MODE_GRAPH;
            end
        end
    end

    wire calc_active=(mode==MODE_CALC);
    wire graph_active=(mode==MODE_GRAPH);

    // Calculator: four operations, signed input and error checking.  The
    // optional history extension is disabled in the small-device build.
    wire [2:0] calc_state;
    wire signed [7:0] calc_a,calc_b;
    wire [1:0] calc_operation;
    wire calc_operation_valid;
    wire signed [15:0] calc_result;
    wire calc_result_valid,calc_div0,calc_overflow,calc_busy;
    wire [1:0] calc_history_count,calc_history_select;
    wire signed [15:0] calc_history_0,calc_history_1,calc_history_2;
    wire calc_recall_error;
    calculator_mode #(.ENABLE_HISTORY(0)) calculator_core(
        .clk(CLOCK),.reset(system_reset),
        .btnC_pressed(calc_active&&btnC_pressed),.btnU_pressed(calc_active&&btnU_pressed),
        .btnD_pressed(calc_active&&btnD_pressed),.btnL_pressed(calc_active&&btnL_pressed),
        .btnR_pressed(calc_active&&btnR_pressed),
        .sw13_history(1'b0),.sw14_new(calc_active&&sw14_level),
        .input_value(signed_switch_value),.state(calc_state),.operand_a(calc_a),
        .operand_b(calc_b),.operation(calc_operation),.operation_valid(calc_operation_valid),
        .result(calc_result),.result_valid(calc_result_valid),.divide_by_zero(calc_div0),
        .overflow(calc_overflow),.busy(calc_busy),.history_count(calc_history_count),
        .history_select(calc_history_select),.history_0(calc_history_0),
        .history_1(calc_history_1),.history_2(calc_history_2),
        .recall_error(calc_recall_error)
    );

    // Graph controller and mathematics from Oskar, renderer from Wang.
    wire [1:0] graph_count;
    wire graph1_type,graph2_type;
    wire signed [7:0] a1,b1,c1,a2,b2,c2;
    wire [2:0] graph_state;
    wire current_graph,graph_ready,graph_draw;
    wire [3:0] graph_scale;
    wire [6:0] graph_origin_x;
    wire [5:0] graph_origin_y;
    wire signed [15:0] cursor_x_q4,cursor_y_q4;
    wire [2:0] graph_status;
    wire intersection_valid;
    wire signed [15:0] intersection_x_q4,intersection_y_q4;

    graph_controller graph_core(
        .clk(CLOCK),.reset(system_reset||!graph_active),
        .btnC_pressed(graph_active&&btnC_pressed),.btnU_pressed(graph_active&&btnU_pressed),
        .btnD_pressed(graph_active&&btnD_pressed),.btnL_pressed(graph_active&&btnL_pressed),
        .btnR_pressed(graph_active&&btnR_pressed),.sw0(sw[0]),
        .sw12_cursor(1'b0),.sw13_zoom(sw13_level),.sw14(sw14_level),
        .input_value(signed_switch_value),
        .mouse_zoom_in(1'b0),.mouse_zoom_out(1'b0),
        .mouse_recenter(1'b0),.mouse_reset_view(1'b0),
        .mouse_screen_x(7'd48),.mouse_screen_y(6'd32),
        .graph_count(graph_count),
        .graph1_type(graph1_type),.graph2_type(graph2_type),
        .a1(a1),.b1(b1),.c1(c1),.a2(a2),.b2(b2),.c2(c2),
        .state(graph_state),.current_graph(current_graph),.ready(graph_ready),.draw(graph_draw),
        .scale_px_per_unit(graph_scale),.origin_x(graph_origin_x),.origin_y(graph_origin_y),
        .cursor_x_q4(cursor_x_q4),.cursor_y_q4(cursor_y_q4),
        .graph_status(graph_status),.intersection_valid(intersection_valid),
        .intersection_x_q4(intersection_x_q4),.intersection_y_q4(intersection_y_q4)
    );

    wire [12:0] pixel_index;
    wire frame_begin,sending_pixels,sample_pixel;

    // Snapshot all renderer inputs at a frame boundary.  This prevents a
    // button press from producing a half-old/half-new OLED frame.
    reg [1:0] frame_mode;
    reg [1:0] frame_menu_arrow;
    reg signed [7:0] frame_input,frame_calc_a,frame_calc_b;
    reg [2:0] frame_calc_state;
    reg [1:0] frame_calc_operation;
    reg frame_calc_operation_valid;
    reg signed [15:0] frame_calc_result;
    reg frame_calc_result_valid,frame_calc_div0,frame_calc_overflow,frame_calc_busy;
    reg [1:0] frame_graph_count;
    reg frame_graph1_type,frame_graph2_type,frame_current_graph,frame_graph_draw;
    reg signed [7:0] frame_a1,frame_b1,frame_c1,frame_a2,frame_b2,frame_c2;
    reg [2:0] frame_graph_state,frame_graph_status;
    reg frame_intersection_valid;
    reg signed [15:0] frame_ix,frame_iy;
    reg [3:0] frame_scale;
    reg [6:0] frame_origin_x;
    reg [5:0] frame_origin_y;

    always @(posedge clk6p25m) begin
        if(system_reset) begin
            frame_mode<=MODE_MENU; frame_menu_arrow<=2'd0; frame_input<=0; frame_calc_state<=0;
            frame_graph_draw<=0; frame_intersection_valid<=0;
        end else if(frame_begin) begin
            frame_mode<=mode;
            frame_menu_arrow<=menu_arrow;
            frame_input<=signed_switch_value;
            frame_calc_a<=calc_a; frame_calc_b<=calc_b; frame_calc_state<=calc_state;
            frame_calc_operation<=calc_operation; frame_calc_operation_valid<=calc_operation_valid;
            frame_calc_result<=calc_result; frame_calc_result_valid<=calc_result_valid;
            frame_calc_div0<=calc_div0; frame_calc_overflow<=calc_overflow; frame_calc_busy<=calc_busy;
            frame_graph_count<=graph_count; frame_graph1_type<=graph1_type; frame_graph2_type<=graph2_type;
            frame_a1<=a1; frame_b1<=b1; frame_c1<=c1; frame_a2<=a2; frame_b2<=b2; frame_c2<=c2;
            frame_graph_state<=graph_state; frame_current_graph<=current_graph; frame_graph_draw<=graph_draw;
            frame_graph_status<=graph_status; frame_intersection_valid<=intersection_valid;
            frame_ix<=intersection_x_q4; frame_iy<=intersection_y_q4; frame_scale<=graph_scale;
            frame_origin_x<=graph_origin_x; frame_origin_y<=graph_origin_y;
        end
    end

    wire [15:0] menu_pixel_data,calc_pixel_data,graph_pixel_data;
    wire [6:0] unused_screen_x;
    wire [5:0] unused_screen_y;
    menu_renderer #(.INCLUDE_TEXT(0)) menu(
        .pixel_index(pixel_index),.pixel_data(menu_pixel_data));
    calculator_renderer #(.INCLUDE_TEXT(0)) calc_ui(
        .pixel_index(pixel_index),.input_value(frame_input),.operand_a(frame_calc_a),
        .operand_b(frame_calc_b),.state(frame_calc_state),.operation(frame_calc_operation),
        .operation_valid(frame_calc_operation_valid),.result(frame_calc_result),
        .result_valid(frame_calc_result_valid),.divide_by_zero(frame_calc_div0),
        .overflow(frame_calc_overflow),.busy(frame_calc_busy),.sw13_history(1'b0),
        .history_count(2'd0),.history_select(2'd0),
        .history_0(16'sd0),.history_1(16'sd0),.history_2(16'sd0),
        .recall_error(1'b0),.pixel_data(calc_pixel_data)
    );
    graph_renderer #(.INCLUDE_TEXT(0)) graph_ui(
        .pixel_index(pixel_index),.graph_count(frame_graph_count),
        .graph1_type(frame_graph1_type),.graph2_type(frame_graph2_type),
        .a1(frame_a1),.b1(frame_b1),.c1(frame_c1),.a2(frame_a2),.b2(frame_b2),.c2(frame_c2),
        .current_input(frame_input),
        .controller_state(frame_graph_state),.current_graph(frame_current_graph),
        .draw_enable(frame_graph_draw),.graph_status(frame_graph_status),
        .intersection_valid(frame_intersection_valid),.intersection_x_q4(frame_ix),.intersection_y_q4(frame_iy),
        .scale_px_per_unit(frame_scale),.origin_x(frame_origin_x),.origin_y(frame_origin_y),
        .cursor_enable(1'b0),.cursor_x_q4(16'sd0),.cursor_y_q4(16'sd0),
        .screen_x(unused_screen_x),.screen_y(unused_screen_y),.pixel_data(graph_pixel_data)
    );
    wire compact_text_on;
    wire [15:0] compact_text_pixel;
    compact_text_renderer shared_text(
        .mode(frame_mode),.menu_arrow(frame_menu_arrow),
        .screen_x(unused_screen_x),.screen_y(unused_screen_y),
        .input_value(frame_input),.calc_a(frame_calc_a),.calc_state(frame_calc_state),
        .calc_result(frame_calc_result),.calc_result_valid(frame_calc_result_valid),
        .calc_div0(frame_calc_div0),.calc_overflow(frame_calc_overflow),
        .calc_busy(frame_calc_busy),.history_view(1'b0),
        .history_count(2'd0),.history_0(16'sd0),
        .history_1(16'sd0),.history_2(16'sd0),
        .recall_error(1'b0),.graph_count(frame_graph_count),
        .graph_state(frame_graph_state),.current_graph(frame_current_graph),
        .graph_draw(frame_graph_draw),.graph_status(frame_graph_status),
        .cursor_enable(1'b0),.cursor_x_q4(16'sd0),
        .cursor_y_q4(16'sd0),.text_on(compact_text_on),
        .text_pixel_data(compact_text_pixel)
    );
    wire [15:0] background_pixel_data=(frame_mode==MODE_CALC)?calc_pixel_data:
                                      (frame_mode==MODE_GRAPH)?graph_pixel_data:menu_pixel_data;
    wire [15:0] oled_pixel_data=compact_text_on?compact_text_pixel:background_pixel_data;

    wire oled_cs,oled_sdin,oled_sclk,oled_d_cn,oled_resn,oled_vccen,oled_pmoden;
    Oled_Display oled_unit(
        .clk(clk6p25m),.reset(system_reset),.frame_begin(frame_begin),
        .sending_pixels(sending_pixels),.sample_pixel(sample_pixel),
        .pixel_index(pixel_index),.pixel_data(oled_pixel_data),.cs(oled_cs),
        .sdin(oled_sdin),.sclk(oled_sclk),.d_cn(oled_d_cn),.resn(oled_resn),
        .vccen(oled_vccen),.pmoden(oled_pmoden)
    );

    assign JB[0]=oled_cs; assign JB[1]=oled_sdin; assign JB[2]=1'b0; assign JB[3]=oled_sclk;
    assign JB[4]=oled_d_cn; assign JB[5]=oled_resn; assign JB[6]=oled_vccen; assign JB[7]=oled_pmoden;
endmodule
