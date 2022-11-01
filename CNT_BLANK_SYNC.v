module CNT_BLANK_SYNC(clk, reset, HCNT, VCNT,
 BLANK, SYNC, HSYNC, VSYNC);

parameter sync_h = 12'd44; 
parameter fp_h = 12'd88; 			//화면이 좌상단으로 밀려서 fp 조정
parameter active_h = 12'd1920;
parameter total_h = 12'd2200;
parameter sync_v = 11'd5; 
parameter fp_v = 11'd4; 			//화면이 좌상단으로 밀려서 fp 조정
parameter active_v = 11'd1080;
parameter total_v = 11'd1125;

/*parameter sync_h = 12'd4; 
parameter fp_h = 12'd14;
parameter active_h = 12'd190;
parameter total_h = 12'd220;
parameter sync_v = 11'd2; 
parameter fp_v = 11'd3;
parameter active_v = 11'd108;
parameter total_v = 11'd120;*/

input clk, reset;
output [11:0] HCNT, VCNT;
output BLANK, SYNC;
output HSYNC, VSYNC;

wire clk, reset;
reg [11:0] HCNT, VCNT;
reg HBLANK, HSYNC, VBLANK, VSYNC;
wire BLANK, SYNC;

always @(posedge clk or negedge reset)
begin
	if(reset == 1'b0)
	begin
		HCNT <= 12'd0;
		VCNT <= 12'd0;
	end
	else
	begin
		if(HCNT >= total_h)
		begin
			HCNT <= 12'd0;
			VCNT <= VCNT + 12'd1;
			if(VCNT >= total_v)
				VCNT <= 12'd0;
		end
		else
			HCNT <= HCNT + 12'd1;
	end
end

always @(posedge clk or negedge reset)
begin
	if(reset == 1'b0)
	begin
		HBLANK <= 1'b0;
		HSYNC <= 1'b1;
		VBLANK <= 1'b0;
		VSYNC <= 1'b1;
	end
	else
	begin
		if((HCNT < active_h - 1) || (HCNT == total_h))
			HBLANK <= 1'b1;
		else //if(HCNT >= active_h - 1)
			HBLANK <= 1'b0;

		if((HCNT < (active_h + fp_h - 1)) || (HCNT >= (active_h + fp_h + sync_h - 1)))
			HSYNC <= 1'b1;
		else //if(HCNT >= (active_h + fp_h + sync_h - 1))
			HSYNC <= 1'b0;

		if(VCNT < active_v - 1)
			VBLANK <= 1'b1;
		if(HCNT == total_h)
		begin
			if(VCNT == total_v)// || (VCNT < active_v))
				VBLANK <= 1'b1;
			else if(VCNT >= active_v - 1)
				VBLANK <= 1'b0;

			if((VCNT >= (active_v + fp_v + sync_v) - 1) || (VCNT < (active_v + fp_v) - 1))
				VSYNC <= 1'b1;
			else //if(VCNT >= (active_v + fp_v) - 1)
				VSYNC <= 1'b0;
		end
	end
end

assign BLANK = HBLANK & VBLANK;
assign SYNC = HSYNC & VSYNC;

endmodule