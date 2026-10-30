`timescale 1ns / 1ps

// Exercises Hanna's calculator interface with the timing-safe divider.
module calculator_sequential_tb;
    reg clk=0,btnU=0,btnD=0,btnL=0,btnR=0,btnC=0;
    reg [10:0] sw=0;
    reg SW13=0,SW14=0,SW15=0;
    wire [15:0] oled_data;
    wire [3:0] an;
    wire [7:0] seg;
    always #5 clk=~clk;

    calculator dut(
        .CLOCK(clk),.btnU(btnU),.btnD(btnD),.btnL(btnL),.btnR(btnR),
        .btnC(btnC),.sw(sw),.SW13(SW13),.SW14(SW14),.SW15(SW15),
        .pixel_index(13'd0),.oled_data(oled_data),.an(an),.seg(seg)
    );

    task press_confirm;
        begin
            @(negedge clk);btnC=1;
            @(negedge clk);btnC=0;
        end
    endtask

    task press_operation;
        input [1:0] op;
        begin
            @(negedge clk);
            case(op)
                2'd0: btnU=1;
                2'd1: btnD=1;
                2'd2: btnL=1;
                2'd3: btnR=1;
            endcase
            @(negedge clk);
            btnU=0;btnD=0;btnL=0;btnR=0;
        end
    endtask

    task run_case;
        input signed [7:0] lhs,rhs;
        input [1:0] op;
        input signed [15:0] expected;
        input expected_invalid,expected_overflow;
        integer cycles;
        begin
            @(negedge clk);SW14=1;
            @(negedge clk);SW14=0;
            sw[7:0]=lhs;press_confirm();
            press_operation(op);press_confirm();
            sw[7:0]=rhs;press_confirm();
            if (!expected_invalid && dut.state!==dut.CALCULATING) begin
                $display("FAIL calculator did not enter CALCULATING");
                $finish_and_return(1);
            end
            // A switch change after confirmation must not alter operand B.
            sw[7:0]=8'd99;
            for(cycles=0;cycles<16 && dut.state!==dut.SHOW_RESULT;cycles=cycles+1)
                @(negedge clk);
            #1;
            if (dut.state!==dut.SHOW_RESULT || dut.result!==expected ||
                dut.invalid_result!==expected_invalid ||
                dut.overflow!==expected_overflow) begin
                $display("FAIL calc a=%0d b=%0d op=%0d result=%0d expected=%0d invalid=%b overflow=%b",
                    lhs,rhs,op,dut.result,expected,dut.invalid_result,dut.overflow);
                $finish_and_return(1);
            end
        end
    endtask

    initial begin
        run_case(8,5,0,13,0,0);
        run_case(-7,2,3,-3,0,0);
        run_case(-128,-1,3,128,0,1);
        run_case(5,0,3,0,1,0);
        run_case(-12,6,2,-72,0,0);
        $display("PASS calculator staged arithmetic, signed division, invalid and overflow");
        $finish;
    end
endmodule
