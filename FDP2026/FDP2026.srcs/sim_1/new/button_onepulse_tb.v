`timescale 1ns / 1ps

module button_onepulse_tb;
    reg clk=0, reset=1, button=0;
    wire pressed;
    integer pulse_count=0;
    always #5 clk=~clk;
    always @(posedge clk) if(pressed) pulse_count=pulse_count+1;

    button_onepulse #(.COUNTER_BITS(2)) dut(
        .clk(clk),.reset(reset),.button_in(button),.pressed(pressed));

    initial begin
        repeat(2) @(posedge clk); reset=0;
        button=1; repeat(12) @(posedge clk);
        if(pulse_count!=1) begin
            $display("FAIL held button pulses=%0d",pulse_count);
            $finish_and_return(1);
        end
        button=0; repeat(8) @(posedge clk);
        button=1; repeat(8) @(posedge clk);
        if(pulse_count!=2) begin
            $display("FAIL second press pulses=%0d",pulse_count);
            $finish_and_return(1);
        end
        $display("PASS button debounce and one-pulse behavior");
        $finish;
    end
endmodule
