`timescale 1ns / 1ps

// Check that one rising-edge color register stays aligned with the OLED
// driver's falling-edge SPI load. The timing version of the driver emits a
// complete 6144-word frame, so every pixel must remain aligned.
module oled_pixel_output_stage_tb;
    reg clk = 0;
    always #80 clk = ~clk;
    reg reset = 1;
    wire frame_begin, sending_pixels, sample_pixel;
    wire [12:0] pixel_index;
    wire cs, sdin, sclk, d_cn;
    reg [15:0] staged_pixel;
    integer word_count = 0;
    integer bit_count = 0;
    reg [15:0] serial_word = 0;

    always @(posedge clk)
        staged_pixel <= {3'b000, pixel_index};

    Oled_Display #(.ClkFreq(6_250_000)) oled (
        .clk(clk), .reset(reset), .frame_begin(frame_begin),
        .sending_pixels(sending_pixels), .sample_pixel(sample_pixel),
        .pixel_index(pixel_index), .pixel_data(staged_pixel),
        .cs(cs), .sdin(sdin), .sclk(sclk), .d_cn(d_cn),
        .resn(), .vccen(), .pmoden()
    );

    // Skip power-up delays; this test concerns pixel alignment only.
    always @(posedge clk)
        if (!reset && !sending_pixels) oled.delay = 0;

    always @(posedge sclk) begin
        if (!cs && d_cn) begin
            serial_word = {serial_word[14:0], sdin};
            bit_count = bit_count + 1;
            if (bit_count == 16) begin
                if (serial_word !== word_count[15:0])
                    $fatal(1, "pixel %0d expected %h got %h",
                           word_count, word_count[15:0], serial_word);
                word_count = word_count + 1;
                bit_count = 0;
            end
        end
    end

    initial begin
        repeat (4) @(posedge clk);
        #1 reset = 0;
        wait (sending_pixels);
        @(negedge sending_pixels);
        #1;
        if (word_count != 6144 || bit_count != 0)
            $fatal(1, "expected 6144 complete OLED words, got %0d", word_count);
        $display("PASS one-stage OLED output register: %0d aligned SPI pixels", word_count);
        $finish;
    end

    initial begin
        #100_000_000;
        $fatal(1, "OLED output-stage timeout");
    end
endmodule
