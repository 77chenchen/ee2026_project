`timescale 1ns / 1ps

// Hardware diagnostic only: isolate the panel and SPI path from all fonts,
// graph maths, and the main project's pixel mux.
module OLED_Uniform_Test(
    input  wire       CLOCK,
    input  wire [1:0] sw,
    output wire [7:0] JB
);
    wire oled_clk;
    wire cs, sdin, sclk, d_cn, resn, vccen, pmoden;
    reg [1:0] startup_count = 2'd0;
    wire oled_reset = (startup_count != 2'd2);

    clock_hz clk_6_25(
        .HZ(32'd6250000), .CLOCK(CLOCK), .SLOW_CLOCK(oled_clk)
    );

    always @(posedge oled_clk) begin
        if (startup_count != 2'd2)
            startup_count <= startup_count + 1'b1;
    end

    // 00 white, 01 red, 10 green, 11 blue. A uniform image makes any
    // persistent missing panel pixels easy to distinguish from font logic.
    wire [15:0] solid_color =
        (sw == 2'b01) ? 16'hF800 :
        (sw == 2'b10) ? 16'h07E0 :
        (sw == 2'b11) ? 16'h001F : 16'hFFFF;

    Oled_Display #(.ClkFreq(6250000)) oled(
        .clk(oled_clk), .reset(oled_reset),
        .frame_begin(), .sending_pixels(), .sample_pixel(),
        .pixel_index(), .pixel_data(solid_color),
        .cs(cs), .sdin(sdin), .sclk(sclk), .d_cn(d_cn),
        .resn(resn), .vccen(vccen), .pmoden(pmoden)
    );

    assign JB[0] = cs;
    assign JB[1] = sdin;
    assign JB[2] = 1'b0;
    assign JB[3] = sclk;
    assign JB[4] = d_cn;
    assign JB[5] = resn;
    assign JB[6] = vccen;
    assign JB[7] = pmoden;
endmodule
