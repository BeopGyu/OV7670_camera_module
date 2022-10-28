module Seg7(num ,seg);
input [3:0] num;
output [6:0] seg;

wire [3:0] num;
reg [6:0] seg;

always @(num)
begin
	case(num)
	/*
		//active_high
		4'd0 : seg <= 7'b011_1111;
		4'd1 : seg <= 7'b000_0110;
		4'd2 : seg <= 7'b101_1011;
		4'd3 : seg <= 7'b100_1111;
		4'd4 : seg <= 7'b110_0110;
		4'd5 : seg <= 7'b110_1101;
		4'd6 : seg <= 7'b111_1101;
		4'd7 : seg <= 7'b010_0111;
		4'd8 : seg <= 7'b111_1111;
		4'd9 : seg <= 7'b110_1111;
		4'd10 : seg <= 7'b111_0111;
		4'd11 : seg <= 7'b111_1100;
		4'd12 : seg <= 7'b101_1000;
		4'd13 : seg <= 7'b101_1110;
		4'd14 : seg <= 7'b111_1001;
		4'd15 : seg <= 7'b111_0001;
		*/
		//active_low
		4'd0 : seg <= 7'b100_0000;
		4'd1 : seg <= 7'b111_1001;
		4'd2 : seg <= 7'b010_0100;
		4'd3 : seg <= 7'b011_0000;
		4'd4 : seg <= 7'b001_1001;
		4'd5 : seg <= 7'b001_0010;
		4'd6 : seg <= 7'b000_0010;
		4'd7 : seg <= 7'b101_1000;
		4'd8 : seg <= 7'b000_0000;
		4'd9 : seg <= 7'b001_0000;
		4'd10 : seg <= 7'b000_1000;
		4'd11 : seg <= 7'b000_0011;
		4'd12 : seg <= 7'b010_0111;
		4'd13 : seg <= 7'b010_0001;
		4'd14 : seg <= 7'b000_0110;
		4'd15 : seg <= 7'b000_1110;
		
	endcase
end
endmodule