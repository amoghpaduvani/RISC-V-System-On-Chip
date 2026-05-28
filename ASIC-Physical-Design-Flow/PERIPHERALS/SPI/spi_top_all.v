`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/31/2024 10:24:58 AM
// Design Name: 
// Module Name: spi_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module spi_top (
    input wire PRESETn,
    input wire PSEL,
	input wire PCLK,
	input wire PENABLE,
	input wire PWRITE,
	
	input wire [7:0] PADDR,
	input wire [31:0] PWDATA,
	input wire miso,
    
	output wire [31:0] PRDATA,
	output wire ss,
	output wire sclk,
	output wire mosi
    );
    wire clk;
    wire [31:0] MWDATA,MRDATA;  
    wire [7:0] MADDR;
    wire [7:0]SPICR_1,SPICR_2,SPIBDR,SPISR;

    spi_controller controller(
    .PCLK(PCLK),
    .PSEL(PSEL),
	.PRESETn(PRESETn),
	.PWRITE(PWRITE),
	.PADDR(PADDR),
	.PWDATA(PWDATA),
	.MRDATA(MRDATA), 
	.SPISR(SPISR),    
	.clk(clk),
	.MADDR(MADDR),
	.MWDATA(MWDATA),                     
	.PRDATA(PRDATA),
	.SPICR_1(SPICR_1),
	.SPICR_2(SPICR_2),
	.SPIBDR(SPIBDR)
    );
    
    spi_master master(
    .PCLK(clk),
    .PRESETn(PRESETn),
    .miso(miso),
    .MADDR(MADDR),
    .MWDATA(MWDATA),
    .SPICR_1(SPICR_1),                    // 7-6 RESERVED 5-SPIF, 4-SPE, 3-MSTR, 2-CPOL, 1-CPHASE, 0-LSBFE
    .SPICR_2(SPICR_2),                    // 7 to 1-RESERVED, 0-SPC0
    .SPISR(SPISR),                        // 7-3 RESERVED 2-TXCR 1-TXCW 0-SPTEF                
    .MRDATA(MRDATA),
    .ss(ss),
    .sclk(sclk),
    .mosi(mosi)  
    );
    
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/31/2024 10:29:06 AM
// Design Name: 
// Module Name: spi_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module spi_controller(
    input PCLK,
    input PSEL,
	input PRESETn,
	input PWRITE,
	
	input [7:0] PADDR,
	input [31:0] PWDATA,     // to write the data
	input [31:0] MRDATA,     // to read the data
	
	input [7:0]SPISR,            // 7-SPIF, 6-RESERVED, 5-SPTEF, 4-MODF, 3 to 0-RESERVED     

    output wire clk,
    
	output reg [7:0]MADDR,
	output reg [31:0]MWDATA,                     
	output reg [31:0]PRDATA,
	
	output reg [7:0]SPICR_1,     // 7-RESERVED 6-SPE, 5-SPTIE, 4-MSTR, 3-CPOL, 2-CPHASE, 1-SSOE, 0-LSBFE
	output reg [7:0]SPICR_2,     // 7 to 1-RESERVED, 0-SPC0
	output reg [7:0]SPIBDR     // 7-RESERVED 6-SPPR2, 5-SPPR1, 4-SPPR0, 3-RESERVED, 2-SPR2, 1-SPR1, 0-SPR0   
    );
	 
	

    reg [1:0] current_state, next_state;
    reg clk_2;
    reg [31:0] counter ;
    reg [31:0] divisor;
    assign clk = (divisor == 4'd1) ? PCLK : clk_2;
    always @(posedge PCLK) begin
        if (PRESETn || SPISR[0]==1) begin
            // Reset all registers and internal signals
            SPICR_1 <= 8'b0;
            SPICR_2 <= 8'b0;
            SPIBDR <= 8'b0;
            MADDR <= 32'b0;
            MWDATA <= 32'b0;
            PRDATA <= 32'b0;
        end else if (PSEL == 1'b1) begin
        if (PADDR[7:0] == 8'h00 && PWRITE == 1 && SPISR[5]==1) begin
                SPICR_1[7:0] <= PWDATA[7:0];          // REGISTER CONFIGURATION SPICR-1
                SPICR_2[7:0] <= PWDATA[15:8];         // REGISTER CONFIGURATION SPICR-2
                SPIBDR[7:0] <= PWDATA[23:16];         // BAUD RATE CONFIGURATION
        end else if (PADDR[7:0] == 8'h04 && PWRITE == 1 && SPISR[5]==1) begin
                MWDATA[31:0] <= PWDATA[31:0];
        end else if (PADDR[7:0] == 8'h08 && PWRITE == 0) begin
                PRDATA <= {24'b0, SPISR};
        end else if (PADDR[7:0] == 8'h0C && PWRITE == 0) begin
                 PRDATA <= MRDATA; 
        end else begin
            MADDR <= PADDR;
        end
    end
  end  
    always@(posedge PCLK)
    begin
        if (PRESETn) begin
            divisor <= 32'd0;
        end else begin
        if(SPIBDR[6:4]==3'b000 && SPIBDR[2:0]==3'b000)
            divisor <= 32'd1;
        else if(SPIBDR[6:4]==3'b000 && SPIBDR[2:0]==3'b001)
            divisor <= 32'd2;
        else if(SPIBDR[6:4]==3'b000 && SPIBDR[2:0]==3'b010)
            divisor <= 32'd10;
        else if(SPIBDR[6:4]==3'b000 && SPIBDR[2:0]==3'b011)
            divisor <= 32'd100000000;
        else
            divisor <= 32'd1;
  
        if(divisor>32'd1)
         begin
             counter <= counter + 32'd1;
             if(counter >= (divisor-1))
             counter <= 32'd0;
             clk_2 <= (counter<divisor/2)?1'b1:1'b0;
         end 
        else
         begin
            clk_2 <= 0;
         end
               
    end
  end    
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/31/2024 10:27:33 AM
// Design Name: 
// Module Name: spi_master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module spi_master(
input PCLK,
input PRESETn,

input miso,

input [7:0]MADDR,
input [31:0]MWDATA,
                                       
input [7:0]SPICR_1,                 // 7-RESERVED 6-SPE, 5-SPTIE, 4-MSTR, 3-CPOL, 2-CPHASE, 1-SSOE, 0-LSBFE
input [7:0]SPICR_2,                 // 7 to 1-RESERVED, 0-SPC0
          
output reg [7:0]SPISR,        // 7-SPIF, 6-RESERVED, 5-SPTEF, 4-MODF, 3 to 0-RESERVED     
output reg [31:0]MRDATA,
output reg ss,
output reg sclk,
output reg mosi
    );
    
reg [3:0] count1,count2; 
reg [2:0] scount;
reg [7:0]SPIDR_W[0:3];
reg [7:0]SPIDR_R[0:3];
reg [7:0]temp;
reg [3:0]dcount;

localparam idle=3'b000, setup = 3'b001, write = 3'b010, read = 3'b011, delay = 3'b100, delay1 = 3'b101;

reg [2:0]current_state,next_state;

always @(posedge PCLK) begin
    if (PRESETn) begin
        sclk <= 0;
    end else if (current_state == write || current_state == read) begin
        sclk <= ~sclk ; // Toggle sclk during write and read
    end 
    else begin
        sclk <= 0; // Default to 0 in other states
    end
end

always @(posedge PCLK)
begin
    if(PRESETn)
    begin
        current_state <= idle;
    end
    else
    begin
        current_state <= next_state;
    end
end

	always@(posedge PCLK)
	begin
		case(current_state)
			idle:
			begin
			    SPISR =8'h20;       //SPTEF=1
			    mosi <= 0;
			    ss = 1 ;
			    count1=4'b0;
			    count2=4'b0;
			    scount=3'b0;
			    dcount=4'b0;
			    if(PRESETn==1)           // active low signal
                begin
                    next_state<=idle;
                end
                
                else if(SPICR_1[6]==1 && MWDATA)
                begin
                    SPIDR_W[0][7:0]<=0;
                    SPIDR_W[1][7:0]<=0;
                    SPIDR_W[2][7:0]<=0;
                    SPIDR_W[3][7:0]<=0;
                    
                    next_state <= setup;
                end
                
                else if(SPICR_1[6]==1 && ~SPICR_2[0])
                begin                   
                    SPIDR_R[0][7:0]<=0;
                    SPIDR_R[1][7:0]<=0;
                    SPIDR_R[2][7:0]<=0;
                    SPIDR_R[3][7:0]<=0;  
                    
                    next_state <= setup;
                end
                
                else
                begin
                    next_state <= idle;
                end
            end
            
			setup:
			begin
			     if(SPICR_1[1]==1'b1)
			     begin
			        ss= 0;                              // slave select active low
			     end
			    
                 if(SPICR_1[4]==1'b1 && SPICR_2[0]==1'b1 && SPISR[5]==1'b1)
                 begin
                    SPISR[7] = 1'b1;   // SPIF bit New Data is copied to spidr
                    if(SPICR_1[0]==1)                      // lsb first
                    begin
                        temp = {MWDATA[0],MWDATA[1],MWDATA[2],MWDATA[3],MWDATA[4],MWDATA[5],MWDATA[6],MWDATA[7]};
                        SPIDR_W[0][7:0]<= temp;
                        temp = {MWDATA[8],MWDATA[9],MWDATA[10],MWDATA[11],MWDATA[12],MWDATA[13],MWDATA[14],MWDATA[15]};
                        SPIDR_W[1][7:0]<= temp;
                        temp = {MWDATA[16],MWDATA[17],MWDATA[18],MWDATA[19],MWDATA[20],MWDATA[21],MWDATA[22],MWDATA[23]};
                        SPIDR_W[2][7:0]<= temp;
                        temp = {MWDATA[24],MWDATA[25],MWDATA[26],MWDATA[27],MWDATA[28],MWDATA[29],MWDATA[30],MWDATA[31]};
                        SPIDR_W[3][7:0]<= temp;
                    end
                    
                    else if(SPICR_1[0]==0)                 //msb first
                    begin
                        SPIDR_W[3][7:0]<= MWDATA[7:0];
                        SPIDR_W[2][7:0]<= MWDATA[15:8];
                        SPIDR_W[1][7:0]<= MWDATA[23:16];
                        SPIDR_W[0][7:0]<= MWDATA[31:24];
                    end
                
                    next_state <= write;
                 end
                
                 else if(SPICR_1[4] == 1'b0 && SPICR_2[0]==1'b0)
		         begin
			         next_state <= read;
		         end
		          
		         else if(SPICR_1[6]==0)
		         begin
	                 next_state <= idle;
		         end
			end
			
			write:
			begin
				if(scount<3'd4)
				begin
				   if(count1<4'd8)                             // 8bit BIT
				   begin
				       SPISR[5] = 1'b0;                       //SPTEF=0;
				       SPISR[7] = 1'b0;                       //SPIF = 0 Transfer not yet complete
					   if(sclk==0)
				       begin
					   mosi<=SPIDR_W[scount][4'h7-count1];
					   count1=count1+1'b1;
					   end
				   end
					
				   if(count1==4'd8)                      // 32 BIT
				   begin						
					  count1=0;
					  scount=scount+1;
					  next_state<=write;
				   end
			   end
				   
			   else if(scount==3'd4)
			   begin
			       scount=3'b0;
			       SPISR[0] = 1'b1; 
			       next_state<=idle;
			   end
				
	    	   else if(SPICR_1[6]==1'b0)
			   begin
			        next_state<=idle;
			   end
		    end
			
			read:
			begin
			    if(scount<3'd4)
			    begin
				    if(count2<4'd8)                            //32 BIT
				    begin
					   if(sclk==0)
				       begin
					   SPIDR_R[scount][4'h7-count2]<=miso;
					   count2=count2+1'b1;
					   end
				    end
				
				    if(count2==4'd8)
				    begin   
					   count2=0;
					   scount=scount+1;					
					   next_state<=read;
				    end
			     end
			
			if(scount==3'd4)
			begin
			     scount=3'b0;                        	
			     MRDATA[7:0]=SPIDR_R[3][7:0];
			     MRDATA[15:8]=SPIDR_R[2][7:0];
			     MRDATA[23:16]=SPIDR_R[1][7:0];
			     MRDATA[31:24]=SPIDR_R[0][7:0];
			     SPISR[6] = 1'b1;                  //SPTEF_R=1 
			     next_state<=delay;
			end
		end
		
		delay: begin                       //delay transitions so that there should be time to read data before reset everthing
		       if(dcount==4'b1010)begin
		        dcount=0;
		        next_state<=delay1;
		        end
		        else begin 
		        dcount = dcount+1;
		        next_state<=delay;
                end
		       end
 
		delay1: begin
		       SPISR[0] = 1'b1;
		       next_state<=idle;
		       end
		       
    		default:
			begin
				next_state<=idle;
			end
		endcase
	end
	
endmodule

