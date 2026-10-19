`timescale 1ns / 1ps

// Calculator control and arithmetic core.
//
// Inputs are signed 8-bit two's-complement values.  Results and history are
// signed 16-bit values.  The overflow output reports that a valid result does
// not fit back into eight signed bits; the full 16-bit result is still kept.
// Division is performed over eight clocks so that no long combinational
// divider is placed on the 100 MHz system-clock path.
module calculator_mode #(
    parameter ENABLE_HISTORY = 1
) (
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    btnC_pressed,
    input  wire                    btnU_pressed,
    input  wire                    btnD_pressed,
    input  wire                    btnL_pressed,
    input  wire                    btnR_pressed,
    input  wire                    sw13_history,
    input  wire                    sw14_new,
    input  wire signed [7:0]       input_value,

    output reg  [2:0]              state,
    output reg  signed [7:0]       operand_a,
    output reg  signed [7:0]       operand_b,
    output reg  [1:0]              operation,
    output reg                     operation_valid,
    output reg  signed [15:0]      result,
    output reg                     result_valid,
    output reg                     divide_by_zero,
    output reg                     overflow,
    output wire                    busy,

    output wire [1:0]              history_count,
    output reg  [1:0]              history_select,
    output wire signed [15:0]      history_0,
    output wire signed [15:0]      history_1,
    output wire signed [15:0]      history_2,
    output reg                     recall_error
);

    localparam [2:0] INPUT_A   = 3'd0;
    localparam [2:0] SELECT_OP = 3'd1;
    localparam [2:0] INPUT_B   = 3'd2;
    localparam [2:0] EXECUTE   = 3'd3;
    localparam [2:0] RESULT    = 3'd4;

    localparam [1:0] ADD = 2'd0;
    localparam [1:0] SUB = 2'd1;
    localparam [1:0] MUL = 2'd2;
    localparam [1:0] DIV = 2'd3;

    assign busy = (state == EXECUTE);

    reg sw13_previous;
    reg sw14_previous;
    wire history_rising = sw13_history && !sw13_previous;
    wire new_rising = sw14_new && !sw14_previous;

    wire signed [15:0] operand_a_wide = {{8{operand_a[7]}}, operand_a};
    wire signed [15:0] input_wide = {{8{input_value[7]}}, input_value};
    wire signed [15:0] add_value = operand_a_wide + input_wide;
    wire signed [15:0] sub_value = operand_a_wide - input_wide;
    wire signed [31:0] multiply_value_wide = operand_a_wide * input_wide;
    wire signed [15:0] multiply_value = multiply_value_wide[15:0];

    function [7:0] magnitude8;
        input signed [7:0] value;
        begin
            magnitude8 = value[7] ? (~value + 1'b1) : value;
        end
    endfunction

    wire add_overflow;
    wire sub_overflow;
    wire multiply_overflow;
    wire division_overflow;
    wire division_invalid;

    check_overflow add_range(.result(add_value), .overflow(add_overflow));
    check_overflow sub_range(.result(sub_value), .overflow(sub_overflow));
    check_overflow mul_range(.result(multiply_value), .overflow(multiply_overflow));
    check_invalid validity(
        .operand_b(input_value), .ready(1'b1), .operation(operation),
        .invalid(division_invalid)
    );

    // Unsigned restoring divider state.  Signs are restored after bit 8.
    reg [7:0] div_dividend_shift;
    reg [7:0] div_divisor;
    reg [7:0] div_quotient;
    reg [8:0] div_remainder;
    reg [3:0] div_iteration;
    reg       div_negative;

    wire [8:0] div_trial_remainder =
        {div_remainder[7:0], div_dividend_shift[7]};
    wire div_trial_ge =
        div_trial_remainder >= {1'b0, div_divisor};
    wire [8:0] div_remainder_next = div_trial_ge ?
        (div_trial_remainder - {1'b0, div_divisor}) :
        div_trial_remainder;
    wire [7:0] div_quotient_next =
        {div_quotient[6:0], div_trial_ge};
    wire signed [15:0] div_positive_result =
        $signed({8'd0, div_quotient_next});
    wire signed [15:0] div_signed_result = div_negative ?
        -div_positive_result : div_positive_result;
    check_overflow div_range(.result(div_signed_result), .overflow(division_overflow));

    reg history_save;
    reg signed [15:0] history_save_value;
    generate
        if (ENABLE_HISTORY) begin : g_history
            calculation_history history_store(
                .clk(clk), .reset(reset), .save(history_save),
                .result(history_save_value), .count(history_count),
                .history_0(history_0), .history_1(history_1), .history_2(history_2)
            );
        end else begin : g_no_history
            assign history_count = 2'd0;
            assign history_0 = 16'sd0;
            assign history_1 = 16'sd0;
            assign history_2 = 16'sd0;
        end
    endgenerate

    wire signed [15:0] selected_history =
        (history_select == 2'd0) ? history_0 :
        (history_select == 2'd1) ? history_1 : history_2;
    wire selected_history_valid = history_select < history_count;
    wire selected_history_fits =
        (selected_history >= -16'sd128) &&
        (selected_history <= 16'sd127);

    always @(posedge clk) begin
        sw13_previous <= sw13_history;
        sw14_previous <= sw14_new;
        history_save <= 1'b0;

        if (reset) begin
            state <= INPUT_A;
            operand_a <= 8'sd0;
            operand_b <= 8'sd0;
            operation <= ADD;
            operation_valid <= 1'b0;
            result <= 16'sd0;
            result_valid <= 1'b0;
            divide_by_zero <= 1'b0;
            overflow <= 1'b0;
            history_select <= 2'd0;
            history_save <= 1'b0;
            history_save_value <= 16'sd0;
            recall_error <= 1'b0;
            sw13_previous <= sw13_history;
            sw14_previous <= sw14_new;
            div_dividend_shift <= 8'd0;
            div_divisor <= 8'd0;
            div_quotient <= 8'd0;
            div_remainder <= 9'd0;
            div_iteration <= 4'd0;
            div_negative <= 1'b0;
        end else if (new_rising) begin
            // Start a fresh expression but deliberately preserve history.
            state <= INPUT_A;
            operand_a <= 8'sd0;
            operand_b <= 8'sd0;
            operation <= ADD;
            operation_valid <= 1'b0;
            result <= 16'sd0;
            result_valid <= 1'b0;
            divide_by_zero <= 1'b0;
            overflow <= 1'b0;
            recall_error <= 1'b0;
            history_select <= 2'd0;
        end else if (ENABLE_HISTORY && sw13_history) begin
            // History is an overlay: normal calculation state is paused.
            if (history_rising) begin
                history_select <= 2'd0;
                recall_error <= 1'b0;
            end else if (btnU_pressed && (history_select != 0)) begin
                history_select <= history_select - 1'b1;
                recall_error <= 1'b0;
            end else if (btnD_pressed &&
                         (history_select + 1'b1 < history_count)) begin
                history_select <= history_select + 1'b1;
                recall_error <= 1'b0;
            end else if (btnC_pressed && selected_history_valid) begin
                if (selected_history_fits) begin
                    operand_a <= selected_history[7:0];
                    state <= SELECT_OP;
                    operation_valid <= 1'b0;
                    result_valid <= 1'b0;
                    divide_by_zero <= 1'b0;
                    overflow <= 1'b0;
                    recall_error <= 1'b0;
                end else begin
                    // A recalled operand must fit the calculator's 8-bit input.
                    recall_error <= 1'b1;
                end
            end
        end else begin
            recall_error <= 1'b0;
            case (state)
                INPUT_A: begin
                    if (btnC_pressed) begin
                        operand_a <= input_value;
                        operation_valid <= 1'b0;
                        result_valid <= 1'b0;
                        divide_by_zero <= 1'b0;
                        overflow <= 1'b0;
                        state <= SELECT_OP;
                    end
                end

                SELECT_OP: begin
                    if (btnU_pressed) begin
                        operation <= ADD;
                        operation_valid <= 1'b1;
                    end else if (btnD_pressed) begin
                        operation <= SUB;
                        operation_valid <= 1'b1;
                    end else if (btnL_pressed) begin
                        operation <= MUL;
                        operation_valid <= 1'b1;
                    end else if (btnR_pressed) begin
                        operation <= DIV;
                        operation_valid <= 1'b1;
                    end else if (btnC_pressed && operation_valid) begin
                        state <= INPUT_B;
                    end
                end

                INPUT_B: begin
                    if (btnC_pressed) begin
                        operand_b <= input_value;
                        result_valid <= 1'b0;
                        divide_by_zero <= 1'b0;
                        overflow <= 1'b0;

                        case (operation)
                            ADD: begin
                                result <= add_value;
                                result_valid <= 1'b1;
                                overflow <= add_overflow;
                                history_save <= 1'b1;
                                history_save_value <= add_value;
                                history_select <= 2'd0;
                                state <= RESULT;
                            end
                            SUB: begin
                                result <= sub_value;
                                result_valid <= 1'b1;
                                overflow <= sub_overflow;
                                history_save <= 1'b1;
                                history_save_value <= sub_value;
                                history_select <= 2'd0;
                                state <= RESULT;
                            end
                            MUL: begin
                                result <= multiply_value;
                                result_valid <= 1'b1;
                                overflow <= multiply_overflow;
                                history_save <= 1'b1;
                                history_save_value <= multiply_value;
                                history_select <= 2'd0;
                                state <= RESULT;
                            end
                            default: begin
                                if (division_invalid) begin
                                    result <= 16'sd0;
                                    divide_by_zero <= 1'b1;
                                    state <= RESULT;
                                end else begin
                                    div_dividend_shift <= magnitude8(operand_a);
                                    div_divisor <= magnitude8(input_value);
                                    div_quotient <= 8'd0;
                                    div_remainder <= 9'd0;
                                    div_iteration <= 4'd0;
                                    div_negative <= operand_a[7] ^ input_value[7];
                                    state <= EXECUTE;
                                end
                            end
                        endcase
                    end
                end

                EXECUTE: begin
                    div_dividend_shift <= {div_dividend_shift[6:0], 1'b0};
                    div_remainder <= div_remainder_next;
                    div_quotient <= div_quotient_next;

                    if (div_iteration == 4'd7) begin
                        result <= div_signed_result;
                        result_valid <= 1'b1;
                        overflow <= division_overflow;
                        history_save <= 1'b1;
                        history_save_value <= div_signed_result;
                        history_select <= 2'd0;
                        state <= RESULT;
                    end else begin
                        div_iteration <= div_iteration + 1'b1;
                    end
                end

                RESULT: begin
                    // Stay here until SW14 rises, or history recall is requested.
                end

                default: begin
                    state <= INPUT_A;
                    operation_valid <= 1'b0;
                    result_valid <= 1'b0;
                    divide_by_zero <= 1'b0;
                    overflow <= 1'b0;
                end
            endcase
        end
    end

endmodule
