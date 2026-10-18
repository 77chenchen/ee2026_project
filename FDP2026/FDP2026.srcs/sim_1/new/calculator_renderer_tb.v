`timescale 1ns / 1ps
module calculator_renderer_tb;
    reg [12:0] pixel_index=0;
    reg signed [7:0] input_value=-12,operand_a=8,operand_b=5;
    reg [2:0] state=0;
    reg [1:0] operation=0;
    reg operation_valid=0;
    reg signed [15:0] result=13;
    reg result_valid=0,divide_by_zero=0,overflow=0,busy=0,history_view=0;
    reg [1:0] history_count=3,history_select=0;
    reg signed [15:0] history_0=13,history_1=-4,history_2=200;
    reg recall_error=0;
    wire [15:0] pixel_data;
    integer i,green_count,yellow_count,red_count,cyan_count;

    calculator_renderer dut(
        .pixel_index(pixel_index),.input_value(input_value),.operand_a(operand_a),
        .operand_b(operand_b),.state(state),.operation(operation),
        .operation_valid(operation_valid),.result(result),.result_valid(result_valid),
        .divide_by_zero(divide_by_zero),.overflow(overflow),.busy(busy),
        .sw13_history(history_view),.history_count(history_count),
        .history_select(history_select),.history_0(history_0),.history_1(history_1),
        .history_2(history_2),.recall_error(recall_error),.pixel_data(pixel_data)
    );

    task scan;
        begin
            green_count=0;yellow_count=0;red_count=0;cyan_count=0;
            for(i=0;i<6144;i=i+1) begin pixel_index=i; #1;
                if(pixel_data==16'h07E0)green_count=green_count+1;
                if(pixel_data==16'hFFE0)yellow_count=yellow_count+1;
                if(pixel_data==16'hF800)red_count=red_count+1;
                if(pixel_data==16'h07FF)cyan_count=cyan_count+1;
            end
        end
    endtask

    initial begin
        scan();
        if(green_count==0||yellow_count==0||cyan_count==0) begin
            $display("FAIL input UI g=%0d y=%0d c=%0d",green_count,yellow_count,cyan_count); $finish_and_return(1);
        end
        state=4; result_valid=1; divide_by_zero=1; scan();
        if(red_count==0) begin $display("FAIL error UI"); $finish_and_return(1); end
        divide_by_zero=0; history_view=1; recall_error=1; scan();
        if(green_count==0||red_count==0) begin $display("FAIL history UI"); $finish_and_return(1); end
        $display("PASS calculator renderer input, result, error and history screens");
        $finish;
    end
endmodule
