`timescale 1ns / 1ps

// End-to-end test of direct curve evaluation, pixel address and real SPI
// serialization. The oracle evaluates the functions independently, rather
// than comparing the renderer against its own intermediate values.
module graph_oled_tb;
    reg clk=0;
    always #5 clk=~clk;
    reg [3:0] divider=0;
    always @(posedge clk) divider<=divider+1'b1;
    wire pixel_clk=divider[3];
    reg reset=1;
    reg quadratic1=0,quadratic2=0;
    reg signed [7:0] a1=0,b1=1,c1=0,a2=0,b2=-1,c2=0;
    reg [3:0] scale=4;
    reg [6:0] ox=48;
    reg [5:0] oy=32;
    wire frame_begin,sending_pixels,sample_pixel;
    wire [12:0] pixel_index;
    wire [15:0] pixel_data;
    wire cs,sdin,sclk,d_cn;
    integer word_count=0,bit_count=0,frames=0,view;
    reg [15:0] serial_word=0;

    graph_renderer #(.INCLUDE_TEXT(0)) graph(
        .pixel_clk(pixel_clk),
        .pixel_index(pixel_index),
        .graph_count(2'd2),.graph1_type(quadratic1),.graph2_type(quadratic2),
        .a1(a1),.b1(b1),.c1(c1),
        .a2(a2),.b2(b2),.c2(c2),
        .current_input(8'sd0),.controller_state(3'd7),.current_graph(1'b0),
        .draw_enable(1'b1),.graph_status(3'd0),
        .intersection_valid(1'b1),.intersection_x_q4(-16'sd16),
        .intersection_y_q4(16'sd0),.intersection2_valid(1'b1),
        .intersection2_x_q4(16'sd48),.intersection2_y_q4(16'sd0),
        .scale_px_per_unit(scale),.origin_x(ox),.origin_y(oy),
        .cursor_enable(1'b0),.cursor_x_q4(16'sd0),.cursor_y_q4(16'sd0),
        .screen_x(),.screen_y(),.pixel_data(pixel_data)
    );
    Oled_Display #(.ClkFreq(6_250_000)) oled(
        .clk(pixel_clk),.reset(reset),.frame_begin(frame_begin),
        .sending_pixels(sending_pixels),.sample_pixel(sample_pixel),
        .pixel_index(pixel_index),.pixel_data(pixel_data),
        .cs(cs),.sdin(sdin),.sclk(sclk),.d_cn(d_cn),
        .resn(),.vccen(),.pmoden()
    );

    // Power sequencing has its own unaccelerated oled_display_tb. Skip only
    // those settling counters here; retain the real SPI FSM and bit timing.
    always @(posedge pixel_clk) begin
        if (!reset && !sending_pixels) oled.delay=0;
    end

    function integer floor_div;
        input integer numerator,denominator;
        begin
            if (numerator<0) floor_div=-((-numerator+denominator-1)/denominator);
            else floor_div=numerator/denominator;
        end
    endfunction
    function integer curve_y;
        input integer graph_number,column;
        integer x,numerator,av,bv,cv,s,y0;
        begin
            x=column-ox;s=scale;y0=oy;
            // Widen signed coefficients before mixing them with unsigned
            // viewport ports; the reference math must stay signed too.
            av=(graph_number==0)?a1:a2;
            bv=(graph_number==0)?b1:b2;
            cv=(graph_number==0)?c1:c2;
            if ((graph_number==0)?quadratic1:quadratic2) begin
                numerator=av*x*x+bv*x*s+cv*s*s;
                curve_y=y0-floor_div(numerator,s);
            end else curve_y=y0-(bv*x+cv*s);
        end
    endfunction
    function curve_pixel;
        input integer graph_number,x,y;
        integer v0,v1,lo,hi;
        begin
            v0=curve_y(graph_number,x-1);
            v1=curve_y(graph_number,x);
            lo=(v0<v1)?v0:v1;
            hi=(v0>v1)?v0:v1;
            curve_pixel=0;
            if (!(lo>63 || hi<0)) begin
                if (lo<0) lo=0;
                if (hi>63) hi=63;
                curve_pixel=(y+1>=lo && y<=hi+1);
            end
        end
    endfunction
    function [15:0] expected_pixel;
        input integer index;
        integer x,y,spacing,mx;
        begin
            x=index%96;y=index/96;
            spacing=(scale<4)?8:scale*2;
            expected_pixel=16'h0000;
            if ((x-ox)%spacing==0 || (y-oy)%spacing==0)
                expected_pixel=16'h2104;
            if (x==ox || y==oy) expected_pixel=16'h7BEF;
            if (curve_pixel(1,x,y)) expected_pixel=16'hFD20;
            if (curve_pixel(0,x,y)) expected_pixel=16'h07E0;
            // Two independent marker crosses, with the same final overlay
            // priority but independently computed positions and footprint.
            mx=ox-scale;
            if ((x==mx && y>=oy-3 && y<=oy+3) ||
                (y==oy && x>=mx-3 && x<=mx+3)) expected_pixel=16'hFFFF;
            mx=ox+3*scale;
            if ((x==mx && y>=oy-3 && y<=oy+3) ||
                (y==oy && x>=mx-3 && x<=mx+3)) expected_pixel=16'hFFFF;
        end
    endfunction

    always @(posedge sending_pixels) begin
        word_count=0;bit_count=0;serial_word=0;
    end
    always @(posedge sclk) begin
        if (!cs && d_cn) begin
            serial_word={serial_word[14:0],sdin};
            bit_count=bit_count+1;
            if (bit_count==16) begin
                if (serial_word!==expected_pixel(word_count))
                    $fatal(1,"view=%0d SPI pixel=%0d (%0d,%0d) expected=%h got=%h",
                           view,word_count,word_count%96,word_count/96,
                           expected_pixel(word_count),serial_word);
                word_count=word_count+1;
                bit_count=0;
            end
        end
    end
    always @(negedge sending_pixels) begin
        if (!reset && word_count!=0) begin
            if (word_count!=6144 || bit_count!=0)
                $fatal(1,"incomplete graph SPI frame: %0d words",word_count);
            frames=frames+1;
        end
    end

    initial begin
        repeat(4) @(posedge pixel_clk);
        #1;reset=0;
        for(view=0;view<4;view=view+1) begin
            if (view>0) begin
                // View changes do not need a RAM rebuild. Test a mixed pair
                // and two quadratics at minimum/maximum zoom and after pan.
                quadratic1=1;quadratic2=1;
                a1=1;b1=-2;c1=-3;
                a2=-1;b2=2;c2=1;
                case(view)
                    1: begin quadratic1=0;scale=1;ox=48;oy=32;end
                    2: begin scale=8;ox=48;oy=32;end
                    3: begin scale=2;ox=40;oy=24;end
                endcase
            end
            wait(sending_pixels);
            @(negedge sending_pixels);#1;
        end
        if (frames!=4) $fatal(1,"expected four complete graph frames");
        $display("PASS direct graph OLED SPI: 24576 RGB565 pixels, row boundaries, two markers, linear/quadratic, zoom and pan");
        $finish;
    end
    initial begin
        #100_000_000;
        $fatal(1,"graph OLED SPI regression timeout");
    end
endmodule
