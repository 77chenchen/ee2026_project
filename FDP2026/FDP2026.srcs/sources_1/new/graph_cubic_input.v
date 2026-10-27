`timescale 1ns / 1ps

// Graph-only extension. Oskar's controller remains the source for setups that
// use only linear/quadratic graphs; this controller takes over when SW1 selects
// a cubic at either type-selection step.
module graph_cubic_input(
    input wire clk, reset, start, btnC_pressed, sw0, sw1, sw14,
    input wire [1:0] start_count,
    input wire start_second,
    input wire start_graph1_type,
    input wire signed [7:0] start_a1, start_b1, start_c1,
    input wire signed [7:0] input_value,
    output reg [1:0] graph_count,
    output reg graph1_type, graph2_type, cubic1, cubic2,
    output reg signed [7:0] a1,b1,c1,d1,a2,b2,c2,d2,
    output reg [2:0] state,
    output reg current_graph, ready, draw
);
    localparam SELECT_TYPE=3'd1, ENTER_A=3'd2, ENTER_B=3'd3,
               ENTER_C=3'd4, ENTER_D=3'd5, READY=3'd6, VIEW=3'd7;
    reg sw14_previous;
    always @(posedge clk) begin
        sw14_previous <= sw14;
        if (reset) begin
            graph_count<=1; graph1_type<=0; graph2_type<=0;
            cubic1<=0; cubic2<=0;
            a1<=0; b1<=0; c1<=0; d1<=0;
            a2<=0; b2<=0; c2<=0; d2<=0;
            state<=SELECT_TYPE; current_graph<=0; ready<=0; draw<=0;
            sw14_previous<=sw14;
        end else if (start) begin
            // A graph-2 cubic can be selected after Oskar has already saved
            // graph 1. Copy that finished graph into our isolated FSM.
            graph_count<=start_count;
            current_graph<=start_second;
            graph1_type<=start_graph1_type;
            a1<=start_a1; b1<=start_b1; c1<=start_c1; d1<=0;
            a2<=0; b2<=0; c2<=0; d2<=0;
            cubic1<=!start_second; cubic2<=start_second;
            graph2_type<=0;
            state<=ENTER_A; ready<=0; draw<=0;
        end else begin
            case (state)
                SELECT_TYPE: if (btnC_pressed) begin
                    // SW1 wins over SW0, so both switches high still means
                    // cubic. Linear skips A; only cubic requests D.
                    if (current_graph) begin
                        cubic2<=sw1; graph2_type<=sw0 && !sw1;
                        a2<=0; d2<=0;
                    end else begin
                        cubic1<=sw1; graph1_type<=sw0 && !sw1;
                        a1<=0; d1<=0;
                    end
                    state<=(sw1 || sw0)?ENTER_A:ENTER_B;
                end
                ENTER_A: if (btnC_pressed) begin
                    if (current_graph) a2<=input_value; else a1<=input_value;
                    state<=ENTER_B;
                end
                ENTER_B: if (btnC_pressed) begin
                    if (current_graph) b2<=input_value; else b1<=input_value;
                    state<=ENTER_C;
                end
                ENTER_C: if (btnC_pressed) begin
                    if (current_graph) c2<=input_value; else c1<=input_value;
                    if ((current_graph && cubic2) || (!current_graph && cubic1))
                        state<=ENTER_D;
                    else if (!current_graph && graph_count==2) begin
                        current_graph<=1; state<=SELECT_TYPE;
                    end else begin ready<=1; state<=READY; end
                end
                ENTER_D: if (btnC_pressed) begin
                    if (current_graph) d2<=input_value; else d1<=input_value;
                    if (!current_graph && graph_count==2) begin
                        current_graph<=1; state<=SELECT_TYPE;
                    end else begin ready<=1; state<=READY; end
                end
                READY: if (sw14 && !sw14_previous) begin draw<=1; state<=VIEW; end
                default: begin end
            endcase
        end
    end
endmodule
