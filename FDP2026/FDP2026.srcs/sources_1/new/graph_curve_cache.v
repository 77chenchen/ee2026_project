`timescale 1ns / 1ps

// Rebuilds the two 96-column plots when the view or coefficients change.
// Horner evaluation reuses one signed multiplier over several 100 MHz clocks.
// The small column tables are read by the OLED renderer without a multiplier.
module graph_curve_cache(
    input wire clk, enable,
    input wire [6:0] screen_x,origin_x,
    input wire [5:0] origin_y,
    input wire [3:0] scale,
    input wire graph1_type,graph2_type,cubic1,cubic2,
    input wire signed [7:0] a1,b1,c1,d1,a2,b2,c2,d2,
    output reg ready=0,
    output wire [13:0] bounds1,bounds2
);
    reg [13:0] table1[0:95];
    reg [13:0] table2[0:95];
    assign bounds1=table1[screen_x];
    assign bounds2=table2[screen_x];

    reg initialized=0;
    reg [3:0] old_scale;
    reg [6:0] old_ox;
    reg [5:0] old_oy;
    reg old_type1,old_type2,old_cubic1,old_cubic2;
    reg signed [7:0] old_a1,old_b1,old_c1,old_d1;
    reg signed [7:0] old_a2,old_b2,old_c2,old_d2;
    wire changed=old_scale!=scale || old_ox!=origin_x || old_oy!=origin_y ||
        old_type1!=graph1_type || old_type2!=graph2_type ||
        old_cubic1!=cubic1 || old_cubic2!=cubic2 ||
        old_a1!=a1 || old_b1!=b1 || old_c1!=c1 || old_d1!=d1 ||
        old_a2!=a2 || old_b2!=b2 || old_c2!=c2 || old_d2!=d2;
    wire [1:0] scale_shift=(scale==8)?2'd3:
                           (scale==4)?2'd2:
                           (scale==2)?2'd1:2'd0;
    // Widen before combining shifts: a two-bit `scale_shift << 1` wraps
    // at zoom 4/8 and corrupts the quadratic/cubic coefficients.
    wire [3:0] double_shift={1'b0,scale_shift,1'b0};
    wire [3:0] triple_shift={scale_shift,1'b0}+{2'b0,scale_shift};
    reg [6:0] column=0;
    reg graph_number=0,previous=1;
    reg [2:0] phase=0;
    localparam IDLE=0,PREP=1,MUL1=2,MUL2=3,MUL3=4,STORE=5;
    wire signed [8:0] dx=$signed({2'b0,column})-
                          $signed({2'b0,origin_x})-(previous?9'sd1:9'sd0);
    wire signed [7:0] ca=graph_number?a2:a1;
    wire signed [7:0] cb=graph_number?b2:b1;
    wire signed [7:0] cc=graph_number?c2:c1;
    wire signed [7:0] cd=graph_number?d2:d1;
    wire is_cubic=graph_number?cubic2:cubic1;
    wire is_quadratic=graph_number?graph2_type:graph1_type;
    reg signed [27:0] work;
    wire signed [36:0] product=work*dx;
    // Horner evaluation stays in pixel coordinates: dx is pixels from the
    // graph origin, while scale=2^scale_shift pixels per graph unit.
    // For cubic, work advances A*dx+B*s, then *dx+C*s^2, then *dx+D*s^3;
    // dividing by s^2 yields the final vertical displacement in pixels.
    wire signed [36:0] term_b=$signed(cb) <<< scale_shift;
    wire signed [36:0] term_c=$signed(cc) <<< double_shift;
    wire signed [36:0] term_d=$signed(cd) <<< triple_shift;
    reg signed [37:0] previous_y;
    wire signed [37:0] final_value =
        is_cubic ? ((product+term_d) >>> double_shift) :
        is_quadratic ? ((product+term_c) >>> scale_shift) :
                       (product+($signed(cc) <<< scale_shift));
    wire signed [37:0] screen_y_value=$signed({1'b0,origin_y})-final_value;
    wire signed [37:0] lower=previous_y<screen_y_value?previous_y:screen_y_value;
    wire signed [37:0] upper=previous_y>screen_y_value?previous_y:screen_y_value;
    wire [6:0] clipped_low=lower<0?7'd0:lower>63?7'd63:lower[6:0];
    wire [6:0] clipped_high=upper<0?7'd0:upper>63?7'd63:upper[6:0];
    wire [13:0] packed_bounds=(lower>63 || upper<0) ?
                              {7'd127,7'd127} : {clipped_low,clipped_high};
    always @(posedge clk) begin
        if (!enable) begin
            initialized<=0;ready<=0;phase<=IDLE;
        end else if (!initialized || changed) begin
            initialized<=1;ready<=0;
            old_scale<=scale;old_ox<=origin_x;old_oy<=origin_y;
            old_type1<=graph1_type;old_type2<=graph2_type;
            old_cubic1<=cubic1;old_cubic2<=cubic2;
            old_a1<=a1;old_b1<=b1;old_c1<=c1;old_d1<=d1;
            old_a2<=a2;old_b2<=b2;old_c2<=c2;old_d2<=d2;
            column<=0;graph_number<=0;previous<=1;phase<=PREP;
        end else case(phase)
            PREP: begin
                // Linear uses b*x+c. Quadratic/cubic begin with a*x.
                work<=(!is_cubic && !is_quadratic) ? $signed(cb) : $signed(ca);
                phase<=MUL1;
            end
            MUL1: begin
                if (!is_cubic && !is_quadratic) phase<=STORE;
                else begin
                    work<=product+term_b;
                    phase<=MUL2;
                end
            end
            MUL2: begin
                if (is_quadratic) phase<=STORE;
                else begin
                    work<=product+term_c;
                    phase<=MUL3;
                end
            end
            MUL3: phase<=STORE;
            STORE: begin
                if (previous) begin
                    // Each column stores the range from x-1 to x, rather
                    // than one point, so steep segments stay continuous.
                    previous_y<=screen_y_value;
                    previous<=0;
                    phase<=PREP;
                end else begin
                    if (graph_number) table2[column]<=packed_bounds;
                    else table1[column]<=packed_bounds;
                    previous<=1;
                    if (!graph_number) begin
                        graph_number<=1;phase<=PREP;
                    end else if (column==95) begin
                        ready<=1;phase<=IDLE;
                    end else begin
                        column<=column+1'b1;graph_number<=0;phase<=PREP;
                    end
                end
            end
            default: begin end
        endcase
    end
endmodule
