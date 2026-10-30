`timescale 1ns / 1ps

module right_angle_triangle(input CLOCK,
                            input btnU, btnD, btnC,
                            input [6:0] sw,
                            input SW14,
                            input [12:0] pixel_index,
                            output wire [15:0] oled_data
    );
  
    wire [6:0] x;
    wire [5:0] y;
    
    assign x = pixel_index % 96;
    assign y = pixel_index / 96;
    
    localparam BLACK  = 16'h0000;
    localparam ORANGE = 16'hFF60;
    localparam GREEN  = 16'h07E0;
  
    // square root function:
    function [6:0] sqrt;
        input [14:0] number;
        integer i;
    
        begin
            sqrt = 0;
    
            for (i = 0; i < 128; i = i + 1) begin
                if (i*i <= number)
                    sqrt = i;
            end
        end
    endfunction
  
    
    localparam choice_hyp = 0;
    localparam choice_leg = 1;
    reg choice = choice_hyp;
    
    localparam state_0 = 2'd0;
    localparam state_1 = 2'd1;
    localparam state_2 = 2'd2;
    localparam state_3 = 2'd3;
    reg [1:0] state = state_0;
 
    // legs
    reg [6:0] a = 0;
    reg [6:0] b = 0;
    
    // hyphotenus
    reg [14:0] c = 0;
    
    // calculation
    reg [14:0] square_value;
    
    always @(posedge CLOCK) begin
        
        case (state)
            // choose hypotenuse or leg
            state_0: begin
                if (btnU)
                    choice <= choice_hyp;
                else if (btnD)
                    choice <= choice_leg;

                if (btnC)
                    state <= state_1;
            end

            // enter first operand
            state_1: begin
                if (btnC) begin
                    if (choice == choice_hyp)
                        a <= sw;
                    else
                        b <= sw;

                    state <= state_2;
                end
            end

            // enter second operand
            state_2: begin
                if (btnC) begin
                    if (choice == choice_hyp)
                        b <= sw;
                    else
                        c <= sw;

                    state <= state_3;
                end
            end

            // calculate
            state_3: begin

                if (choice == choice_hyp) begin
                    square_value = a*a + b*b;
                    c <= sqrt(square_value);
                end

                else begin
                    if (c*c >= b*b) begin
                        square_value = c*c - b*b;
                        a <= sqrt(square_value);
                    end

                    else begin
                        a <= 0;
                    end

                end
            end
        endcase
        
        // Reset to first state
        if (SW14) begin
            state <= state_0;
            choice <= choice_hyp;
        end

    end
    
  
  //triangle graphics
  triangle_renderer graphics(.pixel_index(pixel_index),
                             .state(state),
                             .choice(choice),
                             .a(a),
                             .b(b),
                             .c(c),
                             .sw(sw),
                             .invalid(invalid),
                             .oled_data(oled_data));
    
endmodule



