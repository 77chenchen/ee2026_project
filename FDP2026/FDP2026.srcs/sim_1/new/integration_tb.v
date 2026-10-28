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

    initial begin
        repeat(72)@(posedge CLOCK); #1;
        if(dut.choice!=0) begin $display("FAIL boot menu"); $finish_and_return(1); end

        raw_press_c();
        if(dut.choice!=1) begin $display("FAIL enter calculator mode=%0d",dut.choice); $finish_and_return(1); end
        sw[7:0]=8'sd8; settle_switches(); raw_press_c();
        raw_press_u(); raw_press_c();
        sw[7:0]=8'sd5; settle_switches(); raw_press_c(); repeat(3)@(posedge CLOCK); #1;
        if(dut.calculator_module.result!=13) begin
            $display("FAIL Hanna calculator result=%0d",dut.calculator_module.result); $finish_and_return(1);
        end
        // Division must complete through the serialized divider and enter
        // history; a zero divisor must not be recorded.
        sw[14]=1; settle_switches(); sw[14]=0; settle_switches();
        sw[7:0]=8'sd7; settle_switches(); raw_press_c();
        raw_press_r(); raw_press_c();
        sw[7:0]=8'sd0; settle_switches(); raw_press_c();
        repeat(3)@(posedge CLOCK); #1;
        if(!dut.calculator_module.invalid_result ||
           dut.calculator_module.result!=0 ||
           dut.calculator_module.state!=3'd4) begin
            $display("FAIL integrated divide-zero invalid=%0d result=%0d state=%0d",
                     dut.calculator_module.invalid_result,
                     dut.calculator_module.state,
                     dut.calculator_module.result);$finish_and_return(1);
        end
        sw[14]=1; settle_switches(); sw[14]=0; settle_switches();
        sw[7:0]=-8'sd100; settle_switches(); raw_press_c();
        raw_press_r(); raw_press_c();
        sw[7:0]=8'sd4; settle_switches(); raw_press_c();
        repeat(20)@(posedge CLOCK); #1;
        if(dut.calculator_module.result!=-25 ||
           dut.calculator_module.state!=3'd4) begin
            $display("FAIL integrated divide result=%0d state=%0d",
                     dut.calculator_module.result,
                     dut.calculator_module.state);$finish_and_return(1);
        end
        sw[15]=1; settle_switches();
        if(dut.choice!=0) begin $display("FAIL calculator back"); $finish_and_return(1); end
        sw[15]=0; settle_switches(); raw_press_d(); raw_press_c();
        if(dut.choice!=2) begin $display("FAIL enter graph"); $finish_and_return(1); end

        // Exercise the actual Hanna-top graph wiring and the signed
        // quadratic coefficient path through the synchronizer.
        sw[7:0]=0;settle_switches();raw_press_c(); // one graph
        sw[0]=1;settle_switches();raw_press_c(); // quadratic
        if(dut.graphnator.controller.state!=3'd2) begin
            $display("FAIL integrated quadratic selection");$finish_and_return(1);
        end
        sw[7:0]=8'sd1;settle_switches();raw_press_c();
        sw[7:0]=8'sd2;settle_switches();raw_press_c();
        sw[7:0]=-8'sd3;settle_switches();raw_press_c();
        if(!dut.graphnator.controller.ready ||
           dut.graphnator.controller.a1!=1 ||
           dut.graphnator.controller.b1!=2 ||
           dut.graphnator.controller.c1!=-3) begin
            $display("FAIL integrated quadratic input");$finish_and_return(1);
        end
        sw[14]=1;settle_switches();
        if(!dut.graphnator.controller.draw) begin
            $display("FAIL integrated graph draw");$finish_and_return(1);
        end
        sw[15]=1; settle_switches();
        if(dut.choice!=0) begin $display("FAIL graph back"); $finish_and_return(1); end

        // Hanna's third menu item and its input pulses stay isolated.
        sw[15]=0;settle_switches();
        raw_press_d();raw_press_d();raw_press_c();
        if(dut.choice!=3) begin $display("FAIL enter triangle");$finish_and_return(1);end
        sw[15]=1;settle_switches();
        if(dut.choice!=0) begin $display("FAIL triangle back");$finish_and_return(1);end

        $display("PASS integrated Hanna menu and calculator/graph navigation");
        $finish;
    end
endmodule
