//This implementation of Dual port RAM
//Which has the ability to write and read simultanuosly in different clocks
//This Buffer has two inside ports Buffer A(150x150x8) and B(150x150x1)
module Buffer(
	input [15:0]d_in_a,			// Port A input data
	input [15:0] r_addr,		// Port A address for reading
	input [15:0] w_addr,		//	Port A address for writing
	input w_clk,					//	Write clock (25MHz)
	input r_clk,					//	Read clock  (50MHz)
	input w_en_a,					//	Port A write flag enable
	input r_rd,
	output reg [15:0] d_out_a,	// Port A data out (8-bits)
	output reg err_w_a,			// Port A error in writing
	output reg r_done
);

	reg [15:0] data_a[65535:0]; //Registers array (256x256x16) 
	reg [15:0] data_b[65535:0];  
	
	reg [15:0] data_t;
	
	reg [16:0] read_count;
	
	reg read_p1,read_p2;
	wire read_start;
	
	// This block is activated at the positive edge of the writing clock (25MHz)
	// This block is responsible to write the datat in buffer port A
	always @(posedge w_clk) 
	begin
		// Check if the writing enable is activated or not to write on port B
		if(w_en_a && !r_rd)
		begin
			err_w_a <= 0;
			data_a[w_addr] <= d_in_a;
		end
		else
			err_w_a <= 1;
				
	end
	
	// This block is activated at the positive edge of the reading clock (50MHz)
	// This block is responsible to read from the port A and read and write from port B
	// Port B is read and writen at the same clock (50MHz) as it is read by VGA and writen by Sobel operator
	always @(posedge r_clk)
	begin
		read_p1 <= r_rd;
		read_p2 <= read_p1;
		
		data_t <=data_a[r_addr];
		
		if(r_rd) begin
			if(read_start) begin
				read_count <= 17'd0;
				r_done <= 1'd0;
			end
			if(read_count <= 17'd65535) begin
				read_count <= read_count + 17'd1;
				data_b[r_addr] <= data_t;
			end
			else r_done <= 1'd1;
		end
	
		d_out_a <= data_b[r_addr];		// Set the A out data from the registers of A
	end
	
	assign read_start = read_p1 && !read_p2;
	
endmodule
