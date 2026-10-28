`timescale 1ns / 1ps

module right_angle_triangle(input CLOCK,
                            input OLED_CLOCK, frame_begin,
                            input btnU, btnD, btnC,
                            input [6:0] sw,
                            input SW14,
                            input [12:0] pixel_index,
                            output wire [15:0] oled_data
    );
  
    // Register the OLED address before triangle/number rendering so the
    // fall-edge SPI sample never sees divide-decode through color logic.
    reg [6:0] x;
    reg [5:0] y;
    always @(posedge OLED_CLOCK) begin
        x <= pixel_index % 96;
        y <= pixel_index / 96;
    end
    
    localparam BLACK  = 16'h0000;
    localparam ORANGE = 16'hFF60;
    localparam GREEN  = 16'h07E0;
  
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
    
    // Register the two squares before forming the radicand. The restoring
    // square root consumes two radicand bits per clock, for eight clocks;
    // it needs no multiplier or 128-way combinational search of its own.
    localparam CALC_SQUARE=0,CALC_COMBINE=1,CALC_ROOT=2,CALC_DONE=3;
    reg [1:0] calc_phase=CALC_SQUARE;
    reg [15:0] first_square=0,second_square=0;
    reg [15:0] radicand_shift=0;
    reg [9:0] root_remainder=0;
    reg [7:0] root=0;
    reg [2:0] root_step=0;
    reg invalid=0;
    wire [7:0] first_operand=(choice==choice_hyp)?{1'b0,a}:c[7:0];
    wire [11:0] trial_remainder={root_remainder,radicand_shift[15:14]};
    wire [11:0] trial_divisor={2'b0,root,2'b01};
    wire take_root_bit=trial_remainder>=trial_divisor;
    wire [11:0] next_remainder=take_root_bit ?
        trial_remainder-trial_divisor : trial_remainder;
    wire [7:0] next_root={root[6:0],take_root_bit};
    
    always @(posedge CLOCK) begin
        
        if (SW14) begin
            state<=state_0;choice<=choice_hyp;
            calc_phase<=CALC_SQUARE;invalid<=0;
        end else case (state)
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
                    calc_phase<=CALC_SQUARE;
                end
            end

            // calculate
            state_3: begin

                case (calc_phase)
                    CALC_SQUARE: begin
                        first_square<=first_operand*first_operand;
                        second_square<=b*b;
                        calc_phase<=CALC_COMBINE;
                    end
                    CALC_COMBINE: begin
                        if (choice==choice_leg && first_square<second_square) begin
                            invalid<=1;a<=0;calc_phase<=CALC_DONE;
                        end else begin
                            invalid<=0;
                            radicand_shift<=(choice==choice_hyp) ?
                                first_square+second_square : first_square-second_square;
                            root<=0;root_remainder<=0;root_step<=7;
                            calc_phase<=CALC_ROOT;
                        end
                    end
                    CALC_ROOT: begin
                        radicand_shift<={radicand_shift[13:0],2'b0};
                        root_remainder<=next_remainder[9:0];
                        root<=next_root;
                        if (root_step==0) begin
                            // Two 7-bit legs can produce a hypotenuse of
                            // 179, so retain all eight root bits for c.
                            if (choice==choice_hyp) c<={7'd0,next_root};
                            else a<=next_root[6:0];
                            calc_phase<=CALC_DONE;
                        end else root_step<=root_step-1'b1;
                    end
                    default: begin end
                endcase
            end
        endcase
        
    end

    // Keep the renderer in the OLED domain, as in graph/calculator mode.
    // Capture a completed calculation atomically; a busy result waits for
    // the next frame rather than displaying a partially updated value.
    reg [1:0] frame_state=state_0;
    reg frame_choice=choice_hyp,frame_invalid=0;
    reg [6:0] frame_a=0,frame_b=0,frame_sw=0;
    reg [14:0] frame_c=0;
    always @(posedge OLED_CLOCK) begin
        if (frame_begin && (state!=state_3 || calc_phase==CALC_DONE)) begin
            frame_state<=state;frame_choice<=choice;
            frame_a<=a;frame_b<=b;frame_c<=c;frame_sw<=sw;
            frame_invalid<=invalid;
        end
    end
    
  
  //triangle graphics
  triangle_renderer graphics(.pixel_index(pixel_index),
                             .state(frame_state),
                             .choice(frame_choice),
                             .a(frame_a),
                             .b(frame_b),
                             .c(frame_c),
                             .sw(frame_sw),
                             .invalid(frame_invalid),
                             .oled_data(oled_data));
    
endmodule



