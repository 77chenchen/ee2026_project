`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//  FILL IN THE FOLLOWING INFORMATION:
//  STUDENT A NAME: Milla Glännfjord
//  STUDENT B NAME: Hanna Wahlgren
//  STUDENT C NAME: Wang Qichen
//  STUDENT D NAME: Oskar Plogner
//  group 06 
//////////////////////////////////////////////////////////////////////////////////

module My_Top_Module (input CLOCK,
                      input [15:0] sw,
                      input btnU, btnD, btnC, btnL, btnR,
                      output [7:0] JB,
                      output [15:0] led,
                      output [7:0] seg,
                      output [3:0] an);

    wire clk6p25m;
    
    clock_hz clk_6_25 (.HZ(6_250_000),
                       .CLOCK(CLOCK),
                       .SLOW_CLOCK(clk6p25m) 
                        );
    wire [6:0] x;
    wire [5:0] y;
    
    assign x = pixel_index % 96;
    assign y = pixel_index / 96;
    
    localparam BLACK  = 16'h0000;
    localparam WHITE  = 16'hFFFF;
    localparam GREEN  = 16'h07E0;
    localparam ORANGE = 16'hFF60;
    
    wire [15:0] oled_data;
    wire [12:0] pixel_index;
        
    // oleds for different modules 
    wire [15:0] oled_data_graph = 16'hFFFF;
    wire [15:0] oled_data_calculator;
    wire [15:0] oled_data_triangle;
    reg  [15:0] oled_data_menu;
    
    assign JB[0] = oled_cs;
    assign JB[1] = oled_sdin;
    assign JB[3] = oled_sclk;
    assign JB[4] = oled_d_cn;
    assign JB[5] = oled_resn;
    assign JB[6] = oled_vccen;
    assign JB[7] = oled_pmoden;
    
    Oled_Display oled (
        .clk(clk6p25m),
        .reset(1'b0),

        .frame_begin(frame_begin),
        .sending_pixels(sending_pixels),
        .sample_pixel(sample_pixel),

        .pixel_index(pixel_index),
        .pixel_data(oled_data),

        .cs(oled_cs),
        .sdin(oled_sdin),
        .sclk(oled_sclk),
        .d_cn(oled_d_cn),
        .resn(oled_resn),
        .vccen(oled_vccen),
        .pmoden(oled_pmoden)
    );
    
    wire db_btnU;
    wire db_btnD;
    wire db_btnL;
    wire db_btnR;
    wire db_btnC;
    
    function [34:0] letter_pattern;
            input [7:0] character;
        
            begin
                case (character)
                    "A": letter_pattern = 35'b01110_10001_10001_11111_10001_10001_10001;
                    "B": letter_pattern = 35'b11110_10001_10001_11110_10001_10001_11110;
                    "C": letter_pattern = 35'b01111_10000_10000_10000_10000_10000_01111;
                    "E": letter_pattern = 35'b11111_10000_10000_11110_10000_10000_11111;
                    "G": letter_pattern = 35'b01111_10000_10000_10111_10001_10001_01111;
                    "H": letter_pattern = 35'b10001_10001_10001_11111_10001_10001_10001;
                    "I": letter_pattern = 35'b11111_00100_00100_00100_00100_00100_11111;
                    "L": letter_pattern = 35'b10000_10000_10000_10000_10000_10000_11111;
                    "M": letter_pattern = 35'b10001_11011_10101_10101_10001_10001_10001;
                    "N": letter_pattern = 35'b10001_11001_10101_10011_10001_10001_10001;
                    "O": letter_pattern = 35'b01110_10001_10001_10001_10001_10001_01110;
                    "P": letter_pattern = 35'b11110_10001_10001_11110_10000_10000_10000;
                    "R": letter_pattern = 35'b11110_10001_10001_11110_10100_10010_10001;
                    "T": letter_pattern = 35'b11111_00100_00100_00100_00100_00100_00100;
                    "U": letter_pattern = 35'b10001_10001_10001_10001_10001_10001_01110;
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
        
                if (x >= xpos && x < xpos+5 &&
                    y >= ypos && y < ypos+7) begin
        
                    col_index = x - xpos;
                    row_index = y - ypos;
        
                    draw_char = pattern[34 - row_index*5 - col_index];
                end
            end
        endfunction
    
            
        function draw_word;
            input [1:0] word_id;
            input [6:0] x;
            input [5:0] y;
            input [6:0] xpos;
            input [5:0] ypos;
        
            begin
                draw_word = 0;
        
                case (word_id)
                    // MENU
                    0: draw_word =
                        draw_char("M", x, y, xpos,    ypos) ||
                        draw_char("E", x, y, xpos+6,  ypos) ||
                        draw_char("N", x, y, xpos+12, ypos) ||
                        draw_char("U", x, y, xpos+18, ypos);
        
                    // CALCULATOR
                    1: draw_word =
                        draw_char("C", x, y, xpos,    ypos) ||
                        draw_char("A", x, y, xpos+6,  ypos) ||
                        draw_char("L", x, y, xpos+12, ypos) ||
                        draw_char("C", x, y, xpos+18, ypos) ||
                        draw_char("U", x, y, xpos+24, ypos) ||
                        draw_char("L", x, y, xpos+30, ypos) ||
                        draw_char("A", x, y, xpos+36, ypos) ||
                        draw_char("T", x, y, xpos+42, ypos) ||
                        draw_char("O", x, y, xpos+48, ypos) ||
                        draw_char("R", x, y, xpos+54, ypos);
        
                    // GRAPH
                    2: draw_word =
                        draw_char("G", x, y, xpos,    ypos) ||
                        draw_char("R", x, y, xpos+6,  ypos) ||
                        draw_char("A", x, y, xpos+12, ypos) ||
                        draw_char("P", x, y, xpos+18, ypos) ||
                        draw_char("H", x, y, xpos+24, ypos);
        
                    // TRIANGLE
                    3: draw_word =
                        draw_char("T", x, y, xpos,    ypos) ||
                        draw_char("R", x, y, xpos+6,  ypos) ||
                        draw_char("I", x, y, xpos+12, ypos) ||
                        draw_char("A", x, y, xpos+18, ypos) ||
                        draw_char("N", x, y, xpos+24, ypos) ||
                        draw_char("G", x, y, xpos+30, ypos) ||
                        draw_char("L", x, y, xpos+36, ypos) ||
                        draw_char("E", x, y, xpos+42, ypos);
                endcase
            end
        endfunction
        
          
    function draw_arrow;
        input [6:0] x;
        input [5:0] y;
        input [6:0] xpos;
        input [5:0] ypos;
    
        begin
            draw_arrow =
                ((x == xpos)   && (y >= ypos && y <= ypos+6)) ||
                ((x == xpos+1) && (y >= ypos+1 && y <= ypos+5)) ||
                ((x == xpos+2) && (y >= ypos+2 && y <= ypos+4)) ||
                ((x == xpos+3) && (y == ypos+3));
        end
    endfunction  
        
        
    // DEBOUNCE:
    debounce dbU(.clk(CLOCK),
                 .btn(btnU),
                 .btn_pressed(db_btnU));
                
    debounce dbD(.clk(CLOCK),
                 .btn(btnD),
                 .btn_pressed(db_btnD));
                
    debounce dbL(.clk(CLOCK),
                 .btn(btnL),
                 .btn_pressed(db_btnL));
                
    debounce dbR(.clk(CLOCK),
                 .btn(btnR),
                 .btn_pressed(db_btnR));
                
    debounce dbC(.clk(CLOCK),
                 .btn(btnC),
                 .btn_pressed(db_btnC));
    
    // MENU: arrow going up or down with btnU/btnD
    //       showing which program to use
    
    reg [1:0] arrow  = 2'b00;
    
    localparam state_nothing    = 2'b00;
    localparam state_calculator = 2'b01;
    localparam state_graph      = 2'b10;
    localparam state_triangle   = 2'b11;
    
    reg [1:0] choice = state_nothing;
    
    // Calculator module:
    calculator calculator_module(.CLOCK(CLOCK),
                                 .btnU(db_btnU && choice == state_calculator),
                                 .btnD(db_btnD && choice == state_calculator),
                                 .btnL(db_btnL && choice == state_calculator),
                                 .btnR(db_btnR && choice == state_calculator),
                                 .btnC(db_btnC && choice == state_calculator),
                                 .sw(sw[10:0]),
                                 .SW13(sw[13]),
                                 .SW14(sw[14]),
                                 .SW15(sw[15]),
                                 .pixel_index(pixel_index),
                                 .oled_data(oled_data_calculator),
                                 .an(an[3:0]),
                                 .seg(seg[7:0])
    );
    
    // Graph-module:
    
    // ....
    
    // Triangle module:
    
   right_angle_triangle triangle(.CLOCK(CLOCK),
                                 .btnU(db_btnU && choice == state_triangle),
                                 .btnD(db_btnD && choice == state_triangle),
                                 .btnC(db_btnC && choice == state_triangle),
                                 .sw(sw[6:0]),
                                 .SW14(sw[14]),
                                 .pixel_index(pixel_index),
                                 .oled_data(oled_data_triangle));
                                 
    
    always @(posedge CLOCK) begin
        
        // Menu:
        if (choice == state_nothing) begin    
            
            // Move up        
            if (db_btnU)
                arrow <= (arrow == 2'b00) ? 2'b00 : (arrow - 1);
            
            // Move down
            else if (db_btnD)
                arrow <= (arrow == 2'b10) ? 2'b10 : (arrow + 1);                        
            
            else if (db_btnC) begin
                if (arrow == 2'b00)
                    choice <= state_calculator;
                else if (arrow == 2'b01)
                    choice <= state_graph;
                else if (arrow == 2'b10) 
                    choice <= state_triangle;
            end
        end   
        
        // Return from calculator, graph or triangle
        else if (choice == state_calculator || 
                 choice == state_graph      ||
                 choice == state_triangle) begin 
        
            if (sw[15]) begin
                choice <= state_nothing;
                arrow <= 2'b00;
            end
        end
            
    end
    
        
    always @(*) begin
    
        oled_data_menu = BLACK;
    
        // MENU title
        if (draw_word(0, x, y, 36, 5))
            oled_data_menu = ORANGE;
    
        // CALCULATOR
        if (draw_word(1, x, y, 20, 20))
            oled_data_menu = (arrow == 0) ? GREEN : WHITE;
    
        // GRAPH
        if (draw_word(2, x, y, 20, 35))
            oled_data_menu = (arrow == 1) ? GREEN : WHITE;
    
        // TRIANGLE
        if (draw_word(3, x, y, 20, 50))
            oled_data_menu = (arrow == 2) ? GREEN : WHITE;
    
        // Selection arrow
        if (draw_arrow(x, y, 10,
            (arrow == 0) ? 20 :
            (arrow == 1) ? 35 : 50))
            oled_data_menu = ORANGE;
    
    end
    
    assign led = sw;
    
    assign oled_data = (choice == state_calculator) ? oled_data_calculator :
                       (choice == state_graph)      ? oled_data_graph      :
                       (choice == state_triangle)   ? oled_data_triangle   :
                                                      oled_data_menu;
    
endmodule

