`timescale 1ns / 1ps

// Synchronise and debounce an asynchronous board switch.  level changes only
// after the new value has remained stable for 2**COUNTER_BITS clock cycles;
// rising and falling are one-clock pulses.
module switch_sync #(
    parameter integer COUNTER_BITS = 18
) (
    input  wire clk,
    input  wire reset,
    input  wire async_in,
    output reg  level,
    output reg  rising,
    output reg  falling
);
    reg sync_0;
    reg sync_1;
    reg [COUNTER_BITS-1:0] counter;

    always @(posedge clk) begin
        if (reset) begin
            sync_0 <= 1'b0;
            sync_1 <= 1'b0;
            level <= 1'b0;
            counter <= {COUNTER_BITS{1'b0}};
            rising <= 1'b0;
            falling <= 1'b0;
        end else begin
            sync_0 <= async_in;
            sync_1 <= sync_0;
            rising <= 1'b0;
            falling <= 1'b0;

            if (sync_1 == level) begin
                counter <= {COUNTER_BITS{1'b0}};
            end else if (&counter) begin
                level <= sync_1;
                counter <= {COUNTER_BITS{1'b0}};
                if (sync_1)
                    rising <= 1'b1;
                else
                    falling <= 1'b1;
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end
endmodule
