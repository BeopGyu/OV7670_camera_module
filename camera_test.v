module camera_test(
	clk50,
	OV7670_SIOC,
	OV7670_SIOD,
	OV7670_RESET,
	OV7670_PWDN,
	OV7670_VSYNC,
	OV7670_HREF,
	OV7670_PCLK,
	OV7670_XCLK,
	OV7670_D,
	vga_red,
	vga_green,
	vga_blue,
	vga_hsync,
	vga_vsync,
	vga_clk,
	BLANK,
	SYNC,
	rst,
	btn,
	led_test1,
	led_test2
	
	);
	
//	output [7:0] LED, 
	output [7:0] vga_red;
	output [7:0] vga_green;
	output [7:0] vga_blue;
	output vga_hsync;
	output vga_vsync;
	output vga_clk;

	input clk50;
	output OV7670_SIOC;
	inout OV7670_SIOD;
	output OV7670_RESET;
	output OV7670_PWDN;
	input OV7670_VSYNC;
	input OV7670_HREF;
	input OV7670_PCLK;
	output OV7670_XCLK;
	input [7:0] OV7670_D;
	input rst;
	input btn;
	
	output BLANK, SYNC;
	
	output led_test1;
	output led_test2;
	
	
   wire clk25;
	wire clk148_5;
	
	wire [18:0] frame_addr;
   wire [11:0] frame_pixel;
   wire [18:0] capture_addr;
   wire [11:0] capture_data;
   wire capture_we;
   wire resend;
   wire config_finished;
	
	wire [11:0] HCNT, VCNT;
	wire HBLANK, VBLANK;
	wire BLANK, SYNC;
	wire HSYNC, VSYNC;
	
	wire vga_vsync_m;
	wire vga_hsync_m;
	wire vga_red_t;
	wire vga_green_t;
	wire vga_blue_t;
	
	sclk sclk(.inclk0(clk50), .c0(clk25));
	sccb_clk sccbclk(.inclk0(clk50), .c0(clk400k));		//400KHz
	clk_PatGen patclk(.inclk0(clk50), .c0(clk148_5)); // 148.5MHz
// debounce db1(.clk(clk50),.i(btn),.o(resend));
// ov7670_controller_verilog con(.clk(clk50),.sioc(OV7670_SIOC),.resend(resend),.config_finished(config_finished),.siod(OV7670_SIOD),.pwdn(OV7670_PWDN),.reset(OV7670_RESET),.xclk(OV7670_XCLK));
	debounce db1(.clk(clk50),.i(btn),.o(resend));
	CNT_BLANK_SYNC blank_sync (.clk(clk148_5), .reset(rst), .HCNT(HCNT), .VCNT(VCNT), .BLANK(BLANK), .SYNC(SYNC), .HSYNC(HSYNC), .VSYNC(VSYNC));
   vga vg1(.clk25(clk25),.vga_red(vga_red_t),.vga_green(vga_green_t),.vga_blue(vga_blue_t),.vga_hsync(vga_hsync_m),.vga_vsync(vga_vsync_m),.frame_addr(frame_addr),.frame_pixel(frame_pixel));
   frame_buffer fb1(.clka(OV7670_PCLK),.wea(capture_we),.addra(capture_addr),.dina(capture_data),.clkb(clk50),.addrb(frame_addr),.doutb(frame_pixel));
   ov7670_capture_verilog cap1(.pclk(OV7670_PCLK),.vsync(OV7670_VSYNC),.href(OV7670_HREF),.d(OV7670_D),.addr(capture_addr),.dout(capture_data),.we(capture_we));
   ov7670_controller_verilog con1(.clk(clk50),.sioc(OV7670_SIOC),.resend(resend),.config_finished(config_finished),.siod(OV7670_SIOD),.pwdn(OV7670_PWDN),.reset(OV7670_RESET),.xclk(OV7670_XCLK));
    
assign led_test1 = resend;
//assign led_test2 = config_finished;
assign vga_clk = clk148_5;

assign vga_red = {vga_red_t,4'd0};
assign vga_green = {vga_green_t,4'd0};
assign vga_blue = {vga_blue_t,4'd0};

assign vga_hsync = HSYNC;//vga_hsync_m
assign vga_vsync = VSYNC;//vga_vsync_m

endmodule

