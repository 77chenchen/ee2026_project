`timescale 1ns / 1ps

// Synchronises the eight data switches and exposes one signed two's-complement
// value.  The calculator and graph controller both use this exact convention.
module signed_switch_input (
    input  wire              clk,
    input  wire              reset,
    input  wire [7:0]        switches,
    output wire signed [7:0] value
);
    reg [7:0] sync_0;
    reg [7:0] sync_1;

    always @(posedge clk) begin
        if (reset) begin
            sync_0 <= 8'd0;
            sync_1 <= 8'd0;
        end else begin
            sync_0 <= switches;
            sync_1 <= sync_0;
        end
    end

    assign value = $signed(sync_1);
endmodule
