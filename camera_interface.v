`timescale 1ns / 1ps

  module camera_interface(
	input wire clk,rst_n,
	//camera pinouts
	inout cmos_sda,cmos_scl, //i2c comm wires
	//Debugging
	output wire cmos_pwdn, cmos_rst_n,
	output wire[3:0] led
    );
	 //FSM state declarations
	 localparam idle=0,
					start_sccb=1,
					write_address=2,
					write_data=3,
					digest_loop=4,
					delay=5,
					
					digest_end = 6,
					
					stopping=10;
					
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
	 wire rd_tick;
	 wire[1:0] ack;
	 wire[7:0] rd_data;
	 wire[3:0] state;
	 reg[3:0] led_q=0,led_d; 
	 reg[27:0] delay_q=0,delay_d;
	 reg start_delay_q=0,start_delay_d;
	 reg delay_finish;
	 reg[15:0] message[250:0];
	 reg[7:0] message_index_q=0,message_index_d;
	 reg[15:0] pixel_q,pixel_d;
	 reg wr_en;
	 wire full;
	 wire key0_tick,key1_tick,key2_tick,key3_tick;
	 
	 //buffer for all inputs coming from the camera
	 reg pclk_1,pclk_2,href_1,href_2,vsync_1,vsync_2;

	 
	 initial begin //collection of all adddresses and values to be written in the camera
				//{address,data}
		
	 message[0]=16'h12_80;  //reset all register to default values
	 message[1]=16'h12_04;  //set output format to RGB
	 message[2]=16'h15_00;  
	 message[3]=16'h40_d0;	//RGB565
	 /*
    message[4]= 16'h11_c0; // CLKRC     internal PLL matches input clock
    message[5]= 16'h3E_00; // COM14,    no scaling, normal pclock
    message[6]= 16'h04_00; // COM1,     disable CCIR656
    message[7]= 16'h3E_00; // COM14,    no scaling, normal pclock
    message[8]= 16'h3a_04; //TSLB       set correct output data sequence (magic)
	 message[9]= 16'h14_18; //COM9       MAX AGC value x4 0001_1000
    message[10]= 16'h4F_B3; //MTX1       all of these are magical matrix coefficients
    message[11]= 16'h50_B3; //MTX2
    message[12]= 16'h51_00; //MTX3
    message[13]= 16'h52_3d; //MTX4
    message[14]= 16'h53_A7; //MTX5
    message[15]= 16'h54_E4; //MTX6
    message[16]= 16'h58_9E; //MTXS
    message[17]= 16'h3D_C0; //COM13      sets gamma enable, does not preserve reserved bits, may be wrong?
    message[18]= 16'hB0_84; //RSVD       magic value from the internet *required* for good color
    message[19]= 16'hB1_0c; //ABLC1
    message[20]= 16'hB2_0e; //RSVD       more magic internet values
    //gamma curve values
    message[21]= 16'h7a_20;
    message[22]= 16'h7b_10;
    message[23]= 16'h7c_1e;
    message[24]= 16'h7d_35;
    message[25]= 16'h7e_5a;
    message[26]= 16'h7f_69;
    message[27]= 16'h80_76;
    message[28]= 16'h81_80;
    message[29]= 16'h82_88;
    message[30]= 16'h83_8f;
    message[31]= 16'h84_96;
    message[32]= 16'h85_a3;
    message[33]= 16'h86_af;
    message[34]= 16'h87_c4;
    message[35]= 16'h88_d7;
    message[36]= 16'h89_e8;
	 message[37]= 16'h69_06; //gain of RGB(manually adjusted)
//    //AGC and AEC
//    message[37]= 16'h13_e0; //COM8, disable AGC / AEC
//    message[38]= 16'h00_00; //set gain reg to 0 for AGC
//    message[39]= 16'h10_00; //set ARCJ reg to 0
//    message[40]= 16'h0d_40; //magic reserved bit for COM4
//    message[41]= 16'h14_18; //COM9, 4x gain + magic bit
//    message[42]= 16'ha5_05; // BD50MAX
//    message[43]= 16'hab_07; //DB60MAX
//    message[44]= 16'h24_95; //AGC upper limit
//    message[45]= 16'h25_33; //AGC lower limit
//    message[46]= 16'h26_e3; //AGC/AEC fast mode op region
//    message[47]= 16'h9f_78; //HAECC1
//    message[48]= 16'ha0_68; //HAECC2
//    message[49]= 16'ha1_03; //magic
//    message[50]= 16'ha6_d8; //HAECC3
//    message[51]= 16'ha7_d8; //HAECC4
//    message[52]= 16'ha8_f0; //HAECC5
//    message[53]= 16'ha9_90; //HAECC6
//    message[54]= 16'haa_94; //HAECC7
//    message[55]= 16'h13_e5; //COM8, enable AGC / AEC
*/
	 
	// These are values scalped from https://github.com/jonlwowski012/OV7670_NEXYS4_Verilog/blob/master/ov7670_registers_verilog.v
    message[4]= 16'h12_04; // COM7,     set RGB color output
    message[5]= 16'h11_80; // CLKRC     internal PLL matches input clock
    message[6]= 16'h0C_00; // COM3,     downsampling enable
//    message[6]= 16'h0C_00; // COM3,     default settings
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
//	 message[20]= 16'h17_11; //HSTART     start high 8 bits
//    message[21]= 16'h18_61; //HSTOP      stop high 8 bits //these kill the odd colored line
//    message[22]= 16'h32_80; //HREF       edge offset
//    message[23]= 16'h19_03; //VSTART     start high 8 bits
//    message[24]= 16'h1A_7B; //VSTOP      stop high 8 bits
//    message[25]= 16'h03_03; //VREF       vsync edge offset
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
    message[38]= 16'h72_22;
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
	 message[76]= 16'h1E_23; //Mirror Image
	 message[77]= 16'h69_06; //gain of RGB(manually adjusted)
	 /*
	 message[0]<= 16'hFF01;
    message[1]<= 16'h1280;
    message[2]<= 16'hFF00;
    message[3]<= 16'h2CFF;
    message[4]<= 16'h2EDF;
    message[5]<= 16'hFF01;
    message[6]<= 16'h3C32;
    message[7]<= 16'h1101;
    message[8]<= 16'h0902;
    message[9]<= 16'h0420;
    message[10]<= 16'h13E5;
    message[11]<= 16'h1448;
    message[12]<= 16'h2C0C;
    message[13]<= 16'h3378;
    message[14]<= 16'h3A33;
    message[15]<= 16'h3BFB;
    message[16]<= 16'h3E00;
    message[17]<= 16'h4311;
    message[18]<= 16'h1610;
    message[19]<= 16'h3992;
    message[20]<= 16'h35DA;
    message[21]<= 16'h221A;
    message[22]<= 16'h37C3;
    message[23]<= 16'h2300;
    message[24]<= 16'h34C0;
    message[25]<= 16'h361A;
    message[26]<= 16'h0688;
    message[27]<= 16'h07C0;
    message[28]<= 16'h0D87;
    message[29]<= 16'h0E41;
    message[30]<= 16'h4C00;
    message[31]<= 16'h4800;
    message[32]<= 16'h5B00;
    message[33]<= 16'h4203;
    message[34]<= 16'h4A81;
    message[35]<= 16'h2199;
    message[36]<= 16'h2440;
    message[37]<= 16'h2538;
    message[38]<= 16'h2682;
    message[39]<= 16'h5C00;
    message[40]<= 16'h6300;
    message[41]<= 16'h4600;
    message[42]<= 16'h0C3C;
    message[43]<= 16'h6170;
    message[44]<= 16'h6280;
    message[45]<= 16'h7C05;
    message[46]<= 16'h2080;
    message[47]<= 16'h2830;
    message[48]<= 16'h6C00;
    message[49]<= 16'h6D80;
    message[50]<= 16'h6E00;
    message[51]<= 16'h7002;
    message[52]<= 16'h7194;
    message[53]<= 16'h73C1;
    message[54]<= 16'h1240;
    message[55]<= 16'h1711;
    message[56]<= 16'h1839;
    message[57]<= 16'h1900;
    message[58]<= 16'h1A3C;
    message[59]<= 16'h3209;
    message[60]<= 16'h37C0;
    message[61]<= 16'h4FCA;
    message[62]<= 16'h50A8;
    message[63]<= 16'h5A23;
    message[64]<= 16'h6D00;
    message[65]<= 16'h3D38;
    message[66]<= 16'hFF00;
    message[67]<= 16'hE57F;
    message[68]<= 16'hF9C0;
    message[69]<= 16'h4124;
    message[70]<= 16'hE014;
    message[71]<= 16'h76FF;
    message[72]<= 16'h33A0;
    message[73]<= 16'h4220;
    message[74]<= 16'h4318;
    message[75]<= 16'h4C00;
    message[76]<= 16'h87D5;
    message[77]<= 16'h883F;
    message[78]<= 16'hD703;
    message[79]<= 16'hD910;
    message[80]<= 16'hD382;
    message[81]<= 16'hC808;
    message[82]<= 16'hC980;
    message[83]<= 16'h7C00;//////
    message[84]<= 16'h7D00;///////
    message[85]<= 16'h7C03;////////
    message[86]<= 16'h7D48;/////////
    message[87]<= 16'h7D48;/////////
    message[88]<= 16'h7C08;////////
    message[89]<= 16'h7D20;
    message[90]<= 16'h7D10;
    message[91]<= 16'h7D0E;
    message[92]<= 16'h9000;
    message[93]<= 16'h910E;
    message[94]<= 16'h911A;
    message[95]<= 16'h9131;
    message[96]<= 16'h915A;
    message[97]<= 16'h9169;
    message[98]<= 16'h9175;
    message[99]<= 16'h917E;
    message[100]<= 16'h9188;
    message[101]<= 16'h918F;
    message[102]<= 16'h9196;
    message[103]<= 16'h91A3;
    message[104]<= 16'h91AF;
    message[105]<= 16'h91C4;
    message[106]<= 16'h91D7;
    message[107]<= 16'h91E8;
    message[108]<= 16'h9120;
    message[109]<= 16'h9200;
    message[110]<= 16'h9306;
    message[111]<= 16'h93E3;
    message[112]<= 16'h9305;
    message[113]<= 16'h9305;
    message[114]<= 16'h9300;
    message[115]<= 16'h9304;
    message[116]<= 16'h9300;
    message[117]<= 16'h9300;
    message[118]<= 16'h9300;
    message[119]<= 16'h9300;
    message[120]<= 16'h9300;
    message[121]<= 16'h9300;
    message[122]<= 16'h9300;
    message[123]<= 16'h9600;
    message[124]<= 16'h9708;
    message[125]<= 16'h9719;
    message[126]<= 16'h9702;
    message[127]<= 16'h970C;
    message[128]<= 16'h9724;
    message[129]<= 16'h9730;
    message[130]<= 16'h9728;
    message[131]<= 16'h9726;
    message[132]<= 16'h9702;
    message[133]<= 16'h9798;
    message[134]<= 16'h9780;
    message[135]<= 16'h9700;
    message[136]<= 16'h9700;
    message[137]<= 16'hC3ED;
    message[138]<= 16'hA400;
    message[139]<= 16'hA800;///////
    message[140]<= 16'hC511;////////
    message[141]<= 16'hC651;/////////
    message[142]<= 16'hBF80;/////////
    message[143]<= 16'hC710;////////
    message[144]<= 16'hB666;
    message[145]<= 16'hB8A5;
    message[146]<= 16'hB764;
    message[147]<= 16'hB97C;
    message[148]<= 16'hB3AF;
    message[149]<= 16'hB497;
    message[150]<= 16'hB5FF;
    message[151]<= 16'hB0C5;
    message[152]<= 16'hB194;
    message[153]<= 16'hB20F;
    message[154]<= 16'hC45C;
    message[155]<= 16'hC050;
    message[156]<= 16'hC13C;
    message[157]<= 16'h8C00;
    message[158]<= 16'h863D;
    message[159]<= 16'h5000;
    message[160]<= 16'h51A0;
    message[161]<= 16'h5278;
    message[162]<= 16'h5300;
    message[163]<= 16'h5400;
    message[164]<= 16'h5500;
    message[165]<= 16'h5AA0;
    message[166]<= 16'h5B78;
    message[167]<= 16'h5C00;
    message[168]<= 16'hD382;
    message[169]<= 16'hC3ED;
    message[170]<= 16'h7F00;
    message[171]<= 16'hDA08;
    message[172]<= 16'hE51F;
    message[173]<= 16'hE167;
    message[174]<= 16'hE000;
    message[175]<= 16'hDD7F;
    message[176]<= 16'h0500;
*/
  end
	 
	 //register operations
	 always @(posedge clk,negedge rst_n) begin
		if(!rst_n) begin
			state_q<=0;
			led_q<=4'b0001;
			delay_q<=0;
			start_delay_q<=0;
			message_index_q<=0;
			pixel_q<=0;
			
			
			sccb_state_q<=0;
			addr_q<=0;
			data_q<=0;
			brightness_q<=0;
			contrast_q<=0;
		end
		else begin
			state_q<=state_d;
			led_q<=led_d;
			delay_q<=delay_d;
			start_delay_q<=start_delay_d;
			message_index_q<=message_index_d;
			
			sccb_state_q<=sccb_state_d;
			addr_q<=addr_d;
			data_q<=data_d;
			brightness_q<=brightness_d;
			contrast_q<=contrast_d;
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
		wr_en=0;
		
		sccb_state_d=sccb_state_q;
		addr_d=addr_q;
		data_d=data_q;
		brightness_d=brightness_q;
		contrast_d=contrast_q;
		
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
					
			  idle:  begin
						if(delay_finish) begin //idle for 0.6s to start-up the camera
							state_d=start_sccb; 
							start_delay_d=0;
						end
						else start_delay_d=1;
						end

		start_sccb:  begin   //start of SCCB transmission
							start=1;
							wr_data=8'h42; //slave address of OV7670 for write
							state_d=write_address;	
							led_d = 4'b1000;
						end
	 write_address: if(ack==2'b11) begin 
							wr_data=message[message_index_q][15:8]; //write address
							state_d=write_data;
							led_d = 4'b0100;
						end
		 write_data: if(ack==2'b11) begin 
							wr_data=message[message_index_q][7:0]; //write data
							state_d=digest_loop;
							led_d = 4'b0010;
						end
	  digest_loop: if(ack==2'b11) begin //stop sccb transmission
							stop=1;
							start_delay_d=1;
							message_index_d=message_index_q+1'b1;
							state_d=delay;
							
						end
			  delay: begin
							if(message_index_q==(MSG_INDEX+1) && delay_finish) begin 
								state_d=digest_end;
							end
							else if(state==0 && delay_finish) state_d=start_sccb; //small delay before next SCCB transmission(if all messages are not yet digested)
						end
			  digest_end:  begin
							led_d = 4'b1111;
								end
			  

		default: state_d=idle;
		endcase
		
		//Logic for increasing/decreasing brightness and contrast via the 4 keybuttons
		case(sccb_state_q)
			wait_init: if(state_q==write_address) begin //wait for initial SCCB transmission to finish
							sccb_state_d=sccb_idle;
							addr_d=0;
							data_d=0;
							brightness_d=8'h00; 
							contrast_d=8'h40;
							led_d = 4'b1111;
						  end
			sccb_idle: if(state==0) begin //wait for any pushbutton
								if(key0_tick) begin//increase brightness
									brightness_d=(brightness_q[7]==1)? brightness_q-1:brightness_q+1;
									if(brightness_q==8'h80) brightness_d=0;
									start=1;
									wr_data=8'h42; //slave address of OV7670 for write
									addr_d=8'h55; //brightness control address
									data_d=brightness_d;
									sccb_state_d=sccb_address;
									led_d=4'b1110;
								end
								if(key1_tick) begin //decrease brightness
									brightness_d=(brightness_q[7]==1)? brightness_q+1:brightness_q-1;
									if(brightness_q==0) brightness_d=8'h80;
									start=1;
									wr_data=8'h42; 
									addr_d=8'h55;
									data_d=brightness_d;
									sccb_state_d=sccb_address;
									led_d=4'b1101;
								end
								else if(key2_tick) begin //increase contrast
									contrast_d=contrast_q+1;
									start=1;
									wr_data=8'h42; //slave address of OV7670 for write
									addr_d=8'h56; //contrast control address
									data_d=contrast_d;
									sccb_state_d=sccb_address;
									led_d=4'b1011;
								end
								else if(key3_tick) begin //change contrast
									contrast_d=contrast_q-1;
									start=1;
									wr_data=8'h42;
									addr_d=8'h56;
									data_d=contrast_d;
									sccb_state_d=sccb_address;
									led_d=4'b1010;
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
							led_d = 4'b1001;
						 end
			 default: sccb_state_d=wait_init;
		endcase
		
	 end
	 

	 assign cmos_pwdn=0; 
	 assign cmos_rst_n=1;
	 assign led=led_q;
	 
	 //module instantiations
	 i2c_top #(.freq(100_000)) m0
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
	
endmodule
