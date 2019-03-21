`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of CS, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2017/10/16 14:21:33
// Design Name: 
// Module Name: lab5
// Project Name: 
// Target Devices: Xilinx FPGA @ 100MHz 
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


module lab5(
  input clk,
  input reset_n,
  input [3:0] usr_btn,
  output [3:0] usr_led,
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);

// turn off all the LEDs
assign usr_led = 4'b0000;

wire btn_level, btn_pressed;
reg prev_btn_level;
reg direction;
reg [127:0] row_A = "Prime #01 is 002"; // Initialize the text of the first row. 
reg [127:0] row_B = "Prime #02 is 003"; // Initialize the text of the second row.

reg [7:0] prime_tag;
reg [31:0] tag_counter;

wire [7:0] prime_tag2;

reg [0:1023]primes={1024{1'b1}};
reg [9:0] idx;
reg [10:0] jdx;
reg end_cal;
reg [9:0] prime_data[0:172];
reg end_store;
reg [7:0] store_tag;
reg [9:0] store_counter;

assign prime_tag2 = (prime_tag==8'd172)? 8'd1:prime_tag+8'd1;

LCD_module lcd0(
  .clk(clk),
  .reset(~reset_n),
  .row_A(row_A),
  .row_B(row_B),
  .LCD_E(LCD_E),
  .LCD_RS(LCD_RS),
  .LCD_RW(LCD_RW),
  .LCD_D(LCD_D)
);

debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[3]),
  .btn_output(btn_level)
);

always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 1;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level == 1 && prev_btn_level == 0);
    

always @(posedge clk) begin
  if (~reset_n) begin
    direction<=1'd0;
  end
  else begin
    if(btn_pressed==1'd1) 
      direction<=direction+1'd1;
    else
      direction<=direction;
  end
end     

always @(posedge clk) begin
  if (~reset_n) begin
    // Initialize the text when the user hit the reset button
    row_A = "Prime #01 is 002";
    row_B = "Prime #02 is 003";
  end 
  else if(end_store==1'd1) begin
    row_A[127:72]<="Prime #";
    if(4'd9>=prime_tag[7:4] && prime_tag[7:4]>=4'd0)
      row_A[71:64]<=prime_tag[7:4]+8'd48;
    else
      row_A[71:64]<=prime_tag[7:4]+8'd55;
    if(4'd9>=prime_tag[3:0] && prime_tag[3:0]>=4'd0)
      row_A[63:56]<=prime_tag[3:0]+8'd48;
    else
      row_A[63:56]<=prime_tag[3:0]+8'd55;
    row_A[55:24] <= " is ";
    row_A[23:16] <= prime_data[prime_tag][9:8]+8'd48;
    if(4'd9>=prime_data[prime_tag][7:4] && prime_data[prime_tag][7:4]>=4'd0)
      row_A[15:8] <= prime_data[prime_tag][7:4]+8'd48;
    else
      row_A[15:8] <= prime_data[prime_tag][7:4]+8'd55;
    if(4'd9>=prime_data[prime_tag][3:0] && prime_data[prime_tag][3:0]>=4'd0)
      row_A[7:0] <= prime_data[prime_tag][3:0]+8'd48;
    else
      row_A[7:0] <= prime_data[prime_tag][3:0]+8'd55;
    
    row_B[127:72]<="Prime #";
    if(4'd9>=prime_tag2[7:4] && prime_tag2[7:4]>=4'd0)
      row_B[71:64]<=prime_tag2[7:4]+8'd48;
    else
      row_B[71:64]<=prime_tag2[7:4]+8'd55;
    if(4'd9>=prime_tag2[3:0] && prime_tag2[3:0]>=4'd0)
      row_B[63:56]<=prime_tag2[3:0]+8'd48;
    else
      row_B[63:56]<=prime_tag2[3:0]+8'd55;
    row_B[55:24] <= " is ";
    row_B[23:16] <= prime_data[prime_tag2][9:8]+8'd48;
    if(4'd9>=prime_data[prime_tag2][7:4] && prime_data[prime_tag2][7:4]>=4'd0)
      row_B[15:8] <= prime_data[prime_tag2][7:4]+8'd48;
    else
      row_B[15:8] <= prime_data[prime_tag2][7:4]+8'd55;
    if(4'd9>=prime_data[prime_tag2][3:0] && prime_data[prime_tag2][3:0]>=4'd0)
      row_B[7:0] <= prime_data[prime_tag2][3:0]+8'd48;
    else
      row_B[7:0] <= prime_data[prime_tag2][3:0]+8'd55;
  end
end

always @(posedge clk) begin
  if (~reset_n) begin
    tag_counter<=32'd0;
  end
  else begin
    if(tag_counter==32'd70000000) begin
      tag_counter<=32'd0;
    end
    else begin
      tag_counter<=tag_counter+32'd1;
    end
  end 
end

always @(posedge clk) begin
  if (~reset_n) begin
    prime_tag<=8'd1;
  end
  else begin
    if(tag_counter==32'd70000000) begin
      if(direction==1'd0) begin 
        if(prime_tag==8'd172) 
          prime_tag<=8'd1;
        else
          prime_tag<=prime_tag+8'd1;
      end
      else begin
        if(prime_tag==8'd1) 
          prime_tag<=8'd172;
        else
          prime_tag<=prime_tag-8'd1;
      end
    end
    else begin
      prime_tag<=prime_tag;
    end 
  end
end

always @(posedge clk) begin
  if (~reset_n) begin
    primes={1024{1'b1}};
    idx<=10'd2;
    jdx<=11'd4;
    end_cal<=1'd0;
  end
  else begin
    if(idx==10'd1022) begin
      end_cal<=1'd1;
    end
    else begin
      if(primes[idx]==1'b1) begin
        if(11'd1024>jdx)begin
          primes[jdx]<=1'b0;
          jdx<=jdx+idx;
        end
        else begin
          idx<=idx+10'd1;
          jdx<=idx+idx+11'd2;
        end
      end
      else begin
        idx<=idx+10'd1;
        jdx<=idx+idx+11'd2;
      end
    end
  end  
end

always @(posedge clk) begin
  if (~reset_n) begin
    store_tag<=8'd1;
    store_counter<=10'd2;
    end_store<=1'd0;
  end
  else begin
    if(end_cal==1'd1)begin
      if(store_counter==10'd1022)begin
        end_store<=1'd1;
      end
      else begin
        if(primes[store_counter]==1'b1) begin
          prime_data[store_tag]<=store_counter;
          store_tag<=store_tag+8'd1;
          store_counter<=store_counter+10'd1;
        end
        else begin
          store_counter<=store_counter+10'd1;
        end
      end
    end  
  end
end      
    
    

    


endmodule