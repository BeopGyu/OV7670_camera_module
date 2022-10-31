module Edge_detection_project(
	//General
	input button,									//Button input to select showing the static image or the real-time video
	input rst_n,
	//VGA I/O
	output [7:0] VGA_red, VGA_green, VGA_blue,	//VGA colors' channel		
	output VGA_hsync, VGA_vsync,				//VGA vertical and horziontal synchronization signals
	output VGA_clk, VGA_sync, VGA_blank,
	//Camera I/O
	input cam_clock,								//(pixel clk pin) Camera's clock that generated from the camera to indicate that pixel is ready to be sent
	input cam_vsync, cam_href,					//Cameera vertical and horizontal synchronization signals
	input [7:0] cam_data_wires,				//Camera data wires (d0-d7)
	output cmos_scl,
	inout cmos_sda,
	//Clocks
	input clk_50,									//Clock 50 MHz input from the board itself
	output cam_xclk,									//Clock 25 MHz generated from PLL to be connected to Camera system clock pin
	
	output [5:0] ledG,
	
	output rst, pwdn
	);

	
	//---------------------------VGA---------------------------
	// Interface for VGA module
	wire	[9:0]	VGA_hpos, VGA_vpos;				// Current pixel position
	wire 			VGA_active;					// Active flag to indicate when the screen area is active
	wire			VGA_pixel_tick;				// Signal coming from the VGA generator when the pixel position is ready to be displayed
	wire	[7:0]	pixel_VGA_R;			// Current pixel's RGB value
	wire	[7:0]	pixel_VGA_G;
	wire	[7:0]	pixel_VGA_B;
	
	//-----------------------------------------------------------------------------------------------------
	
	wire clk_24;
	wire clk_25;
	
	assign rst = 1'b1;
	assign pwdn = 1'b0;
	
	assign VGA_clk = clk_25;
	assign VGA_sync = VGA_hsync & VGA_vsync;
	assign VGA_blank = VGA_active;
	
	clock_25 n1 (.inclk0(clk_50), .c0(clk_25));		// Instance of pll module
	
	OV7670(
		.rst_n(rst_n),
		.write(button),
		//VGA I/O
		.VGA_active(VGA_active),
		.VGA_pixel_tick(VGA_pixel_tick),
		.data_vpos(VGA_vpos),
		.data_hpos(VGA_hpos),
		.pixel_data_R(pixel_VGA_R),
		.pixel_data_G(pixel_VGA_G),
		.pixel_data_B(pixel_VGA_B),
		//Camera I/O
		.cam_vsync(cam_vsync),
		.cam_href(cam_href),
		.cam_data_wires(cam_data_wires),
		.cam_pclk(cam_clock),
		.cam_xclk(cam_xclk),
		.cmos_scl(cmos_scl),
		.cmos_sda(cmos_sda),
		
		.led_d(ledG),
		
		//Clocks
		.clk_50(clk_50)
	
	);
	
	VGA v1(							// Instance of VGA module
		.clk(clk_50),
		.pixel_r(pixel_VGA_R),
		.pixel_g(pixel_VGA_G),
		.pixel_b(pixel_VGA_B),
		.hsync(VGA_hsync),
		.vsync(VGA_vsync),
		.red(VGA_red),
		.green(VGA_green),
		.blue(VGA_blue),
		.active(VGA_active),
		.ptick(VGA_pixel_tick),
		.xpos(VGA_hpos),
		.ypos(VGA_vpos),
	);
	
	
endmodule
