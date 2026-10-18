`timescale 1ns / 1ps

// Two-flop synchronizer, debounce filter and one-clock press pulse.
module button_onepulse #(
    parameter integer COUNTER_BITS = 19
) (
    input  wire clk,
    input  wire reset,
    input  wire button_in,
    output reg  pressed
);
    reg sync_0;
    reg sync_1;
    reg stable_state;
    reg [COUNTER_BITS-1:0] counter;

    always @(posedge clk) begin
        if (reset) begin
            sync_0 <= 1'b0;
            sync_1 <= 1'b0;
            stable_state <= 1'b0;
            counter <= {COUNTER_BITS{1'b0}};
            pressed <= 1'b0;
        end else begin
            sync_0 <= button_in;
            sync_1 <= sync_0;
            pressed <= 1'b0;

            if (sync_1 == stable_state) begin
                counter <= {COUNTER_BITS{1'b0}};
            end else if (&counter) begin
                stable_state <= sync_1;
                counter <= {COUNTER_BITS{1'b0}};
                if (sync_1) pressed <= 1'b1;
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end
endmodule
