`timescale 1ns / 1ps

module calculator_mode_tb;
    reg clk=0, reset=0;
    reg c=0,u=0,d=0,l=0,r=0,hist=0,new_calc=0;
    reg signed [7:0] input_value=0;
    wire [2:0] state;
    wire signed [7:0] operand_a,operand_b;
    wire [1:0] operation;
    wire operation_valid;
    wire signed [15:0] result;
    wire result_valid,divide_by_zero,overflow,busy;
    wire [1:0] history_count,history_select;
    wire signed [15:0] history_0,history_1,history_2;
    wire recall_error;

    always #5 clk=~clk;

    calculator_mode dut(
        .clk(clk),.reset(reset),.btnC_pressed(c),.btnU_pressed(u),
        .btnD_pressed(d),.btnL_pressed(l),.btnR_pressed(r),
        .sw13_history(hist),.sw14_new(new_calc),.input_value(input_value),
        .state(state),.operand_a(operand_a),.operand_b(operand_b),
        .operation(operation),.operation_valid(operation_valid),.result(result),
        .result_valid(result_valid),.divide_by_zero(divide_by_zero),
        .overflow(overflow),.busy(busy),.history_count(history_count),
        .history_select(history_select),.history_0(history_0),
        .history_1(history_1),.history_2(history_2),.recall_error(recall_error)
    );

    task pulse_c; begin c=1; @(posedge clk); #1; c=0; @(posedge clk); #1; end endtask
    task pulse_u; begin u=1; @(posedge clk); #1; u=0; @(posedge clk); #1; end endtask
    task pulse_d; begin d=1; @(posedge clk); #1; d=0; @(posedge clk); #1; end endtask
    task pulse_l; begin l=1; @(posedge clk); #1; l=0; @(posedge clk); #1; end endtask
    task pulse_r; begin r=1; @(posedge clk); #1; r=0; @(posedge clk); #1; end endtask
    task fresh; begin new_calc=0; @(posedge clk); #1; new_calc=1; @(posedge clk); #1; new_calc=0; @(posedge clk); #1; end endtask

    task enter_expression;
        input signed [7:0] av;
        input [1:0] op;
        input signed [7:0] bv;
        begin
            input_value=av; pulse_c();
            case(op) 0:pulse_u(); 1:pulse_d(); 2:pulse_l(); default:pulse_r(); endcase
            pulse_c();
            input_value=bv; pulse_c();
            if(op==3) repeat(10) begin @(posedge clk); #1; end
            else begin @(posedge clk); #1; end
        end
    endtask

    initial begin
        reset=1; repeat(3) @(posedge clk); #1; reset=0;

        enter_expression(8,0,5);
        if(!result_valid || result!=13 || divide_by_zero || overflow) begin
            $display("FAIL add result=%0d",result); $finish_and_return(1);
        end
        if(history_count!=1 || history_0!=13) begin
            $display("FAIL add history count=%0d h0=%0d",history_count,history_0); $finish_and_return(1);
        end

        fresh(); enter_expression(-8,1,5);
        if(result!=-13 || !result_valid) begin
            $display("FAIL subtract result=%0d",result); $finish_and_return(1);
        end

        fresh(); enter_expression(20,2,10);
        if(result!=200 || !overflow) begin
            $display("FAIL multiply/overflow result=%0d ovf=%0d",result,overflow); $finish_and_return(1);
        end

        fresh(); enter_expression(-100,3,4);
        if(result!=-25 || !result_valid || divide_by_zero) begin
            $display("FAIL divide result=%0d valid=%0d",result,result_valid); $finish_and_return(1);
        end

        fresh(); enter_expression(7,3,0);
        if(!divide_by_zero || result_valid) begin
            $display("FAIL divide-zero div0=%0d valid=%0d",divide_by_zero,result_valid); $finish_and_return(1);
        end

        // The three most recent valid results are -25, 200 and -13.
        if(history_count!=3 || history_0!=-25 || history_1!=200 || history_2!=-13) begin
            $display("FAIL history %0d %0d %0d",history_0,history_1,history_2); $finish_and_return(1);
        end
        hist=1; repeat(2) @(posedge clk); #1; pulse_d();
        // 200 cannot be recalled into an 8-bit operand.
        pulse_c();
        if(!recall_error) begin
            $display("FAIL recall range check"); $finish_and_return(1);
        end
        pulse_u(); pulse_c(); hist=0; @(posedge clk); #1;
        if(state!=1 || operand_a!=-25) begin
            $display("FAIL history recall state=%0d a=%0d",state,operand_a); $finish_and_return(1);
        end

        $display("PASS calculator arithmetic, errors, overflow and history");
        $finish;
    end
endmodule
