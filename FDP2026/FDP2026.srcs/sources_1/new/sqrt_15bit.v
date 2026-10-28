`timescale 1ns / 1ps

// Serialized integer square root for a 15-bit unsigned value.  Each trial
// square uses a registered 8x8 multiplier and a compare on the following
// clock, keeping the triangle arithmetic off a long combinational path.
module sqrt_15bit(
    input  wire        clk,
    input  wire        start,
    input  wire [14:0] value,
    output reg         busy,
    output reg         done,
    output reg  [7:0]  root
);
    reg [7:0] root_value;
    reg [2:0] bit_index;
    reg [7:0] trial;
    reg [15:0] trial_square;
    reg [2:0] phase;
    reg [15:0] value_latched;

    always @(posedge clk) begin
        done <= 1'b0;
        if (start) begin
            root_value <= 8'd0;
            bit_index <= 3'd7;
            phase <= 3'd1;
            value_latched <= {1'b0, value};
            busy <= 1'b1;
        end else if (busy) begin
            case (phase)
                3'd1: begin
                    trial <= root_value | (8'd1 << bit_index);
                    phase <= 3'd2;
                end
                3'd2: begin
                    trial_square <= trial * trial;
                    phase <= 3'd3;
                end
                default: begin
                    if (trial_square <= value_latched)
                        root_value <= trial;
                    if (bit_index == 3'd0) begin
                        root <= (trial_square <= value_latched) ?
                            trial : root_value;
                        busy <= 1'b0;
                        done <= 1'b1;
                        phase <= 3'd0;
                    end else begin
                        bit_index <= bit_index - 1'b1;
                        phase <= 3'd1;
                    end
                end
            endcase
        end
    end
endmodule
