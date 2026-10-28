`timescale 1ns / 1ps

module triangle_renderer(input [12:0] pixel_index,
                         input wire [6:0] x,
                         input wire [5:0] y,
                         input [1:0] state,
                         input choice,
                         input [6:0] a,
                         input [6:0] b,
                         input [14:0] c,
                         input [6:0] sw,
                         input invalid,
                         output reg [15:0] oled_data);
                         
    // OLED colours (RGB565)
    localparam BLACK    = 16'h0000;
    localparam WHITE    = 16'hFFFF;
    localparam GREEN    = 16'h07E0;
    localparam ORANGE   = 16'hFF60;
    localparam RED      = 16'hF800;
    
    //states from right_angel_triangle
    localparam state_0 = 2'd0;
    localparam state_1 = 2'd1;
    localparam state_2 = 2'd2;
    localparam state_3 = 2'd3;
    
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
                row = $signed({1'b0, y}) - $signed({1'b0, ypos});
                bits = 0;
                draw_letter = 0;
                
                if (row >= 0 && row < 7) begin
                    case (letter)
                        "A", "a": case(row)
                            0: bits = 5'b01110;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b11111;
                            4: bits = 5'b10001;
                            5: bits = 5'b10001;
                            6: bits = 5'b10001;
                        endcase
                        
                        "B", "b": case(row)
                            0: bits = 5'b11110;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b11110;
                            4: bits = 5'b10001;
                            5: bits = 5'b10001;
                            6: bits = 5'b11110;
                        endcase
                        
                        "C", "c": case(row)
                            0: bits = 5'b01110;
                            1: bits = 5'b10001;
                            2: bits = 5'b10000;
                            3: bits = 5'b10000;
                            4: bits = 5'b10000;
                            5: bits = 5'b10001;
                            6: bits = 5'b01110;
                        endcase
                        
                        "D": case(row)
                            0: bits = 5'b11110;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b10001;
                            4: bits = 5'b10001;
                            5: bits = 5'b10001;
                            6: bits = 5'b11110;
                        endcase
                        
                        "E": case(row)
                            0: bits = 5'b11111;
                            1: bits = 5'b10000;
                            2: bits = 5'b10000;
                            3: bits = 5'b11111;
                            4: bits = 5'b10000;
                            5: bits = 5'b10000;
                            6: bits = 5'b11111;
                        endcase
                        
                        "G": case(row)
                            0: bits = 5'b01111;
                            1: bits = 5'b10000;
                            2: bits = 5'b10000;
                            3: bits = 5'b10111;
                            4: bits = 5'b10001;
                            5: bits = 5'b10001;
                            6: bits = 5'b01111;
                        endcase
                        
                        "H": case(row)
                            0: bits = 5'b10001;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b11111;
                            4: bits = 5'b10001;
                            5: bits = 5'b10001;
                            6: bits = 5'b10001;
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
                             
                        "P": case(row)
                            0: bits = 5'b11110;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b11110;
                            4: bits = 5'b10000;
                            5: bits = 5'b10000;
                            6: bits = 5'b10000;
                        endcase
                             
                        "U": case(row)
                            0: bits = 5'b10001;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b10001;
                            4: bits = 5'b10001;
                            5: bits = 5'b10001;
                            6: bits = 5'b01110;
                        endcase
                        
                        "Y": case(row)
                            0: bits = 5'b10001;
                            1: bits = 5'b10001;
                            2: bits = 5'b01010;
                            3: bits = 5'b00100;
                            4: bits = 5'b00100;
                            5: bits = 5'b00100;
                            6: bits = 5'b00100;
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
                        
                        "O": case(row)
                            0: bits = 5'b01110;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b10001;
                            4: bits = 5'b10001;
                            5: bits = 5'b10001;
                            6: bits = 5'b01110;
                        endcase
                        
                        "=": case(row)
                            2: bits = 5'b11111;
                            4: bits = 5'b11111;
                        endcase
                    endcase
                    
                    if (x >= xpos && x < xpos + 5)
                        draw_letter = bits[4 - (x - xpos)];
                    end
                end
            endfunction
            
    // Function to draw the digits
    function draw_digit;
        input [3:0] digit;
        input [6:0] x;
        input [5:0] y;
        input [6:0] xpos;
        input [5:0] ypos;
        
        reg A, B, C, D, E, F, G;
        
        begin
            
            A = 0; B = 0; C = 0; D = 0; E = 0; F = 0; G = 0;
            
            case(digit)
                0: begin
                    A = 1; B = 1; C = 1; D = 1; E = 1; F = 1;
                end
                
                1: begin
                    B = 1; C = 1;
                end
                
                2: begin
                    A = 1; B = 1; G = 1; E = 1; D = 1;
                end
                
                3: begin
                    A = 1; B = 1; C = 1; D = 1; G = 1;
                end
                
                4: begin
                    F = 1; G = 1; B = 1; C = 1;
                end   
                
                5: begin
                    A = 1; F = 1; G = 1; C = 1; D = 1;
                end 
                
                6: begin
                    A = 1; E = 1; G = 1; F = 1; D = 1; C = 1; 
                end
                
                7: begin
                    A = 1; B = 1; C = 1;
                end
                
                8: begin
                    A = 1; B = 1; C = 1; D = 1; E = 1; F = 1; G = 1;
                end
                
                9: begin
                    A = 1; B = 1; C = 1; D = 1; F = 1; G = 1;
                end
                
            endcase
            
            draw_digit =
                (A && x >= xpos+1  && x <= xpos+6 &&
                      y >= ypos    && y <= ypos+1) ||

                (B && x >= xpos+6  && x <= xpos+7 &&
                      y >= ypos    && y <= ypos+5) ||

                (C && x >= xpos+6  && x <= xpos+7 &&
                      y >= ypos+5  && y <= ypos+9) ||

                (D && x >= xpos+1  && x <= xpos+6 &&
                      y >= ypos+9  && y <= ypos+10) ||

                (E && x >= xpos+1  && x <= xpos+2 &&
                      y >= ypos+5  && y <= ypos+9) ||

                (F && x >= xpos+1  && x <= xpos+2 &&
                      y >= ypos    && y <= ypos+5) ||

                (G && x >= xpos+1  && x <= xpos+6 &&
                      y >= ypos+5  && y <= ypos+6) ||

                0;
            end
        endfunction
        
        //draw a number using three digits
        function draw_number;
                input [14:0] number;
                input [6:0] xpos;
                input [5:0] ypos;

                reg [3:0] hundreds;
                reg [3:0] tens;
                reg [3:0] ones;

                begin
                    //seperate the number into digits
                    hundreds = (number / 100) % 10;
                    tens = (number / 10) % 10;
                    ones = number % 10;
                    
                    //draw each digit
                    draw_number = draw_digit(hundreds, x, y, xpos, ypos) ||
                                  draw_digit(tens, x, y, xpos+12, ypos) ||
                                  draw_digit(ones, x, y, xpos+24, ypos);

                    end
            endfunction
    
    always @(*) begin
        //defult background
        oled_data = BLACK;
        
        //state 0: show right angle triangle
        if (state == state_0) begin
            
            //draw side a
            if (x == 23 && y >= 5 && y <= 34)
                oled_data = ORANGE;
                
            //draw side b
            else if (y == 34 && x >= 23 && x <= 63) 
                oled_data = ORANGE;
                
            //draw side c
            else if (x >= 23 && x <= 63 && y >= 5 && y <= 34 && 
                     y >= 5 + ((x - 23) * 29) / 40 &&
                     y <= 6 + ((x - 23) * 29) / 40)
                oled_data = ORANGE;
                
            //draw triangle lables
            if (draw_letter("a", x, y, 12, 17) ||
                draw_letter("b", x, y, 42, 37) ||
                draw_letter("c", x, y, 43, 10))
                oled_data = GREEN;
                
            //menu option 1: U CALC HYP
            if (draw_letter("U", x, y, 3, 46) ||
                draw_letter("C", x, y, 15, 46) ||
                draw_letter("A", x, y, 21, 46) ||
                draw_letter("L", x, y, 27, 46) ||
                draw_letter("C", x, y, 33, 46) ||
                draw_letter("H", x, y, 45, 46) ||
                draw_letter("Y", x, y, 51, 46) ||
                draw_letter("P", x, y, 57, 46))
                oled_data = WHITE;
                
            //menu option 2: D CALC LEG
            if (draw_letter("D", x, y, 3, 56) ||
                draw_letter("C", x, y, 15, 56) ||
                draw_letter("A", x, y, 21, 56) ||
                draw_letter("L", x, y, 27, 56) ||
                draw_letter("C", x, y, 33, 56) ||
                draw_letter("L", x, y, 45, 56) ||
                draw_letter("E", x, y, 51, 56) ||
                draw_letter("G", x, y, 57, 56))
                oled_data = WHITE;
            
            //highligt selected calculation
            if (choice == 0) begin
                //hypothenuse selected
                if (x <= 1 && y >= 46 && y <= 52)
                    oled_data = GREEN;
            end
            else begin
                //leg selected
                if (x <= 1 && y >= 56 && y <= 62)
                    oled_data = GREEN;
            end    
            
        end
        
        //state 1: enter first value
        else if (state == state_1) begin
            //show which side we are enering
            if ((choice == 0 && draw_letter("a", x, y, 15, 15)) ||
                (choice == 1 && draw_letter("b", x, y, 15, 15)) ||
                draw_letter("=", x, y, 24, 15))
                oled_data = GREEN;
                
            //show current switch value
            if (draw_number({8'd0, sw}, 36, 15))
                oled_data = ORANGE;
        end
        
        //state 2: enter second value
        else if (state == state_2) begin
            //show which side we are entering
            if ((choice == 0 && draw_letter("b", x, y, 15, 15)) ||
                (choice == 1 && draw_letter("c", x, y, 15, 15)) ||
                draw_letter("=", x, y, 24, 15))
                oled_data = GREEN;
            
            //show current switch value
            if (draw_number({8'd0, sw}, 36, 15))
                oled_data = ORANGE;
        end
        
        //state 3: show saved values and result
        else if (state == state_3) begin
            if (invalid) begin
                //show error if calculation is invalid
                if (draw_letter("E", x, y, 25, 25) ||
                    draw_letter("R", x, y, 31, 25) ||
                    draw_letter("R", x, y, 37, 25) ||
                    draw_letter("O", x, y, 43, 25) ||
                    draw_letter("R", x, y, 49, 25))
                    oled_data = RED;
            end
            else begin
                //first saved value
                if ((choice == 0 && draw_letter("a", x, y, 12, 7)) ||
                    (choice == 1 && draw_letter("b", x, y, 12, 7)) ||
                    draw_letter("=", x, y, 22, 7))
                    oled_data = WHITE;
                    
                if (draw_number(choice == 0 ?
                                {8'd0, a} : {8'd0, b}, 36, 5))
                    oled_data = GREEN;
                    
                //second saved value
                if ((choice == 0 && draw_letter("b", x, y, 12, 25)) ||
                    (choice == 1 && draw_letter("c", x, y, 12, 25)) ||
                    draw_letter("=", x, y, 22, 25))
                    oled_data = WHITE;
                    
                if (draw_number(choice == 0 ?
                                {8'd0, b} : c, 36, 23))
                    oled_data = GREEN;
                    
                //separator
                if (y == 38 && x >= 8 && x <= 87)
                    oled_data = WHITE;
                    
                //result
                if ((choice == 0 && draw_letter("c", x, y, 12, 47)) ||
                    (choice == 1 && draw_letter("a", x, y, 12, 47)) ||
                    draw_letter("=", x, y, 22, 47))
                    oled_data = ORANGE;
                    
                if (draw_number(choice == 0 ?
                                c : {8'd0, a}, 36, 45))
                    oled_data = ORANGE;
                end
           end
    end 
endmodule

