`timescale 1ns / 1ps

   module camera_test(
	input wire clk,rst_n,
	input wire[3:0] key, //key[1:0] for brightness control , key[3:2] for contrast control
	//camera pinouts
	input wire cmos_pclk,cmos_href,cmos_vsync,
	input wire[7:0] cmos_db,
	inout cmos_sda,cmos_scl, 
	output wire cmos_rst_n, cmos_pwdn, cmos_xclk,
	//Debugging
	output[3:0] ledt,
	output ledtt,
	//controller to sdram
	output wire sdram_clk,
	output wire sdram_cke, 
	output wire sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n, 
	output wire[12:0] sdram_addr,
	output wire[1:0] sdram_ba, 
	output wire[1:0] sdram_dqm, 
	inout[15:0] sdram_dq,
	//VGA output
	output wire[7:0] vga_out_r,
	output wire[7:0] vga_out_g,
	output wire[7:0] vga_out_b,
	output wire vga_out_vs,vga_out_hs,vga_out_bl,vga_out_sy,clk_out
    );
	 
	 wire f2s_data_valid;
	 wire[9:0] data_count_r;
	 wire[15:0] dout,din;
	 wire clk_sdram;
	 wire clk_100;
	 wire empty_fifo;
	 wire clk_vga;
	 wire state;
	 wire rd_en;
	 wire [4:0] tr,tb;
	 wire [5:0] tg;
	 assign sdram_clk = clk_sdram;
	 assign ledtt = vga_out_r[3];
//	 assign vga_out_r = {3'b0,tr};		
//	 assign vga_out_g = {2'b0,tg};
//	 assign vga_out_b = {3'b0,tb};
	 assign vga_out_r = {tr,3'b0};		
	 assign vga_out_g = {tg,2'b0};
	 assign vga_out_b = {tb,3'b0};	
	 
	camera_interface m0 //control logic for retrieving data from camera, storing data to asyn_fifo, and  sending data to sdram
	(
		.clk(clk_out),
		.clk_100(clk_sdram),
		.rst_n(rst_n),
		.key(key),
		//asyn_fifo IO
		.rd_en(f2s_data_valid),
		.data_count_r(data_count_r),
		.dout(dout),
		//camera pinouts
		.cmos_pclk(cmos_pclk),
		.cmos_href(cmos_href),
		.cmos_vsync(cmos_vsync),
		.cmos_db(cmos_db),
		.cmos_sda(cmos_sda),
		.cmos_scl(cmos_scl), 
		.cmos_rst_n(cmos_rst_n),
		.cmos_pwdn(cmos_pwdn),
		.cmos_xclk(cmos_xclk),
		//Debugging
		.led(ledt)
    );
	 
	 sdram_interface m1 //control logic for writing the pixel-data from camera to sdram and reading pixel-data from sdram to vga
	 (
		.clk(clk_sdram),
		.rst_n(rst_n),
		//asyn_fifo IO
		.clk_vga(clk_vga),
		.rd_en(rd_en),
		.data_count_r(data_count_r),
		.f2s_data(dout),
		.f2s_data_valid(f2s_data_valid),
		.empty_fifo(empty_fifo),
		.dout(din),
		//controller to sdram
		.sdram_cke(sdram_cke), 
		.sdram_cs_n(sdram_cs_n),
		.sdram_ras_n(sdram_ras_n),
		.sdram_cas_n(sdram_cas_n),
		.sdram_we_n(sdram_we_n), 
		.sdram_addr(sdram_addr),
		.sdram_ba(sdram_ba), 
		.sdram_dqm(sdram_dqm),
		.sdram_dq(sdram_dq)
    );
	 
	 vga_interface m2 //control logic for retrieving data from sdram, storing data to asyn_fifo, and sending data to vga
	 (
		.clk(clk),
		.rst_n(rst_n),
		//asyn_fifo IO
		.empty_fifo(empty_fifo),
		.din(din),
		.clk_vga(clk_vga),
		.rd_en(rd_en),
		//VGA output
		.vga_out_r(tr),
		.vga_out_g(tg),
		.vga_out_b(tb),
		.vga_out_vs(vga_out_vs),
		.vga_out_hs(vga_out_hs),
		.vga_out_bl(vga_out_bl),
		.vga_out_sy(vga_out_sy)
    );
	 
	
	//SDRAM clock
	dcm_165MHz m3
   (// Clock in ports
    .inclk0(clk),      // IN
    // Clock out ports
    .c0(clk_sdram),     // OUT
    // Status and control signals
		);      // OUT
	dcm_25MHz m4 //clock for vga(620x480 60fps) 
   (// Clock in ports
    .inclk0(clk),      // IN
    // Clock out ports
    .c0(clk_out),     // OUT
    // Status and control signals
    );   
	 
	 clk_100MHz m5
	 (
	  .inclk0(clk),
	  .c0(clk_100)
	  );


endmodule
