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
	output reg [15:0] d_out_b,	// Port B data out
	output reg err_w_a,			// Port A error in writing
	output reg r_done = 1,
	
	output [1:0] led_d
);

	reg [15:0] data_a[65535:0]; //Registers array (256x256x16) 
	reg [15:0] data_b[65535:0];  
	
	reg [15:0] data_t;
	
	reg [16:0] read_count;
	
	reg [15:0] w_addr_t;
	
	reg [1:0] state;
	
	reg read_p1,read_p2;
	wire read_start;
	
	
	localparam  idle = 0,
					wait_start=1,
					read=2;
	
	// This block is activated at the positive edge of the writing clock (25MHz)
	// This block is responsible to write the datat in buffer port A
	always @(posedge w_clk) 
	begin
		// Check if the writing enable is activated or not to write on port B
		if(w_en_a && r_done)
		begin
			err_w_a <= 0;
			w_addr_t <= w_addr;
			data_a[w_addr_t] <= d_in_a;
		end
		else
			err_w_a <= 1;
				
	end
	
	// This block is activated at the positive edge of the reading clock (50MHz)
	// This block is responsible to read from the port A and read and write from port B
	always @(posedge r_clk)
	begin
		read_p1 <= r_rd;
		read_p2 <= read_p1;
		
		
		
		if(r_rd) begin
			case(state)
				idle:	begin
					if(read_start) begin
						read_count <= 17'd0;
						state <= wait_start;
					end
				end
				wait_start: begin
					r_done <= 1'd0;
					state <= read;
				end
				read: begin
					if(read_count <= 17'd65535 ) begin
						data_t <= data_a[read_count[15:0] + 16'd1];
//						data_t <= data_a[read_count[15:0]];
						read_count <= read_count + 17'd1;
						data_b[read_count[15:0]] <= data_t;
					end
					else begin
						r_done <= 1'd1;
						state <= idle;
					end
				end
				default: begin
					state <= idle;
				end
			endcase
		end
	
		d_out_b <= data_b[r_addr];		
	end
	
	assign read_start = read_p1 && !read_p2;
	assign led_d = state;
	
endmodule
