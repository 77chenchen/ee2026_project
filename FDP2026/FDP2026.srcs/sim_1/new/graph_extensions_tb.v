`timescale 1ns / 1ps
module graph_extensions_tb;
    reg clk=0,reset=1,enable=0,q1=0,q2=1;
    reg signed [7:0] a1=0,b1=0,c1=0,a2=1,b2=0,c2=-1;
    reg [3:0] scale=4;
    reg [6:0] ox=48;
    reg [5:0] oy=32;
    wire [2:0] status;
    wire v1,v2;
    wire signed [15:0] x1,y1,x2,y2;
    always #5 clk=~clk;
    graph_quadratic_intersections dut(
        .clk(clk),.reset(reset),.enable(enable),
        .graph1_quadratic(q1),.graph2_quadratic(q2),
        .a1(a1),.b1(b1),.c1(c1),.a2(a2),.b2(b2),.c2(c2),
        .scale(scale),.origin_x(ox),.origin_y(oy),
        .status(status),.valid1(v1),.valid2(v2),
        .x1_q4(x1),.y1_q4(y1),.x2_q4(x2),.y2_q4(y2)
    );
    task settle; begin repeat(100) @(posedge clk); #1; end endtask
    task check_two_roots;
        begin
            if (status!=0 || !v1 || !v2 ||
                !((x1==-16 && x2==16)||(x1==16 && x2==-16)) ||
                y1!=0 || y2!=0) begin
                $display("FAIL two roots status=%0d v=%b%b x=%0d,%0d y=%0d,%0d",
                         status,v1,v2,x1,x2,y1,y2);
                $finish_and_return(1);
            end
        end
    endtask
    initial begin
        repeat(2) @(posedge clk);#1;reset=0;enable=1;
        settle();check_two_roots(); // y=0 versus y=x^2-1
        c2=0;settle();
        if(status!=0||!v1||v2||x1!=0||y1!=0) begin
            $display("FAIL tangent status=%0d v=%b%b x=%0d",status,v1,v2,x1);
            $finish_and_return(1);
        end
        c2=1;settle();
        if(status!=5||v1||v2) begin
            $display("FAIL no real roots status=%0d v=%b%b",status,v1,v2);
            $finish_and_return(1);
        end
        q1=1;a1=1;a2=-1;c1=0;c2=2;settle();
        if(status!=0||!v1||!v2||x1!=-16||x2!=16||y1!=16||y2!=16) begin
            $display("FAIL quadratic pair status=%0d v=%b%b x=%0d,%0d y=%0d,%0d",
                     status,v1,v2,x1,x2,y1,y2);
            $finish_and_return(1);
        end
        q1=0;a1=0;a2=1;c1=0;c2=-2;settle();
        if(status!=0||!v1||!v2||
           !((x1==-22&&x2==22)||(x1==22&&x2==-22))) begin
            $display("FAIL fractional roots status=%0d v=%b%b x=%0d,%0d",
                     status,v1,v2,x1,x2);$finish_and_return(1);
        end
        c2=-100;scale=8;settle();
        if(status!=3||v1||v2) begin
            $display("FAIL roots outside view status=%0d v=%b%b",status,v1,v2);
            $finish_and_return(1);
        end
        scale=4;q1=0;q2=1;a1=0;b1=1;c1=0;a2=1;b2=0;c2=0;
        settle();
        if(status!=0||!v1||!v2||
           !((x1==0&&y1==0&&x2==16&&y2==16)||
             (x2==0&&y2==0&&x1==16&&y1==16))) begin
            $display("FAIL line/quadratic y=x roots x=%0d,%0d y=%0d,%0d",
                     x1,x2,y1,y2);$finish_and_return(1);
        end
        // Equal quadratic terms leave a linear difference and one root.
        q1=1;a1=1;b1=0;c1=0;q2=1;a2=1;b2=1;c2=0;settle();
        if(status!=0||!v1||v2||x1!=0||y1!=0) begin
            $display("FAIL equal-A quadratic root status=%0d x=%0d y=%0d",
                     status,x1,y1);$finish_and_return(1);
        end
        b2=0;settle();
        if(status!=2||v1||v2) begin
            $display("FAIL identical quadratics status=%0d",status);
            $finish_and_return(1);
        end
        $display("PASS mixed and quadratic intersections: 0, 1, 2 roots");
        $finish;
    end
endmodule
