`timescale 1ns / 1ps

module mouse_graph_adapter_tb;
    reg clk=0;
    reg reset=0;
    reg mouse_enable=0;
    reg view_graph=0;
    reg new_event=0;
    reg [11:0] xpos=48, ypos=32;
    reg [3:0] zpos=0;
    reg left=0, right=0;
    reg [3:0] scale=4;
    reg [6:0] origin_x=48;
    reg [5:0] origin_y=32;

    wire setup_done;
    wire [11:0] setup_value;
    wire setup_setx,setup_sety,setup_setmax_x,setup_setmax_y;
    wire zoom_in,zoom_out,recenter,reset_view;
    wire [6:0] screen_x;
    wire [5:0] screen_y;
    wire signed [15:0] cursor_x_q4,cursor_y_q4;

    integer pulse_errors=0;
    integer pulse_count=0;
    integer count_at_event;
    reg seen_zoom_in,seen_zoom_out,seen_recenter,seen_reset_view;

    always #5 clk=~clk;

    mouse_graph_adapter dut(
        .clk(clk),.reset(reset),.mouse_enable(mouse_enable),.view_graph(view_graph),
        .new_event(new_event),.xpos(xpos),.ypos(ypos),.zpos(zpos),
        .left(left),.right(right),.scale(scale),.origin_x(origin_x),.origin_y(origin_y),
        .setup_done(setup_done),.setup_value(setup_value),
        .setup_setx(setup_setx),.setup_sety(setup_sety),
        .setup_setmax_x(setup_setmax_x),.setup_setmax_y(setup_setmax_y),
        .mouse_zoom_in(zoom_in),.mouse_zoom_out(zoom_out),
        .mouse_recenter(recenter),.mouse_reset_view(reset_view),
        .mouse_screen_x(screen_x),.mouse_screen_y(screen_y),
        .cursor_x_q4(cursor_x_q4),.cursor_y_q4(cursor_y_q4)
    );

    task do_event;
        begin
            new_event=1;
            @(posedge clk); #1;
            count_at_event=pulse_count;
            new_event=0;
            @(posedge clk); #1;
            if((pulse_count-count_at_event)!=0) begin
                $display("FAIL more than one clock pulse from new_event");
                pulse_errors=pulse_errors+1;
            end
        end
    endtask

    task expect_coord;
        input [6:0] ex;
        input [5:0] ey;
        input integer eqx;
        input integer eqy;
        begin
            if(screen_x!=ex || screen_y!=ey ||
               cursor_x_q4!==eqx || cursor_y_q4!==eqy) begin
                $display("FAIL coordinate (%0d,%0d) scale=%0d: got (%0d,%0d) q4=(%0d,%0d), expected (%0d,%0d) q4=(%0d,%0d)",
                         xpos,ypos,scale,screen_x,screen_y,cursor_x_q4,cursor_y_q4,ex,ey,eqx,eqy);
                pulse_errors=pulse_errors+1;
            end
        end
    endtask

    task expect_pulse;
        input which;
        input expected;
        reg actual;
        begin
            case(which)
                0: actual=zoom_in; 1: actual=zoom_out; 2: actual=recenter; 3: actual=reset_view;
            endcase
            if(actual!==expected) begin
                $display("FAIL pulse %0d expected=%0d got=%0d",which,expected,actual);
                pulse_errors=pulse_errors+1;
            end
        end
    endtask

    initial begin
        reset=1; repeat(2) @(posedge clk); #1; reset=0;
        if(setup_done!==0) begin $display("FAIL setup_done during reset"); pulse_errors=pulse_errors+1; end

        // Confirm the exact MouseCtl configuration sequence: each command lasts
        // one setup-state clock, max_x/max_y first and x/y origin second.
        if(dut.setup_state!==0 || setup_setx || setup_sety || setup_setmax_x || setup_setmax_y || setup_value!==0) begin
            $display("FAIL setup idle state=%0d value=%0d",dut.setup_state,setup_value);
            pulse_errors=pulse_errors+1;
        end
        @(posedge clk); #1;
        if(dut.setup_state!==1 || !setup_setmax_x || setup_value!==95) begin
            $display("FAIL setup max_x state=%0d strobe=%0b value=%0d",dut.setup_state,setup_setmax_x,setup_value);
            pulse_errors=pulse_errors+1;
        end
        @(posedge clk); #1;
        if(dut.setup_state!==2 || !setup_setmax_y || setup_value!==63) begin
            $display("FAIL setup max_y state=%0d strobe=%0b value=%0d",dut.setup_state,setup_setmax_y,setup_value);
            pulse_errors=pulse_errors+1;
        end
        @(posedge clk); #1;
        if(dut.setup_state!==3 || !setup_setx || setup_value!==48) begin
            $display("FAIL setup set_x state=%0d strobe=%0b value=%0d",dut.setup_state,setup_setx,setup_value);
            pulse_errors=pulse_errors+1;
        end
        @(posedge clk); #1;
        if(dut.setup_state!==4 || !setup_sety || setup_value!==32) begin
            $display("FAIL setup set_y state=%0d strobe=%0b value=%0d",dut.setup_state,setup_sety,setup_value);
            pulse_errors=pulse_errors+1;
        end
        @(posedge clk); #1;
        if(!setup_done) begin
            $display("FAIL setup sequence not complete");
            pulse_errors=pulse_errors+1;
        end
        if(dut.SETUP_MAX_X!==3'd1 || dut.SETUP_MAX_Y!==3'd2 ||
           dut.SETUP_SET_X!==3'd3 || dut.SETUP_SET_Y!==3'd4) begin
            $display("FAIL setup command ordering constants");
            pulse_errors=pulse_errors+1;
        end
        repeat(2) @(posedge clk); #1;

        do_event();
        expect_coord(48,32,0,0);

        scale=1; xpos=44; ypos=28; do_event(); expect_coord(44,28,-64,64);
        scale=2; xpos=44; ypos=28; do_event(); expect_coord(44,28,-32,32);
        scale=4; xpos=44; ypos=28; do_event(); expect_coord(44,28,-16,16);
        scale=8; xpos=44; ypos=28; do_event(); expect_coord(44,28,-8,8);
        scale=4; xpos=120; ypos=100; do_event(); expect_coord(95,63,188,-124);
        scale=4; xpos=0; ypos=0; do_event(); expect_coord(0,0,-192,128);

        // The crosshair must remain under the mouse after the graph is panned.
        origin_x=40; origin_y=24; xpos=44; ypos=28;
        do_event(); expect_coord(44,28,16,-16);
        origin_x=48; origin_y=32;

        mouse_enable=1; view_graph=1;
        repeat(2) @(posedge clk); #1;

        // Wheel up/down and the complementary two's-complement values.
        pulse_count=0; seen_zoom_in=0; seen_zoom_out=0;
        fork
            begin #1; if(zoom_in) begin seen_zoom_in=1; pulse_count=pulse_count+1; end
                   #10; if(zoom_in) begin seen_zoom_in=1; pulse_count=pulse_count+1; end end
            begin zpos=1; do_event(); end
        join
        if(!seen_zoom_in || seen_zoom_out || pulse_count!=1) begin
            $display("FAIL zoom-in pulse seen_in=%0b seen_out=%0b count=%0d",seen_zoom_in,seen_zoom_out,pulse_count);
            pulse_errors=pulse_errors+1;
        end

        pulse_count=0; seen_zoom_in=0; seen_zoom_out=0;
        fork
            begin #1; if(zoom_out) begin seen_zoom_out=1; pulse_count=pulse_count+1; end
                   #10; if(zoom_out) begin seen_zoom_out=1; pulse_count=pulse_count+1; end end
            begin zpos=15; do_event(); end
        join
        if(!seen_zoom_out || seen_zoom_in || pulse_count!=1) begin
            $display("FAIL zoom-out pulse seen_in=%0b seen_out=%0b count=%0d",seen_zoom_in,seen_zoom_out,pulse_count);
            pulse_errors=pulse_errors+1;
        end

        // Left click once on a held button.
        pulse_count=0; seen_recenter=0; left=1;
        fork begin #1; if(recenter) begin seen_recenter=1; pulse_count=pulse_count+1; end
                    #10; if(recenter) begin seen_recenter=1; pulse_count=pulse_count+1; end end
              begin do_event(); end
        join
        if(!seen_recenter || pulse_count!=1) begin
            $display("FAIL left click edge count=%0d",pulse_count); pulse_errors=pulse_errors+1;
        end
        do_event(); // still held, no second recenter

        // Right click once, including press/release/press edges.
        pulse_count=0; seen_reset_view=0; left=0; right=1;
        fork begin #1; if(reset_view) begin seen_reset_view=1; pulse_count=pulse_count+1; end
                    #10; if(reset_view) begin seen_reset_view=1; pulse_count=pulse_count+1; end end
              begin do_event(); end
        join
        if(!seen_reset_view || pulse_count!=1) begin
            $display("FAIL right click edge count=%0d",pulse_count); pulse_errors=pulse_errors+1;
        end
        right=0; do_event();
        right=1; do_event();

        // Held button state is sampled on every mouse event while disabled, so
        // re-enabling must not invent a click.
        mouse_enable=0; repeat(2) @(posedge clk); #1;
        left=1; do_event();
        mouse_enable=1; repeat(2) @(posedge clk); #1;
        pulse_count=0;
        fork begin #1; if(recenter) pulse_count=pulse_count+1; #10; if(recenter) pulse_count=pulse_count+1; end
              begin do_event(); end
        join
        if(pulse_count!=0) begin $display("FAIL stale held click"); pulse_errors=pulse_errors+1; end
        left=0; do_event();

        // Gating: operation pulses are suppressed outside VIEW_GRAPH and while
        // setup is not complete, while held-button state keeps updating.
        view_graph=0; zpos=1; right=1;
        do_event(); expect_pulse(0,0); expect_pulse(3,0);
        view_graph=1; right=0; repeat(2) @(posedge clk); #1; right=1; do_event(); expect_pulse(3,0);
        right=0; repeat(2) @(posedge clk); #1;

        if(pulse_errors==0) $display("PASS mouse_graph_adapter setup, coordinates, zoom, clicks and gating");
        else begin $display("FAILED mouse_graph_adapter with %0d errors",pulse_errors); $finish_and_return(1); end
        $finish;
    end
endmodule
