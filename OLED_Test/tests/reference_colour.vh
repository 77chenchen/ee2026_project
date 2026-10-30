// Independent simulation oracle; never added to the synthesis fileset.
function [15:0] reference_colour;
    input integer pattern,index,bar;
    integer x,y;
    begin
        x=index%96;y=index/96;
        case(pattern)
            0:reference_colour=16'hF800;
            1:reference_colour=16'h07E0;
            2:reference_colour=16'h001F;
            3:reference_colour=16'hFFFF;
            4:reference_colour=(((x/8)+(y/8))%2)?16'hFFFF:16'h0000;
            5:begin
                reference_colour=(x==0 || x==95 || y==0 || y==63)?16'hFFFF:16'h0000;
                if(x<=3 && y<=3) reference_colour=16'hF800;
                if(x>=92 && y<=3) reference_colour=16'h07E0;
                if(x<=3 && y>=60) reference_colour=16'h001F;
                if(x>=92 && y>=60) reference_colour=16'hFFE0;
            end
            6:reference_colour=(x==48 || y==32)?16'hFFFF:16'h0000;
            7:begin
                if(x<32) reference_colour=16'hF800;
                else if(x<64) reference_colour=16'h07E0;
                else reference_colour=16'h001F;
                if(x>=bar && x-bar<4) reference_colour=16'hFFFF;
            end
            default:reference_colour=16'hF81F;
        endcase
    end
endfunction
