`timescale 1ns / 1ps

module history_renderer(
    input [12:0] pixel_index,
    input wire [6:0] x,
    input wire [5:0] y,
    input [1:0] count,
    input [1:0] history_select,
    
    input signed [7:0] history_a0,
    input signed [7:0] history_a1,
    input signed [7:0] history_a2,
    input signed [7:0] history_b0,
    input signed [7:0] history_b1,
    input signed [7:0] history_b2,
    
    input [1:0] history_op0,
    input [1:0] history_op1,
    input [1:0] history_op2,
    
    input signed [7:0] history_0,
    input signed [7:0] history_1,
    input signed [7:0] history_2,
    
    input recall_error,
    output reg [15:0] pixel_data
    );
    
    // OLED colours (RGB565)
    localparam BLACK  = 16'h0000;
    localparam WHITE  = 16'hFFFF;
    localparam GREEN  = 16'h07E0;
    localparam CYAN   = 16'h07FF;
    localparam BLUE   = 16'h001F;
    localparam RED    = 16'hF800;
    

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
                //top
                (A && x >= xpos+1  && x <= xpos+3 &&
                      y == ypos) ||
                //upper right
                (B && x == xpos+3  &&
                      y >= ypos    && y <= ypos+3) ||
                //lower right
                (C && x == xpos+3  &&
                      y >= ypos+3  && y <= ypos+6) ||
                //bottom
                (D && x >= xpos+1  && x <= xpos+3 &&
                      y == ypos+6) ||
                //lower left
                (E && x == xpos  && 
                      y >= ypos+3  && y <= ypos+6) ||
                //upper left
                (F && x == xpos  && 
                      y >= ypos    && y <= ypos+3) ||
                //middle
                (G && x >= xpos+1  && x <= xpos+3 &&
                      y == ypos+3) ||

                0;
            end
        endfunction
        
        
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
                        "H": case(row)
                            0: bits = 5'b10001;
                            1: bits = 5'b10001;
                            2: bits = 5'b11111;
                            3: bits = 5'b10001;
                            4: bits = 5'b10001;
                            5: bits = 5'b10001;
                            6: bits = 5'b10001;
                        endcase
                        
                        "I": case(row)
                            0: bits = 5'b11111;
                            1: bits = 5'b00100;
                            2: bits = 5'b00100;
                            3: bits = 5'b00100;
                            4: bits = 5'b00100;
                            5: bits = 5'b00100;
                            6: bits = 5'b11111;
                        endcase
                        
                        "S": case(row)
                            0: bits = 5'b01111;
                            1: bits = 5'b10000;
                            2: bits = 5'b10000;
                            3: bits = 5'b01110;
                            4: bits = 5'b00001;
                            5: bits = 5'b10001;
                            6: bits = 5'b11110;
                        endcase
                        
                        "T": case(row)
                            0: bits = 5'b11111;
                            1: bits = 5'b00100;
                            2: bits = 5'b00100;
                            3: bits = 5'b00100;
                            4: bits = 5'b00100;
                            5: bits = 5'b00100;
                            6: bits = 5'b00100;
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
                        
                        "R": case(row)
                            0: bits = 5'b11110;
                            1: bits = 5'b10001;
                            2: bits = 5'b10001;
                            3: bits = 5'b11110;
                            4: bits = 5'b10100;
                            5: bits = 5'b10010;
                            6: bits = 5'b10001;
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
                    endcase
                    
                    if (x >= xpos && x < xpos + 5)
                        draw_letter = bits[4 - (x - xpos)];
                    end
                end
            endfunction
            
            
        //count how many characters a number needs
        function integer number_length;
            input signed [15:0] number;
            integer value;
            
            begin
                if (number < 0)
                    value = -number;
                else    
                    value = number;
                    
                number_length = 1;
                
                if (value >= 10)
                    number_length = 2;
                if (value >= 100)
                    number_length = 3;
                if (value >= 1000)
                    number_length = 4;
                if (value >= 10000)
                    number_length = 5;
                    
                //extra caracter for negative numbers
                if (number < 0)
                    number_length = number_length + 1;
                end
            endfunction
            
        
            function draw_number;
                input signed [7:0] number;
                input integer xpos;
                input integer ypos;

                reg [7:0] value;
                reg [3:0] hundreds;
                reg [3:0] tens;
                reg [3:0] ones;
                reg [7:0] remainder;
                integer start_x;

                begin
                    draw_number = 0;

                    // Make negative numbers positive
                    if (number < 0)
                        value = -number;
                    else
                        value = number;

                    start_x = xpos;

                    // Draw minus sign for negative numbers
                    if (number < 0) begin
                        if (x >= xpos && x <= xpos+3 &&
                            y == ypos+3)
                            draw_number = 1;

                        start_x = xpos + 5;
                    end

                    // Calculate hundreds without division
                    if (value >= 100) begin
                        hundreds = 1;
                        remainder = value - 100;
                    end
                    else begin
                        hundreds = 0;
                        remainder = value;
                    end

                    // Calculate tens without division
                    tens = 0;

                    if (remainder >= 80) begin
                        tens = 8;
                        remainder = remainder - 80;
                    end

                    if (remainder >= 40) begin
                        tens = tens + 4;
                        remainder = remainder - 40;
                    end

                    if (remainder >= 20) begin
                        tens = tens + 2;
                        remainder = remainder - 20;
                    end

                    if (remainder >= 10) begin
                        tens = tens + 1;
                        remainder = remainder - 10;
                    end

                    // Remaining value is the ones digit
                    ones = remainder[3:0];

                    // Draw hundreds if needed
                    if (value >= 100) begin
                        if (draw_digit(hundreds, x, y, start_x, ypos))
                            draw_number = 1;

                        start_x = start_x + 5;
                    end

                    // Draw tens if needed
                    if (value >= 10) begin
                        if (draw_digit(tens, x, y, start_x, ypos))
                            draw_number = 1;

                        start_x = start_x + 5;
                    end

                    // Draw ones
                    if (draw_digit(ones, x, y, start_x, ypos))
                        draw_number = 1;
                end     
            endfunction
            
            function draw_symbol;
                input [2:0] symbol;
                input integer xpos;
                input integer ypos;
                
                begin
                    draw_symbol = 0;
                    
                    case (symbol)
                        //adition
                        3'd0: begin
                            draw_symbol = ((x == xpos+2 && y >= ypos+1 && y <= ypos+5) ||
                                            (y == ypos+3 && x >= xpos && x <= xpos+4));
                        end
                        //subtraction
                        3'd1: begin
                            draw_symbol = ((y == ypos+3 && x >= xpos && x <= xpos+4));
                        end
                        //multiplication
                        3'd2: begin
                            draw_symbol = ((x == xpos && (y == ypos+1 || y == ypos+5)) ||
                                            (x == xpos+1 && (y == ypos+2 || y == ypos+4)) ||
                                            (x == xpos+2 && y == ypos+3) ||
                                            (x == xpos+3 && (y == ypos+2 || y == ypos+4)) ||
                                            (x == xpos+4 && (y == ypos+1 || y == ypos+5)));
                        end
                        //division
                        3'd3: begin
                            draw_symbol = ((x == xpos+4 && y == ypos+1) ||
                                            (x == xpos+3 && y == ypos+2) ||
                                            (x == xpos+2 && y == ypos+3) ||
                                            (x == xpos+1 && y == ypos+4) ||
                                            (x == xpos && y == ypos+5));
                        end
                        //equal sign
                        3'd4: begin
                            draw_symbol = ((y == ypos+2 || y == ypos+4) && x >= xpos && x <= xpos+4);
                        end
                    endcase
                end
            endfunction
        
            
            
            //draw one complete calculation
            function draw_calculation;
                input signed [7:0] number_a;
                input signed [7:0] number_b;
                input [1:0] operation;
                input signed [7:0] result;
                
                input [5:0] ypos;
                
                integer pos_a;
                integer pos_op;
                integer pos_b;
                integer pos_equal;
                integer pos_result;
                
                begin
                    //draw the calculation
                    draw_calculation = 0;
                    
                    //first number starts at x = 5
                    pos_a = 5;
                    pos_op = pos_a + number_length(number_a) * 5 + 2;
                    pos_b = pos_op + 7;
                    pos_equal = pos_b + number_length(number_b) * 5 + 2;
                    pos_result = pos_equal + 7;
                    
                    //draw the complete expression
                    if (draw_number(number_a, pos_a, ypos))
                        draw_calculation = 1;
                        
                    if (draw_symbol({1'b0, operation}, pos_op, ypos))
                        draw_calculation = 1;
                        
                    if (draw_number(number_b, pos_b, ypos))
                        draw_calculation = 1;
                        
                    if (draw_symbol(3'd4, pos_equal, ypos))
                        draw_calculation = 1;
                        
                    if (draw_number(result, pos_result, ypos))
                        draw_calculation = 1;
                end
            endfunction
       
        
            always @(*) begin
        //defult bakground
        pixel_data = BLACK;
        
        //highligt the selected calculation
        if (history_select == 0 && count > 0 && y >= 12 && y <= 25) begin
            pixel_data = BLUE;
        end
        else if (history_select == 1 && count > 1 && y >= 27 && y <= 40) begin
            pixel_data = BLUE;
        end
        else if (history_select == 2 && count > 2 && y >= 42 && y <= 55) begin
            pixel_data = BLUE;
        end
        
        //draw the threee latest calculations
        if (count > 0) begin
            if (draw_calculation(history_a0, history_b0, history_op0, history_0, 16))
                pixel_data = GREEN;
            end
        if (count > 1) begin
            if (draw_calculation(history_a1, history_b1, history_op1, history_1, 31))
                pixel_data = GREEN;
            end
        if (count > 2) begin
            if (draw_calculation(history_a2, history_b2, history_op2, history_2, 46))
                pixel_data = GREEN;
            end
        
        //draw HISTORY title
            if (draw_letter("H", x, y, 27, 2) ||
                draw_letter("I", x, y, 33, 2) ||
                draw_letter("S", x, y, 39, 2) ||
                draw_letter("T", x, y, 45, 2) ||
                draw_letter("O", x, y, 51, 2) ||
                draw_letter("R", x, y, 57, 2) ||
                draw_letter("Y", x, y, 63, 2)) begin
                
                pixel_data = CYAN;
            end
            
            //line below title
            if (y == 10 && x >= 5 && x <= 90)
                pixel_data = CYAN;           
    end
    
endmodule

