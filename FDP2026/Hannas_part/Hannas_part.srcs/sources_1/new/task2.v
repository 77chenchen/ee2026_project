`timescale 1ns / 1ps

module task2(input CLOCK,
             input btnD,
             input [12:0] pixel_index,
             output reg [15:0] oled_data
    );
    
    wire [6:0] x;
    wire [5:0] y;
    
    assign x = pixel_index % 96;
    assign y = pixel_index / 96;
    
    localparam BLACK  = 16'h0000;
    localparam RED    = 16'hF800;
    localparam GREEN  = 16'h07E0;
    localparam BLUE   = 16'h001F;
    localparam YELLOW = 16'hFFE0;

    reg [1:0] counter = 2'b00;
    
    always @(posedge CLOCK) begin
        
        if (btnD)
            counter <= counter + 1;
    end
    
    always @(*) begin
        
        oled_data = BLACK;
         
        if ((x >= 10 && x <= 20) &&
            (y >= 40 && y <= 50))
            oled_data = RED;
             
        else if ((x >= 70 && x <= 80) &&
            (y >= 40 && y <= 50))
            oled_data = GREEN;
            
        else if ((x >= 38 && x <= 57) &&
                 (y >= 40 && y <= 59))
                 oled_data = (counter == 2'b00) ? GREEN  :
                             (counter == 2'b01) ? RED    :
                             (counter == 2'b10) ? BLUE   :
                                                  YELLOW;
           
        end
    
    
endmodule
