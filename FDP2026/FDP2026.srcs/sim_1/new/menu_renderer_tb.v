`timescale 1ns / 1ps
module menu_renderer_tb;
    reg [12:0] pixel_index;
    wire [15:0] pixel_data;
    integer i,cyan_count,green_count,orange_count;
    menu_renderer dut(.pixel_index(pixel_index),.pixel_data(pixel_data));
    initial begin
        cyan_count=0;green_count=0;orange_count=0;
        for(i=0;i<6144;i=i+1) begin pixel_index=i; #1;
            if(pixel_data==16'h07FF)cyan_count=cyan_count+1;
            if(pixel_data==16'h07E0)green_count=green_count+1;
            if(pixel_data==16'hFD20)orange_count=orange_count+1;
        end
        if(cyan_count==0||green_count==0||orange_count==0) begin
            $display("FAIL menu colors title=%0d calc=%0d graph=%0d",cyan_count,green_count,orange_count);
            $finish_and_return(1);
        end
        $display("PASS menu calculator and graph entries");
        $finish;
    end
endmodule
