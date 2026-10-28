`timescale 1ns / 1ps

module graph_renderer_tb;
    reg clk=0;
    always #5 clk=~clk;
    reg [12:0] pixel_index;
    reg [1:0] graph_count=2;
    reg graph1_type=0, graph2_type=0;
    reg signed [7:0] a1=0,b1=1,c1=0,a2=0,b2=-1,c2=0;
    reg [2:0] state=7;
    reg current_graph=0, draw=1;
    reg [2:0] status=0;
    reg intersection_valid=1;
    reg intersection2_valid=0;
    reg signed [15:0] ix=0,iy=0,cursor_x=0,cursor_y=0;
    reg signed [15:0] ix2=0,iy2=0;
    reg [3:0] scale=4;
    reg [6:0] origin_x=48;
    reg [5:0] origin_y=32;
    reg cursor_enable=0;
    wire [6:0] screen_x;
    wire [5:0] screen_y;
    wire [15:0] pixel_data;
    integer i, green_count, orange_count, white_count, red_count;

    graph_renderer dut(
        .pixel_index(pixel_index),.graph_count(graph_count),
        .graph1_type(graph1_type),.graph2_type(graph2_type),
        .a1(a1),.b1(b1),.c1(c1),
        .a2(a2),.b2(b2),.c2(c2),
        .current_input(8'sd0),
        .controller_state(state),.current_graph(current_graph),.draw_enable(draw),
        .graph_status(status),.intersection_valid(intersection_valid),
        .intersection_x_q4(ix),.intersection_y_q4(iy),
        .intersection2_valid(intersection2_valid),
        .intersection2_x_q4(ix2),.intersection2_y_q4(iy2),
        .scale_px_per_unit(scale),.origin_x(origin_x),.origin_y(origin_y),
        .cursor_enable(cursor_enable),.cursor_x_q4(cursor_x),.cursor_y_q4(cursor_y),
        .screen_x(screen_x),.screen_y(screen_y),.pixel_data(pixel_data)
    );

    initial begin
        repeat(4) @(posedge clk);#1;
        green_count=0; orange_count=0; white_count=0;
        for(i=0;i<6144;i=i+1) begin
            pixel_index=i; #1;
            if(pixel_data==16'h07E0) green_count=green_count+1;
            if(pixel_data==16'hFD20) orange_count=orange_count+1;
            if(pixel_data==16'hFFFF) white_count=white_count+1;
        end
        if(green_count<40 || orange_count<40 || white_count<5) begin
            $display("FAIL lines marker g=%0d o=%0d w=%0d",
                     green_count,orange_count,white_count);
            $finish_and_return(1);
        end

        status=1; intersection_valid=0; red_count=0; white_count=0;
        for(i=0;i<6144;i=i+1) begin
            pixel_index=i; #1;
            if(pixel_data==16'hF800) red_count=red_count+1;
            if(pixel_data==16'hFFFF) white_count=white_count+1;
        end
        if(red_count==0 || white_count!=0) begin
            $display("FAIL invalid marker/status red=%0d white=%0d",red_count,white_count);
            $finish_and_return(1);
        end

        status=0; graph1_type=1; a1=1; b1=0; cursor_enable=1;
        intersection_valid=0; origin_x=40; origin_y=20;
        repeat(4) @(posedge clk);#1;
        pixel_index=20*96+40; #1;
        if(pixel_data!=16'h07FF) begin
            $display("FAIL cursor/pan got=%h",pixel_data);
            $finish_and_return(1);
        end
        pixel_index=38*96+52; #1;
        if(pixel_data!=16'h07FF) begin
            $display("FAIL cursor coordinate label got=%h",pixel_data);
            $finish_and_return(1);
        end
        cursor_enable=0; pixel_index=16*96+44; #1;
        if(pixel_data!=16'h07E0) begin
            $display("FAIL quadratic got=%h",pixel_data);
            $finish_and_return(1);
        end

        // Zooming out retains a readable grid and correct signed quadratic
        // pixels. At scale 1, x=1 maps one pixel right and y=1 one pixel up.
        graph_count=1;graph1_type=1;
        a1=1;b1=0;c1=0;
        origin_x=48;origin_y=32;scale=1;
        repeat(4) @(posedge clk);#1;
        pixel_index=31*96+49;#1;
        if(pixel_data!=16'h07E0) begin
            $display("FAIL quadratic zoom-out pixel=%h",pixel_data);
            $finish_and_return(1);
        end
        // No every-other-column grid flood at minimum scale.
        pixel_index=19*96+54;#1;
        if(pixel_data==16'h2104) begin
            $display("FAIL zoom-out grid flood");$finish_and_return(1);
        end
        // Negative x with a negative linear and constant coefficient.
        // y=x^2+2x-3: f(1)=0 and f(-1)=-4.
        b1=2;c1=-3;scale=4;
        repeat(4) @(posedge clk);#1;
        pixel_index=32*96+52;#1;
        if(pixel_data!=16'h07E0) begin
            $display("FAIL full quadratic positive x=%h",pixel_data);
            $finish_and_return(1);
        end
        pixel_index=48*96+44;#1;
        if(pixel_data!=16'h07E0) begin
            $display("FAIL full quadratic negative x=%h",pixel_data);
            $finish_and_return(1);
        end
        // Both independent intersection positions are rendered.
        intersection_valid=1;intersection2_valid=1;
        ix=-16;iy=0;ix2=16;iy2=0;scale=4;
        repeat(4) @(posedge clk);#1;
        pixel_index=32*96+44;#1;
        if(pixel_data!=16'hFFFF) begin
            $display("FAIL first marker=%h",pixel_data);$finish_and_return(1);
        end
        pixel_index=32*96+52;#1;
        if(pixel_data!=16'hFFFF) begin
            $display("FAIL second marker=%h",pixel_data);$finish_and_return(1);
        end

        $display("PASS graph renderer linear, quadratic, zoom and two markers");
        $finish;
    end
endmodule
