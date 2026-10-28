`timescale 1ns / 1ps

module right_angle_triangle(input CLOCK,
                            input OLED_CLOCK, input frame_prepare,
                            input btnU, btnD, btnC,
                            input [6:0] sw,
                            input SW14,
                            input [12:0] pixel_index,
                            output wire [15:0] oled_data
    );
  
    wire [6:0] x = pixel_index % 96;
    wire [5:0] y = pixel_index / 96;
    
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
    
    // calculation
    reg [14:0] square_value;
    reg calculate;
    wire sqrt_busy,sqrt_done;
    wire [7:0] sqrt_result;
    sqrt_15bit square_root(
        .clk(CLOCK),.start(calculate),.value(square_value),
        .busy(sqrt_busy),.done(sqrt_done),.root(sqrt_result));

    reg calculation_phase;
    wire [13:0] a_squared = a*a;
    wire [13:0] b_squared = b*b;
    wire [13:0] c_squared = c*c;
    
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

            // calculate over explicit cycles; no 128-way square search or
            // multi-cycle multiplier sits in one 100 MHz path.
            state_3: begin
                if (calculation_phase == 1'b0) begin
                    if (choice == choice_hyp)
                        square_value <= a_squared + b_squared;
                    else if (c_squared >= b_squared)
                        square_value <= c_squared - b_squared;
                    else
                        square_value <= 0;
                    calculate <= 1'b1;
                    calculation_phase <= 1'b1;
                end else begin
                    calculate <= 1'b0;
                    if (sqrt_done) begin
                        if (choice == choice_hyp) c <= sqrt_result;
                        else a <= (c_squared >= b_squared) ? sqrt_result : 7'd0;
                        calculation_phase <= 1'b0;
                    end
                end
            end
        endcase
        
        // Reset to first state
        if (SW14) begin
            state <= state_0;
            choice <= choice_hyp;
            calculate <= 1'b0;
            calculation_phase <= 1'b0;
        end

    end
    
  
  //triangle graphics
    // Freeze all triangle display values on the OLED frame boundary.
    localparam integer SNAPSHOT_WIDTH = 40;
    wire [SNAPSHOT_WIDTH-1:0] snapshot_in,snapshot_out;
    wire [1:0] frame_state;
    wire frame_choice,frame_invalid;
    wire [6:0] frame_a,frame_b,frame_sw;
    wire [14:0] frame_c;
    wire [15:0] triangle_pixel;
    wire invalid = 1'b0;
    assign snapshot_in={state,choice,a,b,c,sw,invalid};
    assign {frame_state,frame_choice,frame_a,frame_b,frame_c,frame_sw,
            frame_invalid}=snapshot_out;
    frame_snapshot #(.WIDTH(SNAPSHOT_WIDTH)) frame_values(
        .clk_src(CLOCK),.reset_src(SW14),
        .clk_dst(OLED_CLOCK),.reset_dst(SW14),
        .frame_prepare(frame_prepare),.data(snapshot_in),
        .data_out(snapshot_out));
    // Each renderer uses the current pixel_index.  Do not add another aligned
    // stage here: triangle_renderer already drives the final pixel for that
    // address, and a second stage would shift color by one OLED pixel.
    assign oled_data = triangle_pixel;

  triangle_renderer graphics(.x(x),.y(y),
                             .state(frame_state),
                             .choice(frame_choice),
                             .a(frame_a),
                             .b(frame_b),
                             .c(frame_c),
                             .sw(frame_sw),
                             .invalid(frame_invalid),
                             .oled_data(triangle_pixel));
    
endmodule



