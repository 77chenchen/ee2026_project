`timescale 1ns / 1ps

// Targeted multi-cycle arithmetic checks: signed division including the
// -128/-1 corner, 15-bit square root, and the frame-boundary snapshot.
module timing_primitives_tb;
    reg clk = 0;
    always #5 clk = ~clk;

    reg start = 0;
    reg signed [7:0] dividend = 0, divisor = 1;
    wire div_busy, div_done;
    wire signed [15:0] quotient;
    calculator_divider div(
        .clk(clk), .start(start), .dividend(dividend), .divisor(divisor),
        .busy(div_busy), .done(div_done), .quotient(quotient));

    reg sqrt_start = 0;
    reg [14:0] sqrt_input = 0;
    wire sqrt_busy, sqrt_done;
    wire [7:0] sqrt_root;
    sqrt_15bit root(
        .clk(clk), .start(sqrt_start), .value(sqrt_input),
        .busy(sqrt_busy), .done(sqrt_done), .root(sqrt_root));

    reg clk_a = 0, clk_b = 0;
    always #5 clk_a = ~clk_a;
    always #83 clk_b = ~clk_b;
    reg reset = 0;
    reg prepare = 0;
    reg [31:0] snapshot_data = 32'h0000_0000;
    wire [31:0] snapshot_out;
    frame_snapshot #(.WIDTH(32)) snap(
        .clk_src(clk_a), .reset_src(reset),
        .clk_dst(clk_b), .reset_dst(reset),
        .frame_prepare(prepare), .data(snapshot_data), .data_out(snapshot_out));

    integer i;
    integer errors = 0;

    task check_div;
        input signed [7:0] a,b;
        input signed [15:0] expected;
        begin
            dividend=a; divisor=b; start=1; @(posedge clk); #1; start=0;
            i=0;
            while (!div_done && i<32) begin @(posedge clk); #1; i=i+1; end
            if (quotient!==expected) begin
                $display("FAIL divide %0d/%0d=%0d expected=%0d",a,b,quotient,expected);
                errors=errors+1;
            end
            @(posedge clk); #1;
        end
    endtask

    initial begin
        reset=1; repeat(4) @(posedge clk_b); #1; reset=0;

        check_div(8'sd8,8'sd5,16'sd1);
        check_div(-8'sd100,8'sd4,-16'sd25);
        check_div(8'sd127,-8'sd2,-16'sd63);
        check_div(-8'sd128,-8'sd1,16'sd128);

        sqrt_input=15'd0; sqrt_start=1; @(posedge clk); #1; sqrt_start=0;
        i=0; while(!sqrt_done && i<40) begin @(posedge clk); #1; i=i+1; end
        if(sqrt_root!==8'd0) begin $display("FAIL sqrt 0=%0d",sqrt_root);errors=errors+1;end
        sqrt_input=15'd255; sqrt_start=1; @(posedge clk); #1; sqrt_start=0;
        i=0; while(!sqrt_done && i<40) begin @(posedge clk); #1; i=i+1; end
        if(sqrt_root!==8'd15) begin $display("FAIL sqrt 255=%0d",sqrt_root);errors=errors+1;end
        sqrt_input=15'd32767; sqrt_start=1; @(posedge clk); #1; sqrt_start=0;
        i=0; while(!sqrt_done && i<40) begin @(posedge clk); #1; i=i+1; end
        if(sqrt_root!==8'd181) begin $display("FAIL sqrt 32767=%0d",sqrt_root);errors=errors+1;end

        // Hold the source word stable across the whole handshake and verify the
        // destination only observes complete old/new snapshots.
        snapshot_data=32'hA5A5_0001; prepare=1; @(posedge clk_a); #1; prepare=0;
        repeat(4) @(posedge clk_b); #1;
        if(snapshot_out!==32'hA5A5_0001) begin
            $display("FAIL first snapshot=%h",snapshot_out);errors=errors+1;
        end
        snapshot_data=32'h5A5A_8000; prepare=1; @(posedge clk_a); #1; prepare=0;
        repeat(4) @(posedge clk_b); #1;
        if(snapshot_out!==32'h5A5A_8000) begin
            $display("FAIL second snapshot=%h",snapshot_out);errors=errors+1;
        end

        if(errors==0) $display("PASS serialized divider, square root and frame snapshot");
        else begin
            $display("FAIL primitive errors=%0d",errors);
            $finish_and_return(1);
        end
        $finish;
    end
endmodule
