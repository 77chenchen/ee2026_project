`timescale 1ns / 1ps

// Standalone Basys3 + Digilent PmodOLEDrgb (SSD1331) light-up test.
// No other Verilog module is needed. The OLED on JB turns fully on.
module OLED_Test_Top(
    input  wire       CLOCK,  // Basys3 100 MHz oscillator
    output wire [7:0] JB,
    output wire [4:0] led
);
    // Divide 100 MHz by 16 to make the SPI clock 6.25 MHz.
    reg [2:0] divide_count = 0;
    reg oled_clk = 0;
    always @(posedge CLOCK) begin
        divide_count <= divide_count + 1'b1;
        if (divide_count == 7)
            oled_clk <= ~oled_clk;
    end

    localparam [3:0] POWER_WAIT = 0, RESET_LOW = 1, RESET_HIGH = 2,
                     INIT = 3, CLEAR_WAIT = 4, VCC_WAIT = 5,
                     DISPLAY_ON = 6, ALL_ON = 7, DONE = 8;
    reg [3:0] phase = POWER_WAIT;
    reg [19:0] wait_count = 0;
    reg [5:0] command_index = 0;
    reg [7:0] shift = 0;
    reg [3:0] bits_left = 0;

    wire busy = (bits_left != 0);
    assign JB[0] = ~busy;                        // CS, active low
    assign JB[1] = shift[7];                    // MOSI, MSB first
    assign JB[2] = 1'b0;                        // Unused Pmod pin
    assign JB[3] = busy ? oled_clk : 1'b1;      // SCLK
    assign JB[4] = 1'b0;                        // D/C = command
    assign JB[5] = (phase != RESET_LOW);        // RESN
    assign JB[6] = (phase >= VCC_WAIT);         // VCCEN
    assign JB[7] = 1'b1;                        // PMODEN

    // Board LEDs make it possible to diagnose a black OLED without ILA.
    reg [24:0] heartbeat_count = 0;
    always @(posedge CLOCK)
        heartbeat_count <= heartbeat_count + 1'b1;
    assign led[0] = heartbeat_count[24];        // Blinks if FPGA clock runs
    assign led[1] = JB[7];                      // OLED logic power enabled
    assign led[2] = JB[6];                      // OLED panel power enabled
    assign led[3] = JB[5];                      // OLED reset released
    assign led[4] = (phase == DONE) && !busy;   // Initialization complete

    // SSD1331 settings from Digilent's PmodOLEDrgb initialization sequence.
    // 0x2E stops scrolling; 0x25 clears the 96x64 screen before VCC is enabled.
    function [7:0] init_byte;
        input [5:0] index;
        begin
            case (index)
                 0: init_byte=8'hFD;  1: init_byte=8'h12;
                 2: init_byte=8'hAE;  3: init_byte=8'hA0;
                 4: init_byte=8'h72;  5: init_byte=8'hA1;
                 6: init_byte=8'h00;  7: init_byte=8'hA2;
                 8: init_byte=8'h00;  9: init_byte=8'hA4;
                10: init_byte=8'hA8; 11: init_byte=8'h3F;
                12: init_byte=8'hAD; 13: init_byte=8'h8E;
                14: init_byte=8'hB0; 15: init_byte=8'h0B;
                16: init_byte=8'hB1; 17: init_byte=8'h31;
                18: init_byte=8'hB3; 19: init_byte=8'hF0;
                20: init_byte=8'h8A; 21: init_byte=8'h64;
                22: init_byte=8'h8B; 23: init_byte=8'h78;
                24: init_byte=8'h8C; 25: init_byte=8'h64;
                26: init_byte=8'hBB; 27: init_byte=8'h3A;
                28: init_byte=8'hBE; 29: init_byte=8'h3E;
                30: init_byte=8'h87; 31: init_byte=8'h06;
                32: init_byte=8'h81; 33: init_byte=8'h91;
                34: init_byte=8'h82; 35: init_byte=8'h50;
                36: init_byte=8'h83; 37: init_byte=8'h7D;
                38: init_byte=8'h2E; 39: init_byte=8'h25;
                40: init_byte=8'h00; 41: init_byte=8'h00;
                42: init_byte=8'h5F; 43: init_byte=8'h3F;
                default: init_byte=8'h00;
            endcase
        end
    endfunction

    // Change MOSI on falling SCLK; the OLED samples it on rising SCLK.
    always @(negedge oled_clk) begin
        if (busy) begin
            shift <= {shift[6:0], 1'b0};
            bits_left <= bits_left - 1'b1;
        end else begin
            case (phase)
                POWER_WAIT: if (wait_count == 125_000) begin // at least 20 ms
                    wait_count <= 0; phase <= RESET_LOW;
                end else wait_count <= wait_count + 1'b1;
                RESET_LOW: if (wait_count == 19-1) begin // >= 3 us
                    wait_count <= 0; phase <= RESET_HIGH;
                end else wait_count <= wait_count + 1'b1;
                RESET_HIGH: if (wait_count == 19-1) begin
                    wait_count <= 0; phase <= INIT;
                end else wait_count <= wait_count + 1'b1;
                INIT: if (command_index < 44) begin
                    shift <= init_byte(command_index);
                    bits_left <= 8;
                    command_index <= command_index + 1'b1;
                end else begin
                    wait_count <= 0; phase <= CLEAR_WAIT;
                end
                CLEAR_WAIT: if (wait_count == 31_250-1) begin // 5 ms
                    wait_count <= 0; phase <= VCC_WAIT;
                end else wait_count <= wait_count + 1'b1;
                VCC_WAIT: if (wait_count == 625_000-1) begin // 100 ms
                    phase <= DISPLAY_ON;
                end else wait_count <= wait_count + 1'b1;
                DISPLAY_ON: begin
                    shift <= 8'hAF; bits_left <= 8; phase <= ALL_ON;
                end
                ALL_ON: begin
                    shift <= 8'hA5; bits_left <= 8; phase <= DONE;
                end
                default: phase <= DONE;
            endcase
        end
    end
endmodule
