`timescale 1ns / 1ps
module integration_tb;
    reg clk=0;
    reg [15:0] sw=0;
    reg btnU=0,btnD=0,btnL=0,btnR=0,btnC=0;
    wire [15:0] led;
    wire [7:0] JA;
    wire PS2Clk,PS2Data;
    always #5 clk=~clk;

    My_Top_Module #(
        .BUTTON_COUNTER_BITS(1),.SWITCH_COUNTER_BITS(1),.ENABLE_HARDWARE_MOUSE(0)
    ) dut(
        .clk(clk),.sw(sw),.btnU(btnU),.btnD(btnD),.btnL(btnL),
        .btnR(btnR),.btnC(btnC),.PS2Clk(PS2Clk),.PS2Data(PS2Data),
        .led(led),.JA(JA)
    );

    task raw_press_c; begin btnC=1; repeat(8)@(posedge clk); btnC=0; repeat(8)@(posedge clk); end endtask
    task raw_press_u; begin btnU=1; repeat(8)@(posedge clk); btnU=0; repeat(8)@(posedge clk); end endtask
    task raw_press_d; begin btnD=1; repeat(8)@(posedge clk); btnD=0; repeat(8)@(posedge clk); end endtask
    task raw_press_l; begin btnL=1; repeat(8)@(posedge clk); btnL=0; repeat(8)@(posedge clk); end endtask
    task settle_switches; begin repeat(6)@(posedge clk); end endtask

    initial begin
        repeat(72)@(posedge clk); #1;
        if(dut.mode!=0) begin $display("FAIL boot menu"); $finish_and_return(1); end

        raw_press_l();
        if(dut.mode!=1) begin $display("FAIL enter calculator mode=%0d",dut.mode); $finish_and_return(1); end
        sw[7:0]=8; settle_switches(); raw_press_c();
        raw_press_u(); raw_press_c();
        sw[7:0]=5; settle_switches(); raw_press_c(); repeat(3)@(posedge clk); #1;
        if(!dut.calc_result_valid || dut.calc_result!=13) begin
            $display("FAIL integrated calculator result=%0d",dut.calc_result); $finish_and_return(1);
        end

        sw[15]=1; settle_switches();
        if(dut.mode!=0) begin $display("FAIL calculator back"); $finish_and_return(1); end
        sw[15]=0; settle_switches(); raw_press_d();
        if(dut.mode!=2 || dut.graph_state!=0) begin $display("FAIL enter graph"); $finish_and_return(1); end

        // Two linear graphs y=x and y=-x.
        sw[0]=1; raw_press_c();
        sw[0]=0; raw_press_c();
        sw[7:0]=8'd1; settle_switches(); raw_press_c();
        sw[7:0]=8'd0; settle_switches(); raw_press_c(); repeat(2)@(posedge clk);
        sw[0]=0; raw_press_c();
        sw[7:0]=-8'sd1; settle_switches(); raw_press_c();
        sw[7:0]=8'd0; settle_switches(); raw_press_c(); repeat(3)@(posedge clk); #1;
        if(!dut.graph_ready || !dut.intersection_valid || dut.intersection_x_q4!=0) begin
            $display("FAIL integrated graph ready=%0d valid=%0d ix=%0d",dut.graph_ready,dut.intersection_valid,dut.intersection_x_q4); $finish_and_return(1);
        end
        sw[14]=1; settle_switches();
        if(!dut.graph_draw || dut.graph_state!=7) begin $display("FAIL graph draw"); $finish_and_return(1); end
        sw[15]=1; settle_switches();
        if(dut.mode!=0) begin $display("FAIL graph back"); $finish_and_return(1); end

        $display("PASS resource-light menu, calculator, graph and back navigation");
        $finish;
    end
endmodule
