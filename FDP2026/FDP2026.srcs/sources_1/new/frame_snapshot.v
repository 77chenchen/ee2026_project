`timescale 1ns / 1ps

// Coherent frame-boundary transfer from the 100 MHz control domain to the
// 6.25 MHz OLED display domain.
//
// frame_prepare is a one-OLED-clock pulse generated while the driver changes
// its address window.  The source domain latches the complete display state
// once and toggles a request.  The destination domain changes data_out only
// after the request has crossed two flops, so no display parameter can change
// halfway through a frame.
module frame_snapshot #(
    parameter integer WIDTH = 1
) (
    input  wire             clk_src,
    input  wire             reset_src,
    input  wire             clk_dst,
    input  wire             reset_dst,
    input  wire             frame_prepare,
    input  wire [WIDTH-1:0] data,
    output reg  [WIDTH-1:0] data_out
);
    // The 100 MHz source is stable while the destination consumes it, so
    // request_sync is a real two-flop synchronizer and the data bus has a
    // settled-valid qualification.  CDC constraints below document that.
    reg [WIDTH-1:0] holding = {WIDTH{1'b0}};
    reg request = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg [1:0] prepare_sync = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [1:0] request_sync = 2'b00;
    reg request_seen = 1'b0;

    wire prepare_rise = prepare_sync[0] && !prepare_sync[1];
    wire request_edge = request_sync[0] ^ request_sync[1];

    always @(posedge clk_src) begin
        if (reset_src) begin
            prepare_sync <= 2'b00;
            holding <= {WIDTH{1'b0}};
            request <= 1'b0;
        end else begin
            prepare_sync <= {prepare_sync[0], frame_prepare};
            if (prepare_rise) begin
                holding <= data;
                request <= ~request;
            end
        end
    end

    always @(posedge clk_dst) begin
        if (reset_dst) begin
            request_sync <= 2'b00;
            request_seen <= 1'b0;
            data_out <= {WIDTH{1'b0}};
        end else begin
            request_sync <= {request_sync[0], request};
            if (request_edge && (request_sync[0] != request_seen)) begin
                data_out <= holding;
                request_seen <= request_sync[0];
            end
        end
    end
endmodule
