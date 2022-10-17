`timescale 1ns / 1ps

  module camera_interface(
	input wire clk,rst_n, //100MHz clk
	input start_camera, //flag for starting the camera
	//triggers to start camera saving
	input btn,
	input pir_sensor,sound_sensor, temp_sensor,
	//camera fifo IO
	input wire rd_en,
	output empty,
	output wire[7:0] dout,
	//camera pinouts
	input wire cmos_pclk,cmos_href,cmos_vsync,
	input wire[7:0] cmos_db,
	inout cmos_sda,cmos_scl, //i2c comm wires
	output wire cmos_rst_n, cmos_pwdn, cmos_xclk,
	//Debugging
	output wire[3:0] led
    );
	 //FSM state declarations
	 localparam idle=0,
					start_sccb=1,
					write_address=2,
					write_data=3,
					digest_loop=4,
					delay=5,
					vsync_fedge=6,
					byte1=7,
					byte2=8,
					fifo_write=9,
					stopping=10,
					rest=11;
					
	 localparam wait_init=0,
					sccb_idle=1,
					sccb_address=2,
					sccb_data=3,
					sccb_stop=4;
					
	 localparam MSG_INDEX=77; //number of the last index to be digested by SCCB
	 
	 
	 
	 reg[3:0] state_q=0,state_d;
	 reg[2:0] sccb_state_q=0,sccb_state_d;
	 reg[7:0] addr_q,addr_d;
	 reg[7:0] data_q,data_d;
	 reg[7:0] brightness_q,brightness_d;
	 reg[7:0] contrast_q,contrast_d;
	 reg start,stop;
	 reg[7:0] wr_data;
	 reg[3:0] led_q=0,led_d; 
	 reg[27:0] delay_q=0,delay_d;
	 reg start_delay_q=0,start_delay_d;
	 reg delay_finish;
	 reg[15:0] message[250:0];
	 reg[7:0] message_index_q=0,message_index_d;
	 reg[15:0] pixel_q,pixel_d;
	 reg wr_en;
	 reg[7:0] gray_pixel_q=0,gray_pixel_d;
	 reg mod2_q=0,mod2_d;
	 reg[2:0] lines_q,lines_d;
	 reg[7:0] gray;
	 wire rd_tick;
	 wire[1:0] ack;
	 wire[7:0] rd_data;
	 wire[3:0] state;
	 wire full;
	 wire key0_tick,key1_tick,key2_tick,key3_tick;
	 
	 reg[18:0] count_q=0,count_d;
	 
	 
	 //buffer for all inputs coming from the camera
	 reg pclk_1,pclk_2,href_1,href_2,vsync_1,vsync_2;

	 
	 initial begin //collection of all adddresses and values to be written in the camera
				//{address,data}
	 message[0]=16'h12_80;  //reset all register to default values
	 message[1]=16'h12_04;  //set output format to RGB
	 message[2]=16'h15_20;  //pclk will not toggle during horizontal blank
	 message[3]=16'h40_d0;	//RGB565
	 
	// These are values scalped from https://github.com/jonlwowski012/OV7670_NEXYS4_Verilog/blob/master/ov7670_registers_verilog.v
    message[4]= 16'h12_04; // COM7,     set RGB color output
    message[5]= 16'h11_80; // CLKRC     internal PLL matches input clock
    message[6]= 16'h0C_00; // COM3,     default settings
    message[7]= 16'h3E_00; // COM14,    no scaling, normal pclock
    message[8]= 16'h04_00; // COM1,     disable CCIR656
    message[9]= 16'h40_d0; //COM15,     RGB565, full output range
    message[10]= 16'h3a_04; //TSLB       set correct output data sequence (magic)
	 message[11]= 16'h14_18; //COM9       MAX AGC value x4 0001_1000
    message[12]= 16'h4F_B3; //MTX1       all of these are magical matrix coefficients
    message[13]= 16'h50_B3; //MTX2
    message[14]= 16'h51_00; //MTX3
    message[15]= 16'h52_3d; //MTX4
    message[16]= 16'h53_A7; //MTX5
    message[17]= 16'h54_E4; //MTX6
    message[18]= 16'h58_9E; //MTXS
    message[19]= 16'h3D_C0; //COM13      sets gamma enable, does not preserve reserved bits, may be wrong?
    message[20]= 16'h17_14; //HSTART     start high 8 bits
    message[21]= 16'h18_02; //HSTOP      stop high 8 bits //these kill the odd colored line
    message[22]= 16'h32_80; //HREF       edge offset
    message[23]= 16'h19_03; //VSTART     start high 8 bits
    message[24]= 16'h1A_7B; //VSTOP      stop high 8 bits
    message[25]= 16'h03_0A; //VREF       vsync edge offset
    message[26]= 16'h0F_41; //COM6       reset timings
    message[27]= 16'h1E_00; //MVFP       disable mirror / flip //might have magic value of 03
    message[28]= 16'h33_0B; //CHLF       //magic value from the internet
    message[29]= 16'h3C_78; //COM12      no HREF when VSYNC low
    message[30]= 16'h69_00; //GFIX       fix gain control
    message[31]= 16'h74_00; //REG74      Digital gain control
    message[32]= 16'hB0_84; //RSVD       magic value from the internet *required* for good color
    message[33]= 16'hB1_0c; //ABLC1
    message[34]= 16'hB2_0e; //RSVD       more magic internet values
    message[35]= 16'hB3_80; //THL_ST
    //begin mystery scaling numbers
    message[36]= 16'h70_3a;
    message[37]= 16'h71_35;
    message[38]= 16'h72_11;
    message[39]= 16'h73_f0;
    message[40]= 16'ha2_02;
    //gamma curve values
    message[41]= 16'h7a_20;
    message[42]= 16'h7b_10;
    message[43]= 16'h7c_1e;
    message[44]= 16'h7d_35;
    message[45]= 16'h7e_5a;
    message[46]= 16'h7f_69;
    message[47]= 16'h80_76;
    message[48]= 16'h81_80;
    message[49]= 16'h82_88;
    message[50]= 16'h83_8f;
    message[51]= 16'h84_96;
    message[52]= 16'h85_a3;
    message[53]= 16'h86_af;
    message[54]= 16'h87_c4;
    message[55]= 16'h88_d7;
    message[56]= 16'h89_e8;
    //AGC and AEC
    message[57]= 16'h13_e0; //COM8, disable AGC / AEC
    message[58]= 16'h00_00; //set gain reg to 0 for AGC
    message[59]= 16'h10_00; //set ARCJ reg to 0
    message[60]= 16'h0d_40; //magic reserved bit for COM4
    message[61]= 16'h14_18; //COM9, 4x gain + magic bit
    message[62]= 16'ha5_05; // BD50MAX
    message[63]= 16'hab_07; //DB60MAX
    message[64]= 16'h24_95; //AGC upper limit
    message[65]= 16'h25_33; //AGC lower limit
    message[66]= 16'h26_e3; //AGC/AEC fast mode op region
    message[67]= 16'h9f_78; //HAECC1
    message[68]= 16'ha0_68; //HAECC2
    message[69]= 16'ha1_03; //magic
    message[70]= 16'ha6_d8; //HAECC3
    message[71]= 16'ha7_d8; //HAECC4
    message[72]= 16'ha8_f0; //HAECC5
    message[73]= 16'ha9_90; //HAECC6
    message[74]= 16'haa_94; //HAECC7
    message[75]= 16'h13_e5; //COM8, enable AGC / AEC
	// message[76]= 16'h1E_23; //Mirror Image
	 message[77]= 16'h69_06; //gain of RGB(manually adjusted)
  end
	 
	 //register operations
	 always @(posedge clk,negedge rst_n) begin
		if(!rst_n) begin
			state_q<=0;
			led_q<=0;
			delay_q<=0;
			start_delay_q<=0;
			message_index_q<=0;
			pixel_q<=0;
			gray_pixel_q<=0;
			
			sccb_state_q<=0;
			addr_q<=0;
			data_q<=0;
			brightness_q<=0;
			contrast_q<=0;
			mod2_q<=0;
			count_q<=0;
			lines_q<=0;
		end
		else begin
			state_q<=state_d;
			led_q<=led_d;
			delay_q<=delay_d;
			start_delay_q<=start_delay_d;
			message_index_q<=message_index_d;			
			pclk_1<=cmos_pclk; 
			pclk_2<=pclk_1;
			href_1<=cmos_href;
			href_2<=href_1;
			vsync_1<=cmos_vsync;
			vsync_2<=vsync_1;
			pixel_q<=pixel_d;
			
			gray_pixel_q<=gray_pixel_d;
			sccb_state_q<=sccb_state_d;
			addr_q<=addr_d;
			data_q<=data_d;
			brightness_q<=brightness_d;
			contrast_q<=contrast_d;
			mod2_q<=mod2_d;
			count_q<=count_d;
			lines_q<=lines_d;
		end
	 end
	 	 
	 
	 //FSM next-state logics
	 always @* begin
		state_d=state_q;
		led_d=led_q;
		start=0;
		stop=0;
		wr_data=0;
		start_delay_d=start_delay_q;
		delay_d=delay_q;
		delay_finish=0;
		message_index_d=message_index_q;
		pixel_d=pixel_q;
		gray_pixel_d=gray_pixel_q;
		lines_d=lines_q;
		wr_en=0;
		
		sccb_state_d=sccb_state_q;
		addr_d=addr_q;
		data_d=data_q;
		brightness_d=brightness_q;
		contrast_d=contrast_q;
		mod2_d=mod2_q;
		count_d=count_q;
		
		//delay logic  
		if(start_delay_q) delay_d=delay_q+1'b1;
		if(delay_q[16] && message_index_q!=(MSG_INDEX+1) && (state_q!=start_sccb))  begin  //delay between SCCB transmissions (0.66ms)
			delay_finish=1;
			start_delay_d=0;
			delay_d=0;
		end
		else if((delay_q[26] && message_index_q==(MSG_INDEX+1)) || (delay_q[26] && state_q==start_sccb)) begin //delay BEFORE SCCB transmission, AFTER SCCB transmission, and BEFORE retrieving pixel data from camera (0.67s)
			delay_finish=1;
			start_delay_d=0;
			delay_d=0;
		end
		
		case(state_q) 
		
					////////Begin: Setting register values of the camera via SCCB///////////
					
			  idle:  if(delay_finish && start_camera) begin //idle for 0.6s to start-up the camera
							state_d=start_sccb; 
							start_delay_d=0;
							count_d=0;
							lines_d=0;
							led_d=4'b1000;
						end
						else start_delay_d=1;

		start_sccb:  begin   //start of SCCB transmission
							start=1;
							wr_data=8'h42; //slave address of OV7670 for write
							state_d=write_address;	
							led_d=4'b1100;
						end
	 write_address: if(ack==2'b11) begin 
							wr_data=message[message_index_q][15:8]; //write address
							state_d=write_data;
							led_d=4'b1110;
						end
		 write_data: if(ack==2'b11) begin 
							wr_data=message[message_index_q][7:0]; //write data
							state_d=digest_loop;
						end
	  digest_loop: if(ack==2'b11) begin //stop sccb transmission
							stop=1;
							start_delay_d=1;
							message_index_d=message_index_q+1'b1;
							state_d=delay;
						end
			  delay: begin
							if(message_index_q==(MSG_INDEX+1) && delay_finish) begin 
								state_d=rest; //if all messages are already digested, proceed to retrieving camera pixel data
								mod2_d=0;
								led_d=4'b1111; //red LEDs
							end
							else if(state==0 && delay_finish) state_d=start_sccb; //small delay before next SCCB transmission(if all messages are not yet digested)
						end
			  
			  

				///////////////Begin: Retrieving Pixel Data from Camera to be Stored to SDRAM/////////////////
			   rest: if(key_tick || pir_sensor || !sound_sensor || temp_sensor) begin
			             lines_d=0;
			             state_d=vsync_fedge;
			         end
		vsync_fedge: begin
                        if(vsync_1==0 && vsync_2==1 && empty && lines_q<5) begin 
                              lines_d=lines_q+1;
                              state_d=byte1; //vsync falling edge means new frame is incoming
                              count_d=0;
                         end
                         else if(lines_q==5) begin
                                     state_d=rest;
                                     led_d=4'b0110;
                         end
                      end
				byte1: if(pclk_1==1 && pclk_2==0 && href_1==1 && href_2==1) begin //rising edge of pclk means new pixel data(first byte of 16-bit pixel RGB565) is available at output
								//pixel_d[15:8]=cmos_db;
								//state_d=byte2;
								///////////////
								case(lines_q)
								1:wr_en=count_q>=0 && count_q<=65535;
								2:wr_en=count_q>=65536 && count_q<=131071;
								3:wr_en=count_q>=131072 && count_q<=196607;
								4:wr_en=count_q>=196608 && count_q<=262143;
								5:wr_en=count_q>=262144 && count_q<=327679;
								endcase
                                state_d=byte2;					
								///////////////
								led_d=4'b1001;
						 end
						 else if(vsync_1==1 && vsync_2==1) begin
							state_d=vsync_fedge;
						 end
				byte2: if(pclk_1==1 && pclk_2==0 && href_1==1 && href_2==1) begin //rising edge of pclk means new pixel data(second byte of 16-bit pixel RGB565) is available at output
								//pixel_d[7:0]=cmos_db;
								//state_d=fifo_write;
								case(lines_q)
								1:wr_en=count_q>=0 && count_q<=65535;
								2:wr_en=count_q>=65536 && count_q<=131071;
								3:wr_en=count_q>=131072 && count_q<=196607;
								4:wr_en=count_q>=196608 && count_q<=262143;
								5:wr_en=count_q>=262144 && count_q<=327679;
								endcase
                                state_d=byte1;	
                                count_d=(count_q<307200)? (count_q+1'b1):count_q;
						 end
						 else if(vsync_1==1 && vsync_2==1) begin
							state_d=vsync_fedge;
						 end
		 /*fifo_write: begin //write the 16-bit data to asynchronous fifo to be retrieved later by SDRAM
								state_d=byte1;
								////////////////////////////
								gray=(pixel_q[15:11]+(pixel_q[10:5]>>1)+pixel_q[4:0])/3; //RGB to grayscale conversion using averaging method
								gray_pixel_d={gray_pixel_q[3:0],gray[3:0]};
								mod2_d=mod2_q+1; 
								wr_en=(mod2_q==1) && count_q<256000; //save data when two gray pixel(8 bytes) are saved on gray_pixel_q;
								led_d=wr_en? 4'b1001:4'b0110;
						 end*/
		default: state_d=idle;
		endcase
		
		/*
		//Logic for increasing/decreasing brightness and contrast via the 4 keybuttons
		case(sccb_state_q)
			wait_init: if(state_q==byte1) begin //wait for initial SCCB transmission to finish
							sccb_state_d=sccb_idle;
							addr_d=0;
							data_d=0;
							brightness_d=8'h00; 
							contrast_d=8'h40;
						  end
			sccb_idle: if(state==0) begin //wait for any pushbutton
								if(key0_tick) begin//increase brightness
									brightness_d=(brightness_q[7]==1)? brightness_q-5:brightness_q+5;
									if(brightness_q==8'h80) brightness_d=0;
									start=1;
									wr_data=8'h42; //slave address of OV7670 for write
									addr_d=8'h55; //brightness control address
									data_d=brightness_d;
									sccb_state_d=sccb_address;
									led_d=0;
								end
								if(key1_tick) begin //decrease brightness
									brightness_d=(brightness_q[7]==1)? brightness_q+5:brightness_q-5;
									if(brightness_q==0) brightness_d=8'h80;
									start=1;
									wr_data=8'h42; 
									addr_d=8'h55;
									data_d=brightness_d;
									sccb_state_d=sccb_address;
									led_d=0;
								end
								else if(key2_tick) begin //increase contrast
									contrast_d=contrast_q+5;
									start=1;
									wr_data=8'h42; //slave address of OV7670 for write
									addr_d=8'h56; //contrast control address
									data_d=contrast_d;
									sccb_state_d=sccb_address;
									led_d=0;
								end
								else if(key3_tick) begin //decrease contrast
									contrast_d=contrast_q-5;
									start=1;
									wr_data=8'h42;
									addr_d=8'h56;
									data_d=contrast_d;
									sccb_state_d=sccb_address;
									led_d=0;
								end
						  end
		sccb_address: if(ack==2'b11) begin 
							wr_data=addr_q; //write address
							sccb_state_d=sccb_data;
						end
		  sccb_data: if(ack==2'b11) begin 
							wr_data=data_q; //write databyte
							sccb_state_d=sccb_stop;
						 end
		  sccb_stop: if(ack==2'b11) begin //stop
							stop=1;
							sccb_state_d=sccb_idle;
							led_d=4'b1001;
						 end
			 default: sccb_state_d=wait_init;
		endcase
		*/
		//debug
		/*if(count_q<38400) pixel_d={{5{1'b0}},{6{1'b0}},{5{1'b0}}};
		else if(count_q<76800) pixel_d={{5{1'b0}},{6{1'b0}},{5{1'b1}}};
		else if(count_q<115200) pixel_d={{5{1'b0}},{6{1'b1}},{5{1'b0}}};
		else if(count_q<153600) pixel_d={{5{1'b0}},{6{1'b1}},{5{1'b1}}};
		else if(count_q<192000) pixel_d={{5{1'b1}},{6{1'b0}},{5{1'b0}}};
		else if(count_q<230400) pixel_d={{5{1'b1}},{6{1'b0}},{5{1'b1}}};
		else if(count_q<268800) pixel_d={{5{1'b1}},{6{1'b1}},{5{1'b0}}};
		else if(count_q<307200) pixel_d={{5{1'b1}},{6{1'b1}},{5{1'b1}}};*/
	 end
	 

	 assign cmos_pwdn=0; 
	 assign cmos_rst_n=1;
	 assign led=led_q;
	 
	 //module instantiations
	 i2c_top #(.main_clock(100_000_000), .freq(100_000)) m0
	(
		.clk(clk),
		.rst_n(rst_n),
		.start(start),
		.stop(stop),
		.wr_data(wr_data),
		.rd_tick(rd_tick), //ticks when read data from servant is ready,data will be taken from rd_data
		.ack(ack), //ack[1] ticks at the ack bit[9th bit],ack[0] asserts when ack bit is ACK,else NACK
		.rd_data(rd_data), 
		.scl(cmos_scl),
		.sda(cmos_sda),
		.state(state)
    ); 
	 
	 
	assign cmos_xclk=clk;
	 

	asyn_fifo #(.DATA_WIDTH(8),.FIFO_DEPTH_WIDTH(17)) m2 //2048x8 FIFO mem
	(
		.rst_n(rst_n),
		.clk_write(clk),
		.clk_read(clk), //clock input from both domains
		.write(wr_en),
		.read(rd_en), 
		//.data_write(gray_pixel_q), //input FROM write clock domain
		.data_write(cmos_db),
		.data_read(dout), //output TO read clock domain
		.full(full),
		.empty(empty) //full=sync to write domain clk , empty=sync to read domain clk
		//.data_count_r() 
    );
	
debounce_explicit m3
	(
		.clk(clk),
		.rst_n(rst_n),
		.sw(btn),
		.db_level(),
		.db_tick(key_tick)
    );
	
endmodule