module RGB(clk, reset, mode, HCNT, VCNT, R, G, B);

parameter sync_h = 12'd44; 
parameter fp_h = 12'd91; 			//화면이 좌상단으로 밀려서 fp 조정
parameter active_h = 12'd1920;
parameter total_h = 12'd2200;
parameter sync_v = 11'd5; 
parameter fp_v = 11'd6; 			//화면이 좌상단으로 밀려서 fp 조정
parameter active_v = 11'd1080;
parameter total_v = 11'd1125;

//parameter p1_h_int = active_h >> 8;
//parameter p1_v_int = active_v / 4;
//parameter p2_h_int = active_h / 5;
//parameter p2_v_int = active_v / 5;
//parameter p3_h_int = active_h / 7;

input clk, reset;
input [1:0] mode;
input [11:0] HCNT, VCNT;
output [7:0] R, G, B;

wire clk, reset;
wire [1:0] mode;
wire [11:0] HCNT, VCNT;
reg [7:0] R, G, B;

always @(posedge clk or negedge reset)
begin
	if(reset == 1'b0)
	begin
		R <= 7'd0;
		G <= 7'd0;
		B <= 7'd0;
	end
	else
	begin
		if(mode == 2'b00)
		begin
			if(HCNT < fp_h + active_h)
			begin
				if(HCNT[2:0] == 4'b000)
				begin
					if(VCNT[9:8] == 2'b00)
					begin
						R <= R + 8'd1;
						G <= G + 8'd1;
						B <= B + 8'd1;						
					end
					else if(VCNT[9:8] == 2'b01)
					begin
						R <= R + 8'd1;
						G <= 8'd0;
						B <= 8'd0;
					end
					else if(VCNT[9:8] == 2'b10)
					begin
						G <= G + 8'd1;
						R <= 8'd0;
						B <= 8'd0;
					end
					else if(VCNT[9:8] == 2'b11)
					begin
						B <= B + 8'd1;
						R <= 8'd0;
						G <= 8'd0;
					end
				end
			end
			else
			begin
				R <= 8'd0;
				G <= 8'd0;
				B <= 8'd0;
			end
		end
		if(mode == 2'b01)
		begin
			if(HCNT[9] == 1'b0)
			begin
				if(VCNT[8] == 1'b0)
				begin
					R <= 8'd255;
					G <= 8'd255;
					B <= 8'd255;
				end
				else
				begin
					R <= 8'd0;
					G <= 8'd0;
					B <= 8'd0;
				end
			end
			else
			begin
				if(VCNT[8] == 1'b0)
				begin
					R <= 8'd0;
					G <= 8'd0;
					B <= 8'd0;
				end
				else
				begin
					R <= 8'd255;
					G <= 8'd255;
					B <= 8'd255;
				end
			end
		end
		if(mode == 2'b10)
		begin
			if(HCNT[10:8] == 3'b000)
			begin
				R <= 8'd255;
				G <= 8'd0;
				B <= 8'd0;
			end
			else if(HCNT[10:8] == 3'b001)
			begin
				R <= 8'd0;
				G <= 8'd255;
				B <= 8'd0;
			end
			else if(HCNT[10:8] == 3'b010)
			begin
				R <= 8'd0;
				G <= 8'd0;
				B <= 8'd255;
			end
			else if(HCNT[10:8] == 3'b011)
			begin
				R <= 8'd255;
				G <= 8'd255;
				B <= 8'd0;
			end
			else if(HCNT[10:8] == 3'b100)
			begin
				R <= 8'd255;
				G <= 8'd0;
				B <= 8'd255;
			end
			else if(HCNT[10:8] == 3'b101)
			begin
				R <= 8'd0;
				G <= 8'd255;
				B <= 8'd255;
			end
			else// if(HCNT[11:9] == 3'b110)
			begin
				R <= 8'd255;
				G <= 8'd255;
				B <= 8'd255;
			end
		end
		if(mode == 2'b11)
		begin
			if((HCNT == 12'd0 || HCNT == 12'd1) || (HCNT == 12'd1919 || HCNT == 12'd1918) 
			|| (VCNT == 12'd0 || VCNT == 12'd1) || (VCNT == 12'd1079 || VCNT == 12'd1078))
			//if((HCNT == fp_h) || (HCNT == 12'd1919 + fp_h) || (VCNT == fp_v) || (VCNT == 12'd 1079 + fp_v))
			begin
				R <= 8'd255;
				G <= 8'd255;
				B <= 8'd255;
			end
			else
			begin
				R <= 8'd0;
				G <= 8'd0;
				B <= 8'd0;
			end
			
		/*
			if(VCNT[9:7] == 3'b000)
			begin
				R <= 8'd255;
				G <= 8'd0;
				B <= 8'd0;
			end
			else if(VCNT[9:7] == 3'b001)
			begin
				R <= 8'd0;
				G <= 8'd255;
				B <= 8'd0;
			end
			else if(VCNT[9:7] == 3'b010)
			begin
				R <= 8'd0;
				G <= 8'd0;
				B <= 8'd255;
			end
			else if(VCNT[9:7] == 3'b011)
			begin
				R <= 8'd255;
				G <= 8'd255;
				B <= 8'd0;
			end
			else if(VCNT[9:7] == 3'b100)
			begin
				R <= 8'd255;
				G <= 8'd0;
				B <= 8'd255;
			end
			else if(VCNT[9:7] == 3'b101)
			begin
				R <= 8'd0;
				G <= 8'd255;
				B <= 8'd255;
			end
			else if(VCNT[9:7] == 3'b110)
			begin
				R <= 8'd0;
				G <= 8'd0;
				B <= 8'd0;
			end
			else
			begin
				R <= 8'd255;
				G <= 8'd255;
				B <= 8'd255;
			end
		*/
		end
	end
end
endmodule