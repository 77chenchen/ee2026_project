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
                      output [7:0] JB);

    wire clk6p25m;
    
    clock_hz clk_6_25 (.HZ(6_250_000),
                       .CLOCK(CLOCK),
                       .SLOW_CLOCK(clk6p25m) 
                        );

    wire [15:0] oled_data;
    wire [12:0] pixel_index;
        
    wire [15:0] oled_data_graph;
    wire [15:0] oled_data_calculator;
    
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
    
    reg [1:0] choice = state_nothing;
    
    // calculator
    calculator calculatornator(.CLOCK(CLOCK),
                               .btnU(db_btnU && choice == state_calculator),
                               .btnD(db_btnD && choice == state_calculator),
                               .btnL(db_btnL && choice == state_calculator),
                               .btnR(db_btnR && choice == state_calculator),
                               .btnC(db_btnC && choice == state_calculator),
                               .sw(sw[7:0]),
                               .SW14(sw[14]),
                               .SW15(sw[15]),
                               .pixel_index(pixel_index),
                               .oled_data(oled_data_calculator)
    );
    
    // Graph-module:
    
    // ....
    
    
    always @(posedge CLOCK) begin
        
        // Menu:
        if (choice == state_nothing) begin    
            
            // Move up        
            if (db_btnU)
                arrow <= (arrow == 2'b00) ? 2'b00 : (arrow - 1);
            
            // Move down
            else if (db_btnD)
                arrow <= (arrow == 2'b01) ? 2'b01 : (arrow + 1);                        
            
            else if (db_btnC) begin
                if (arrow == 2'b00)
                    choice <= state_calculator;
                else if (arrow == 2'b01)
                    choice <= state_graph;
            end
        end   
        
        // Return from calculator or graph
        else if (choice == state_calculator || choice == state_graph) begin 
        
            if (sw[15]) begin
                choice <= state_nothing;
                arrow <= 2'b00;
            end
        end
            
    end
    
    assign oled_data = (choice == state_calculator) ? oled_data_calculator :
                       (choice == state_graph)      ? 16'hFFFF             :
                                                      16'hF800;
    
endmodule