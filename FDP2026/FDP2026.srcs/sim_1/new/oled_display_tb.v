`timescale 1ns / 1ps

// Interface-level regression for the supplied SSD1331 driver.  It verifies
// the two failure modes that are easy to miss in a framebuffer-only test:
// the power-up settling interval and transmission of all 6144 RGB565 words.
module oled_display_tb;
    localparam integer CLK_FREQ = 6_250_000;
    localparam integer CLK_HALF_PERIOD_NS = 80;
    localparam integer POWER_DELAY_NS = 20_000_000;
    localparam integer RESET_DELAY_NS = 3_000;

    reg clk = 1'b0;
    reg reset = 1'b1;

    wire frame_begin;
    wire sending_pixels;
    wire sample_pixel;
    wire [12:0] pixel_index;
    wire [15:0] pixel_data = {3'b000, pixel_index};
    wire cs;
    wire sdin;
    wire sclk;
    wire d_cn;
    wire resn;
    wire vccen;
    wire pmoden;

    integer power_enabled_at;
    integer reset_asserted_at;
    integer reset_released_at;
    integer sample_count = 0;
    integer word_count = 0;
    integer bit_count = 0;
    integer error_count = 0;
    reg [15:0] captured_word = 16'h0000;
    reg video_seen = 1'b0;
    reg frame_active = 1'b0;
    reg pixel_zero_prefetched = 1'b0;

    always #CLK_HALF_PERIOD_NS clk = ~clk;

    Oled_Display #(.ClkFreq(CLK_FREQ)) dut (
        .clk(clk), .reset(reset),
        .frame_begin(frame_begin), .sending_pixels(sending_pixels),
        .sample_pixel(sample_pixel), .pixel_index(pixel_index),
        .pixel_data(pixel_data), .cs(cs), .sdin(sdin), .sclk(sclk),
        .d_cn(d_cn), .resn(resn), .vccen(vccen), .pmoden(pmoden)
    );

    always @(posedge pmoden)
        power_enabled_at = $time;

    always @(negedge resn) begin
        reset_asserted_at = $time;
        if (($time - power_enabled_at) < POWER_DELAY_NS) begin
            $display("FAIL OLED power delay: %0d ns", $time-power_enabled_at);
            error_count = error_count + 1;
        end
    end

    always @(posedge resn) begin
        // Ignore the initial X/1 transition before the first reset assertion.
        if (reset_asserted_at > 0) begin
            reset_released_at = $time;
            if (($time - reset_asserted_at) < RESET_DELAY_NS) begin
                $display("FAIL OLED reset width: %0d ns", $time-reset_asserted_at);
                error_count = error_count + 1;
            end
        end
    end

    always @(posedge sample_pixel) begin
        video_seen = 1'b1;
        if (frame_active) begin
            if (pixel_index !== sample_count[12:0]) begin
                $display("FAIL sample index expected=%0d got=%0d", sample_count,
                         pixel_index);
                error_count = error_count + 1;
            end
            sample_count = sample_count + 1;
        end else if (pixel_index == 0) begin
            // The core requests pixel zero while waiting for the frame start.
            pixel_zero_prefetched = 1'b1;
        end
    end

    always @(posedge sending_pixels) begin
        frame_active = 1'b1;
        sample_count = 1; // pixel zero was requested immediately before entry
        if (!pixel_zero_prefetched) begin
            $display("FAIL pixel zero was not prefetched");
            error_count = error_count + 1;
        end
    end

    always @(negedge sending_pixels)
        frame_active = 1'b0;

    // Observe the serial interface rather than internal registers.  A word is
    // captured MSB first on each active SCLK rising edge.
    always @(posedge sclk) begin
        if (!cs && d_cn) begin
            captured_word = {captured_word[14:0], sdin};
            bit_count = bit_count + 1;
            if (bit_count == 16) begin
                if (captured_word !== word_count[15:0]) begin
                    $display("FAIL pixel word expected=%0d got=%h", word_count,
                             captured_word);
                    error_count = error_count + 1;
                end
                word_count = word_count + 1;
                bit_count = 0;
                captured_word = 16'h0000;
            end
        end
    end

    initial begin
        power_enabled_at = 0;
        reset_asserted_at = 0;
        reset_released_at = 0;

        repeat (4) @(posedge clk);
        #1 reset = 1'b0;

        wait (video_seen);
        wait (sending_pixels);
        @(negedge sending_pixels);
        #1;

        if (sample_count != 6144) begin
            $display("FAIL sample count expected=6144 got=%0d", sample_count);
            error_count = error_count + 1;
        end
        if (word_count != 6144) begin
            $display("FAIL pixel word count expected=6144 got=%0d", word_count);
            error_count = error_count + 1;
        end
        if (bit_count != 0) begin
            $display("FAIL partial final pixel bits=%0d", bit_count);
            error_count = error_count + 1;
        end

        if (error_count == 0)
            $display("PASS OLED power/reset timing and complete 96x64 frame");
        else
            $display("FAIL OLED regression errors=%0d", error_count);
        $finish;
    end

    initial begin
        #300_000_000;
        $display("FAIL OLED regression timeout");
        $finish;
    end
endmodule
