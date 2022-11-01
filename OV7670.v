module OV7670(
	//General
	input rst_n,
	input write,
	//VGA I/O
	input VGA_active, 							// Active flag to indicate when the screen area is active
	input VGA_pixel_tick,						// Signal coming from the VGA generator when the pixel position is ready to be displayed
	input [9:0] data_vpos, data_hpos,			// data position to decide read address for buffer port B
	output reg[7:0] pixel_data_R, pixel_data_G, pixel_data_B,	//VGA colors' channel
	//Camera I/O
	input cam_vsync, cam_href,					//Cameera vertical and horizontal synchronization signals
	input [7:0] cam_data_wires,				//Camera data wires (d0-d7)
	input cam_pclk,								//Camera's clock that generated from the camera to indicate that pixel is ready to be sent
	output cam_xclk,								//Clock 25 MHz generated from PLL to be connected to Camera system clock pin
	output cmos_scl,								//Clock for SCCB interface
	inout cmos_sda,								//Data for SCCB interface
	
	//Debug
	output [5:0] led_d,
	
	//Clocks
	input clk_50									//Clock 50 MHz input from the board itself
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
	
	//---------------------------Buffer---------------------------
	// The interface for Buffer module
	reg [15:0]data_buffer_in_a = 0;		//Input data for the port A
	reg [15:0] write_addr = 0;			// Address of port A for writing
	reg [15:0] read_addr = 0;			// Address of port B for reading
	reg write_en_a = 0;						// Writing enable flag for port A
	wire error_write_a;						// Writing error flag for port A
	wire [15:0] outp_b;							// Output data from the port B
	
	wire r_done;							// Flag for reading sequence is done
	reg read_ready = 0;					// Flag for reading sequence start
	//-----------------------------------------------------------------------------------------------------

	
	wire [3:0] led_sccb;

	assign led_d[0] = write;
	assign led_d[1] = VGA_active;
	assign led_d[5:2] = led_sccb;
	
	wire clk_24;
	wire clk_25;
	
	assign cam_xclk = clk_24;
	
	clock_25 n1 (.inclk0(clk_50), .c0(clk_25));		// Instance of pll module
	clk24 n2 (.inclk0(clk_50), .c0(clk_24));
	
	// This block recieve the pixel's color values in RGB565 format and store it in Buffer port A
	always @(posedge cam_pixel_valid or posedge cam_frame_done) 
	begin
	
		if(cam_frame_done) begin
			pixel_cam_counterh <= 10'd0;
			pixel_cam_counterv <= 9'd0;
		end
		
		// This is to check the button to stop the real-time at specific frame or to display the static image
		else if(write == 1)
		begin				
			data_buffer_in_a <= cam_pixel_data;

			// Check if the current pixel in the needed portion of the image or not (256x256)
			if(pixel_cam_counterv < 9'd256 && pixel_cam_counterh < 10'd256 )
			begin
				// Start writing to the buffer port A
				write_en_a <= 1'b1;									// Set the Enable to write on the buffer
				write_addr <= {pixel_cam_counterv[7:0], pixel_cam_counterh[7:0]};
			end
			else write_en_a <= 1'b0;
			
			// Increase the Vertical and Horizontal counter by one and check their limits
			if(pixel_cam_counterh == 10'd639)begin
				pixel_cam_counterh <= 10'd0;
				if(pixel_cam_counterv == 9'd480)	pixel_cam_counterv <= 9'd0;
				else pixel_cam_counterv <= pixel_cam_counterv + 9'd1;
			end
			else pixel_cam_counterh <= pixel_cam_counterh + 10'd1;
		end
	end
	
	// This block is activated at the positive edge of pixel_tick signal from VGA (25MHz)
	// This block is responsible to output the pixel on the monitor
	always @(posedge VGA_pixel_tick) begin
		// Check if the monitor is active and ready to display the pixel or not
		if (! VGA_active)
		begin
			pixel_data_R <= 8'd0;
			pixel_data_G <= 8'd0;
			pixel_data_B <= 8'd0;
			end
		else begin
			if(cam_frame_done) begin
				read_ready <= 1'b1;
			end
			else if(r_done) begin
				read_ready <= 1'b0;
			end
			
			// Check if the pixel that is displayed in the available portion of the storage or not
			if(data_vpos < 10'd256 && data_hpos < 10'd256)
			begin	
				read_addr <= {data_vpos[7:0], data_hpos[7:0]};
				
				// Set the value of displayed pixel; 
				pixel_data_R <= {outp_b[15:11],3'd0};
				pixel_data_G <= {outp_b[10:5],2'd0};
				pixel_data_B <= {outp_b[4:0],3'd0};
				
			end
			else
			begin
				//if it is not in our portion of memory it will be gray
				pixel_data_R <= 8'd70;
				pixel_data_G <= 8'd70;
				pixel_data_B <= 8'd70;
			end	
		end
	end
	
	
	Camera c1(						// Instance of Camera module
	.clock(cam_pclk),
	.vsync(cam_vsync),
	.href(cam_href),
	.data_wires(cam_data_wires),
	.p_valid(cam_pixel_valid),
	.p_data(cam_pixel_data),
	.f_done(cam_frame_done)
   );
	
	camera_interface i1( 		// Instance of Camera register setting module
	.clk(clk_25),
	.rst_n(rst_n),
	//camera pinouts
	.cmos_sda(cmos_sda),
	.cmos_scl(cmos_scl), 
	.cmos_pwdn(pwdn),
	.cmos_rst_n(rst),
	//Debugging
	.led(led_sccb)
    );
	
	Buffer b1(						// Instance of Buffer module
	.d_in_a(data_buffer_in_a),
	.r_addr(read_addr),
	.w_addr(write_addr),
	.w_clk(clk_50),
	.r_clk(VGA_pixel_tick),
	.w_en_a(write_en_a),
	.r_rd(read_ready),
	.d_out_b(outp_b),
	.err_w_a(error_write_a),
	.r_done(r_done),
//	.led_d(led_b)
	);
	
endmodule
