`timescale 1ns/1ps
module pattern_tb;
    reg [12:0] pixel_index=0;
    reg [2:0] pattern=0;
    reg [6:0] bar_x=0;
    wire [15:0] pixel_data;
    integer p,i,b,checks=0;
    oled_test_pattern dut(.*);
    `include "reference_colour.vh"
    initial begin
        for(p=0;p<8;p=p+1) begin
            pattern=p;
            for(i=0;i<6144;i=i+1) begin
                pixel_index=i;#1;
                if(pixel_data!==reference_colour(p,i,0))
                    $fatal(1,"pattern=%0d index=%0d expected=%h got=%h",
                        p,i,reference_colour(p,i,0),pixel_data);
                checks=checks+1;
            end
        end
        for(b=31;b<=95;b=b+32) begin
            pattern=7;bar_x=b;
            for(i=0;i<6144;i=i+1) begin
                pixel_index=i;#1;
                if(pixel_data!==reference_colour(7,i,b)) $fatal(1,"moving bar mismatch");
                checks=checks+1;
            end
        end
        if(checks!=67584) $fatal(1,"pattern coverage count");
        $display("PASS OLED test patterns: 67584 RGB565 pixel checks");
        $finish;
    end
endmodule
