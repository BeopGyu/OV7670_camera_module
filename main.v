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
	output cam_xclk,									//Clock 25 MHz generated from PLL to be connected to Camera system clock pin
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
	reg [15:0]data_buffer_in_a = 0;		//Input data for the port A
	reg [15:0] read_addr = 0;			// Address of port A for reading
	reg [15:0] write_addr = 0;			// Address of port A for writing
	reg write_en_a = 0;						// Writing enable flag for port A
	wire [15:0]outp_a;							// Output data from the port A (8-bits)
	wire error_write_a;						// Writing error flag for port A
	
	reg read_ready = 0;
	reg [15:0] read_count;
	//-----------------------------------------------------------------------------------------------------
	
	
	//---------------------------VGA---------------------------
	// Interface for VGA module
	wire	[9:0]	VGA_hpos, VGA_vpos;				// Current pixel position
	wire 			VGA_active;					// Active flag to indicate when the screen area is active
	wire			VGA_pixel_tick;				// Signal coming from the VGA generator when the pixel position is ready to be displayed
	reg	[7:0]	pixel_VGA_R;			// Current pixel's RGB value
	reg	[7:0]	pixel_VGA_G;
	reg	[7:0]	pixel_VGA_B;
	
	reg [15:0] pixel_data_hold[65535:0];
	//-----------------------------------------------------------------------------------------------------
	
	reg [2:0] led_test;
	wire clk_24;
	assign cam_xclk = clk_24;
	assign ledt[0] = button;
	assign ledG = pixel_VGA_G[7:2];
	assign VGA_clk = clk_25;
	assign VGA_sync = VGA_hsync & VGA_vsync;
	assign VGA_blank = VGA_active;
	
	reg [25:0] cnt;
	always@(posedge cam_clock)
	begin
		cnt <= cnt + 26'd1;
	end
	assign ledt[1] = cnt[25];
	
	
	reg [25:0] cnt2;
	always@(posedge cam_xclk)
	begin
		cnt2 <= cnt2 + 26'd1;
	end
	assign ledt[2] = cnt2[25];
	
	
	
	wire [3:0] S100, S10, S1;
	
	assign S1 = pixel_cam_counterv % 10;
	assign S10 = (pixel_cam_counterv / 10)%10;
	assign S100 = pixel_cam_counterv / 100;
	
	Seg7 Seg100(.num(S100), .seg(seg_100));
	Seg7 Seg10(.num(S10), .seg(seg_10));
	Seg7 Seg1(.num(S1), .seg(seg_1));
	
	
	clock_25 n1 (.inclk0(clk_50), .c0(clk_25));		// Instance of pll module
	clk24 n2 (.inclk0(clk_50), .c0(clk_24));
		
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
	.r_addr(read_addr),
	.w_addr(write_addr),
	.w_clk(clk_25),
	.r_clk(clk_50),
	.w_en_a(write_en_a),
	.d_out_a(outp_a),
	.err_w_a(error_write_a),
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
//			data_buffer_in_a <= 16'd0;					
			data_buffer_in_a <= cam_pixel_data;

			// Check if the current pixel in the needed portion of the image or not (256x256)
			if(pixel_cam_counterv < 'd256 && pixel_cam_counterh < 'd256 )
			begin
				// Start writing to the buffer port A
				if(!read_ready)	write_en_a <= 1'b1;									// Set the Enable to write on the buffer
				write_addr <= pixel_cam_counterh + pixel_cam_counterv << 8;
			end
			else write_en_a <= 1'b0;
			// Increase the Vertical and Horizontal counter by one and check their limits
			if(cam_frame_done) begin
				pixel_cam_counterh <= 10'd0;
				pixel_cam_counterv <= 9'd0;
				end
			else if(pixel_cam_counterh == 10'd639)begin
				pixel_cam_counterh <= 10'd0;
				if(pixel_cam_counterv == 9'd479)	pixel_cam_counterv <= 9'd0;
				else pixel_cam_counterv <= pixel_cam_counterv + 9'd1;
				end
				else pixel_cam_counterh <= pixel_cam_counterh + 10'd1;
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
			if(cam_frame_done) begin
				read_ready = 1'b1;
				read_count <= 16'd0;
			end
			
			// Check if the pixel that is displayed in the available portion of the storage or not
			if(VGA_vpos < 'd256 && VGA_hpos < 'd256)
			begin	
				read_addr = VGA_hpos[7:0] + VGA_vpos[7:0] << 8;
				
				if(read_ready) begin
					pixel_data_hold[read_addr] <= outp_a;
					read_count <= read_count + 16'd1;
					if(read_count == 16'd65535) begin
						read_ready <= 1'b0;
						read_count == 16'd0;
					end
				end
				// Set the value of displayed pixe; if the value is one it will display white
				pixel_VGA_R <= {pixel_data_hold[read_addr][7:3],3'd0};
				pixel_VGA_G <= {pixel_data_hold[read_addr][2:0],pixel_data_hold[read_addr][15:13],2'd0};
				pixel_VGA_B <= {pixel_data_hold[read_addr][12:8],3'd0};
				
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
