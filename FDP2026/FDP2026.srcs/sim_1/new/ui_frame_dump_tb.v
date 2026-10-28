`timescale 1ns / 1ps
module ui_frame_dump_tb;
    reg clk=0,pixel_clk=0;
    always #5 clk=~clk;
    always #80 pixel_clk=~pixel_clk;
    reg [12:0] pixel_index;
    wire [15:0] menu_pixel,calc_pixel,graph_pixel;
    wire [6:0] sx; wire [5:0] sy;
    reg [2:0] graph_state=3'd7;
    reg graph_draw=1'b1;
    reg signed [7:0] graph_input=-8'sd12;
    integer f,i;

    menu_renderer menu(.pixel_index(pixel_index),.pixel_data(menu_pixel));
    calculator_renderer calc(
        .pixel_index(pixel_index),.input_value(8'sd5),.operand_a(8'sd8),
        .operand_b(8'sd5),.state(3'd4),.operation(2'd0),.operation_valid(1'b1),
        .result(16'sd13),.result_valid(1'b1),.divide_by_zero(1'b0),
        .overflow(1'b0),.busy(1'b0),.sw13_history(1'b0),.history_count(2'd3),
        .history_select(2'd0),.history_0(16'sd13),.history_1(-16'sd4),
        .history_2(16'sd200),.recall_error(1'b0),.pixel_data(calc_pixel)
    );
    graph_renderer graph(
        .clk(clk),.pixel_clk(pixel_clk),
        .pixel_index(pixel_index),.graph_count(2'd2),.graph1_type(1'b0),.graph2_type(1'b1),
        .cubic1(1'b0),.cubic2(1'b0),.d1(8'sd0),.d2(8'sd0),
        .a1(8'sd0),.b1(8'sd1),.c1(8'sd0),.a2(8'sd1),.b2(8'sd0),.c2(-8'sd3),.current_input(graph_input),
        .controller_state(graph_state),.current_graph(1'b0),.draw_enable(graph_draw),.graph_status(3'd0),
        .intersection_valid(1'b1),.intersection_x_q4(16'sd0),.intersection_y_q4(16'sd0),
        .intersection2_valid(1'b0),.intersection2_x_q4(16'sd0),.intersection2_y_q4(16'sd0),
        .scale_px_per_unit(4'd4),.origin_x(7'd48),.origin_y(6'd32),.cursor_enable(1'b1),
        .cursor_x_q4(16'sd16),.cursor_y_q4(16'sd16),.screen_x(sx),.screen_y(sy),
        .pixel_data(graph_pixel)
    );

    task write_rgb;
        input integer fd; input [15:0] colour;
        integer red,green,blue;
        begin
            red=((colour>>11)&31)*255/31;
            green=((colour>>5)&63)*255/63;
            blue=(colour&31)*255/31;
            $fwrite(fd,"%0d %0d %0d\n",red,green,blue);
        end
    endtask

    initial begin
        pixel_index=0;
        wait(graph.cache_ready);
        f=$fopen("menu.ppm","w"); $fwrite(f,"P3\n96 64\n255\n");
        for(i=0;i<6144;i=i+1)begin pixel_index=i;#1;write_rgb(f,menu_pixel);end $fclose(f);
        f=$fopen("calculator.ppm","w"); $fwrite(f,"P3\n96 64\n255\n");
        for(i=0;i<6144;i=i+1)begin pixel_index=i;#1;write_rgb(f,calc_pixel);end $fclose(f);
        f=$fopen("graph.ppm","w"); $fwrite(f,"P3\n96 64\n255\n");
        for(i=0;i<6144;i=i+1)begin pixel_index=i;@(posedge pixel_clk);#1;write_rgb(f,graph_pixel);end $fclose(f);
        graph_state=3'd3; graph_draw=1'b0;
        f=$fopen("graph_input.ppm","w"); $fwrite(f,"P3\n96 64\n255\n");
        for(i=0;i<6144;i=i+1)begin pixel_index=i;#1;write_rgb(f,graph_pixel);end $fclose(f);
        $display("PASS wrote OLED preview frames");
        $finish;
    end
endmodule
