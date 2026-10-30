`timescale 1ns/1ps
module controls_tb;
    reg CLOCK=0;
    always #5 CLOCK=~CLOCK;
    reg [3:0] sw=0;
    reg SW15=0;
    wire [7:0] JB,led;
    integer p,n,heartbeat_edges=0;
    time previous_edge=0;
    OLED_Test_Top #(.HEARTBEAT_HALF_CYCLES(8),.AUTO_FRAMES(2)) dut(.*);
    always @(posedge dut.oled_clk) begin
        if(previous_edge!=0 && $time-previous_edge!=160) $fatal(1,"OLED clock is not 6.25 MHz");
        previous_edge=$time;
    end
    always @(led[0]) if($time>0) heartbeat_edges=heartbeat_edges+1;
    task switches;
        input [3:0] value;
        begin @(negedge CLOCK);sw=value;repeat(4)@(posedge CLOCK);#1;end
    endtask
    task frame;
        begin
            // Control-only unit test; the separate SPI test uses real frames.
            @(negedge dut.oled_clk);#1;force dut.frame_begin=1'b1;
            @(posedge dut.oled_clk);#1;release dut.frame_begin;
        end
    endtask
    initial begin
        #1;
        if(JB[7]!==0 || JB[2]!==0) $fatal(1,"OLED startup/reset or unused JB pin");
        repeat(200)@(posedge CLOCK);#1;
        if(dut.oled_reset!==0 || JB[7]!==1 || dut.oled.delay==0 || heartbeat_edges<10)
            $fatal(1,"startup divider/reset/heartbeat failed");
        for(p=0;p<8;p=p+1) begin
            switches(p);frame();
            if(led[7:5]!==p[2:0]) $fatal(1,"manual pattern %0d",p);
        end
        switches(0);frame();switches(8);
        for(n=0;n<16;n=n+1) begin
            frame();
            if(dut.active_pattern!==(n/2)) $fatal(1,"auto cycle frame %0d",n);
        end
        switches(3);
        if(dut.active_pattern!==7) $fatal(1,"pattern changed before frame boundary");
        frame();
        if(dut.active_pattern!==3) $fatal(1,"return to manual mode");
        SW15=1;repeat(4)@(posedge CLOCK);repeat(2)@(posedge dut.oled_clk);#1;
        if(dut.oled_reset!==1 || JB[7]!==0) $fatal(1,"SW15 did not hold OLED reset");
        SW15=0;repeat(12)@(posedge dut.oled_clk);#1;
        if(dut.oled_reset!==0 || JB[7]!==1) $fatal(1,"SW15 release did not restart OLED");
        $display("PASS OLED controls: real clock divider, startup, heartbeat, manual/auto modes and reset");
        $finish;
    end
    initial begin #50_000;$fatal(1,"control test timeout");end
endmodule
