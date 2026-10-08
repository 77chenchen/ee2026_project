`timescale 1ns / 1ps

module oled( (input [1:0] SEL, output reg [15:0] PIXEL_COLOUR); 
always @ (SEL) 
begin  
if  ( SEL[1] == 0 && SEL[0] == 0 ) 
PIXEL_COLOUR = {5'b11111, 6'b000000, 5'b00000}; 
else if ( SEL[1] == 0 && SEL[0] == 1) 
PIXEL_COLOUR = {5'b00000, 6'b000000, 5'b11111}; 
else if ( SEL[1] == 1 && SEL[0] == 0) 
PIXEL_COLOUR = {5'b00000, 6'b111111, 5'b00000}; 
else                                 
PIXEL_COLOUR = { 5'b11111, 6'b000000, 5'b11111}; 
end 


// Solution 1b - Behavioral Style of Modeling using case statements 
always @ (*)     
begin  
case ({SEL[1],SEL[0]}) 
2'b00 : PIXEL_COLOUR = 16'hF800; 
2'b01 : PIXEL_COLOUR = 16'h001F; 
2'b10 : PIXEL_COLOUR = 16'h07E0; 
2'b11 : PIXEL_COLOUR = 16'hF81F; 
default : PIXEL_COLOUR = 16'h0000;   
//the default statement is used to capture all other cases! 
endcase 
end 

// Solution 2 - Dataflow Style of Modeling using continuous assignments 
assign PIXEL_COLOUR = (SEL[1]) ? ( SEL[0] ?  16'hF81F :  16'h07E0): 
: ( SEL[0] ?  16'h001F :  16'hF800);

endmodule
