//This implementation of Dual port RAM
//Which has the ability to write and read simultanuosly in different clocks
//This Buffer has two inside ports Buffer A(150x150x8) and B(150x150x1)
module Buffer(
	input [15:0]d_in_a,			// Port A input data
	input [14:0] r_addr_a,		// Port A address for reading
	input [14:0] w_addr_a,		//	Port A address for writing
	input d_in_b,					// Port B input data
	input [14:0] r_addr_b,		//	Port B address for reading
	input [14:0] w_addr_b,		// Port B address for writing
	input w_clk,					//	Write clock (25MHz)
	input r_clk,					//	Read clock  (50MHz)
	input w_en_a,					//	Port A write flag enable
	input w_en_b,					// Port B write flag enable
	output reg [15:0] d_out_a,	// Port A data out (8-bits)
	output reg err_w_a	,		// Port A error in writing
	output reg d_out_b,			// Port A data out (1-bit)
	output reg err_w_b			// Port B error in writing
);

	reg [15:0] data_a[22499:0]; //Registers array (150x150x8) 
	reg data_b[22499:0]; 		//Registers array (150x150x1)
	
	
	// This block is activated at the positive edge of the writing clock (25MHz)
	// This block is responsible to write the datat in buffer port A
	always @(posedge w_clk) 
	begin
		// Check if the writing enable is activated or not to write on port B
		if(w_en_a)
		begin
			err_w_a <= 0;
			data_a[w_addr_a] <= d_in_a;
		end
		else
			err_w_a <= 1;
				
	end
	
	// This block is activated at the positive edge of the reading clock (50MHz)
	// This block is responsible to read from the port A and read and write from port B
	// Port B is read and writen at the same clock (50MHz) as it is read by VGA and writen by Sobel operator
	always @(posedge r_clk)
	begin
		d_out_a <= data_a[r_addr_a];		// Set the A out data from the registers of A
		d_out_b <= data_b[r_addr_b];		// Set the B out data from the registers of B
		
		// Check if the writing enable is activated or not to write on port B
		if(w_en_b == 1)
		begin
			err_w_b <= 0;
			data_b[w_addr_b] <= d_in_b;	// Store the input data
		end
		else
			err_w_b <= 1;
	end
	
endmodule
