`timescale 1ns/1ps
module spi_tb;
    reg CLOCK=0;
    always #5 CLOCK=~CLOCK;
    reg [3:0] sw=0;
    reg SW15=0;
    wire [7:0] JB,led;
    OLED_Test_Top dut(.*);
    integer requested=0,frames=0,words=0,bits=0,bar=0,total_words=0;
    reg [15:0] word_value=0;
    reg video_seen=0;
    time power_on=0,reset_low=0;
    `include "reference_colour.vh"

    // No acceleration, forced clocks, skipped power delays or injected
    // frame events: exercise the real top-level clock/reset/SPI chain.
    always @(posedge JB[7]) power_on=$time;
    always @(negedge JB[5]) begin
        if(power_on>0) begin
            reset_low=$time;
            if($time-power_on<20_000_000) $fatal(1,"OLED VDD power settling too short");
        end
    end
    always @(posedge JB[5]) begin
        if(reset_low>0 && $time-reset_low<3_000) $fatal(1,"OLED hardware reset pulse too short");
    end
    always @(posedge dut.sending_pixels) begin
        video_seen=1;words=0;bits=0;bar=dut.bar_x;
        if(JB[7:5]!==3'b111 || dut.active_pattern!==requested[2:0])
            $fatal(1,"OLED power or selected pattern at frame start");
    end
    always @(posedge JB[3]) begin
        if(!JB[0] && JB[4]) begin
            word_value={word_value[14:0],JB[1]};bits=bits+1;
            if(bits==16) begin
                if(word_value!==reference_colour(requested,words,bar))
                    $fatal(1,"SPI pattern=%0d pixel=%0d expected=%h got=%h",
                        requested,words,reference_colour(requested,words,bar),word_value);
                words=words+1;total_words=total_words+1;bits=0;
            end
        end
    end
    always @(negedge dut.sending_pixels) begin
        if(video_seen) begin
            if(words!=6144 || bits!=0) $fatal(1,"Incomplete OLED frame");
            frames=frames+1;
        end
    end
    initial begin
        for(requested=0;requested<8;requested=requested+1) begin
            if(requested>0) sw=requested;
            wait(dut.sending_pixels);
            @(negedge dut.sending_pixels);#1;
        end
        if(frames!=8 || total_words!=49152) $fatal(1,"OLED SPI frame coverage");
        $display("PASS standalone OLED hardware top: unaccelerated startup and 49152 serial pixels across all 8 patterns");
        $finish;
    end
    initial begin #350_000_000;$fatal(1,"OLED serial test timeout");end
endmodule
