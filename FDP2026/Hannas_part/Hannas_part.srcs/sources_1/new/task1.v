`timescale 1ns / 1ps

module task1(input CLOCK,
             input btnU,
             input [12:0] pixel_index,
             output reg [15:0] oled_data
    );
    
    wire [6:0] x; //96
    wire [5:0] y; //64
    
    assign x = pixel_index % 96;
    assign y = pixel_index / 96;
    
    localparam BLACK = 16'h0000;
    localparam RED   = 16'hF800;
    localparam GREEN = 16'h07E0;
    localparam WHITE = 16'hFFFF;
        
    reg pressed = 1'b0;
    reg old_btnU = 1'b0;
    
    reg [24:0] debounce_count = 0;
    reg debounce_active = 0;
    
    always @(posedge CLOCK) begin
        if (btnU)
            pressed <= ~pressed;
    end
        
        
    always @(*) begin
    
        oled_data = BLACK; //varje pixel börjar svart
    
        
        if (!pressed) begin
            //red 5
            if ((x >= 10 && x <= 39) &&
                (y >= 10 && y <= 16))
                oled_data = RED;
            else if ((x >= 10 && x <= 16) &&
                     (y >= 10 && y <= 31))
                oled_data = RED;
            else if ((x >= 10 && x <= 39) &&
                     (y >= 29 && y <= 35))
                oled_data = RED;
            else if ((x >= 33 && x <= 39) &&
                     (y >= 29 && y <= 55))
                oled_data = RED; 
            else if ((x >= 10 && x <= 39) &&
                     (y >= 49 && y <= 55))
                oled_data = RED; 
                
            //green 7
            if ((x >= 57 && x <= 86) &&
                (y >= 10 && y <= 16))
                oled_data = GREEN;
            else if ((x >= 80 && x <= 86) &&
                     (y >= 10 && y <= 55))
                oled_data = GREEN;
                
            //white circle
            if (((x - 6)*(x - 6) + (y - 6)*(y - 6)) <= 25)
                oled_data = WHITE;
            end
    end
 
endmodule
