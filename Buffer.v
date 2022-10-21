//This implementation of Dual port RAM
//Which has the ability to write and read simultanuosly in different clocks
//This Buffer has two inside ports Buffer A(150x150x8) and B(150x150x1)
module Buffer(
	input [15:0]d_in_a,			// Port A input data
	input [7:0] r_addr_r,		// Port A address for reading
	input [7:0] r_addr_c,	
	input [7:0] w_addr_r,		//	Port A address for writing		
	input [7:0] w_addr_c,		
	input w_clk,					//	Write clock (25MHz)
	input r_clk,					//	Read clock  (50MHz)
	input w_en_a,					//	Port A write flag enable
	output reg [15:0] d_out_a,	// Port A data out (8-bits)
	output reg err_w_a			// Port A error in writing
);

	reg [15:0] data_a[250:0][250:0]; //Registers array (150x150x8) 
	
	
	// This block is activated at the positive edge of the writing clock (25MHz)
	// This block is responsible to write the datat in buffer port A
	always @(posedge w_clk) 
	begin
		// Check if the writing enable is activated or not to write on port B
		if(w_en_a)
		begin
			err_w_a <= 0;
			data_a[w_addr_r][w_addr_c] <= d_in_a;
		end
		else
			err_w_a <= 1;
				
	end
	
	// This block is activated at the positive edge of the reading clock (50MHz)
	// This block is responsible to read from the port A and read and write from port B
	// Port B is read and writen at the same clock (50MHz) as it is read by VGA and writen by Sobel operator
	always @(posedge r_clk)
	begin
		d_out_a <= data_a[r_addr_r][r_addr_c];		// Set the A out data from the registers of A
	end
	
endmodule
