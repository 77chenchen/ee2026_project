`timescale 1ns / 1ps

module calculator_signed_divider_tb;
    reg clk = 1'b0;
    reg start = 1'b0;
    reg signed [7:0] dividend = 8'sd0;
    reg signed [7:0] divisor = 8'sd1;
    wire busy, done;
    wire signed [15:0] quotient;
    integer expected;
    integer i;
    integer random_a, random_b;

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

    initial begin
        check_division(8'sd100, 8'sd4);
        check_division(-8'sd100, 8'sd4);
        check_division(8'sd100, -8'sd4);
        check_division(-8'sd100, -8'sd4);
        check_division(-8'sd128, -8'sd1);
        check_division(-8'sd128, 8'sd1);
        check_division(8'sd127, -8'sd128);
        check_division(8'sd7, 8'sd3);
        check_division(-8'sd7, 8'sd3);
        for (i = 0; i < 128; i = i + 1) begin
            random_a = $random;
            random_b = $random;
            if (random_b[7:0] == 0)
                random_b = 1;
            check_division(random_a[7:0], random_b[7:0]);
        end

        @(negedge clk);
        dividend = 8'sd5;
        divisor = 8'sd0;
        start = 1'b1;
        @(posedge clk); #1;
        if (busy || !done || quotient !== 16'sd0) begin
            $display("FAIL divide-by-zero guard");
            $finish_and_return(1);
        end
        $display("PASS sequential signed calculator division");
        $finish;
    end
endmodule
