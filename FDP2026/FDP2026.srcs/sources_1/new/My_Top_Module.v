`timescale 1ns / 1ps

// Group 06 integrated graphical-calculator top level.
// BTNL enters the calculator, BTND enters Graph Mode and SW15 returns home.
module My_Top_Module #(
    parameter integer BUTTON_COUNTER_BITS = 19,
    parameter integer SWITCH_COUNTER_BITS = 18,
    parameter integer ENABLE_HARDWARE_MOUSE = 1
) (
    input  wire        clk,
    input  wire [15:0] sw,
    input  wire        btnU,
    input  wire        btnD,
    input  wire        btnL,
    input  wire        btnR,
    input  wire        btnC,
    inout wire        PS2Clk,
    inout wire        PS2Data,
    output wire [15:0] led,
    output wire [7:0]  JA
);
    localparam [1:0] MODE_MENU=2'd0, MODE_CALC=2'd1, MODE_GRAPH=2'd2;

    reg [5:0] power_on_reset_count = 6'd63;
    always @(posedge clk)
        if(power_on_reset_count!=0) power_on_reset_count<=power_on_reset_count-1'b1;
    wire system_reset=(power_on_reset_count!=0);

    reg [3:0] oled_clock_divider=0;
    always @(posedge clk) oled_clock_divider<=oled_clock_divider+1'b1;
    wire clk6p25m=oled_clock_divider[3];

    wire btnU_pressed,btnD_pressed,btnL_pressed,btnR_pressed,btnC_pressed;
    button_onepulse #(.COUNTER_BITS(BUTTON_COUNTER_BITS)) db_u(.clk(clk),.reset(system_reset),.button_in(btnU),.pressed(btnU_pressed));
    button_onepulse #(.COUNTER_BITS(BUTTON_COUNTER_BITS)) db_d(.clk(clk),.reset(system_reset),.button_in(btnD),.pressed(btnD_pressed));
    button_onepulse #(.COUNTER_BITS(BUTTON_COUNTER_BITS)) db_l(.clk(clk),.reset(system_reset),.button_in(btnL),.pressed(btnL_pressed));
    button_onepulse #(.COUNTER_BITS(BUTTON_COUNTER_BITS)) db_r(.clk(clk),.reset(system_reset),.button_in(btnR),.pressed(btnR_pressed));
    button_onepulse #(.COUNTER_BITS(BUTTON_COUNTER_BITS)) db_c(.clk(clk),.reset(system_reset),.button_in(btnC),.pressed(btnC_pressed));

    wire sw11_level,sw12_level,sw13_level,sw14_level,sw15_level;
    wire unused_r11,unused_f11,unused_r12,unused_f12,unused_r13,unused_f13,unused_r14,unused_f14,unused_r15,unused_f15;
    switch_sync #(.COUNTER_BITS(SWITCH_COUNTER_BITS)) ss11(.clk(clk),.reset(system_reset),.async_in(sw[11]),.level(sw11_level),.rising(unused_r11),.falling(unused_f11));
    switch_sync #(.COUNTER_BITS(SWITCH_COUNTER_BITS)) ss12(.clk(clk),.reset(system_reset),.async_in(sw[12]),.level(sw12_level),.rising(unused_r12),.falling(unused_f12));
    switch_sync #(.COUNTER_BITS(SWITCH_COUNTER_BITS)) ss13(.clk(clk),.reset(system_reset),.async_in(sw[13]),.level(sw13_level),.rising(unused_r13),.falling(unused_f13));
    switch_sync #(.COUNTER_BITS(SWITCH_COUNTER_BITS)) ss14(.clk(clk),.reset(system_reset),.async_in(sw[14]),.level(sw14_level),.rising(unused_r14),.falling(unused_f14));
    switch_sync #(.COUNTER_BITS(SWITCH_COUNTER_BITS)) ss15(.clk(clk),.reset(system_reset),.async_in(sw[15]),.level(sw15_level),.rising(unused_r15),.falling(unused_f15));
    wire signed [7:0] signed_switch_value;
    signed_switch_input signed_input(.clk(clk),.reset(system_reset),.switches(sw[7:0]),.value(signed_switch_value));

    reg [1:0] mode=MODE_MENU;
    always @(posedge clk) begin
        if(system_reset) mode<=MODE_MENU;
        else if((mode!=MODE_MENU)&&sw15_level) mode<=MODE_MENU;
        else if((mode==MODE_MENU)&&!sw15_level) begin
            if(btnL_pressed) mode<=MODE_CALC;
            else if(btnD_pressed) mode<=MODE_GRAPH;
        end
    end

    wire calc_active=(mode==MODE_CALC);
    wire graph_active=(mode==MODE_GRAPH);

    // Calculator: Hanna's four-operation UI plus Milla's signed input,
    // validation, overflow and three-result history blocks.
    wire [2:0] calc_state;
    wire signed [7:0] calc_a,calc_b;
    wire [1:0] calc_operation;
    wire calc_operation_valid;
    wire signed [15:0] calc_result;
    wire calc_result_valid,calc_div0,calc_overflow,calc_busy;
    wire [1:0] calc_history_count,calc_history_select;
    wire signed [15:0] calc_history_0,calc_history_1,calc_history_2;
    wire calc_recall_error;
    calculator_mode calculator_core(
        .clk(clk),.reset(system_reset),
        .btnC_pressed(calc_active&&btnC_pressed),.btnU_pressed(calc_active&&btnU_pressed),
        .btnD_pressed(calc_active&&btnD_pressed),.btnL_pressed(calc_active&&btnL_pressed),
        .btnR_pressed(calc_active&&btnR_pressed),
        .sw13_history(calc_active&&sw13_level),.sw14_new(calc_active&&sw14_level),
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
    wire mouse_setup_done;
    wire mouse_zoom_in,mouse_zoom_out,mouse_recenter,mouse_reset_view;
    wire [11:0] mouse_xpos,mouse_ypos;
    wire [3:0] mouse_zpos;
    wire mouse_left,mouse_middle,mouse_right,mouse_new_event;
    wire [11:0] mouse_setup_value;
    wire mouse_setup_setx,mouse_setup_sety,mouse_setup_setmax_x,mouse_setup_setmax_y;
    wire [6:0] mouse_screen_x;
    wire [5:0] mouse_screen_y;
    wire signed [15:0] mouse_cursor_x_q4,mouse_cursor_y_q4;
    wire mouse_graph_active=graph_active&&(graph_state==3'd7);
    wire mouse_control_ready=sw11_level&&mouse_setup_done;

    graph_controller graph_core(
        .clk(clk),.reset(system_reset||!graph_active),
        .btnC_pressed(graph_active&&btnC_pressed),.btnU_pressed(graph_active&&btnU_pressed),
        .btnD_pressed(graph_active&&btnD_pressed),.btnL_pressed(graph_active&&btnL_pressed),
        .btnR_pressed(graph_active&&btnR_pressed),.sw0(sw[0]),
        .sw12_cursor(sw12_level),.sw13_zoom(sw13_level),.sw14(sw14_level),
        .input_value(signed_switch_value),
        .mouse_zoom_in(mouse_control_ready&&mouse_zoom_in),
        .mouse_zoom_out(mouse_control_ready&&mouse_zoom_out),
        .mouse_recenter(mouse_control_ready&&mouse_recenter),
        .mouse_reset_view(mouse_control_ready&&mouse_reset_view),
        .mouse_screen_x(mouse_screen_x),.mouse_screen_y(mouse_screen_y),
        .graph_count(graph_count),
        .graph1_type(graph1_type),.graph2_type(graph2_type),
        .a1(a1),.b1(b1),.c1(c1),.a2(a2),.b2(b2),.c2(c2),
        .state(graph_state),.current_graph(current_graph),.ready(graph_ready),.draw(graph_draw),
        .scale_px_per_unit(graph_scale),.origin_x(graph_origin_x),.origin_y(graph_origin_y),
        .cursor_x_q4(cursor_x_q4),.cursor_y_q4(cursor_y_q4),
        .graph_status(graph_status),.intersection_valid(intersection_valid),
        .intersection_x_q4(intersection_x_q4),.intersection_y_q4(intersection_y_q4)
    );

    mouse_graph_adapter mouse_adapter(
        .clk(clk),.reset(system_reset),
        .mouse_enable(sw11_level),.view_graph(mouse_graph_active),
        .new_event(mouse_new_event),.xpos(mouse_xpos),.ypos(mouse_ypos),
        .zpos(mouse_zpos),.left(mouse_left),.right(mouse_right),
        .scale(graph_scale),.origin_x(graph_origin_x),.origin_y(graph_origin_y),
        .setup_done(mouse_setup_done),
        .setup_value(mouse_setup_value),
        .setup_setx(mouse_setup_setx),.setup_sety(mouse_setup_sety),
        .setup_setmax_x(mouse_setup_setmax_x),.setup_setmax_y(mouse_setup_setmax_y),
        .mouse_zoom_in(mouse_zoom_in),.mouse_zoom_out(mouse_zoom_out),
        .mouse_recenter(mouse_recenter),.mouse_reset_view(mouse_reset_view),
        .mouse_screen_x(mouse_screen_x),.mouse_screen_y(mouse_screen_y),
        .cursor_x_q4(mouse_cursor_x_q4),.cursor_y_q4(mouse_cursor_y_q4)
    );

    generate
        if (ENABLE_HARDWARE_MOUSE != 0) begin : g_hardware_mouse
            MouseCtl #(
                .SYSCLK_FREQUENCY_HZ(100000000)
            ) mouse_ctl (
                .clk(clk),.rst(system_reset),
                .xpos(mouse_xpos),.ypos(mouse_ypos),.zpos(mouse_zpos),
                .left(mouse_left),.middle(mouse_middle),.right(mouse_right),
                .new_event(mouse_new_event),
                .value(mouse_setup_value),
                .setx(mouse_setup_setx),.sety(mouse_setup_sety),
                .setmax_x(mouse_setup_setmax_x),.setmax_y(mouse_setup_setmax_y),
                .ps2_clk(PS2Clk),.ps2_data(PS2Data)
            );
        end else begin : g_no_hardware_mouse
            assign mouse_xpos=12'd48;
            assign mouse_ypos=12'd32;
            assign mouse_zpos=4'd0;
            assign mouse_left=1'b0;
            assign mouse_middle=1'b0;
            assign mouse_right=1'b0;
            assign mouse_new_event=1'b0;
            assign PS2Clk=1'bz;
            assign PS2Data=1'bz;
        end
    endgenerate

    wire [12:0] pixel_index;
    wire frame_begin,sending_pixels,sample_pixel;

    // Snapshot all renderer inputs at a frame boundary.  This prevents a
    // button press from producing a half-old/half-new OLED frame.
    reg [1:0] frame_mode;
    reg signed [7:0] frame_input,frame_calc_a,frame_calc_b;
    reg [2:0] frame_calc_state;
    reg [1:0] frame_calc_operation;
    reg frame_calc_operation_valid;
    reg signed [15:0] frame_calc_result;
    reg frame_calc_result_valid,frame_calc_div0,frame_calc_overflow,frame_calc_busy;
    reg frame_history_view,frame_recall_error;
    reg [1:0] frame_history_count,frame_history_select;
    reg signed [15:0] frame_history_0,frame_history_1,frame_history_2;
    reg [1:0] frame_graph_count;
    reg frame_graph1_type,frame_graph2_type,frame_current_graph,frame_graph_draw;
    reg signed [7:0] frame_a1,frame_b1,frame_c1,frame_a2,frame_b2,frame_c2;
    reg [2:0] frame_graph_state,frame_graph_status;
    reg frame_intersection_valid,frame_cursor_enable;
    reg signed [15:0] frame_ix,frame_iy,frame_cursor_x,frame_cursor_y;
    reg [3:0] frame_scale;
    reg [6:0] frame_origin_x;
    reg [5:0] frame_origin_y;

    always @(posedge clk6p25m) begin
        if(system_reset) begin
            frame_mode<=MODE_MENU; frame_input<=0; frame_calc_state<=0;
            frame_graph_draw<=0; frame_intersection_valid<=0; frame_cursor_enable<=0;
        end else if(frame_begin) begin
            frame_mode<=mode;
            frame_input<=signed_switch_value;
            frame_calc_a<=calc_a; frame_calc_b<=calc_b; frame_calc_state<=calc_state;
            frame_calc_operation<=calc_operation; frame_calc_operation_valid<=calc_operation_valid;
            frame_calc_result<=calc_result; frame_calc_result_valid<=calc_result_valid;
            frame_calc_div0<=calc_div0; frame_calc_overflow<=calc_overflow; frame_calc_busy<=calc_busy;
            frame_history_view<=calc_active&&sw13_level; frame_history_count<=calc_history_count;
            frame_history_select<=calc_history_select; frame_history_0<=calc_history_0;
            frame_history_1<=calc_history_1; frame_history_2<=calc_history_2;
            frame_recall_error<=calc_recall_error;
            frame_graph_count<=graph_count; frame_graph1_type<=graph1_type; frame_graph2_type<=graph2_type;
            frame_a1<=a1; frame_b1<=b1; frame_c1<=c1; frame_a2<=a2; frame_b2<=b2; frame_c2<=c2;
            frame_graph_state<=graph_state; frame_current_graph<=current_graph; frame_graph_draw<=graph_draw;
            frame_graph_status<=graph_status; frame_intersection_valid<=intersection_valid;
            frame_ix<=intersection_x_q4; frame_iy<=intersection_y_q4; frame_scale<=graph_scale;
            frame_origin_x<=graph_origin_x; frame_origin_y<=graph_origin_y;
            frame_cursor_enable<=graph_active&&(sw11_level||sw12_level);
            frame_cursor_x<=sw11_level?mouse_cursor_x_q4:cursor_x_q4;
            frame_cursor_y<=sw11_level?mouse_cursor_y_q4:cursor_y_q4;
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
        .overflow(frame_calc_overflow),.busy(frame_calc_busy),.sw13_history(frame_history_view),
        .history_count(frame_history_count),.history_select(frame_history_select),
        .history_0(frame_history_0),.history_1(frame_history_1),.history_2(frame_history_2),
        .recall_error(frame_recall_error),.pixel_data(calc_pixel_data)
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
        .cursor_enable(frame_cursor_enable),.cursor_x_q4(frame_cursor_x),.cursor_y_q4(frame_cursor_y),
        .screen_x(unused_screen_x),.screen_y(unused_screen_y),.pixel_data(graph_pixel_data)
    );
    wire compact_text_on;
    wire [15:0] compact_text_pixel;
    compact_text_renderer shared_text(
        .mode(frame_mode),.screen_x(unused_screen_x),.screen_y(unused_screen_y),
        .input_value(frame_input),.calc_a(frame_calc_a),.calc_state(frame_calc_state),
        .calc_result(frame_calc_result),.calc_result_valid(frame_calc_result_valid),
        .calc_div0(frame_calc_div0),.calc_overflow(frame_calc_overflow),
        .calc_busy(frame_calc_busy),.history_view(frame_history_view),
        .history_count(frame_history_count),.history_0(frame_history_0),
        .history_1(frame_history_1),.history_2(frame_history_2),
        .recall_error(frame_recall_error),.graph_count(frame_graph_count),
        .graph_state(frame_graph_state),.current_graph(frame_current_graph),
        .graph_draw(frame_graph_draw),.graph_status(frame_graph_status),
        .cursor_enable(frame_cursor_enable),.cursor_x_q4(frame_cursor_x),
        .cursor_y_q4(frame_cursor_y),.text_on(compact_text_on),
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

    assign JA[0]=oled_cs; assign JA[1]=oled_sdin; assign JA[2]=1'b0; assign JA[3]=oled_sclk;
    assign JA[4]=oled_d_cn; assign JA[5]=oled_resn; assign JA[6]=oled_vccen; assign JA[7]=oled_pmoden;

    reg [15:0] led_value;
    always @* begin
        led_value=16'd0;
        led_value[13]=sw11_level;
        led_value[14]=sw11_level&&mouse_setup_done;
        if(mode==MODE_MENU) led_value[0]=1'b1;
        else if(mode==MODE_CALC) begin
            led_value[1]=1'b1; led_value[4:2]=calc_state;
            led_value[5]=calc_operation_valid; led_value[6]=calc_result_valid;
            led_value[7]=calc_div0; led_value[8]=calc_overflow;
            led_value[10:9]=calc_history_count; led_value[11]=calc_busy;
        end else begin
            led_value[2:0]=graph_state; led_value[3]=graph_ready; led_value[4]=graph_draw;
            led_value[5]=current_graph; led_value[7:6]=graph_count;
            led_value[10:8]=graph_status; led_value[11]=intersection_valid;
            led_value[15:12]=graph_scale;
        end
    end
    assign led=led_value;
endmodule
