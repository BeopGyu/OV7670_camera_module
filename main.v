module Edge_detection_project(
	//General
	input button,									//Button input to select showing the static image or the real-time video
	input rst_n,
	output [3:0] led_d,
	output [1:0] led_err,
	output [6:0] seg_100, seg_10, seg_1,
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
	output clk_25,									//Clock 25 MHz generated from PLL to be connected to Camera system clock pin
	//Debug
	output [3:0] ledt,
	output [5:0] ledG
	);

	//-------------------------CAMERA--------------------------------
	//Interface for Camera module
	wire cam_pixel_valid;						//Pixel valid flag to indicate that the camra sent a pixel
	wire [15:0] cam_pixel_data;				//Pixel data lines' values
	wire cam_frame_done;						//frame done flage to indicate that the whole frame has finished
	//--------------------------
	reg[8:0] pixel_cam_counterv;		//y-position of the recieved pixel  
	reg[9:0] pixel_cam_counterh;		//x-position of the recieved pixel
	//-----------------------------------------------------------------------------------------------------

	//-------------------------Grayscale converter-----------------------------------
	reg[7:0] gray_value;					//Register 8-bits to store the grayscale value
	reg[4:0] red_channel_gray; 		//Temporary register to store red bits of the camera to be used in the grayscale converter
	reg[5:0] green_channel_gray; 		//Temporary register to store green bits of the camera to be used in the grayscale converter
	reg[4:0] blue_channel_gray;		//Temporary register to store blue bits of the camera to be used in the grayscale converter
	//-----------------------------------------------------------------------------------------------------
	
	//---------------------------Buffer---------------------------
	// The interface for Buffer module
	// Buffer port A 150x150x8: Used to store the grayscale frames
	reg [15:0]data_buffer_in_a = 0;		//Input data for the port A
	reg [14:0] read_addr_a = 0;			// Address of port A for reading
	reg [14:0] write_addr_a = 0;			// Address of port A for writing
	reg write_en_a = 0;						// Writing enable flag for port A
	wire [15:0]outp_a;							// Output data from the port A (8-bits)
	wire error_write_a;						// Writing error flag for port A
	
	// Buffer port B 150x150x1: Used to store the values results from Sobel operator and threshold
	// The data in port B is the final data to be displayed on the monitor
	reg data_buffer_in_b = 0;				// Input data for the port B
	reg [14:0] read_addr_b = 0;			// Address of port B for reading
	reg [14:0] write_addr_b =0 ;			// Address of port B for writing
	reg write_en_b = 0;						// Writing enable flag for port B
	wire outp_b;								// Output data from the port B (1-bit)
	wire error_write_b;						// Writing error flag for port B
	//-----------------------------------------------------------------------------------------------------
	
	
	//------------------------Sobel------------------------------------
	//Interface for core_sobel module
	reg[7:0] p_sobel [8:0];					//Pixels' values to be used in core_sobel module
	wire[7:0] out_sobel;						//Output result pixel's value
	//--------------------------
	reg[7:0] i_sobel = 0;					//Rows counter to iterate over the frame
	reg[7:0] j_sobel = 0;					//Columns counter to iterate over the frame
	reg[3:0] counter_sobel = 0;			//Counter for pixels to take 3x3 pixels kernel
	reg[14:0] target_sobel_addr = 0;		//target pixel address to store in it the sobel result which will be always in the middle
	//-----------------------------------------------------------------------------------------------------
	
	//---------------------------VGA---------------------------
	// Interface for VGA module
	wire	[9:0]	VGA_hpos, VGA_vpos;				// Current pixel position
	wire 			VGA_active;					// Active flag to indicate when the screen area is active
	wire			VGA_pixel_tick;				// Signal coming from the VGA generator when the pixel position is ready to be displayed
	reg	[7:0]	pixel_VGA_R;			// Current pixel's RGB value
	reg	[7:0]	pixel_VGA_G;
	reg	[7:0]	pixel_VGA_B;
	reg 			ck = 1;
	//-----------------------------------------------------------------------------------------------------
	
	reg [2:0] led_test;
	
	assign ledt[0] = button;
	assign ledG = pixel_VGA_G[7:2];
	assign VGA_clk = clk_25;
	assign VGA_sync = VGA_hsync & VGA_vsync;
	assign VGA_blank = VGA_active;
	
	reg [20:0] cnt;
	always@(posedge cam_clock)
	begin
		cnt <= cnt + 21'd1;
	end
	assign ledt[1] = cnt[20];
	
	
	reg [20:0] cnt2;
	always@(posedge clk_25)
	begin
		cnt2 <= cnt2 + 21'd1;
	end
	assign ledt[2] = cnt2[20];
	
	assign led_err[0] = write_en_a ? error_write_a : 1'b0;
	assign led_err[1] = write_en_b ? error_write_b : 1'b0;
	
	
	wire [3:0] S100, S10, S1;
	
	assign S1 = pixel_cam_counterv % 10;
	assign S10 = (pixel_cam_counterv / 10)%10;
	assign S100 = pixel_cam_counterv / 100;
	
	Seg7 Seg100(.num(S100), .seg(seg_100));
	Seg7 Seg10(.num(S10), .seg(seg_10));
	Seg7 Seg1(.num(S1), .seg(seg_1));
	
	
	clock_25(.inclk0(clk_50), .c0(clk_25));		// Instance of pll module

		
	Camera(						// Instance of Camera module
	.clock(cam_clock),
	.vsync(cam_vsync),
	.href(cam_href),
	.data_wires(cam_data_wires),
	.p_valid(cam_pixel_valid),
	.p_data(cam_pixel_data),
	.f_done(cam_frame_done)
   );
	
	
	camera_interface m0 //control logic for retrieving data from camera, storing data to asyn_fifo, and  sending data to sdram
	(
		.clk(clk_25),
		.rst_n(rst_n),
		//camera pinouts
		.cmos_sda(cmos_sda),
		.cmos_scl(cmos_scl), 
		//Debugging
		.led(led_d)
    );
	
	Buffer(						// Instance of Buffer module
	.d_in_a(data_buffer_in_a),
	.r_addr_a(read_addr_a),
	.w_addr_a(write_addr_a),
	.d_in_b(data_buffer_in_b),
	.r_addr_b(read_addr_b),
	.w_addr_b(write_addr_b),
	.w_clk(clk_25),
	.r_clk(clk_50),
	.w_en_a(write_en_a),
	.d_out_a(outp_a),
	.err_w_a(error_write_a),
	.w_en_b(write_en_b),
	.d_out_b(outp_b),
	.err_w_b(error_write_b)
	);
	
	
	VGA(							// Instance of VGA module
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
	
	
	// This block is activated at the positive edge of pixel_valid signal which means that pixel from the camera is ready
	// This block recieve the pixel's color values in RGB565 format and convert it to grayscale then store it in Buffer port A
	always @(posedge cam_pixel_valid) 
	begin
		// This is to check the button to stop the real-time at specific frame or to display the static image in the begining
		if(button == 1)
		begin
			red_channel_gray 	<=	cam_pixel_data[7:3];			// Store the red bits (first 5-bits) in temp register
			green_channel_gray <= {cam_pixel_data[2:0],cam_pixel_data[15:13]};			// Store the green bits (second 6-bits) in temp register
			blue_channel_gray <= cam_pixel_data[12:8];			// Store the blue bits (third 5-bits) in temp register
			// 8-bits gray scale converter from RGB5565 format
			gray_value <= (red_channel_gray >> 2) + (red_channel_gray >> 5)+ (green_channel_gray >> 4) + (green_channel_gray >> 1) + (blue_channel_gray >> 4) + (blue_channel_gray >> 5);
			
//			data_buffer_in_a <= 16'd0;					
			data_buffer_in_a <= cam_pixel_data;

			// Check if the current pixel in the needed portion of the image or not (150x150)
			if(pixel_cam_counterv < 'd150 && pixel_cam_counterh < 'd150 )
			begin
				// Start writing to the buffer port A
				write_en_a <= 1;									// Set the Enable to write on the buffer
				write_addr_a <= pixel_cam_counterv * 'd150 +pixel_cam_counterh;	// Set the address of the pixel in the buffer
			end
			else write_en_a <= 0;
			// Increase the Vertical and Horizontal counter by one and check their limits
			pixel_cam_counterv<= ((pixel_cam_counterh == 'd639)?((pixel_cam_counterv+'d1)%'d480):pixel_cam_counterv);		
			pixel_cam_counterh<= (pixel_cam_counterh+'d1)%'d640;
		end
	end
	
	// This block is activated at the positive edge of pixel_tick signal from VGA module which means that a pixel is ready to be displayed
	// This block is responsible to output the pixel on the monitor
	always @(posedge VGA_pixel_tick) begin
		// Check if the monitor is active and ready to display the pixel or not
		if (! VGA_active)
		begin
			pixel_VGA_R <= 8'd0;
			pixel_VGA_G <= 8'd0;
			pixel_VGA_B <= 8'd0;
			end
		else begin
			// Check if the pixel that is displayed in the available portion of the storage or not
			if(VGA_vpos < 'd150 && VGA_hpos < 'd150)
			begin	
				read_addr_a = (VGA_vpos[7:0])* 'd150 +(VGA_hpos[7:0]);
				// Set the value of displayed pixe; if the value is one it will display white
//				pixel_VGA_R <= {outp_a[4:0],3'd0};
//				pixel_VGA_G <= {outp_a[10:5],2'd0};
//				pixel_VGA_B <= {outp_a[15:11],3'd0};
				pixel_VGA_R <= {outp_a[7:3],3'd0};
				pixel_VGA_G <= {outp_a[2:0],outp_a[15:13],2'd0};
				pixel_VGA_B <= {outp_a[12:8],3'd0};
				
			end
			else
				begin
					pixel_VGA_R <= 8'd70;
					pixel_VGA_G <= 8'd70;
					pixel_VGA_B <= 8'd70;
				end
				//pixel_VGA_RGB <= 8'd0;				//if it is not in our portion of memory it will be black
		end
	end
	
endmodule
