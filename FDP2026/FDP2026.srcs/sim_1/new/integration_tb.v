`timescale 1ns / 1ps
module integration_tb;
    reg CLOCK=0;
    reg [15:0] sw=0;
    reg btnU=0,btnD=0,btnL=0,btnR=0,btnC=0;
    wire [7:0] JB;
    always #5 CLOCK=~CLOCK;

    My_Top_Module dut(
        .CLOCK(CLOCK),.sw(sw),.btnU(btnU),.btnD(btnD),
        .btnL(btnL),.btnR(btnR),.btnC(btnC),.JB(JB),
        .led(),.seg(),.an()
    );

    // The board test uses Hanna's unchanged 200 ms debouncer.  Force only
    // the already-debounced pulses here so this short integration test checks
    // the menu routing without simulating 20 million clock cycles per press.
    task raw_press_c; begin force dut.db_btnC=1; #1; @(posedge CLOCK); #1; release dut.db_btnC; repeat(2)@(posedge CLOCK); end endtask
    task raw_press_u; begin force dut.db_btnU=1; #1; @(posedge CLOCK); #1; release dut.db_btnU; repeat(2)@(posedge CLOCK); end endtask
    task raw_press_d; begin force dut.db_btnD=1; #1; @(posedge CLOCK); #1; release dut.db_btnD; repeat(2)@(posedge CLOCK); end endtask
    task raw_press_l; begin force dut.db_btnL=1; #1; @(posedge CLOCK); #1; release dut.db_btnL; repeat(2)@(posedge CLOCK); end endtask
    task raw_press_r; begin force dut.db_btnR=1; #1; @(posedge CLOCK); #1; release dut.db_btnR; repeat(2)@(posedge CLOCK); end endtask
    task settle_switches; begin repeat(6)@(posedge CLOCK); end endtask
    task capture_oled_frame;
        begin
            force dut.frame_begin=1'b1;
            @(posedge dut.clk6p25m);#1;
            release dut.frame_begin;
        end
    endtask

    initial begin
        #1;
        if (dut.oled_reset !== 1'b1 || JB[7] !== 1'b0) begin
            $display("FAIL OLED startup reset was not asserted");
            $finish_and_return(1);
        end
        repeat(72)@(posedge CLOCK); #1;
        if (dut.oled_reset !== 1'b0 || dut.oled.delay == 0) begin
            $display("FAIL OLED reset did not load its power-up delay");
            $finish_and_return(1);
        end
        if(dut.choice!=0) begin $display("FAIL boot menu"); $finish_and_return(1); end

        raw_press_c();
        if(dut.choice!=1) begin $display("FAIL enter calculator mode=%0d",dut.choice); $finish_and_return(1); end
        sw[7:0]=8'sd8; settle_switches(); raw_press_c();
        raw_press_u(); raw_press_c();
        sw[7:0]=8'sd5; settle_switches(); raw_press_c(); repeat(3)@(posedge CLOCK); #1;
        if(dut.calculator_module.result!=13) begin
            $display("FAIL Hanna calculator result=%0d",dut.calculator_module.result); $finish_and_return(1);
        end
        capture_oled_frame();
        if(dut.calculator_module.frame_result!==16'sd13 ||
           dut.calculator_module.frame_operand_A!==8'sd8 ||
           dut.calculator_module.frame_operand_B!==8'sd5 ||
           dut.calculator_module.frame_history_0!==8'sd13 ||
           dut.calculator_module.frame_history_count!==2'd1) begin
            $display("FAIL calculator/history OLED frame snapshot");$finish_and_return(1);
        end

        // Recall the preceding result through SW8, then divide it. This is
        // the exact history-to-result path that failed routed timing.
        sw[14]=1; settle_switches(); sw[14]=0; settle_switches();
        if(dut.calculator_module.result!==16'sd0 ||
           dut.calculator_module.frame_result!==16'sd13) begin
            $display("FAIL live calculator reset changed the displayed frame");$finish_and_return(1);
        end
        sw[8]=1; sw[7:0]=0; settle_switches(); raw_press_c();
        if(dut.calculator_module.operand_A!=13) begin
            $display("FAIL history recall before division");
            $finish_and_return(1);
        end
        raw_press_r(); raw_press_c();
        sw[8]=0; sw[7:0]=8'sd2; settle_switches(); raw_press_c();
        repeat(12)@(posedge CLOCK); #1;
        if(dut.calculator_module.result!=6) begin
            $display("FAIL history division result=%0d",dut.calculator_module.result);
            $finish_and_return(1);
        end
        sw[13]=1;
        capture_oled_frame();
        if(dut.calculator_module.frame_show_history!==1'b1 ||
           dut.calculator_module.history_screen.count!==2'd2 ||
           dut.calculator_module.history_screen.history_0!==8'sd6 ||
           dut.calculator_module.history_screen.history_1!==8'sd13 ||
           dut.calculator_module.history_screen.history_a0!==8'sd13 ||
           dut.calculator_module.history_screen.history_b0!==8'sd2) begin
            $display("FAIL history view did not capture a consistent frame");$finish_and_return(1);
        end
        sw[13]=0;

        // Also check a negative signed quotient through the full top level.
        sw[14]=1; settle_switches(); sw[14]=0; settle_switches();
        sw[7:0]=-8'sd100; settle_switches(); raw_press_c();
        raw_press_r(); raw_press_c();
        sw[7:0]=8'sd4; settle_switches(); raw_press_c();
        repeat(12)@(posedge CLOCK); #1;
        if(dut.calculator_module.result!=-25 ||
           dut.calculator_module.state!=3'd4) begin
            $display("FAIL integrated signed division result=%0d state=%0d",
                     dut.calculator_module.result,dut.calculator_module.state);
            $finish_and_return(1);
        end
        if(dut.calculator_module.history_0!==-16'sd25 ||
           dut.calculator_module.history_screen.history_0!==8'sd6) begin
            $display("FAIL history renderer changed before the next frame");$finish_and_return(1);
        end

        // Divide-by-zero remains invalid and -128/-1 remains an overflow.
        sw[14]=1; settle_switches(); sw[14]=0; settle_switches();
        sw[7:0]=8'sd7; settle_switches(); raw_press_c();
        raw_press_r(); raw_press_c();
        sw[7:0]=8'sd0; settle_switches(); raw_press_c();
        repeat(3)@(posedge CLOCK); #1;
        if(!dut.calculator_module.invalid_result ||
           dut.calculator_module.state!=3'd4) begin
            $display("FAIL integrated divide-by-zero handling");
            $finish_and_return(1);
        end
        capture_oled_frame();
        if(dut.calculator_module.frame_invalid_result!==1'b1 ||
           dut.calculator_module.frame_overflow!==1'b0 ||
           dut.calculator_module.frame_result!==16'sd0) begin
            $display("FAIL invalid-result OLED frame");$finish_and_return(1);
        end

        sw[14]=1; settle_switches(); sw[14]=0; settle_switches();
        sw[7:0]=8'h80; settle_switches(); raw_press_c();
        raw_press_r(); raw_press_c();
        sw[7:0]=8'hff; settle_switches(); raw_press_c();
        repeat(12)@(posedge CLOCK); #1;
        if(dut.calculator_module.result!=16'sd128 ||
           !dut.calculator_module.overflow) begin
            $display("FAIL integrated division overflow result=%0d",
                     dut.calculator_module.result);
            $finish_and_return(1);
        end
        capture_oled_frame();
        if(dut.calculator_module.frame_invalid_result!==1'b0 ||
           dut.calculator_module.frame_overflow!==1'b1 ||
           dut.calculator_module.frame_result!==16'sd128) begin
            $display("FAIL overflow OLED frame");$finish_and_return(1);
        end

        sw[14]=1; settle_switches(); sw[14]=0; settle_switches();
        sw[7:0]=8'sd20; settle_switches(); raw_press_c();
        raw_press_l(); raw_press_c();
        sw[7:0]=8'sd10; settle_switches(); raw_press_c();
        repeat(3)@(posedge CLOCK); #1;
        if(dut.calculator_module.result!=16'sd200 ||
           !dut.calculator_module.overflow) begin
            $display("FAIL integrated multiplication result=%0d",
                     dut.calculator_module.result);
            $finish_and_return(1);
        end

        sw[14]=1; settle_switches(); sw[14]=0; settle_switches();
        sw[7:0]=-8'sd8; settle_switches(); raw_press_c();
        raw_press_d(); raw_press_c();
        sw[7:0]=8'sd5; settle_switches(); raw_press_c();
        repeat(3)@(posedge CLOCK); #1;
        if(dut.calculator_module.result!=-13 ||
           dut.calculator_module.invalid_result) begin
            $display("FAIL integrated subtraction result=%0d",
                     dut.calculator_module.result);
            $finish_and_return(1);
        end
        capture_oled_frame();
        if(dut.calculator_module.frame_result!==-16'sd13 ||
           dut.calculator_module.frame_show_history!==1'b0 ||
           dut.calculator_module.frame_history_count!==2'd3 ||
           dut.calculator_module.frame_history_0!==-8'sd13 ||
           dut.calculator_module.frame_history_1!==-8'sd25 ||
           dut.calculator_module.frame_history_2!==8'sd6) begin
            $display("FAIL signed result/history rollover in OLED snapshot");$finish_and_return(1);
        end
        sw[15]=1; settle_switches();
        if(dut.choice!=0) begin $display("FAIL calculator back"); $finish_and_return(1); end
        sw[15]=0; settle_switches(); raw_press_d(); raw_press_c();
        if(dut.choice!=2) begin $display("FAIL enter graph"); $finish_and_return(1); end

        // Exercise the actual Hanna-top graph wiring, including SW1 cubic
        // selection and the signed coefficient path through the synchronizer.
        sw[7:0]=0;settle_switches();raw_press_c(); // one graph
        sw[1]=1;settle_switches();raw_press_c(); // cubic
        if(!dut.graphnator.controller.cubic1 ||
           dut.graphnator.controller.state!=3'd2) begin
            $display("FAIL integrated cubic selection");$finish_and_return(1);
        end
        sw[7:0]=8'sd1;settle_switches();raw_press_c();
        sw[7:0]=8'sd2;settle_switches();raw_press_c();
        sw[7:0]=-8'sd3;settle_switches();raw_press_c();
        sw[7:0]=8'sd4;settle_switches();raw_press_c();
        if(!dut.graphnator.controller.ready ||
           dut.graphnator.controller.a1!=1 ||
           dut.graphnator.controller.b1!=2 ||
           dut.graphnator.controller.c1!=-3 ||
           dut.graphnator.controller.d1!=4) begin
            $display("FAIL integrated cubic input");$finish_and_return(1);
        end
        sw[14]=1;settle_switches();
        if(!dut.graphnator.controller.draw) begin
            $display("FAIL integrated cubic draw");$finish_and_return(1);
        end
        // Frame coefficients are captured on the OLED rising edge, leaving
        // the half-cycle before its falling-edge SPI pixel sample.
        force dut.frame_begin=1'b1;
        @(posedge dut.clk6p25m);#1;
        release dut.frame_begin;
        if(dut.graphnator.frame_a1!=1 || dut.graphnator.frame_b1!=2 ||
           dut.graphnator.frame_c1!=-3 || dut.graphnator.frame_d1!=4 ||
           dut.graphnator.frame_input!=4) begin
            $display("FAIL OLED-clock graph frame snapshot");$finish_and_return(1);
        end
        force dut.frame_begin=1'b0;
        sw[7:0]=8'h80;settle_switches();
        @(negedge dut.clk6p25m);#1;
        force dut.frame_begin=1'b1;
        repeat(2)@(posedge CLOCK);#1;
        if(dut.graphnator.frame_input!=4) begin
            $display("FAIL frame input changed on a 100 MHz edge");$finish_and_return(1);
        end
        @(posedge dut.clk6p25m);#1;
        release dut.frame_begin;
        if(dut.graphnator.frame_input!=-128) begin
            $display("FAIL OLED rising edge did not capture signed input");$finish_and_return(1);
        end
        @(negedge dut.clk6p25m);#1;
        if(dut.graphnator.frame_input!=-128 || dut.graphnator.frame_a1!=1) begin
            $display("FAIL graph snapshot changed before OLED pixel sampling");$finish_and_return(1);
        end
        sw[15]=1; settle_switches();
        if(dut.choice!=0) begin $display("FAIL graph back"); $finish_and_return(1); end

        // Hanna's third menu item and its input pulses stay isolated.
        sw[15]=0;settle_switches();
        raw_press_d();raw_press_d();raw_press_c();
        if(dut.choice!=3) begin $display("FAIL enter triangle");$finish_and_return(1);end
        sw[14]=0;settle_switches();raw_press_c();
        sw[6:0]=3;settle_switches();raw_press_c();
        sw[6:0]=4;settle_switches();raw_press_c();
        repeat(12)@(posedge CLOCK);#1;
        if(dut.triangle.c!==15'd5 || dut.triangle.invalid!==1'b0) begin
            $display("FAIL integrated triangle hypotenuse");$finish_and_return(1);
        end
        capture_oled_frame();
        if(dut.triangle.graphics.c!==15'd5 || dut.triangle.graphics.state!==2'd3) begin
            $display("FAIL triangle OLED clock/frame wiring");$finish_and_return(1);
        end
        sw[14]=1;settle_switches();sw[14]=0;settle_switches();
        raw_press_d();raw_press_c();
        sw[6:0]=4;settle_switches();raw_press_c();
        sw[6:0]=3;settle_switches();raw_press_c();
        repeat(4)@(posedge CLOCK);#1;capture_oled_frame();
        if(dut.triangle.graphics.invalid!==1'b1) begin
            $display("FAIL integrated triangle error snapshot");$finish_and_return(1);
        end
        sw[15]=1;settle_switches();
        if(dut.choice!=0) begin $display("FAIL triangle back");$finish_and_return(1);end

        $display("PASS integrated menu, calculator/history, graph and triangle arithmetic/OLED snapshots");
        $finish;
    end
endmodule
