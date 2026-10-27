`timescale 1ns / 1ps

module graph_renderer_tb;
    reg clk=0;
    always #5 clk=~clk;
    reg pixel_clk=0;
    always #80 pixel_clk=~pixel_clk;
    reg [12:0] pixel_index=0;
    reg [1:0] graph_count=2;
    reg graph1_type=0, graph2_type=0;
    reg cubic1=0,cubic2=0;
    reg signed [7:0] a1=0,b1=1,c1=0,a2=0,b2=-1,c2=0;
    reg signed [7:0] d1=0,d2=0;
    reg signed [7:0] current_input=0;
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
    integer input_value, text_x, text_y, magnitude, x_magnitude, y_magnitude;
    integer x_integer, y_integer;
    reg expected_text;

    graph_renderer dut(
        .clk(clk),.pixel_clk(pixel_clk),
        .pixel_index(pixel_index),.graph_count(graph_count),
        .graph1_type(graph1_type),.graph2_type(graph2_type),
        .cubic1(cubic1),.cubic2(cubic2),
        .a1(a1),.b1(b1),.c1(c1),.d1(d1),
        .a2(a2),.b2(b2),.c2(c2),.d2(d2),
        .current_input(current_input),
        .controller_state(state),.current_graph(current_graph),.draw_enable(draw),
        .graph_status(status),.intersection_valid(intersection_valid),
        .intersection_x_q4(ix),.intersection_y_q4(iy),
        .intersection2_valid(intersection2_valid),
        .intersection2_x_q4(ix2),.intersection2_y_q4(iy2),
        .scale_px_per_unit(scale),.origin_x(origin_x),.origin_y(origin_y),
        .cursor_enable(cursor_enable),.cursor_x_q4(cursor_x),.cursor_y_q4(cursor_y),
        .screen_x(screen_x),.screen_y(screen_y),.pixel_data(pixel_data)
    );

    task wait_cache;
        integer cycles;
        begin
            // Allow the OLED read stage to invalidate an old view before
            // waiting for the new 100 MHz table build to finish.
            repeat(2) @(posedge pixel_clk);
            #1;
            for(cycles=0; !dut.cache_ready && cycles<4000; cycles=cycles+1) begin
                @(posedge clk);#1;
            end
            if(!dut.cache_ready) begin
                $display("FAIL graph cache timeout phase=%0d",dut.curve_cache.phase);
                $finish_and_return(1);
            end
        end
    endtask

    task sample_current_pixel;
        begin @(posedge pixel_clk); #1; end
    endtask

    // Independent digit bitmaps and arithmetic form the display oracle.
    // Division is deliberately confined to this nonsynthesizable testbench.
    function reference_digit_pixel;
        input integer digit, column, row;
        reg [34:0] pattern;
        begin
            case(digit)
                0: pattern=35'b01110_10001_10011_10101_11001_10001_01110;
                1: pattern=35'b00100_01100_00100_00100_00100_00100_01110;
                2: pattern=35'b01110_10001_00001_00010_00100_01000_11111;
                3: pattern=35'b11110_00001_00001_01110_00001_00001_11110;
                4: pattern=35'b00010_00110_01010_10010_11111_00010_00010;
                5: pattern=35'b11111_10000_10000_11110_00001_00001_11110;
                6: pattern=35'b01110_10000_10000_11110_10001_10001_01110;
                7: pattern=35'b11111_00001_00010_00100_01000_01000_01000;
                8: pattern=35'b01110_10001_10001_01110_10001_10001_01110;
                9: pattern=35'b01110_10001_10001_01111_00001_00001_01110;
                default: pattern=0;
            endcase
            reference_digit_pixel=0;
            if(column>=0 && column<5 && row>=0 && row<7)
                reference_digit_pixel=pattern[34-row*5-column];
        end
    endfunction

    initial begin
        wait_cache();
        green_count=0; orange_count=0; white_count=0;
        for(i=0;i<6144;i=i+1) begin
            pixel_index=i; sample_current_pixel();
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
            pixel_index=i; sample_current_pixel();
            if(pixel_data==16'hF800) red_count=red_count+1;
            if(pixel_data==16'hFFFF) white_count=white_count+1;
        end
        if(red_count==0 || white_count!=0) begin
            $display("FAIL invalid marker/status red=%0d white=%0d",red_count,white_count);
            $finish_and_return(1);
        end

        status=0; graph1_type=1; a1=1; b1=0; cursor_enable=1;
        intersection_valid=0; origin_x=40; origin_y=20;
        wait_cache();
        pixel_index=20*96+40; sample_current_pixel();
        if(pixel_data!=16'h07FF) begin
            $display("FAIL cursor/pan got=%h",pixel_data);
            $finish_and_return(1);
        end
        pixel_index=38*96+52; sample_current_pixel();
        if(pixel_data!=16'h07FF) begin
            $display("FAIL cursor coordinate label got=%h",pixel_data);
            $finish_and_return(1);
        end
        cursor_enable=0; pixel_index=16*96+44; sample_current_pixel();
        if(pixel_data!=16'h07E0) begin
            $display("FAIL quadratic got=%h",pixel_data);
            $finish_and_return(1);
        end

        // Zooming out must retain a readable grid and correct signed cubic
        // pixels. At scale 1, x=1 maps one pixel right and y=1 one pixel up.
        graph_count=1;graph1_type=0;cubic1=1;
        a1=1;b1=0;c1=0;d1=0;
        origin_x=48;origin_y=32;scale=1;
        wait_cache();
        pixel_index=31*96+49;sample_current_pixel();
        if(pixel_data!=16'h07E0) begin
            $display("FAIL cubic zoom-out pixel=%h ready=%b phase=%0d bounds=%h",
                     pixel_data,dut.cache_ready,dut.curve_cache.phase,dut.bounds1);
            $finish_and_return(1);
        end
        // No every-other-column grid flood at minimum scale.
        pixel_index=19*96+54;sample_current_pixel();
        if(pixel_data==16'h2104) begin
            $display("FAIL zoom-out grid flood");$finish_and_return(1);
        end
        // Use all four coefficients and a negative x value as well.
        // y=x^3+2x^2-3x+1: f(1)=1 and f(-1)=5.
        b1=2;c1=-3;d1=1;scale=4;
        wait_cache();
        pixel_index=28*96+52;sample_current_pixel();
        if(pixel_data!=16'h07E0) begin
            $display("FAIL full cubic positive x=%h ready=%b bounds=%h",
                     pixel_data,dut.cache_ready,dut.bounds1);
            $finish_and_return(1);
        end
        pixel_index=12*96+44;sample_current_pixel();
        if(pixel_data!=16'h07E0) begin
            $display("FAIL full cubic negative x=%h",pixel_data);$finish_and_return(1);
        end
        cubic1=0;graph1_type=1;a1=1;b1=2;c1=-3;d1=0;
        wait_cache();
        // x=2 => y=5, so screen (56,12) at four pixels per unit.
        pixel_index=12*96+56;sample_current_pixel();
        if(pixel_data!=16'h07E0) begin
            $display("FAIL full quadratic zoom scale=%h",pixel_data);$finish_and_return(1);
        end
        // Both independent intersection positions are rendered.
        cubic1=0;intersection_valid=1;intersection2_valid=1;
        ix=-16;iy=0;ix2=16;iy2=0;scale=4;
        wait_cache();
        pixel_index=32*96+44;sample_current_pixel();
        if(pixel_data!=16'hFFFF) begin
            $display("FAIL first marker=%h",pixel_data);$finish_and_return(1);
        end
        pixel_index=32*96+52;sample_current_pixel();
        if(pixel_data!=16'hFFFF) begin
            $display("FAIL second marker=%h",pixel_data);$finish_and_return(1);
        end

        // Both cubic caches must finish with the extra timing pipeline.
        intersection_valid=0;intersection2_valid=0;
        graph_count=2;graph1_type=0;graph2_type=0;cubic1=1;cubic2=1;
        a1=1;b1=0;c1=0;d1=0;
        a2=-1;b2=0;c2=0;d2=0;
        origin_x=48;origin_y=32;scale=1;
        wait_cache();
        if(!dut.cache_ready) begin
            $display("FAIL two-cubic cache did not finish");$finish_and_return(1);
        end
        pixel_index=31*96+49;sample_current_pixel();
        if(pixel_data!=16'h07E0) begin
            $display("FAIL two-cubic first curve=%h",pixel_data);$finish_and_return(1);
        end
        // At x=1 the 1-pixel continuity tolerance overlaps the curves;
        // x=2 separates them and checks graph 2's own cached result.
        pixel_index=40*96+50;sample_current_pixel();
        if(pixel_data!=16'hFD20) begin
            $display("FAIL two-cubic second curve=%h",pixel_data);$finish_and_return(1);
        end
        origin_x=40;scale=4;
        wait_cache();
        if(!dut.cache_ready) begin
            $display("FAIL two-cubic cache after pan/zoom");$finish_and_return(1);
        end
        pixel_index=28*96+44;sample_current_pixel();
        if(pixel_data!=16'h07E0) begin
            $display("FAIL panned cubic first curve=%h",pixel_data);$finish_and_return(1);
        end
        pixel_index=36*96+44;sample_current_pixel();
        if(pixel_data!=16'hFD20) begin
            $display("FAIL panned cubic second curve=%h",pixel_data);$finish_and_return(1);
        end

        // Exhaust every signed switch value, including -128, and compare
        // the complete numeric field with independently formatted digits.
        draw=0;state=2;cursor_enable=0;
        for(input_value=-128;input_value<=127;input_value=input_value+1) begin
            current_input=input_value;
            magnitude=(input_value<0)?-input_value:input_value;
            for(text_y=20;text_y<27;text_y=text_y+1) begin
                for(text_x=34;text_x<57;text_x=text_x+1) begin
                    expected_text=(input_value<0 && text_y==23 && text_x>=35 && text_x<=37) ||
                        (magnitude>=100 && reference_digit_pixel(magnitude/100,text_x-40,text_y-20)) ||
                        (magnitude>=10 && reference_digit_pixel((magnitude/10)%10,text_x-46,text_y-20)) ||
                        reference_digit_pixel(magnitude%10,text_x-52,text_y-20);
                    pixel_index=text_y*96+text_x;#1;
                    if(pixel_data !== (expected_text?16'hFFFF:16'h0000)) begin
                        $display("FAIL input text value=%0d x=%0d y=%0d got=%h expected=%b",
                                 input_value,text_x,text_y,pixel_data,expected_text);
                        $finish_and_return(1);
                    end
                end
            end
        end

        // The same bounded formatter serves signed Q4 cursor coordinates.
        // Cover both signs, the -32768 magnitude, saturation and fractions.
        for(i=-32768;i<=32767;i=i+1) begin
            cursor_x=i;cursor_y=-i-1;#1;
            x_magnitude=(i<0)?-i:i;
            y_magnitude=(-i-1<0)?i+1:-i-1;
            x_integer=x_magnitude/16;y_integer=y_magnitude/16;
            if(x_integer>99) x_integer=99;
            if(y_integer>99) y_integer=99;
            if(dut.cursor_x_digits[7:4] !== x_integer/10 ||
               dut.cursor_x_digits[3:0] !== x_integer%10 ||
               dut.cursor_y_digits[7:4] !== y_integer/10 ||
               dut.cursor_y_digits[3:0] !== y_integer%10 ||
               dut.cursor_x_fraction !== ((x_magnitude%16>=8)?4'd5:4'd0) ||
               dut.cursor_y_fraction !== ((y_magnitude%16>=8)?4'd5:4'd0)) begin
                $display("FAIL Q4 decimal formatting x=%0d y=%0d",cursor_x,cursor_y);
                $finish_and_return(1);
            end
        end

        $display("PASS graph renderer curves, markers, all signed input labels and full Q4 decimal range");
        $finish;
    end
endmodule
