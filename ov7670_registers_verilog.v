module ov7670_registers_verilog(input clk, input resend, input advance, output [15:0] command, output finished);

    reg [15:0] sreg;
    reg finished_temp;
    reg [7:0] address = {8{1'b0}};
    
    assign command = sreg; 
    assign finished = finished_temp;
    
    always@(sreg)
    begin
        if(sreg == 16'b1111111111111111)
            begin
                finished_temp <= 1;
            end
        else
            begin
                finished_temp <= 0;
            end
    end
    
    always@(posedge clk)
        begin
            if(resend == 1)
                begin
                    address <= {8{1'b0}};
                end
            else if(advance == 1)
                begin
                    address <= address+8'd1;
                end
           case (address) 
                0 : sreg <= 16'h1280; 
                1 : sreg <= 16'h1280; 
                2 : sreg <= 16'h1204; 
                3 : sreg <= 16'h1100; 
                4 : sreg <= 16'h0C00; 
                5 : sreg <= 16'h3E00; 
                6 : sreg <= 16'h8C00; 
                7 : sreg <= 16'h0400; 
                8 : sreg <= 16'h4010; 
                9 : sreg <= 16'h3A04; 
                10 : sreg <= 16'h1438; 
                11 : sreg <= 16'h4FB3; 
                12 : sreg <= 16'h50B3; 
                13 : sreg <= 16'h5100; 
                14 : sreg <= 16'h523D; 
                15 : sreg <= 16'h53A7; 
                16 : sreg <= 16'h54E4; 
                17 : sreg <= 16'h589E; 
                18 : sreg <= 16'h3DC0; 
                19 : sreg <= 16'h1100; 
                20 : sreg <= 16'h1711; 
                21 : sreg <= 16'h1861; 
                22 : sreg <= 16'h32A4; 
                23 : sreg <= 16'h1903; 
                24 : sreg <= 16'h1A7B; 
                25 : sreg <= 16'h030A; 
                26 : sreg <= 16'h0E61; 
                27 : sreg <= 16'h0F4B; 
                28 : sreg <= 16'h1602; 
                29 : sreg <= 16'h1E37; 
                30 : sreg <= 16'h2102; 
                31 : sreg <= 16'h2291; 
                32 : sreg <= 16'h2907; 
                33 : sreg <= 16'h330B; 
                34 : sreg <= 16'h350B; 
                35 : sreg <= 16'h371B; 
                36 : sreg <= 16'h3871; 
                37 : sreg <= 16'h392A; 
                38 : sreg <= 16'h3C78; 
                39 : sreg <= 16'h4D40; 
                40 : sreg <= 16'h4E20; 
                41 : sreg <= 16'h6900; 
                42 : sreg <= 16'h7410; 
                43 : sreg <= 16'h7410; 
                44 : sreg <= 16'h8D4F; 
                45 : sreg <= 16'h8E00; 
                46 : sreg <= 16'h8F00; 
                47 : sreg <= 16'h9000; 
                48 : sreg <= 16'h9100; 
                49 : sreg <= 16'h9600; 
                50 : sreg <= 16'h9A00; 
                51 : sreg <= 16'hB084; 
                52 : sreg <= 16'hB10C; 
                53 : sreg <= 16'hB20E; 
                54 : sreg <= 16'hB382; 
                55 : sreg <= 16'hB80A; 
                default : sreg <= 16'hFFFF;
            endcase  
            
        end
endmodule
