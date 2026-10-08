`timescale 1ns / 1ps

module calculator(input CLOCK,
                  input btnU, btnD, btnL, btnR, btnC,
                  input [7:0] sw,
                  input SW14, SW15,
                  input [12:0] pixel_index,
                  output reg [15:0] oled_data
                  );
                  
    wire [6:0] x;
    wire [5:0] y;
    
    assign x = pixel_index % 96;
    assign y = pixel_index / 96;
    
    localparam BLACK  = 16'h0000;
    localparam ORANGE = 16'hFF60;
    localparam GREEN  = 16'h07E0;
       
         // Calculations:
    
    reg signed [7:0] operand_A;
    reg signed [7:0] operand_B;
    wire signed [7:0] switch_value;

    assign switch_value = sw;
    
    reg old_btnC = 0;
    
    // Operation choices
    reg [1:0] operation;
    
    localparam ADD = 2'b00;
    localparam SUB = 2'b01;
    localparam MUL = 2'b10;
    localparam DIV = 2'b11;
    
    reg operation_selected = 0;

    // Result larger than 8 bits (127 * 127 = 16129)
    reg signed [15:0] result;
    
    // States:
    localparam FIRST_NUMBER     = 2'b00;
    localparam CHOOSE_OPERATION = 2'b01;
    localparam SECOND_NUMBER    = 2'b10;
    localparam SHOW_RESULT      = 2'b11;
    reg [1:0] state = FIRST_NUMBER;
    
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
    
    always @(posedge CLOCK) begin
        
        old_btnC <= btnC;

        // State 0: First number choice
        if (state == FIRST_NUMBER) begin
            if (btnC && !old_btnC) begin
                operand_A <= switch_value;
                state <= CHOOSE_OPERATION;
            end
        end
      
        // State 1: Operation choice
        else if (state == CHOOSE_OPERATION) begin
            if (btnU) begin
                operation <= ADD;
                operation_selected <= 1;
            end
            else if (btnD) begin
                operation <= SUB;
                operation_selected <= 1;
            end
            else if (btnL) begin
                operation <= MUL;
                operation_selected <= 1;
            end
            else if (btnR) begin
                operation <= DIV;
                operation_selected <= 1;
            end
                
            if (btnC && !old_btnC && operation_selected)
                state <= SECOND_NUMBER;
        end
        
        // State 2: Second number choice and calculation
       else if (state == SECOND_NUMBER) begin
            if (btnC && !old_btnC) begin
                operand_B <= switch_value;
        
                if (operation == DIV) begin
                    if (switch_value == 0)
                        result <= 0;
                    else
                        result <= operand_A / switch_value;
                end
                else if (operation == ADD)
                    result <= operand_A + switch_value;
                else if (operation == SUB)
                    result <= operand_A - switch_value;
                else if (operation == MUL)
                    result <= operand_A * switch_value;
        
                state <= SHOW_RESULT;
            end
        end
        
        // State 3: Show result
        else if (state == SHOW_RESULT) begin  
        
            if (SW14) begin          
                state <= FIRST_NUMBER;
                operand_A <= 0;
                operand_B <= 0;
                result <= 0;
                operation_selected <= 0;
            end
            
        end
        
    end
    
    reg [3:0] thousands;
    reg [3:0] hundreds;
    reg [3:0] tens;
    reg [3:0] ones;
    
    reg [7:0] display_A;
    reg [7:0] display_B;
    reg [15:0] display_result;
    reg [7:0] display_switch;
    
    always @(*) begin
        
        oled_data = BLACK;
        
        if (operand_A < 0)
            display_A = -operand_A;
        else
            display_A = operand_A;
        
        if (operand_B < 0)
            display_B = -operand_B;
        else
            display_B = operand_B;
        
        if (result < 0)
            display_result = -result;
        else
            display_result = result;
            
        if (switch_value < 0)
            display_switch = -switch_value;
        else
            display_switch = switch_value;    
        
        hundreds = 0;
        tens = 0;
        ones = 0;
            
        // State 0: Write first number in orange
        if (state == FIRST_NUMBER) begin
            
            //OPERAND A:
            // largest possible number: 127
            hundreds  = (display_switch / 100) % 10;
            tens      = (display_switch / 10) % 10;
            ones      = display_switch % 10;
            
            if (draw_digit(hundreds, x, y, 27, 5))
                oled_data = ORANGE;
            else if (draw_digit(tens, x, y, 44, 5))
                oled_data = ORANGE;
            else if (draw_digit(ones, x, y, 61, 5))
                oled_data = ORANGE;
        end
        
        // State 1: Write number again in green + Write operator in orange
        
        else if (state == CHOOSE_OPERATION) begin
            //OPERAND A:
            
            hundreds  = (display_A / 100) % 10;
            tens      = (display_A / 10) % 10;
            ones      = display_A % 10;
            
            if (draw_digit(hundreds, x, y, 27, 5))
                oled_data = GREEN;
            else if (draw_digit(tens, x, y, 44, 5))
                oled_data = GREEN;
            else if (draw_digit(ones, x, y, 61, 5))
                oled_data = GREEN;
        
            //OPERATION SIGN
            if (operation_selected) begin
                if (operation == ADD) begin
                    if (((x >= 79 && x <= 81) &&
                         (y >= 5  && y <= 15)) ||
                        ((x >= 75 && x <= 85) &&
                         (y >= 9  && y <= 11)))
                        oled_data = GREEN;
                end
                
                else if (operation == SUB) begin
                    if ((x >= 75 && x <= 85) &&
                        (y >= 9 && y <= 11))    
                        oled_data = GREEN;    
                end    
                   
                else if (operation == DIV) begin
                    if (((x >= 75 && x <= 85) &&
                         (y >= 9 && y <= 11)) ||
                        ((x >= 79 && x <= 81) &&
                         (y >= 5 && y <= 7)) ||
                        ((x >= 79 && x <= 81) &&
                         (y >= 13 && y <= 15)))
                        oled_data = GREEN; 
                end
                  
                else if (operation == MUL) begin
                    if (((x - 79)*(x - 79) + (y - 9)*(y - 9)) <= 16)
                        oled_data = GREEN;  
                end 
            end
        end
            
        else if (state == SECOND_NUMBER) begin
            
            // OPERAND B:
            // largest possible number: 127
            hundreds  = (display_switch / 100) % 10;
            tens      = (display_switch / 10) % 10;
            ones      = display_switch % 10;
            
            if (draw_digit(hundreds, x, y, 27, 20))
                oled_data = ORANGE;
            else if (draw_digit(tens, x, y, 44, 20))
                oled_data = ORANGE;
            else if (draw_digit(ones, x, y, 61, 20))
                oled_data = ORANGE;
        end   
        
        else if (state == SHOW_RESULT) begin
            // OPERAND B
            
            hundreds = (display_B / 100) % 10;
            tens     = (display_B / 10) % 10;
            ones     = display_B % 10;
            
            if (draw_digit(hundreds, x, y, 27, 20))
                oled_data = GREEN;
            else if (draw_digit(tens, x, y, 44, 20))
                oled_data = GREEN;
            else if (draw_digit(ones, x, y, 61, 20))
                oled_data = GREEN;
            
            // DRAW EQUAL SIGN
            if (((x >= 10 && x <= 20) &&
                 (y >= 44 && y <= 46)) ||
                ((x >= 10 && x <= 20) &&
                 (y >= 50 && y <= 52)))
                oled_data = GREEN;  
            
            // RESULT    
             hundreds  = (display_result / 100) % 10;
            tens      = (display_result / 10) % 10;
            ones      = display_result % 10;
            
            if (draw_digit(hundreds, x, y, 27, 39))
                oled_data = GREEN;
            else if (draw_digit(tens, x, y, 44, 39))
                oled_data = GREEN;
            else if (draw_digit(ones, x, y, 61, 39))
                oled_data = GREEN;
        end   
    end
        
                      
endmodule

