`timescale 1ns / 1ps

module task3(input CLOCK,
             input SW1,
             input [12:0] pixel_index,
             output reg [15:0] oled_data
    );
    
    wire [6:0] x;
    wire [5:0] y;
    
    assign x = pixel_index % 96;
    assign y = pixel_index / 96;
    
    localparam BLACK     = 16'h0000;
    localparam ORANGE    = 16'hFF60;
    localparam LIGHTBLUE = 16'h7DFF;
    
    reg [6:0] blue_x = 0;
    reg direction = 0;
    reg [22:0] move_counter = 0;
    
    always @(posedge CLOCK) begin
                
        if (SW1 == 1)
            if (move_counter == 4_000_000 - 1) begin
            
                move_counter <= 0;
                
                if (direction == 0) begin
                    if (blue_x >= 76)
                        direction <= 1;
                    else  
                        blue_x <= blue_x + 1;
                end            
        //SW1 ? ... : ...;
        //x <= x + 1;
        
                else begin
                    if (blue_x == 0)
                        direction <= 0;
                    else
                        blue_x <= blue_x - 1;
                    
                end
            end
            
            else
            
                move_counter <= move_counter + 1;
            end
    
    always @(*) begin
        
        oled_data = BLACK;
                                   
        if ((x <= 50 && x >= 69) &&
            (y <= 40 && y >= 59))
            oled_data = ORANGE;
            
        else if ((x >= blue_x && x < blue_x + 20) &&
            (y >= 22 && y <= 41))
            oled_data = LIGHTBLUE;

    end    
endmodule
