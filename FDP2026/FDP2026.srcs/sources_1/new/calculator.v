`timescale 1ns / 1ps

module calculator(input CLOCK,
                  input OLED_CLOCK, frame_begin,
                  input btnU, btnD, btnL, btnR, btnC,
                  input [10:0] sw,
                  input SW13, SW14, SW15,
                  input [12:0] pixel_index,
                  output wire [15:0] oled_data,
                  output reg [3:0] an,
                  output reg [7:0] seg
                  );
                      
    wire [6:0] x;
    wire [5:0] y;
    
    assign x = pixel_index % 96;
    assign y = pixel_index / 96;
    
    localparam BLACK  = 16'h0000;
    localparam ORANGE = 16'hFF60;
    localparam GREEN  = 16'h07E0;
    localparam RED    = 16'hF800;
    localparam CYAN   = 16'h07FF;
           
     // States:
    localparam FIRST_NUMBER     = 3'd0;
    localparam CHOOSE_OPERATION = 3'd1;
    localparam SECOND_NUMBER    = 3'd2;
    localparam CALCULATING      = 3'd3;
    localparam SHOW_RESULT      = 3'd4;
    reg [2:0] state = FIRST_NUMBER;

    // Calculations:

    // Two's-complement input: sw[7:0] ranges from -128 to 127.
    wire signed [7:0] switch_value;
    wire signed [7:0] selected_number;
    assign switch_value = $signed(sw[7:0]);    
    
    reg signed [7:0] operand_A = 0;
    reg signed [7:0] operand_B = 0;
    
    // Operation choices
    reg [1:0] operation = 0;
    
    localparam ADD = 2'b00;
    localparam SUB = 2'b01;
    localparam MUL = 2'b10;
    localparam DIV = 2'b11;
    
    reg operation_selected = 0;

    // Keep full precision to detect overflow outside the 8-bit range
    reg signed [15:0] result = 0;
    reg invalid_result = 0;
    
    wire signed [15:0] extended_A = {{8{operand_A[7]}}, operand_A};
    // Operand B is captured before arithmetic, separating history recall
    // from the result register's timing path.
    wire signed [15:0] extended_B = {{8{operand_B[7]}}, operand_B};

    wire signed [15:0] calculated_result =
        (operation == ADD) ? (extended_A + extended_B) :
        (operation == SUB) ? (extended_A - extended_B) :
        (operation == MUL) ? ($signed(operand_A) * $signed(operand_B)) :
                             16'sd0;

    wire invalid_now;
    check_invalid validator (
        .saved_number_2(selected_number),
        .ready(operation_selected && state == SECOND_NUMBER),
        .operation(operation),
        .invalid(invalid_now)
    );

    // Check for overflow:
    wire overflow;
    check_overflow overflow_checker (.result(result), 
                                     .overflow(overflow));
   
    // Save history:
    
    reg history_saved = 0;

    // Initialize history once at startup.
    reg history_reset = 1;

    wire [1:0] history_count;

    wire signed [15:0] history_0;
    wire signed [15:0] history_1;
    wire signed [15:0] history_2;

    wire signed [7:0] history_a0;
    wire signed [7:0] history_a1;
    wire signed [7:0] history_a2;

    wire signed [7:0] history_b0;
    wire signed [7:0] history_b1;
    wire signed [7:0] history_b2;

    wire [1:0] history_op0;
    wire [1:0] history_op1;
    wire [1:0] history_op2;

    wire save_history =
        (state == SHOW_RESULT) &&
        !invalid_result &&
        !overflow &&
        !history_saved;

    calculation_history history_module (
        .clk(CLOCK),
        .reset(history_reset),
        .save(save_history),

        .operand_a(operand_A),
        .operand_b(operand_B),
        .operation(operation),
        .result(result),

        .count(history_count),

        .history_0(history_0),
        .history_1(history_1),
        .history_2(history_2),

        .history_a0(history_a0),
        .history_a1(history_a1),
        .history_a2(history_a2),

        .history_b0(history_b0),
        .history_b1(history_b1),
        .history_b2(history_b2),

        .history_op0(history_op0),
        .history_op1(history_op1),
        .history_op2(history_op2)
    );
    
    
    wire use_history =
        sw[8] || sw[9] || sw[10];

    
    wire signed [15:0] alternate_operand;

    assign alternate_operand =
        sw[10] ? history_2 :
        sw[9]  ? history_1 :
        sw[8]  ? history_0 : 16'sd0;

    // Check that the selected history exists.
    wire history_exists =
        sw[10] ? (history_count >= 3) :
        sw[9]  ? (history_count >= 2) :
        sw[8]  ? (history_count >= 1) : 1'b1;

    // Check that the recalled result fits in 8 bits.
    wire history_in_range =
        (alternate_operand >= -16'sd128) &&
        (alternate_operand <= 16'sd127);

    wire selected_valid =
        !use_history ||
        (history_exists && history_in_range);

    assign selected_number =
        use_history ? alternate_operand[7:0] :
                      switch_value;

    // Capture the live/history operand at btnC, then divide one bit per
    // clock. No division circuit lies on a 100 MHz single-cycle path.
    wire divide_start = (state == SECOND_NUMBER) && btnC &&
                        selected_valid && !invalid_now && (operation == DIV);
    wire divide_done;
    wire signed [15:0] divide_quotient;
    calculator_signed_divider divider (
        .clk(CLOCK), .start(divide_start),
        .dividend(operand_A), .divisor(selected_number),
        .busy(), .done(divide_done), .quotient(divide_quotient)
    );
                      
    //OLED data from history renderer
    wire [15:0] oled_data_history;
    
    //select history calculation
    reg [1:0] history_select = 0;
    
    wire show_history = SW13;
    reg [15:0] calculator_pixel;

    // The arithmetic/history registers remain in the 100 MHz domain.
    // Freeze all OLED inputs once per frame on the OLED rising edge;
    // the driver's falling-edge pixel load then has an 80 ns render budget.
    reg [2:0] frame_state = FIRST_NUMBER;
    reg signed [7:0] frame_operand_A=0,frame_operand_B=0,frame_selected_number=0;
    reg signed [15:0] frame_result=0;
    reg [1:0] frame_operation=ADD;
    reg frame_operation_selected=0,frame_selected_valid=1;
    reg frame_invalid_result=0,frame_overflow=0,frame_show_history=0;
    reg [1:0] frame_history_count=0,frame_history_select=0;
    reg signed [7:0] frame_history_a0=0,frame_history_a1=0,frame_history_a2=0;
    reg signed [7:0] frame_history_b0=0,frame_history_b1=0,frame_history_b2=0;
    reg signed [7:0] frame_history_0=0,frame_history_1=0,frame_history_2=0;
    reg [1:0] frame_history_op0=0,frame_history_op1=0,frame_history_op2=0;

    always @(posedge OLED_CLOCK) begin
        if (frame_begin) begin
            frame_state<=state;
            frame_operand_A<=operand_A;frame_operand_B<=operand_B;
            frame_selected_number<=selected_number;frame_selected_valid<=selected_valid;
            frame_operation<=operation;frame_operation_selected<=operation_selected;
            frame_result<=result;frame_invalid_result<=invalid_result;frame_overflow<=overflow;
            frame_show_history<=show_history;
            frame_history_count<=history_count;frame_history_select<=history_select;
            frame_history_a0<=history_a0;frame_history_a1<=history_a1;frame_history_a2<=history_a2;
            frame_history_b0<=history_b0;frame_history_b1<=history_b1;frame_history_b2<=history_b2;
            frame_history_op0<=history_op0;frame_history_op1<=history_op1;frame_history_op2<=history_op2;
            frame_history_0<=history_0[7:0];frame_history_1<=history_1[7:0];frame_history_2<=history_2[7:0];
        end
    end

    
    //history OLED renderer
    history_renderer history_screen(.pixel_index(pixel_index),
                                    .count(frame_history_count),
                                    .history_select(frame_history_select),
                                    
                                    //first number
                                    .history_a0(frame_history_a0),
                                    .history_a1(frame_history_a1),
                                    .history_a2(frame_history_a2),
                                    
                                    //second number
                                    .history_b0(frame_history_b0),
                                    .history_b1(frame_history_b1),
                                    .history_b2(frame_history_b2),
                                    
                                    //operations 
                                    .history_op0(frame_history_op0),
                                    .history_op1(frame_history_op1),
                                    .history_op2(frame_history_op2),
                                    
                                    //result 
                                    .history_0(frame_history_0),
                                    .history_1(frame_history_1),
                                    .history_2(frame_history_2),
                                    
                                    .recall_error(1'b0),
                                    .pixel_data(oled_data_history));
                                    
    
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
        input signed [15:0] number;
        input [6:0] xpos;
        input [5:0] ypos;

        reg [15:0] abs_number;
        reg [3:0] hundreds;
        reg [3:0] tens;
        reg [3:0] ones;

        integer first_x;
        integer minus_x;
        integer open_x;
        integer close_x;

        begin
            abs_number =
                (number < 0) ? -number : number;

            hundreds = (abs_number / 100) % 10;
            tens     = (abs_number / 10) % 10;
            ones     = abs_number % 10;

            // Find position of first visible digit.
            if (abs_number >= 100)
                first_x = xpos;
            else if (abs_number >= 10)
                first_x = xpos + 12;
            else
                first_x = xpos + 24;

            minus_x = first_x - 7;
            open_x  = first_x - 12;
            close_x = xpos + 33;

            draw_number =
                // Hundreds
                ((abs_number >= 100) &&
                 draw_digit(hundreds, x, y, xpos, ypos)) ||

                // Tens
                ((abs_number >= 10) &&
                 draw_digit(tens, x, y, xpos+12, ypos)) ||

                // Ones
                draw_digit(ones, x, y, xpos+24, ypos);

            if (number < 0) begin

                // Minus sign
                if (x >= minus_x &&
                    x <= minus_x+4 &&
                    y == ypos+5)
                    draw_number = 1;

                // Opening parenthesis (
                if (((x == open_x+1) &&
                     (y == ypos+1 || y == ypos+9)) ||
                    ((x == open_x) &&
                     (y >= ypos+2 && y <= ypos+8)))
                    draw_number = 1;

                // Closing parenthesis )
                if (((x == close_x) &&
                     (y == ypos+1 || y == ypos+9)) ||
                    ((x == close_x+1) &&
                     (y >= ypos+2 && y <= ypos+8)))
                    draw_number = 1;

            end
        end
    endfunction
      
    // draw operator
    function draw_operator;
        input [2:0] op;
        input [6:0] x;
        input [5:0] y;
        input [6:0] xpos;
        input [5:0] ypos;
    
        begin
            draw_operator = 0;
    
            case (op)
                // ADD (+)
                0: begin
                    draw_operator =
                        ((x >= xpos+4 && x <= xpos+6) &&
                         (y >= ypos   && y <= ypos+10)) ||
                        ((x >= xpos   && x <= xpos+10) &&
                         (y >= ypos+4 && y <= ypos+6));
                end
    
                // SUBTRACT (-)
                1: begin
                    draw_operator =
                        (x >= xpos   && x <= xpos+10) &&
                        (y >= ypos+4 && y <= ypos+6);
                end
    
                // MULTIPLY (*)
                2: begin
                      draw_operator =
                        ((x >= xpos+4 && x <= xpos+6) &&
                         (y >= ypos+4 && y <= ypos+6)) ||

                        ((x >= xpos+1 && x <= xpos+9) &&
                         (y >= ypos+1 && y <= ypos+9) &&
                         ((x-xpos == y-ypos) ||
                          (x-xpos + y-ypos == 10)));
                end
    
                // DIVIDE (/)
                3: begin
                    draw_operator =
                            ((x >= xpos && x <= xpos+10) &&
                             (y >= ypos+4 && y <= ypos+6)) ||
                    
                            ((x >= xpos+4 && x <= xpos+6) &&
                             (y >= ypos && y <= ypos+2)) ||
                    
                            ((x >= xpos+4 && x <= xpos+6) &&
                             (y >= ypos+8 && y <= ypos+10));
                end
    
                // EQUAL (=)
                4: begin
                    draw_operator =
                        ((x >= xpos && x <= xpos+10) &&
                         (y >= ypos+3 && y <= ypos+4)) ||
                        ((x >= xpos && x <= xpos+10) &&
                         (y >= ypos+7 && y <= ypos+8));
                end
            endcase
        end
    endfunction 


    function [34:0] letter_pattern;
        input [7:0] character;

        begin
            case (character)
                "A": letter_pattern =
                    35'b01110_10001_10001_11111_10001_10001_10001;

                "C": letter_pattern =
                    35'b01111_10000_10000_10000_10000_10000_01111;

                "D": letter_pattern =
                    35'b11110_10001_10001_10001_10001_10001_11110;

                "E": letter_pattern =
                    35'b11111_10000_10000_11110_10000_10000_11111;

                "F": letter_pattern =
                    35'b11111_10000_10000_11110_10000_10000_10000;

                "I": letter_pattern =
                    35'b11111_00100_00100_00100_00100_00100_11111;

                "L": letter_pattern =
                    35'b10000_10000_10000_10000_10000_10000_11111;

                "N": letter_pattern =
                    35'b10001_11001_10101_10011_10001_10001_10001;

                "O": letter_pattern =
                    35'b01110_10001_10001_10001_10001_10001_01110;

                "R": letter_pattern =
                    35'b11110_10001_10001_11110_10100_10010_10001;

                "T": letter_pattern =
                    35'b11111_00100_00100_00100_00100_00100_00100;

                "U": letter_pattern =
                    35'b10001_10001_10001_10001_10001_10001_01110;

                "V": letter_pattern =
                    35'b10001_10001_10001_10001_10001_01010_00100;

                "W": letter_pattern =
                    35'b10001_10001_10001_10101_10101_10101_01010;

                default: letter_pattern = 35'b0;
            endcase
        end
    endfunction      
      
    
    function draw_char;
        input [7:0] character;
        input [6:0] x;
        input [5:0] y;
        input [6:0] xpos;
        input [5:0] ypos;

        reg [34:0] pattern;
        reg [2:0] row_index;
        reg [2:0] col_index;

        begin
            draw_char = 0;
            pattern = letter_pattern(character);
            row_index = 0;
            col_index = 0;

            if (x >= xpos && x < xpos+5 &&
                y >= ypos && y < ypos+7) begin

                col_index = x - xpos;
                row_index = y - ypos;

                draw_char =
                    pattern[34 - row_index*5 - col_index];
            end
        end
    endfunction


    function draw_text;
        input [1:0] text_id;
        input [6:0] x;
        input [5:0] y;
        input [6:0] xpos;
        input [5:0] ypos;

        begin
            draw_text = 0;

            case (text_id)

                // CALCULATE
                0: draw_text =
                    draw_char("C",x,y,xpos,   ypos) ||
                    draw_char("A",x,y,xpos+6, ypos) ||
                    draw_char("L",x,y,xpos+12,ypos) ||
                    draw_char("C",x,y,xpos+18,ypos) ||
                    draw_char("U",x,y,xpos+24,ypos) ||
                    draw_char("L",x,y,xpos+30,ypos) ||
                    draw_char("A",x,y,xpos+36,ypos) ||
                    draw_char("T",x,y,xpos+42,ypos) ||
                    draw_char("E",x,y,xpos+48,ypos);

                // OVERFLOW
                1: draw_text =
                    draw_char("O",x,y,xpos,   ypos) ||
                    draw_char("V",x,y,xpos+6, ypos) ||
                    draw_char("E",x,y,xpos+12,ypos) ||
                    draw_char("R",x,y,xpos+18,ypos) ||
                    draw_char("F",x,y,xpos+24,ypos) ||
                    draw_char("L",x,y,xpos+30,ypos) ||
                    draw_char("O",x,y,xpos+36,ypos) ||
                    draw_char("W",x,y,xpos+42,ypos);

                // INVALID
                2: draw_text =
                    draw_char("I",x,y,xpos,   ypos) ||
                    draw_char("N",x,y,xpos+6, ypos) ||
                    draw_char("V",x,y,xpos+12,ypos) ||
                    draw_char("A",x,y,xpos+18,ypos) ||
                    draw_char("L",x,y,xpos+24,ypos) ||
                    draw_char("I",x,y,xpos+30,ypos) ||
                    draw_char("D",x,y,xpos+36,ypos);

            endcase
        end
    endfunction
  
      
    always @(posedge CLOCK) begin
        
        // Check if we want to use results from earlier
        history_reset <= 0;

        if (state != SHOW_RESULT)
            history_saved <= 0;
        else if (save_history)
            history_saved <= 1;

        // State 0: First number choice
        if (state == FIRST_NUMBER) begin
            if (btnC && selected_valid) begin
                operand_A <= selected_number;
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
                
            if (btnC && operation_selected)
                state <= SECOND_NUMBER;
        end
        
        // State 2: Capture B. The arithmetic runs only on registered inputs.
       else if (state == SECOND_NUMBER) begin
           if (btnC && selected_valid) begin
                operand_B <= selected_number;
                invalid_result <= invalid_now;
                if (invalid_now) begin
                    result <= 16'sd0;
                    state <= SHOW_RESULT;
                end else begin
                    state <= CALCULATING;
                end
            end
        end

        // State 3: Add/subtract/multiply take one registered cycle; signed
        // division waits for the sequential divider's completion pulse.
        else if (state == CALCULATING) begin
            if (operation == DIV) begin
                if (divide_done) begin
                    result <= divide_quotient;
                    state <= SHOW_RESULT;
                end
            end else begin
                result <= calculated_result;
                state <= SHOW_RESULT;
            end
        end
        
        // State 4: Show result
        else if (state == SHOW_RESULT) begin  
        
            if (SW14) begin          
                state <= FIRST_NUMBER;
                result <= 0;
                operand_A <= 0;
                operand_B <= 0;
                operation_selected <= 0;
                invalid_result <= 0;
            end
            
        end
        
    end

    always @(*) begin
        
        calculator_pixel = BLACK;
        an = 4'b1111;
        seg = 8'b11111111;
        
        if (use_history) begin
            an = 4'b1110;
        
            seg = (!sw[10] && !sw[9] && sw[8]) ? 8'b11111001 : 
                  (!sw[10] &&  sw[9]         ) ? 8'b10100100 : 
                  ( sw[10]                   ) ? 8'b10110000 : 8'b11111111;
        end
        
        // Title and separator
        if (draw_text(0, x, y, 21, 2))
            calculator_pixel = CYAN;
        if (y == 11 && x >= 5 && x <= 90)
            calculator_pixel = CYAN;

        // State 0: Write first number in orange
        if (frame_state == FIRST_NUMBER) begin
            //OPERAND A:
            if (frame_selected_valid) begin
                if (draw_number(frame_selected_number, 30, 15))
                    calculator_pixel = ORANGE;
            end

            else begin
                if (draw_text(2, x, y, 27, 54))
                    calculator_pixel = RED;
            end
        end
        
        // State 1: Write number again in green + Write operator in orange
        
        else if (frame_state == CHOOSE_OPERATION) begin
            //OPERAND A:            
             if (draw_number(frame_operand_A, 30, 15))
                calculator_pixel = GREEN;

            // Selected operation
            if (frame_operation_selected) begin
                if (draw_operator(
                    {1'b0, frame_operation}, x, y, 5, 29))
                    calculator_pixel = GREEN;
            end
        end
            
        else if (frame_state == SECOND_NUMBER || frame_state == CALCULATING) begin
             // Operand A
            if (draw_number(frame_operand_A, 30, 15))
                calculator_pixel = GREEN;

            // Operation
            if (draw_operator(
                {1'b0, frame_operation}, x, y, 5, 29))
                calculator_pixel = GREEN;

            // Operand B
            if (frame_state == CALCULATING) begin
                if (draw_number(frame_operand_B, 30, 29))
                    calculator_pixel = GREEN;
            end else if (frame_selected_valid) begin
                if (draw_number(frame_selected_number, 30, 29))
                    calculator_pixel = ORANGE;
            end

            else begin
                if (draw_text(2, x, y, 27, 54))
                    calculator_pixel = RED;
            end
        end   
        
        else if (frame_state == SHOW_RESULT) begin
             // Operand A
            if (draw_number(frame_operand_A, 30, 15))
                calculator_pixel = GREEN;

            // Operation
            if (draw_operator(
                {1'b0, frame_operation}, x, y, 5, 29))
                calculator_pixel = GREEN;

            // Operand B
            if (draw_number(frame_operand_B, 30, 29))
                calculator_pixel = GREEN;

            // Equal sign
            if (draw_operator(3'd4, x, y, 5, 43))
                calculator_pixel = GREEN;

            // INVALID
            if (frame_invalid_result) begin

                if (draw_text(2, x, y, 27, 54))
                    calculator_pixel = RED;

            end

            // OVERFLOW
            else if (frame_overflow) begin

                if (draw_text(1, x, y, 24, 54))
                    calculator_pixel = RED;

            end

            // Valid result
            else begin

                if (draw_number(frame_result, 30, 43))
                    calculator_pixel = GREEN;

            end

        end
    end
    
    //chose which OLED screen to display
    assign oled_data = frame_show_history ? oled_data_history : calculator_pixel;
    
endmodule
