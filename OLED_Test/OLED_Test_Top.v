`timescale 1ns / 1ps

// Standalone Basys3 OLED diagnostic. All switches OFF => full-screen red.
// SW[2:0] selects a pattern, SW3 enables auto-cycle, SW15 restarts the OLED.
module OLED_Test_Top #(
    parameter integer HEARTBEAT_HALF_CYCLES=50_000_000,
    parameter integer AUTO_FRAMES=180
)(
    input wire CLOCK,
    input wire [3:0] sw,
    input wire SW15,
    output wire [7:0] JB,
    output wire [7:0] led
);
    // Real divide-by-16 clock: 100 MHz -> 6.25 MHz. The XDC constrains
    // oled_clk_reg/Q as a generated clock related to the board oscillator.
    reg [2:0] divide_count=0;
    reg oled_clk=0;
    always @(posedge CLOCK) begin
        divide_count<=divide_count+1'b1;
        if(divide_count==7) oled_clk<=~oled_clk;
    end

    (* ASYNC_REG="TRUE" *) reg [4:0] switch_meta=0,switch_sync=0;
    always @(posedge CLOCK) begin
        switch_meta<={SW15,sw};
        switch_sync<=switch_meta;
    end

    // Keep the core reset across several real OLED edges. Its own delays
    // then perform the full power/reset/display-enable sequence.
    reg [3:0] startup_count=0;
    wire oled_reset=switch_sync[4] || startup_count!=8;
    always @(posedge oled_clk) begin
        if(switch_sync[4]) startup_count<=0;
        else if(startup_count!=8) startup_count<=startup_count+1'b1;
    end

    localparam HB_BITS=(HEARTBEAT_HALF_CYCLES>1)?$clog2(HEARTBEAT_HALF_CYCLES):1;
    reg [HB_BITS-1:0] heartbeat_count=0;
    reg heartbeat=0;
    always @(posedge CLOCK) begin
        if(heartbeat_count==HEARTBEAT_HALF_CYCLES-1) begin
            heartbeat_count<=0;heartbeat<=~heartbeat;
        end else heartbeat_count<=heartbeat_count+1'b1;
    end

    wire frame_begin,sending_pixels,sample_pixel;
    wire [12:0] pixel_index;
    wire [15:0] pixel_data;
    localparam AUTO_BITS=(AUTO_FRAMES>1)?$clog2(AUTO_FRAMES):1;
    reg [AUTO_BITS-1:0] auto_count=0;
    reg [2:0] auto_pattern=0,active_pattern=0;
    reg [6:0] bar_x=0;
    always @(posedge oled_clk) begin
        if(oled_reset) begin
            auto_count<=0;auto_pattern<=0;active_pattern<=0;bar_x<=0;
        end else if(frame_begin) begin
            // Freeze pattern and motion for the complete transmitted frame.
            bar_x<=(bar_x==95)?7'd0:bar_x+1'b1;
            if(switch_sync[3]) begin
                active_pattern<=auto_pattern;
                if(auto_count==AUTO_FRAMES-1) begin
                    auto_count<=0;auto_pattern<=auto_pattern+1'b1;
                end else auto_count<=auto_count+1'b1;
            end else begin
                active_pattern<=switch_sync[2:0];
                auto_pattern<=switch_sync[2:0];auto_count<=0;
            end
        end
    end

    oled_test_pattern patterns(.pixel_index(pixel_index),.pattern(active_pattern),
        .bar_x(bar_x),.pixel_data(pixel_data));
    Oled_Display #(.ClkFreq(6_250_000)) oled(
        .clk(oled_clk),.reset(oled_reset),.frame_begin(frame_begin),
        .sending_pixels(sending_pixels),.sample_pixel(sample_pixel),
        .pixel_index(pixel_index),.pixel_data(pixel_data),
        .cs(JB[0]),.sdin(JB[1]),.sclk(JB[3]),.d_cn(JB[4]),
        .resn(JB[5]),.vccen(JB[6]),.pmoden(JB[7]));
    assign JB[2]=1'b0; // OLED connector pin 3 is not used by the driver.
    assign led[0]=heartbeat;
    assign led[1]=JB[7];
    assign led[2]=JB[6];
    assign led[3]=JB[5];
    assign led[4]=sending_pixels;
    assign led[7:5]=active_pattern;
endmodule
