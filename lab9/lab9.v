`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2017/12/06 20:44:08
// Design Name: 
// Module Name: lab9
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is a sample circuit to show you how to initialize an SRAM
//              with a pre-defined data file. Hit BTN0/BTN1 let you browse
//              through the data.
// 
// Dependencies: LCD_module, debounce
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module lab9(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,

  // 1602 LCD Module Interface
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);

localparam [3:0] S_MAIN_INIT=4'd0,S_MAIN_WAIT = 4'd1,S_MAIN_ADDR =4'd2, S_MAIN_READ = 4'd3,
                 S_MAIN_ADDR2 = 4'd4, S_MAIN_READ2 =4'd5,
                 S_MAIN_CAL = 4'd6,S_MAIN_CAL2 = 4'd7, 
                 S_MAIN_COMPARE = 4'd8,
                 S_MAIN_SHOW = 4'd9;

// declare system variables
wire         btn_level, btn_pressed;
reg          prev_btn_level;
reg  [3:0]        P, P_next;
reg  [11:0]       sample_addr;
reg  signed [7:0] sample_data;
wire [7:0]        abs_data1,abs_data2,abs_data3,abs_data4,abs_data5 ;

reg  [127:0] row_A, row_B;

// declare SRAM control signals
wire [10:0] sram_addr;
wire [7:0]  data_in;
wire [7:0]  data_out;
wire        sram_we, sram_en;

assign usr_led = 4'h00;

reg [23:0] init_counter;

reg signed [7:0] g_function [0:63];
reg signed [7:0] f_function [0:63];    
reg [5:0] g_counter;
reg [9:0] f_counter;

reg [5:0] multiple_counter;

reg signed [23:0] sum , max,mul;
reg [9:0] max_adress;

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
  

debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[0]),
  .btn_output(btn_level)
);

//
// Enable one cycle of btn_pressed per each button hit
//
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 1;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level == 1 && prev_btn_level == 0);

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores an 1024+64 8-bit signed data samples.
sram ram0(.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However,
                             // if you set 'we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = (P == S_MAIN_ADDR || P == S_MAIN_READ || P == S_MAIN_ADDR2 || P == S_MAIN_READ2); // Enable the SRAM block.
assign sram_addr = sample_addr[11:0];
assign data_in = 8'b0; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the main controller
always @(posedge clk) begin
  if (~reset_n) begin
    P <= S_MAIN_INIT; // read samples at 000 first
  end
  else begin
    P <= P_next;
  end
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // Delay 10 us.
	   if (init_counter < 1000) P_next = S_MAIN_INIT;
		else P_next = S_MAIN_WAIT;
    S_MAIN_WAIT: 
      if(btn_pressed) P_next = S_MAIN_ADDR;
      else P_next = S_MAIN_WAIT;
    S_MAIN_ADDR: // send an address to the SRAM 
      P_next = S_MAIN_READ;
    S_MAIN_READ: // fetch the sample from the SRAM
      if(g_counter==6'd63) P_next = S_MAIN_ADDR2;
      else P_next = S_MAIN_ADDR;
    S_MAIN_ADDR2:
      P_next = S_MAIN_READ2;
    S_MAIN_READ2:
      if(f_counter>=10'd63) P_next = S_MAIN_CAL;
      else P_next = S_MAIN_ADDR2;
    S_MAIN_CAL:
       P_next = S_MAIN_CAL2;
    S_MAIN_CAL2:
      if(multiple_counter==6'd63) P_next = S_MAIN_COMPARE;
      else P_next = S_MAIN_CAL;
    S_MAIN_COMPARE:
      if(f_counter==10'd1022) P_next = S_MAIN_SHOW;
      else P_next = S_MAIN_ADDR2; 
    S_MAIN_SHOW:
      P_next = S_MAIN_SHOW;

  endcase
end

always @(posedge clk) begin
  if (P == S_MAIN_INIT) init_counter <= init_counter + 1;
  else init_counter <= 0;
end


always @(posedge clk) begin
  if (~reset_n) 
    g_counter <= 6'd0;
  else if (P==S_MAIN_READ)
    g_counter <= g_counter+6'd1;
  else
    g_counter<=g_counter;
end

always @(posedge clk) begin
  if (~reset_n) 
    f_counter <= 10'd0;
  else if (P==S_MAIN_READ2)
    f_counter <= f_counter+10'd1;
  else
    f_counter<=f_counter;
end
  
integer idx;
// FSM ouput logic: Fetch the data bus of sram[] for display
always @(posedge clk) begin
  if (~reset_n) for(idx = 0; idx < 64; idx = idx + 1) g_function[idx] = 8'd0 ;
  else if (P==S_MAIN_READ && !sram_we) g_function[g_counter] <= data_out;
end

integer jdx,kdx;
// FSM ouput logic: Fetch the data bus of sram[] for display
always @(posedge clk) begin
  if (~reset_n) for(jdx = 0; jdx < 64; jdx = jdx + 1) f_function[jdx] = 8'd0 ;
  else if (P==S_MAIN_READ2 && !sram_we && f_counter<10'd64) f_function[f_counter] <= data_out;
  else if (P==S_MAIN_READ2 && !sram_we && f_counter>=10'd64) begin
    for(kdx = 0; kdx < 63; kdx = kdx + 1) f_function[kdx] = f_function[kdx+1];
    f_function[63] <= data_out;
  end
end
// End of the main controller
// ------------------------------------------------------------------------

always @(posedge clk) begin
  if (~reset_n)
    mul<=24'd0;
  else if (P==S_MAIN_CAL2) mul<=24'd0;
  else if (P==S_MAIN_CAL) mul<=f_function[multiple_counter] * g_function[multiple_counter];
  else mul<=mul;
end
always @(posedge clk) begin
  if (~reset_n) 
    sum<=24'd0;
  else if (P==S_MAIN_READ2)
    sum<=24'd0;
  else if (P==S_MAIN_CAL2)
    sum <= sum + mul;
  else 
    sum <= sum;
end

always @(posedge clk) begin
  if (~reset_n)
    multiple_counter <= 6'd0;
  else if(P==S_MAIN_READ2)
    multiple_counter <= 6'd0;
  else if(P==S_MAIN_CAL2)
    multiple_counter <= multiple_counter + 1; 
  else
    multiple_counter <= multiple_counter;
end

always @(posedge clk) begin
  if (~reset_n) begin
    max_adress <= 10'd0;
    max <= 24'd0;
  end
  else if (P==S_MAIN_COMPARE)
    if(sum>=max) begin
      max<=sum;
      max_adress <= f_counter - 64;
    end
end

// ------------------------------------------------------------------------
// The following code updates the 1602 LCD text messages.
always @(posedge clk) begin
  if (~reset_n) 
    row_A <= "Press BTN0 to do";
  else if(P== S_MAIN_WAIT) 
    row_A <= "Press BTN0 to do";
  else if (P == S_MAIN_SHOW) begin
    row_A[127:48]<="Max value ";  
    row_A[47:40] <= ((max[23:20] > 9)? "7" : "0") + max[23:20];
    row_A[39:32] <= ((max[19:16] > 9)? "7" : "0") + max[19:16] ;
    row_A[31:24] <= ((max[15:12]  > 9)? "7" : "0") + max[15:12];
    row_A[23:16] <= ((max[11:8] > 9)? "7" : "0") + max[11:8];
    row_A[15:8] <= ((max[7:4] > 9)? "7" : "0") + max[7:4];
    row_A[7:0] <= ((max[3:0] > 9)? "7" : "0") + max[3:0];
  end
end


always @(posedge clk) begin
  if (~reset_n) 
    row_B <= "x-correlation...";
  else if(P== S_MAIN_WAIT) 
    row_B <= "x-correlation...";
  else if (P == S_MAIN_SHOW) begin
    row_B[127:24] <="Max location " ;
    row_B[23:16] <= ((max_adress[9:8] > 9)? "7" : "0") + max_adress[9:8];
    row_B[15:8] <= ((max_adress[7:4] > 9)? "7" : "0") + max_adress[7:4];
    row_B[7:0] <= ((max_adress[3:0] > 9)? "7" : "0") + max_adress[3:0];
  end
end
// End of the 1602 LCD text-updating code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// The circuit block that processes the user's button event.
always @(posedge clk) begin
  if (~reset_n)
    sample_addr <= 12'h400;
  else if(sample_addr==12'h43F && P==S_MAIN_READ)
    sample_addr <= 12'h000;
  else if (P==S_MAIN_READ || P==S_MAIN_READ2)
    sample_addr <=  sample_addr + 1;
  else 
    sample_addr <= sample_addr;
end
// End of the user's button control.
// ------------------------------------------------------------------------

endmodule
