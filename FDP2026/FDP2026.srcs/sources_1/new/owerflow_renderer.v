`timescale 1ns / 1ps

module owerflow_renderer(
    input [12:0] pixel_index,
    input overflow,
    output reg [15:0] pixel_data
    );
    
    wire [6:0] x;
    wire [5:0] y;
    
    assign x = pixel_index % 96;
    assign y = pixel_index / 96;
    
    // OLED colours (RGB565)
    localparam BLACK  = 16'h0000;
    localparam RED    = 16'hF800;
    
    
    //draw letters using 5*7 pixels
        function draw_letter;
            input [7:0] letter;
            input [6:0] x;
            input [5:0] y;
            input [6:0] xpos;
            input [5:0] ypos;
            
            reg [4:0] bits;
            integer row;
            
            begin
                row = y - ypos;
                bits = 0;
                draw_letter = 0;
                
                if (row >= 0 && row < 7) begin
                    case (letter)
                        "O": case(row)
                            0: bits = 5'b01110;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b10001;
                            4: bits = 5'b10001;
                            5: bits = 5'b10001;
                            6: bits = 5'b01110;
                        endcase
                        
                        "V": case(row)
                            0: bits = 5'b10001;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b10001;
                            4: bits = 5'b10001;
                            5: bits = 5'b01010;
                            6: bits = 5'b00100;
                        endcase
                        
                        "E": case(row)
                            0: bits = 5'b11111;
                            1: bits = 5'b10000;
                            2: bits = 5'b10000;
                            3: bits = 5'b11110;
                            4: bits = 5'b10000;
                            5: bits = 5'b10000;
                            6: bits = 5'b11111;
                        endcase
                        
                        "R": case(row)
                            0: bits = 5'b11110;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b11110;
                            4: bits = 5'b10100;
                            5: bits = 5'b10010;
                            6: bits = 5'b10001;
                        endcase
                        
                        "F": case(row)
                            0: bits = 5'b11111;
                            1: bits = 5'b10000;
                            2: bits = 5'b10000;
                            3: bits = 5'b11111;
                            4: bits = 5'b10000;
                            5: bits = 5'b10000;
                            6: bits = 5'b10000;
                        endcase
                        
                        "L": case(row)
                            0: bits = 5'b10000;
                            1: bits = 5'b10000;
                            2: bits = 5'b10000;
                            3: bits = 5'b10000;
                            4: bits = 5'b10000;
                            5: bits = 5'b10000;
                            6: bits = 5'b11111;
                        endcase
                        
                        "O": case(row)
                            0: bits = 5'b01110;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b10001;
                            4: bits = 5'b10001;
                            5: bits = 5'b10001;
                            6: bits = 5'b01110;
                        endcase
                        
                        
                        "W": case(row)
                            0: bits = 5'b10001;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b10101;
                            4: bits = 5'b10101;
                            5: bits = 5'b10101;
                            6: bits = 5'b11111;
                        endcase
                    endcase
                    
                    if (x >= xpos && x < xpos + 5)
                        draw_letter = bits[4 - (x - xpos)];
                    end
                end
            endfunction
            
            always @(*) begin
        //defult bakground
        pixel_data = BLACK;
        
        //show OVERFLOW when result is outside allowed rage
        if (overflow == 1) begin
            //draw HISTORY title
            if (draw_letter("O", x, y, 27, 46) ||
                draw_letter("V", x, y, 33, 46) ||
                draw_letter("E", x, y, 39, 46) ||
                draw_letter("R", x, y, 45, 46) ||
                draw_letter("F", x, y, 51, 46) ||
                draw_letter("L", x, y, 57, 46) ||
                draw_letter("O", x, y, 63, 46) ||
                draw_letter("W", x, y, 69, 46)) begin
                
                pixel_data = RED;
            end
          end       
    end
endmodule

