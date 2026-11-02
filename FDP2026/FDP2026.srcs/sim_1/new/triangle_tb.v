`timescale 1ns/1ps

module triangle_tb;
    reg clk=0;
    always #5 clk=~clk;
    reg up=0,down=0,confirm=0,restart=0;
    reg [6:0] switches=0;
    reg [12:0] pixel_index=0;
    wire [15:0] pixel;
    integer first,second,cases=0;

    right_angle_triangle dut(
        .CLOCK(clk),
        .btnU(up),.btnD(down),.btnC(confirm),.sw(switches),
        .SW14(restart),.pixel_index(pixel_index),.oled_data(pixel));

    function integer reference_root;
        input integer radicand;
        integer value;
        begin
            value=0;
            while((value+1)*(value+1)<=radicand) value=value+1;
            reference_root=value;
        end
    endfunction

    task reset_menu;
        begin
            @(negedge clk);restart=1;
            @(negedge clk);restart=0;
        end
    endtask
    task press_confirm;
        begin
            @(negedge clk);confirm=1;
            @(negedge clk);confirm=0;
        end
    endtask
    task enter_values;
        input leg;
        input [6:0] first_value,second_value;
        begin
            reset_menu();
            if(leg) begin
                @(negedge clk);down=1;
                @(negedge clk);down=0;
            end
            press_confirm();
            switches=first_value;press_confirm();
            switches=second_value;press_confirm();
        end
    endtask
    task check_case;
        input leg;
        input [6:0] first_value,second_value;
        integer cycles,expected;
        begin
            enter_values(leg,first_value,second_value);
            for(cycles=0;cycles<16 && dut.calc_phase!=dut.CALC_DONE;cycles=cycles+1)
                @(negedge clk);
            if(dut.calc_phase!==dut.CALC_DONE) begin
                $display("FAIL triangle computation timeout");$finish_and_return(1);
            end
            if(leg && second_value<first_value) begin
                if(dut.invalid!==1'b1 || dut.a!==7'd0) begin
                    $display("FAIL invalid triangle b=%0d c=%0d",first_value,second_value);
                    $finish_and_return(1);
                end
            end else begin
                if(leg) expected=reference_root(second_value*second_value-first_value*first_value);
                else expected=reference_root(first_value*first_value+second_value*second_value);
                if(dut.invalid!==1'b0 || (leg?dut.a:dut.c)!==expected) begin
                    $display("FAIL triangle leg=%b first=%0d second=%0d expected=%0d got=%0d invalid=%b",
                             leg,first_value,second_value,expected,(leg?dut.a:dut.c),dut.invalid);
                    $finish_and_return(1);
                end
            end
            cases=cases+1;
        end
    endtask
    initial begin
        check_case(0,100,100);
        if(dut.c!==15'd141) begin
            $display("FAIL wide hypotenuse");$finish_and_return(1);
        end
        check_case(0,127,127);
        if(dut.c!==15'd179) begin
            $display("FAIL maximum hypotenuse display");$finish_and_return(1);
        end
        check_case(1,4,3);
        pixel_index=25*96+25;#1;
        if(dut.invalid!==1'b1 || pixel!==16'hF800) begin
            $display("FAIL triangle error overlay flag=%b pixel=%h",dut.invalid,pixel);
            $finish_and_return(1);
        end
        check_case(0,3,4);
        if(dut.c!==15'd5 || dut.invalid!==1'b0) begin
            $display("FAIL triangle error recovery");$finish_and_return(1);
        end

        // Reset cancels an in-flight square root, with no late result write.
        enter_values(0,100,100);
        repeat(3)@(negedge clk);reset_menu();
        repeat(12)@(negedge clk);
        if(dut.state!==dut.state_0 || dut.calc_phase!==dut.CALC_SQUARE || dut.c!==15'd5) begin
            $display("FAIL triangle reset while busy");$finish_and_return(1);
        end

        // Cover every pair of 7-bit switch inputs in both calculation modes.
        for(first=0;first<128;first=first+1)
            for(second=0;second<128;second=second+1) begin
                check_case(0,first,second);
                check_case(1,first,second);
            end
        $display("PASS triangle %0d cases, wide roots, invalid inputs, reset and OLED error display",cases);
        $finish;
    end

    initial begin
        #20000000;
        $display("FAIL triangle test watchdog");$finish_and_return(1);
    end
endmodule
