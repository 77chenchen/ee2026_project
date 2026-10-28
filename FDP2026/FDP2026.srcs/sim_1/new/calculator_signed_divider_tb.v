`timescale 1ns / 1ps

module calculator_signed_divider_tb;
    reg clk = 1'b0;
    reg start = 1'b0;
    reg signed [7:0] dividend = 8'sd0;
    reg signed [7:0] divisor = 8'sd1;
    wire busy, done;
    wire signed [15:0] quotient;
    integer expected;
    integer input_a,input_b;

    always #5 clk = ~clk;

    calculator_signed_divider dut (
        .clk(clk), .start(start), .dividend(dividend), .divisor(divisor),
        .busy(busy), .done(done), .quotient(quotient)
    );

    task check_division;
        input signed [7:0] a;
        input signed [7:0] b;
        begin
            expected = a / b;
            @(negedge clk);
            dividend = a;
            divisor = b;
            start = 1'b1;
            @(posedge clk); #1;
            if (!busy || done) begin
                $display("FAIL divider did not start: %0d / %0d", a, b);
                $finish_and_return(1);
            end
            @(negedge clk);
            start = 1'b0;
            repeat (8) @(posedge clk);
            #1;
            if (busy || !done || quotient !== expected) begin
                $display("FAIL division %0d / %0d expected %0d got %0d",
                         a, b, expected, quotient);
                $finish_and_return(1);
            end
            @(posedge clk); #1;
            if (done) begin
                $display("FAIL divider done pulse stayed high");
                $finish_and_return(1);
            end
        end
    endtask

    task check_zero_divisor;
        input signed [7:0] a;
        begin
            @(negedge clk);
            dividend=a;divisor=0;start=1;
            @(posedge clk);#1;
            if (busy || !done || quotient !== 16'sd0) begin
                $display("FAIL divide-by-zero guard dividend=%0d",a);
                $finish_and_return(1);
            end
            @(negedge clk);start=0;
            @(posedge clk);#1;
            if (busy || done) begin
                $display("FAIL divide-by-zero completion pulse");
                $finish_and_return(1);
            end
        end
    endtask

    initial begin
        // Exhaust the signed 8-bit domain, including -128/-1, truncation
        // toward zero, all sign combinations and every zero-divisor input.
        for(input_a=-128;input_a<=127;input_a=input_a+1) begin
            for(input_b=-128;input_b<=127;input_b=input_b+1) begin
                if(input_b==0) check_zero_divisor(input_a);
                else check_division(input_a,input_b);
            end
        end
        $display("PASS all 65536 signed calculator division input pairs and completion pulses");
        $finish;
    end
endmodule
