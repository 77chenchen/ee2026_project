`timescale 1ns / 1ps

// Compare menu text at the physical SPI output with the intended 96x64 bitmap.
module menu_oled_alignment_tb;
    parameter [1:0] MENU_ARROW=2'd0;
    reg clk=0;
    always #5 clk=~clk;
    wire [7:0] jb;
    wire [15:0] leds;
    wire [7:0] seg;
    wire [3:0] an;
    integer word_count=0,bit_count=0,mismatch_count=0;
    reg [15:0] serial_word=0;
    reg [15:0] expected;
    integer px,py;

    My_Top_Module dut(.CLOCK(clk),.sw(16'd0),
        .btnU(1'b0),.btnD(1'b0),.btnC(1'b0),.btnL(1'b0),.btnR(1'b0),
        .JB(jb),.led(leds),.seg(seg),.an(an));

    initial begin
        #1;
        force dut.arrow=MENU_ARROW;
    end

    // Power-up timing is verified separately. Keep the real video/SPI FSM.
    always @(posedge dut.clk6p25m)
        if (!dut.oled_reset && !dut.sending_pixels) dut.oled.delay=0;

    always @(posedge jb[3]) begin
        if (!jb[0] && jb[4]) begin
            serial_word={serial_word[14:0],jb[1]};
            bit_count=bit_count+1;
            if (bit_count==16) begin
                px=(word_count%6144)%96;
                py=(word_count%6144)/96;
                expected=16'h0000;
                if (dut.draw_word(2'd0,px,py,7'd36,6'd5)) expected=16'hFF60;
                if (dut.draw_word(2'd1,px,py,7'd20,6'd20))
                    expected=(MENU_ARROW==0)?16'h07E0:16'hFFFF;
                if (dut.draw_word(2'd2,px,py,7'd20,6'd35))
                    expected=(MENU_ARROW==1)?16'h07E0:16'hFFFF;
                if (dut.draw_word(2'd3,px,py,7'd20,6'd50))
                    expected=(MENU_ARROW==2)?16'h07E0:16'hFFFF;
                if (dut.draw_arrow(px,py,7'd10,
                    (MENU_ARROW==0)?6'd20:(MENU_ARROW==1)?6'd35:6'd50))
                    expected=16'hFF60;
                if (serial_word!==expected) begin
                    if (mismatch_count<10)
                        $display("MISMATCH pixel=%0d (%0d,%0d) expected=%h got=%h",
                            word_count,px,py,expected,serial_word);
                    mismatch_count=mismatch_count+1;
                end
                word_count=word_count+1;
                bit_count=0;
                serial_word=0;
            end
        end
    end

    initial begin
        wait(dut.sending_pixels);
        repeat (3) begin
            @(negedge dut.sending_pixels);
            if (word_count % 6144 != 0)
                $fatal(1,"incomplete menu SPI frame after %0d words",word_count);
            if (word_count < 18432)
                wait(dut.sending_pixels);
        end
        #1;
        if(word_count!==18432 || mismatch_count!==0)
            $fatal(1,"menu SPI frames: %0d words, %0d wrong pixels",word_count,mismatch_count);
        $display("PASS menu SPI: 3 frames, 18432 exact pixels, all English glyphs aligned");
        $finish;
    end

    initial begin
        #100_000_000;
        $fatal(1,"menu SPI test timed out");
    end
endmodule
