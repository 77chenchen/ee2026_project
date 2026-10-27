`timescale 1ns / 1ps
module compact_text_renderer_tb;
    reg [1:0] mode=0;
    reg [1:0] menu_arrow=0;
    reg [6:0] x=0;
    reg [5:0] y=0;
    reg signed [7:0] input_value=-12,calc_a=8;
    reg [2:0] calc_state=0,graph_state=7,graph_status=0;
    reg signed [15:0] calc_result=13,history_0=13,history_1=-4,history_2=200;
    reg calc_result_valid=1,calc_div0=0,calc_overflow=0,calc_busy=0;
    reg history_view=0,recall_error=0;
    reg [1:0] history_count=3,graph_count=2;
    reg current_graph=0,graph_draw=1,cursor_enable=1;
    reg signed [15:0] cursor_x_q4=4,cursor_y_q4=-8;
    wire text_on;
    wire [15:0] pixel;

    compact_text_renderer dut(
        .mode(mode),.menu_arrow(menu_arrow),.screen_x(x),.screen_y(y),.input_value(input_value),
        .calc_a(calc_a),.calc_state(calc_state),.calc_result(calc_result),
        .calc_result_valid(calc_result_valid),.calc_div0(calc_div0),
        .calc_overflow(calc_overflow),.calc_busy(calc_busy),
        .history_view(history_view),.history_count(history_count),
        .history_0(history_0),.history_1(history_1),.history_2(history_2),
        .recall_error(recall_error),.graph_count(graph_count),
        .graph_state(graph_state),.current_graph(current_graph),
        .graph_draw(graph_draw),.graph_status(graph_status),
        .cursor_enable(cursor_enable),.cursor_x_q4(cursor_x_q4),
        .cursor_y_q4(cursor_y_q4),.text_on(text_on),.text_pixel_data(pixel)
    );

    initial begin
        mode=0;x=26;y=8;#1;
        if(!text_on||pixel!=16'h07FF)begin $display("FAIL shared menu font");$finish_and_return(1);end
        mode=0;menu_arrow=1;x=24;y=48;#1;
        if(!text_on||pixel!=16'hFFE0)begin $display("FAIL menu selected graph entry");$finish_and_return(1);end
        mode=1;calc_state=0;x=25;y=27;#1;
        if(!text_on||pixel!=16'h07E0)begin $display("FAIL shared signed number");$finish_and_return(1);end
        mode=2;x=54;y=32;#1;
        if(!text_on||pixel!=16'h07FF)begin $display("FAIL shared cursor label");$finish_and_return(1);end
        graph_status=1;x=72;y=0;#1;
        if(!text_on||pixel!=16'hF800)begin $display("FAIL shared graph status");$finish_and_return(1);end
        $display("PASS compact shared text for menu, calculator and graph");
        $finish;
    end
endmodule
