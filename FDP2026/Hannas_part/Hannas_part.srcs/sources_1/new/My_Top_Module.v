`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//  FILL IN THE FOLLOWING INFORMATION:
//  STUDENT A NAME: Milla Glännfjord
//  STUDENT B NAME: Hanna Wahlgren
//  STUDENT C NAME: Oskar Plogner
//  STUDENT D NAME: Wang Qichen
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
        
    wire [15:0] oled_data_task1;
    wire [15:0] oled_data_task2;
    wire [15:0] oled_data_task3;
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
    
    //TASK 1
    task1 task_1(.CLOCK(CLOCK),
                 .pixel_index(pixel_index),
                 .btnU(db_btnU && mode == 3'b001),
                 .oled_data(oled_data_task1)
    );
    
    //TASK 2
    task2 task_2(.CLOCK(CLOCK),
                 .pixel_index(pixel_index),
                 .btnD(db_btnD && mode == 3'b010),
                 .oled_data(oled_data_task2)
    );
    
    //TASK 3
    task3 task_3(.CLOCK(CLOCK),
                 .pixel_index(pixel_index),
                 .SW1(sw[1] && mode == 3'b011),
                 .oled_data(oled_data_task3)
    );
    
    //calculator
    calculator calculatornator(.CLOCK(CLOCK),
                               .btnU(db_btnU && mode == 3'b100),
                               .btnD(db_btnD && mode == 3'b100),
                               .btnL(db_btnL && mode == 3'b100),
                               .btnR(db_btnR && mode == 3'b100),
                               .btnC(db_btnC && mode == 3'b100),
                               .sw(sw[7:0]),
                               .SW14(sw[14]),
                               .SW15(sw[15]),
                               .pixel_index(pixel_index),
                               .oled_data(oled_data_calculator)
    );

    
    reg [2:0] mode = 3'b000;
    
    always @(posedge CLOCK) begin
    
        // Return from calculator
        if ((mode == 3'b100) && sw[15])
            mode <= 3'b000;
            
         // Return from Tasks 1-3
        else if ((mode != 3'b000) &&
                 (mode != 3'b100) &&
                  db_btnC)
        mode <= 3'b000;                

        else if (mode == 3'b000) begin
            
            if (db_btnU)
                mode <= 3'b001;
            else if (db_btnD)
                mode <= 3'b010;
            else if (db_btnL)
                mode <= 3'b011;
            else if (db_btnR)
                mode <= 3'b100;                        
        end            
    end
    
    assign oled_data = (mode == 3'b001) ? oled_data_task1      :
                       (mode == 3'b010) ? oled_data_task2      :
                       (mode == 3'b011) ? oled_data_task3      :
                       (mode == 3'b100) ? oled_data_calculator :
                                         16'hF800;
    
endmodule