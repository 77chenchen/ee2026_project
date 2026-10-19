`timescale 1ns / 1ps

module graph_controller_tb;
    reg clk = 0;
    reg reset = 0;
    reg btnC = 0, btnU = 0, btnD = 0, btnL = 0, btnR = 0;
    reg sw0 = 0, sw12 = 0, sw13 = 0, sw14 = 0;
    reg signed [7:0] input_value = 0;
    reg mouse_zoom_in=0,mouse_zoom_out=0,mouse_recenter=0,mouse_reset_view=0;
    reg [6:0] mouse_screen_x=48;
    reg [5:0] mouse_screen_y=32;
    wire [1:0] graph_count;
    wire graph1_type, graph2_type;
    wire signed [7:0] a1,b1,c1,a2,b2,c2;
    wire [2:0] state;
    wire current_graph, ready, draw;
    wire [3:0] scale;
    wire [6:0] origin_x;
    wire [5:0] origin_y;
    wire signed [15:0] cursor_x, cursor_y, ix, iy;
    wire [2:0] status;
    wire intersection_valid;

    always #5 clk = ~clk;

    graph_controller #(.ENABLE_MOUSE(1)) dut(
        .clk(clk), .reset(reset),
        .btnC_pressed(btnC), .btnU_pressed(btnU), .btnD_pressed(btnD),
        .btnL_pressed(btnL), .btnR_pressed(btnR),
        .sw0(sw0), .sw12_cursor(sw12), .sw13_zoom(sw13), .sw14(sw14),
        .input_value(input_value),
        .mouse_zoom_in(mouse_zoom_in), .mouse_zoom_out(mouse_zoom_out),
        .mouse_recenter(mouse_recenter), .mouse_reset_view(mouse_reset_view),
        .mouse_screen_x(mouse_screen_x), .mouse_screen_y(mouse_screen_y),
        .graph_count(graph_count), .graph1_type(graph1_type), .graph2_type(graph2_type),
        .a1(a1),.b1(b1),.c1(c1),.a2(a2),.b2(b2),.c2(c2),
        .state(state), .current_graph(current_graph), .ready(ready), .draw(draw),
        .scale_px_per_unit(scale), .origin_x(origin_x), .origin_y(origin_y),
        .cursor_x_q4(cursor_x), .cursor_y_q4(cursor_y),
        .graph_status(status), .intersection_valid(intersection_valid),
        .intersection_x_q4(ix), .intersection_y_q4(iy)
    );

    task pulse_c;
        begin btnC=1; @(posedge clk); #1; btnC=0; @(posedge clk); #1; end
    endtask
    task pulse_u;
        begin btnU=1; @(posedge clk); #1; btnU=0; @(posedge clk); #1; end
    endtask
    task pulse_d;
        begin btnD=1; @(posedge clk); #1; btnD=0; @(posedge clk); #1; end
    endtask
    task pulse_r;
        begin btnR=1; @(posedge clk); #1; btnR=0; @(posedge clk); #1; end
    endtask
    task pulse_mouse_in;
        begin mouse_zoom_in=1; @(posedge clk); #1; mouse_zoom_in=0; @(posedge clk); #1; end
    endtask
    task pulse_mouse_out;
        begin mouse_zoom_out=1; @(posedge clk); #1; mouse_zoom_out=0; @(posedge clk); #1; end
    endtask
    task pulse_mouse_recenter;
        begin mouse_recenter=1; @(posedge clk); #1; mouse_recenter=0; @(posedge clk); #1; end
    endtask
    task pulse_mouse_reset;
        begin mouse_reset_view=1; @(posedge clk); #1; mouse_reset_view=0; @(posedge clk); #1; end
    endtask

    initial begin
        reset=1; repeat(2) @(posedge clk); #1; reset=0;

        // Keep SW14 high early: it must not skip READY without a new rising edge.
        sw14=1;
        sw0=1; pulse_c();                  // two graphs
        sw0=0; pulse_c();                  // graph 1 linear
        input_value=1; pulse_c();           // b1=1
        input_value=0; pulse_c();           // c1=0
        repeat(2) @(posedge clk); #1;
        sw0=0; pulse_c();                  // graph 2 linear
        input_value=-1; pulse_c();          // b2=-1
        input_value=0; pulse_c();           // c2=0
        repeat(2) @(posedge clk); #1;

        if (!ready || draw || state != 3'd6) begin
            $display("FAIL READY/SW14 edge state=%0d ready=%0d draw=%0d",state,ready,draw);
            $finish_and_return(1);
        end
        if (!intersection_valid || status != 0 || ix != 0 || iy != 0) begin
            $display("FAIL intersection valid=%0d status=%0d x=%0d y=%0d",intersection_valid,status,ix,iy);
            $finish_and_return(1);
        end

        sw14=0; @(posedge clk); #1;
        sw14=1; @(posedge clk); #1;
        if (!draw || state != 3'd7) begin
            $display("FAIL draw transition state=%0d draw=%0d",state,draw);
            $finish_and_return(1);
        end

        sw12=0; sw13=0; pulse_r();
        if (origin_x != 52) begin
            $display("FAIL pan origin_x=%0d",origin_x);
            $finish_and_return(1);
        end
        sw13=1; pulse_u();
        if (scale != 8) begin
            $display("FAIL zoom scale=%0d",scale);
            $finish_and_return(1);
        end
        sw13=0; sw12=1; pulse_r();
        if (cursor_x != 8) begin
            $display("FAIL cursor x=%0d",cursor_x);
            $finish_and_return(1);
        end
        sw12=0; sw13=1; pulse_d(); pulse_d(); pulse_d();
        if (scale != 1) begin
            $display("FAIL zoom minimum scale=%0d",scale);
            $finish_and_return(1);
        end
        sw13=0; sw12=1; pulse_r();
        if (cursor_x != 24) begin
            $display("FAIL scale-1 cursor step x=%0d",cursor_x);
            $finish_and_return(1);
        end

        // Mouse zoom has priority over simultaneous button modes.
        sw12=1; sw13=1; mouse_screen_x=48; mouse_screen_y=32;
        mouse_zoom_out=0; pulse_mouse_in();
        if (scale != 2 || cursor_x != 24) begin
            $display("FAIL mouse zoom priority scale=%0d cursor=%0d",scale,cursor_x);
            $finish_and_return(1);
        end
        pulse_mouse_out();
        if (scale != 1) begin
            $display("FAIL mouse zoom-out scale=%0d",scale); $finish_and_return(1);
        end
        mouse_zoom_out=0;

        // Recenter to the clicked position, clamped at both axes.
        mouse_screen_x=20; mouse_screen_y=15; pulse_mouse_recenter();
        if (origin_x != 80 || origin_y != 49) begin
            $display("FAIL mouse recenter origin=(%0d,%0d)",origin_x,origin_y);
            $finish_and_return(1);
        end
        mouse_screen_x=2; mouse_screen_y=60; pulse_mouse_recenter();
        if (origin_x != 87 || origin_y != 21) begin
            $display("FAIL mouse recenter clamp origin=(%0d,%0d)",origin_x,origin_y);
            $finish_and_return(1);
        end
        mouse_screen_x=95; mouse_screen_y=0; pulse_mouse_recenter();
        if (origin_x != 40 || origin_y != 53) begin
            $display("FAIL mouse recenter max clamp origin=(%0d,%0d)",origin_x,origin_y);
            $finish_and_return(1);
        end
        // Reset has priority over recenter and restores the default view.
        mouse_screen_x=80; mouse_screen_y=50;
        mouse_recenter=1; pulse_mouse_reset();
        if (origin_x != 16 || origin_y != 14 || scale != 4) begin
            $display("FAIL mouse reset priority origin=(%0d,%0d) scale=%0d",origin_x,origin_y,scale);
            $finish_and_return(1);
        end
        // Legacy button control remains valid after mouse operations.
        sw12=0; sw13=0; pulse_r();
        if (origin_x != 8 || origin_y != 8) begin
            $display("FAIL legacy pan after mouse origin_x=%0d",origin_x); $finish_and_return(1);
        end

        // Parallel lines: y=x and y=x+1.
        reset=1; @(posedge clk); #1; reset=0; sw14=0; sw12=0;
        sw0=1; pulse_c(); sw0=0; pulse_c();
        input_value=1; pulse_c(); input_value=0; pulse_c(); repeat(2) @(posedge clk);
        sw0=0; pulse_c(); input_value=1; pulse_c(); input_value=1; pulse_c();
        repeat(2) @(posedge clk); #1;
        if (status != 1 || intersection_valid) begin
            $display("FAIL parallel status=%0d valid=%0d",status,intersection_valid);
            $finish_and_return(1);
        end

        // Identical lines.
        reset=1; @(posedge clk); #1; reset=0;
        sw0=1; pulse_c(); sw0=0; pulse_c();
        input_value=1; pulse_c(); input_value=0; pulse_c(); repeat(2) @(posedge clk);
        sw0=0; pulse_c(); input_value=1; pulse_c(); input_value=0; pulse_c();
        repeat(2) @(posedge clk); #1;
        if (status != 2 || intersection_valid) begin
            $display("FAIL same status=%0d valid=%0d",status,intersection_valid);
            $finish_and_return(1);
        end

        // Intersection outside the current 96x64 view.
        reset=1; @(posedge clk); #1; reset=0;
        sw0=1; pulse_c(); sw0=0; pulse_c();
        input_value=1; pulse_c(); input_value=0; pulse_c(); repeat(2) @(posedge clk);
        sw0=0; pulse_c(); input_value=0; pulse_c(); input_value=100; pulse_c();
        repeat(2) @(posedge clk); #1;
        if (status != 3 || intersection_valid) begin
            $display("FAIL out status=%0d valid=%0d x=%0d",status,intersection_valid,ix);
            $finish_and_return(1);
        end

        $display("PASS graph_controller state, intersection, special cases and view controls");
        $finish;
    end
endmodule
