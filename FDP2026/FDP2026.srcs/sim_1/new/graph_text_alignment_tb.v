`timescale 1ns / 1ps

// Verify the Graph title after the top-level OLED output register and SPI.
module graph_text_alignment_tb;
    reg clk=0;
    always #5 clk=~clk;
    wire [7:0] jb;
    integer word_count=0,bit_count=0,mismatch_count=0,title_pixels=0;
    reg [15:0] serial_word=0;
    reg title_bit;
    integer px,py;

    My_Top_Module dut(.CLOCK(clk),.sw(16'd0),
        .btnU(1'b0),.btnD(1'b0),.btnC(1'b0),.btnL(1'b0),.btnR(1'b0),
        .JB(jb),.led(),.seg(),.an());

    initial begin
        #1;
        force dut.choice=2'd2;
    end

    always @(posedge dut.clk6p25m)
        if (!dut.oled_reset && !dut.sending_pixels) dut.oled.delay=0;

    always @(posedge jb[3]) begin
        if (!jb[0] && jb[4]) begin
            serial_word={serial_word[14:0],jb[1]};
            bit_count=bit_count+1;
            if (bit_count==16) begin
                px=word_count%96;
                py=word_count/96;
                if (py>=2 && py<9 && px<34) begin
                    title_bit=
                        dut.graphnator.graph_view.font_pixel("C",px,py,2,2) ||
                        dut.graphnator.graph_view.font_pixel("O",px,py,8,2) ||
                        dut.graphnator.graph_view.font_pixel("U",px,py,14,2) ||
                        dut.graphnator.graph_view.font_pixel("N",px,py,20,2) ||
                        dut.graphnator.graph_view.font_pixel("T",px,py,26,2);
                    if(title_bit) title_pixels=title_pixels+1;
                    if(serial_word!==(title_bit?16'hFFE0:16'h0000)) begin
                        if(mismatch_count<10)
                            $display("GRAPH TITLE mismatch (%0d,%0d): expected=%h got=%h",
                                px,py,(title_bit?16'hFFE0:16'h0000),serial_word);
                        mismatch_count=mismatch_count+1;
                    end
                end
                word_count=word_count+1;
                bit_count=0;
                serial_word=0;
            end
        end
    end

    initial begin
        wait(dut.sending_pixels);
        @(negedge dut.sending_pixels);
        #1;
        if(word_count!==6144 || title_pixels==0 || mismatch_count!==0)
            $fatal(1,"Graph title SPI: %0d words, %0d wrong title pixels",
                word_count,mismatch_count);
        $display("PASS Graph title SPI: %0d exact title pixels",title_pixels);
        $finish;
    end
    initial begin
        #100_000_000;
        $fatal(1,"Graph title SPI test timed out");
    end
endmodule
