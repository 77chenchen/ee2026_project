`timescale 1ns / 1ps

// Shared serialized intersection solver: linear differences bypass square
// root, while quadratic differences do one trial per clock. Both paths reuse
// the same restoring divider and never instantiate a combinational divider.
// Roots are Q4 graph coordinates; a visible root has its own marker-valid bit.
module graph_quadratic_intersections(
    input wire clk, reset, enable,
    input wire graph1_quadratic, graph2_quadratic,
    input wire signed [7:0] a1,b1,c1,a2,b2,c2,
    input wire [3:0] scale,
    input wire [6:0] origin_x,
    input wire [5:0] origin_y,
    output reg [2:0] status,
    output reg valid1, valid2,
    output reg signed [15:0] x1_q4,y1_q4,x2_q4,y2_q4
);
    localparam IDLE=0, SQRT=1, DIV_INIT=2, DIV_RUN=3,
               EVAL_SQUARE=4, EVAL_A=5, EVAL_Y=6, RECORD=7, DONE=8,
               CLASSIFY=9, FORM_DISCRIMINANT=10, CHECK_DISCRIMINANT=11,
               SQRT_COMPARE=12, EVAL_Y_SUM=13, PROJECT_VISIBLE=14,
               EVAL_Y_OFFSET=15, DIV_NUMERATOR=16;
    localparam STATUS_OK=0,STATUS_PAR=1,STATUS_SAME=2,STATUS_OUT=3,
               STATUS_ERR=4,STATUS_NONE=5;
    reg [4:0] phase;
    reg signed [8:0] aa,bb,cc;
    reg signed [17:0] b_square,ac_product;
    reg signed [19:0] discriminant_reg;
    reg [27:0] discriminant_q8;
    reg [13:0] sqrt_value;
    reg [3:0] sqrt_bit;
    wire [13:0] sqrt_trial = sqrt_value | (14'd1 << sqrt_bit);
    reg [13:0] sqrt_trial_reg;
    reg [27:0] sqrt_trial_squared_reg;
    reg [1:0] root_total,root_index;
    reg [17:0] dividend,quotient;
    reg [18:0] remainder;
    reg [9:0] divisor;
    reg quotient_negative;
    reg [4:0] divide_bit;
    wire [18:0] next_remainder = {remainder[17:0],dividend[divide_bit]};
    wire divide_take = next_remainder >= {9'd0,divisor};
    wire signed [18:0] signed_root = quotient_negative ?
                                      -$signed({1'b0,quotient}) : $signed({1'b0,quotient});
    reg signed [17:0] root_numerator_reg;
    reg signed [37:0] root_squared,quadratic_term,linear_term,y_partial,y_calc;
    wire [1:0] scale_shift=(scale==8)?2'd3:(scale==4)?2'd2:
                           (scale==2)?2'd1:2'd0;
    wire signed [37:0] extended_root={{19{signed_root[18]}},signed_root};
    wire signed [37:0] pixel_x = $signed({1'b0,origin_x}) +
                                  ((extended_root <<< scale_shift) >>> 4);
    wire signed [37:0] pixel_y = $signed({1'b0,origin_y}) -
                                  ((y_calc <<< scale_shift) >>> 4);
    wire visible = (signed_root>=-19'sd32768) && (signed_root<=19'sd32767) &&
                   (y_calc>=-38'sd32768) && (y_calc<=38'sd32767) &&
                   (pixel_x>=0) && (pixel_x<=95) &&
                   (pixel_y>=0) && (pixel_y<=63);
    reg visible_reg;
    reg signed [7:0] old_a1,old_b1,old_c1,old_a2,old_b2,old_c2;
    reg old_q1,old_q2,old_enable;
    reg [3:0] old_scale;
    reg [6:0] old_ox;
    reg [5:0] old_oy;
    wire changed = old_a1!=a1 || old_b1!=b1 || old_c1!=c1 ||
                   old_a2!=a2 || old_b2!=b2 || old_c2!=c2 ||
                   old_q1!=graph1_quadratic || old_q2!=graph2_quadratic ||
                   old_scale!=scale || old_ox!=origin_x || old_oy!=origin_y ||
                   old_enable!=enable;
    wire signed [8:0] difference_a =
        (graph1_quadratic ? $signed({a1[7],a1}) : 9'sd0) -
        (graph2_quadratic ? $signed({a2[7],a2}) : 9'sd0);
    wire signed [8:0] difference_b = $signed({b1[7],b1})-$signed({b2[7],b2});
    wire signed [8:0] difference_c = $signed({c1[7],c1})-$signed({c2[7],c2});
    // Solve (A1-A2)x^2+(B1-B2)x+(C1-C2)=0. Register each stage of
    // B^2-4AC: the graph-type input must not pass through both products,
    // subtraction and root-count control in a single 100 MHz cycle.
    wire signed [19:0] b_square_extended={{2{b_square[17]}},b_square};
    wire signed [19:0] ac_product_extended={{2{ac_product[17]}},ac_product};
    wire signed [19:0] discriminant_from_products =
        b_square_extended - (ac_product_extended <<< 2);
    wire signed [9:0] denominator = (aa==0) ?
        $signed({bb[8],bb}) : $signed({aa,1'b0});
    wire signed [17:0] scaled_b=$signed(bb) <<< 4;
    wire signed [17:0] scaled_c=$signed(cc) <<< 4;
    wire signed [17:0] root_offset=$signed({4'b0,sqrt_value});
    wire signed [17:0] root_numerator=(aa==0) ? -scaled_c :
        -scaled_b + (root_index==0 ? -root_offset : root_offset);

    always @(posedge clk) begin
        if (reset) begin
            phase<=IDLE; status<=STATUS_OK; valid1<=0; valid2<=0;
            x1_q4<=0; y1_q4<=0; x2_q4<=0; y2_q4<=0;
            old_enable<=0; old_a1<=0;old_b1<=0;old_c1<=0;
            old_a2<=0;old_b2<=0;old_c2<=0;old_q1<=0;old_q2<=0;
            old_scale<=0;old_ox<=0;old_oy<=0;
            aa<=0;bb<=0;cc<=0;discriminant_q8<=0;
            b_square<=0;ac_product<=0;discriminant_reg<=0;
            sqrt_value<=0;sqrt_bit<=0;root_total<=0;root_index<=0;
            sqrt_trial_reg<=0;sqrt_trial_squared_reg<=0;
            dividend<=0;quotient<=0;remainder<=0;root_numerator_reg<=0;
            divisor<=0;quotient_negative<=0;divide_bit<=0;
            root_squared<=0;quadratic_term<=0;linear_term<=0;
            y_partial<=0;y_calc<=0;
            visible_reg<=0;
        end else if (changed) begin
            old_enable<=enable;
            old_a1<=a1;old_b1<=b1;old_c1<=c1;
            old_a2<=a2;old_b2<=b2;old_c2<=c2;
            old_q1<=graph1_quadratic;old_q2<=graph2_quadratic;
            old_scale<=scale;old_ox<=origin_x;old_oy<=origin_y;
            aa<=difference_a;bb<=difference_b;cc<=difference_c;
            valid1<=0;valid2<=0;status<=STATUS_OK;
            root_index<=0;
            if (!enable) phase<=IDLE;
            else phase<=CLASSIFY;
        end else case (phase)
            CLASSIFY: begin
                if (aa==0) begin
                    if (bb==0) begin
                        status<=(cc==0)?STATUS_SAME:STATUS_PAR;
                        phase<=DONE;
                    end else begin
                        root_total<=1;phase<=DIV_NUMERATOR;
                    end
                end else begin
                    b_square<=$signed(bb)*$signed(bb);
                    ac_product<=$signed(aa)*$signed(cc);
                    phase<=FORM_DISCRIMINANT;
                end
            end
            FORM_DISCRIMINANT: begin
                discriminant_reg<=discriminant_from_products;
                phase<=CHECK_DISCRIMINANT;
            end
            CHECK_DISCRIMINANT: begin
                if (discriminant_reg<0) begin
                    status<=STATUS_NONE;phase<=DONE;
                end else begin
                    root_total<=(discriminant_reg==0)?1:2;
                    discriminant_q8<={discriminant_reg[19:0],8'b0};
                    sqrt_value<=0;sqrt_bit<=13;phase<=SQRT;
                end
            end
            SQRT: begin
                // Register the trial square before its 28-bit comparison.
                sqrt_trial_reg<=sqrt_trial;
                sqrt_trial_squared_reg<=sqrt_trial*sqrt_trial;
                phase<=SQRT_COMPARE;
            end
            SQRT_COMPARE: begin
                if (sqrt_trial_squared_reg<=discriminant_q8)
                    sqrt_value<=sqrt_trial_reg;
                if (sqrt_bit==0) phase<=DIV_NUMERATOR;
                else begin
                    sqrt_bit<=sqrt_bit-1'b1;
                    phase<=SQRT;
                end
            end
            DIV_NUMERATOR: begin
                root_numerator_reg<=root_numerator;
                phase<=DIV_INIT;
            end
            DIV_INIT: begin
                // x=(-B +/- sqrt(D))/2A, with B and sqrt scaled by 16.
                phase<=DIV_RUN;divide_bit<=17;
                dividend<=root_numerator_reg<0 ? -root_numerator_reg : root_numerator_reg;
                quotient_negative<=root_numerator_reg[17] ^ denominator[9];
                divisor<=denominator<0 ? -denominator : denominator;
                quotient<=0;remainder<=0;
            end
            DIV_RUN: begin
                // One restoring-division bit per cycle bounds the area and
                // avoids a long combinational divider on the 100 MHz path.
                remainder<=divide_take ? next_remainder-{9'd0,divisor} : next_remainder;
                quotient[divide_bit]<=divide_take;
                if (divide_bit==0) phase<=EVAL_SQUARE;
                else divide_bit<=divide_bit-1'b1;
            end
            EVAL_SQUARE: begin
                // Pipeline the square, A*x^2 and final Y independently;
                // all marker coordinates are signed Q4 graph units.
                root_squared<=$signed(signed_root)*$signed(signed_root);
                phase<=EVAL_A;
            end
            EVAL_A: begin
                quadratic_term<=graph1_quadratic ?
                    (($signed(a1)*root_squared) >>> 4) : 38'sd0;
                phase<=EVAL_Y;
            end
            EVAL_Y: begin
                linear_term<=$signed(b1)*$signed(signed_root);
                phase<=EVAL_Y_SUM;
            end
            EVAL_Y_SUM: begin
                y_partial<=quadratic_term+linear_term;
                phase<=EVAL_Y_OFFSET;
            end
            EVAL_Y_OFFSET: begin
                y_calc<=y_partial+($signed(c1) <<< 4);
                phase<=PROJECT_VISIBLE;
            end
            PROJECT_VISIBLE: begin
                visible_reg<=visible;
                phase<=RECORD;
            end
            RECORD: begin
                if (root_index==0) begin
                    x1_q4<=signed_root[15:0];y1_q4<=y_calc[15:0];valid1<=visible_reg;
                end else begin
                    x2_q4<=signed_root[15:0];y2_q4<=y_calc[15:0];valid2<=visible_reg;
                end
                if (visible_reg) status<=STATUS_OK;
                else if (!valid1) status<=STATUS_OUT;
                if (root_index+1 < root_total) begin
                    root_index<=root_index+1'b1;phase<=DIV_NUMERATOR;
                end else phase<=DONE;
            end
            default: begin end
        endcase
    end
endmodule
