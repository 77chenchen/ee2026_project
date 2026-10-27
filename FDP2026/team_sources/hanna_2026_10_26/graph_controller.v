`timescale 1ns / 1ps

module graph_controller(
    input clk,
    input reset,
    input btnC_pressed,

    input sw0,  // used to select graph count (1 or 2) and type (linear or quadratic) migght have to expand with more swithces or implement it another way if we choose to add cubic graphs
    input sw14,  // used to start plotting the graphs. the switch is just a placeholder and we can change it to a button or anything else in the future.

    input signed [7:0] input_value, // signed input value (maybe from milla's module if possible?)

    //graph settings
    output reg [1:0] graph_count = 1, // saves how many graphs we want
    output reg graph1_type = 0,  // 0 = linear, 1 = quadratic
    output reg graph2_type = 0,

    // Graph 1 coefficients in the format: y = a1*x^2 + b1*x + c1
    output reg signed [7:0] a1 = 0,
    output reg signed [7:0] b1 = 0,
    output reg signed [7:0] c1 = 0,

    // Graph 2 coefficients: y = a2*x^2 + b2*x + c2
    output reg signed [7:0] a2 = 0,
    output reg signed [7:0] b2 = 0,
    output reg signed [7:0] c2 = 0,

    // Current state
    output reg [2:0] state = 0,

    //indicates that all coefficients have been entered, then it gets set to = 1
    output reg ready = 0,

    // Enables the graph to be drawn (not yet implemented)
    output reg draw = 0
);

    // defining all states we want (yet atleast)

    localparam SELECT_COUNT = 3'd0;
    localparam SELECT_TYPE  = 3'd1;
    localparam ENTER_A      = 3'd2;
    localparam ENTER_B      = 3'd3;
    localparam ENTER_C      = 3'd4;
    localparam NEXT_GRAPH   = 3'd5;
    localparam READY        = 3'd6;
    localparam VIEW_GRAPH   = 3'd7;


    // current_graph is used to track which of the graphs we are entering values for (0 for graph1, and 1 for graph2)
    // this allows us to reuse the states ENTER_A, ENTER_B and ENTER_C for both graphs
    reg current_graph = 0;


    // all the main logic is in here.

    always @(posedge clk) begin

        // if we want to reset the values, we set all values to 0 and set the state to the first one, restarting the process of choosing number of graphs etc..

        if (reset) begin

            state <= SELECT_COUNT;

            graph_count <= 1;
            graph1_type <= 0;
            graph2_type <= 0;

            current_graph <= 0;

            a1 <= 0;
            b1 <= 0;
            c1 <= 0;

            a2 <= 0;
            b2 <= 0;
            c2 <= 0;

            ready <= 0;
            draw <= 0;
        end

        else begin

            case (state)

                // state 0 = select number of graphs
                SELECT_COUNT: begin

                    // SW0 OFF = 1 graph, SW0 ON  = 2 graphs --> Press btnC to confirm
                    if (btnC_pressed) begin

                        if (sw0)
                            graph_count <= 2;
                        else
                            graph_count <= 1;

                        current_graph <= 0;
                        state <= SELECT_TYPE; //setting state to next state of selecting graph type.
                    end
                end


                // state 1 = selecting graph type
                SELECT_TYPE: begin
                    if (btnC_pressed) begin
                    
                        if (current_graph == 0)
                            graph1_type <= sw0;
                        else
                            graph2_type <= sw0;

                        // if sw0 is on it means that a quadratic has bees chosen, and the next step is to enter the A-coefficient
                        // if sw0 is not on it means that a linear graph is chosen and we can set A = 0 and go to ENTER_B immediately.
                        if (sw0) begin

                            state <= ENTER_A;

                        end
                        else begin

                            if (current_graph == 0)
                                a1 <= 0;
                            else
                                a2 <= 0;

                            state <= ENTER_B;
                        end
                    end
                end


                // state 2 = enter a-value. will only get here if current_graph is quadratic as previously explained

                ENTER_A: begin

                    if (btnC_pressed) begin

                        if (current_graph == 0)
                            a1 <= input_value;
                        else
                            a2 <= input_value;

                        state <= ENTER_B;
                    end
                end

                // state 3 = enter b-value.
                ENTER_B: begin

                    if (btnC_pressed) begin

                        if (current_graph == 0)
                            b1 <= input_value;
                        else
                            b2 <= input_value;

                        state <= ENTER_C;
                    end
                end

                // state 4 = enter c-value.
                ENTER_C: begin

                    if (btnC_pressed) begin

                        if (current_graph == 0)
                            c1 <= input_value;
                        else
                            c2 <= input_value;

                        state <= NEXT_GRAPH;
                    end
                end

                // state 5 = check for second graph.
                NEXT_GRAPH: begin

                    // If the user selected 2 graphs and we just finished Graph 1, 
                    // we will enter Graph 2 and choose its graph-type. 
                    // then the same procedure as beforefor A, B, C.

                    if (graph_count == 2 &&
                        current_graph == 0) begin

                        current_graph <= 1;
                        state <= SELECT_TYPE;

                    end
                    else begin

                        // when we get here it means all requested coefficients have been entered.

                        ready <= 1;
                        state <= READY;

                    end
                end


                // state 6 = ready to draw. here we just wait for SW14 (or another input if we want to change) to be turned ON.
                // Once enabled, we can use the saved coefficients to draw the graph somehow.
                READY: begin

                    if (sw14) begin

                        draw <= 1;
                        state <= VIEW_GRAPH;
                    end
                end


                // state 7 = draw and view graph.
                VIEW_GRAPH: begin

                // The user is currently viewing the graphs.
                // the actual pixel rendering is being handled by another module, having this module's a,b,c-values as inputs.
                //
                // Later, we could add controls here for:
                // - Zooming
                // - Panning
                // - Moving a cursor along the graph
                // - Returning to the input menu
                end

                // If "state" doesn't match any of the defined cases, it will execute this code, resetting the process.
                default: begin

                    state <= SELECT_COUNT;
                    ready <= 0;
                    draw <= 0;

                end

            endcase
        end
    end

endmodule