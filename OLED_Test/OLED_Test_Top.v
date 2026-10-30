`timescale 1ns / 1ps

// Minimal Basys3 OLED test: a working display turns solid white on Pmod JB.
module OLED_Test_Top(
    input wire CLOCK,
    output wire [7:0] JB
);
    // 100 MHz board clock / 16 = 6.25 MHz for the course OLED driver.
    reg [2:0] divide_count = 0;
    reg oled_clk = 0;
    always @(posedge CLOCK) begin
        divide_count <= divide_count + 1'b1;
        if (divide_count == 7)
            oled_clk <= ~oled_clk;
    end

    // Reset the driver on power-up so it runs its OLED power-up sequence.
    reg [3:0] reset_count = 0;
    wire oled_reset = (reset_count != 8);
    always @(posedge oled_clk)
        if (reset_count != 8)
            reset_count <= reset_count + 1'b1;

    Oled_Display #(.ClkFreq(6_250_000)) oled(
        .clk(oled_clk), .reset(oled_reset),
        .frame_begin(), .sending_pixels(), .sample_pixel(),
        .pixel_index(), .pixel_data(16'hFFFF),
        .cs(JB[0]), .sdin(JB[1]), .sclk(JB[3]), .d_cn(JB[4]),
        .resn(JB[5]), .vccen(JB[6]), .pmoden(JB[7])
    );
    assign JB[2] = 1'b0; // Unused OLED pin.
endmodule
