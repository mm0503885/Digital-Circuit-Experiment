`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of CS, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2017/04/27 15:06:57
// Design Name: UART I/O example for Arty
// Module Name: 0316041_lab7
// Project Name: 
// Target Devices: Xilinx FPGA @ 100MHz
// Tool Versions: 
// Description: 
// 
// The parameters for the UART controller are 9600 baudrate, 8-N-1-N
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab7(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,
  input  uart_rx,
  output uart_tx,
  
  output spi_ss,
  output spi_sck,
  output spi_mosi,
  input  spi_miso
);

localparam [3:0] S_MAIN_INIT = 0, S_MAIN_WAIT_KEY = 1,
                 S_MAIN_WAIT = 2, S_MAIN_READ = 3,
                 S_MAIN_DONE = 4, S_MAIN_SHOW = 5,
                 S_MAIN_TRANSFER = 6, S_MAIN_CAL = 7,
                 S_MAIN_DIVIDE = 8, S_MAIN_HELLO = 9,
                 S_MAIN_FINISH = 10;
localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
                 S_UART_SEND = 2, S_UART_INCR = 3;

// declare system variables
wire print_enable, print_done;
reg [7:0] send_counter;
reg [3:0] P, P_next;
reg [1:0] Q, Q_next;

reg  [9:0] sd_counter;
reg  [7:0] data_byte;
reg  [31:0] blk_addr;


reg  [2:0] matx_tag_state;
reg  matx_tag_found;
reg  [7:0] element [0:63];
reg  [5:0] element_counter;
reg  [4:0] element_counter2;
reg  store_done;
reg  [7:0] true_element [0:31];
reg  transfer_done;

reg [17:0] ans_matrix [0:15];
reg  cal_done;
reg  [3:0] mul_counter;

reg divide_done;

// Declare SD card interface signals
wire clk_sel;
wire clk_500k;
reg  rd_req;
reg  [31:0] rd_addr;
wire init_finished;
wire [7:0] sd_dout;
wire sd_valid;

// Declare the control/data signals of an SRAM memory block
wire [7:0] data_in;
wire [7:0] data_out;
wire [8:0] sram_addr;
wire       sram_we, sram_en;

assign clk_sel = (init_finished)? clk : clk_500k; // clock for the SD controller

// declare UART signals
wire transmit;
wire received;
wire [7:0] rx_byte;
reg  [7:0] rx_temp;
wire [7:0] tx_byte;
wire is_receiving;
wire is_transmitting;
wire recv_error;

wire btn_level, btn_pressed;
reg  prev_btn_level;

clk_divider#(200) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(clk_500k)
);

sd_card sd_card0(
  .cs(spi_ss),
  .sclk(spi_sck),
  .mosi(spi_mosi),
  .miso(spi_miso),

  .clk(clk_sel),
  .rst(~reset_n),
  .rd_req(rd_req),
  .block_addr(rd_addr),
  .init_finished(init_finished),
  .dout(sd_dout),
  .sd_valid(sd_valid)
);

sram ram0(
  .clk(clk),
  .we(sram_we),
  .en(sram_en),
  .addr(sram_addr),
  .data_i(data_in),
  .data_o(data_out)
);
/* The UART device takes a 100MHz clock to handle I/O at 9600 baudrate */
uart uart(
  .clk(clk),
  .rst(~reset_n),
  .rx(uart_rx),
  .tx(uart_tx),
  .transmit(transmit),
  .tx_byte(tx_byte),
  .received(received),
  .rx_byte(rx_byte),
  .is_receiving(is_receiving),
  .is_transmitting(is_transmitting),
  .recv_error(recv_error)
);

debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level)
);

// ------------------------------------------------------------------------
// The following code sets the control signals of an SRAM memory block
// that is connected to the data output port of the SD controller.
// Once the read request is made to the SD controller, 512 bytes of data
// will be sequentially read into the SRAM memory block, one byte per
// clock cycle (as long as the sd_valid signal is high).
assign sram_we = sd_valid;          // Write data into SRAM when sd_valid is high.
assign sram_en = 1;                 // Always enable the SRAM block.
assign data_in = sd_dout;           // Input data always comes from the SD controller.
assign sram_addr = sd_counter[8:0]; // Set the driver of the SRAM address signal.
// End of the SRAM memory block
// ------------------------------------------------------------------------


// Initializes some strings.
// System Verilog has an easier way to initialize an array,
// but we are using Verilog 2005 :(
//
localparam MEM_SIZE = 147;
localparam PROMPT_STR = 0;
reg [7:0] data[0:MEM_SIZE-1];

initial begin
  { data[ 0], data[ 1], data[ 2], data[ 3], data[ 4], data[ 5], data[ 6], data[ 7],
    data[ 8], data[ 9], data[10], data[11], data[12], data[13], data[14], data[15] }
  <= {"The result is:",8'h0D, 8'h0A };
  
end

assign usr_led = usr_btn;

// ------------------------------------------------------------------------
// Main FSM that reads the UART input and triggers
// the output of the string "Hello, World!".
always @(posedge clk) begin
  if (~reset_n) P <= S_MAIN_INIT;
  else P <= P_next;
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // wait for SD card initialization
	  if (init_finished == 1) P_next =  S_MAIN_WAIT_KEY;
       else P_next = S_MAIN_INIT;
    S_MAIN_WAIT_KEY: // wait for BTN[1] key.
      if (btn_pressed) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_WAIT_KEY;
    S_MAIN_WAIT: // issue a rd_req to the SD controller until it's ready
      P_next = S_MAIN_READ;
    S_MAIN_READ: // wait for the input data to enter the SRAM buffer
      if (sd_counter == 512) P_next = S_MAIN_DONE;
      else P_next = S_MAIN_READ;
    S_MAIN_DONE: // read byte 0 of the superblock from sram[]
      if(store_done) P_next = S_MAIN_TRANSFER;
      else P_next = S_MAIN_SHOW;
    S_MAIN_SHOW:
      if (sd_counter < 512) P_next = S_MAIN_DONE;
      else P_next = S_MAIN_WAIT;
    S_MAIN_TRANSFER:
      if(transfer_done) P_next = S_MAIN_CAL;
      else P_next = S_MAIN_TRANSFER;
    S_MAIN_CAL:
      if(cal_done) P_next = S_MAIN_DIVIDE;
      else P_next = S_MAIN_CAL;
    S_MAIN_DIVIDE:
      if(divide_done) P_next = S_MAIN_HELLO;
      else P_next = S_MAIN_DIVIDE;
    S_MAIN_HELLO: // Print the hello message.
      if (print_done) P_next = S_MAIN_FINISH;
      else P_next = S_MAIN_HELLO;
    S_MAIN_FINISH:
      P_next=S_MAIN_FINISH;
    default:
      P_next = S_MAIN_WAIT_KEY;  
      
  endcase
end

// FSM output logic: controls the 'rd_req' and 'rd_addr' signals.
always @(*) begin
  rd_req = (P == S_MAIN_WAIT);
  rd_addr = blk_addr;
end

always @(posedge clk) begin
  if (~reset_n) 
    blk_addr <= 32'h2000;
  else if(P == S_MAIN_SHOW && P_next == S_MAIN_WAIT)
    blk_addr <= blk_addr+32'd1; // In lab 6, change this line to scan all blocks
  else
    blk_addr <= blk_addr;
end

// FSM output logic: controls the 'sd_counter' signal.
// SD card read address incrementer
always @(posedge clk) begin
  if (~reset_n || (P == S_MAIN_READ && P_next == S_MAIN_DONE) ||(P == S_MAIN_SHOW && P_next == S_MAIN_WAIT) )
    sd_counter <= 0;
  else if ((P == S_MAIN_READ && sd_valid) ||
           (P == S_MAIN_DONE))
    sd_counter <= sd_counter + 1;
end

// FSM ouput logic: Retrieves the content of sram[] for display
always @(posedge clk) begin
  if (~reset_n) data_byte <= 8'b0;
  else if (sram_en && P == S_MAIN_DONE) data_byte <= data_out;
end
// End of the FSM of the SD card reader

always @(posedge clk) begin
  if (~reset_n) begin
    matx_tag_state<=3'd0;
	matx_tag_found<=1'b0;
  end
  else begin
    if(P==S_MAIN_SHOW && (!matx_tag_found)) begin
	  case(matx_tag_state)
	    3'd0:
		  if(data_byte=="M") matx_tag_state<=3'd1;
		  else matx_tag_state<=3'd0;
		3'd1:
		  if(data_byte=="A") matx_tag_state<=3'd2;
		  else matx_tag_state<=3'd0;
		3'd2:
		  if(data_byte=="T") matx_tag_state<=3'd3;
		  else matx_tag_state<=3'd0;
		3'd3:
		  if(data_byte=="X") matx_tag_state<=3'd4;
		  else matx_tag_state<=3'd0;
		3'd4:
		  if(data_byte=="_") matx_tag_state<=3'd5;
		  else matx_tag_state<=3'd0;
		3'd5:
		  if(data_byte=="T") matx_tag_state<=3'd6;
		  else matx_tag_state<=3'd0;
		3'd6:
		  if(data_byte=="A") matx_tag_state<=3'd7;
		  else matx_tag_state<=3'd0;
		3'd7:
		  if(data_byte=="G") matx_tag_found<=1'b1;
		  else matx_tag_state<=3'd0;
      endcase
    end
  end
end

integer idx1;

always @(posedge clk) begin
  if (~reset_n) begin
    element_counter<=6'd0;
    store_done<=1'd0;
	for (idx1 = 0; idx1 < 64; idx1 = idx1 + 1) element[idx1] = 8'd0;
  end
  else begin
      if((P==S_MAIN_SHOW) && (matx_tag_found==1'b1) &&(!store_done)) begin
        if(data_byte!=8'h0A && data_byte!=8'h0D) begin
          element[element_counter]<=data_byte;
          element_counter<=element_counter+6'd1;
          if(element_counter==6'd63) store_done<=1'd1;
        end
      end      
  end
end  

integer idx2;

always @(posedge clk) begin
  if (~reset_n) begin
	transfer_done<=1'd0;
    element_counter2<=5'd0;
	for (idx2 = 0; idx2 < 32; idx2 = idx2 + 1) true_element[idx2] = 8'd0;
  end
  else begin
    if(P==S_MAIN_TRANSFER && (!transfer_done))begin
        true_element[element_counter2][7:4]<=element[element_counter2+element_counter2]-((element[element_counter2+element_counter2]>="7")? "7" : "0");
        true_element[element_counter2][3:0]<=element[element_counter2+element_counter2+1]-((element[element_counter2+element_counter2+1]>="7")? "7" : "0");
        element_counter2<=element_counter2+5'd1;
        if(element_counter2==5'd31) transfer_done<=1'd1;
    end
  end
end

integer idx3;

always @(posedge clk) begin
  if (~reset_n) begin
	cal_done<=1'd0;
    mul_counter<=4'd0;
	for (idx3 = 0; idx3 < 16; idx3 = idx3 + 1) ans_matrix[idx3] = 8'd0;
  end  
  else begin
    if(P==S_MAIN_CAL && (!cal_done))begin
	  case(mul_counter)
      4'd0: begin
        ans_matrix[0]<=true_element[0]*true_element[16];
        ans_matrix[1]<=true_element[0]*true_element[17];
        ans_matrix[2]<=true_element[0]*true_element[18];
        ans_matrix[3]<=true_element[0]*true_element[19];
		mul_counter<=4'd1;
	  end
	  4'd1: begin
		ans_matrix[4]<=true_element[4]*true_element[16];
        ans_matrix[5]<=true_element[4]*true_element[17];
        ans_matrix[6]<=true_element[4]*true_element[18];
        ans_matrix[7]<=true_element[4]*true_element[19];
		mul_counter<=4'd2;
	  end
      4'd2: begin
		ans_matrix[8]<=true_element[8]*true_element[16];
        ans_matrix[9]<=true_element[8]*true_element[17];
        ans_matrix[10]<=true_element[8]*true_element[18];
        ans_matrix[11]<=true_element[8]*true_element[19];
		mul_counter<=4'd3;
	  end
	  4'd3: begin
		ans_matrix[12]<=true_element[12]*true_element[16];
        ans_matrix[13]<=true_element[12]*true_element[17];
        ans_matrix[14]<=true_element[12]*true_element[18];
        ans_matrix[15]<=true_element[12]*true_element[19];
        mul_counter<=4'd4;
      end
      4'd4: begin
	    ans_matrix[0]<=ans_matrix[0]+true_element[1]*true_element[20];
        ans_matrix[1]<=ans_matrix[1]+true_element[1]*true_element[21];
        ans_matrix[2]<=ans_matrix[2]+true_element[1]*true_element[22];
        ans_matrix[3]<=ans_matrix[3]+true_element[1]*true_element[23];
		mul_counter<=4'd5;
      end
	  4'd5: begin
		ans_matrix[4]<=ans_matrix[4]+true_element[5]*true_element[20];
        ans_matrix[5]<=ans_matrix[5]+true_element[5]*true_element[21];
        ans_matrix[6]<=ans_matrix[6]+true_element[5]*true_element[22];
        ans_matrix[7]<=ans_matrix[7]+true_element[5]*true_element[23];
		mul_counter<=4'd6;
	  end
	  4'd6: begin	
		ans_matrix[8]<=ans_matrix[8]+true_element[9]*true_element[20];
        ans_matrix[9]<=ans_matrix[9]+true_element[9]*true_element[21];
        ans_matrix[10]<=ans_matrix[10]+true_element[9]*true_element[22];
        ans_matrix[11]<=ans_matrix[11]+true_element[9]*true_element[23];
		mul_counter<=4'd7;
      end
      4'd7: begin	  
		ans_matrix[12]<=ans_matrix[12]+true_element[13]*true_element[20];
        ans_matrix[13]<=ans_matrix[13]+true_element[13]*true_element[21];
        ans_matrix[14]<=ans_matrix[14]+true_element[13]*true_element[22];
        ans_matrix[15]<=ans_matrix[15]+true_element[13]*true_element[23];
		mul_counter<=4'd8;

      end
      4'd8: begin
	    ans_matrix[0]<=ans_matrix[0]+true_element[2]*true_element[24];
        ans_matrix[1]<=ans_matrix[1]+true_element[2]*true_element[25];
        ans_matrix[2]<=ans_matrix[2]+true_element[2]*true_element[26];
        ans_matrix[3]<=ans_matrix[3]+true_element[2]*true_element[27];
		mul_counter<=4'd9;
      end
      4'd9: begin	  
		ans_matrix[4]<=ans_matrix[4]+true_element[6]*true_element[24];
        ans_matrix[5]<=ans_matrix[5]+true_element[6]*true_element[25];
        ans_matrix[6]<=ans_matrix[6]+true_element[6]*true_element[26];
        ans_matrix[7]<=ans_matrix[7]+true_element[6]*true_element[27];
		mul_counter<=4'd10;
      end
	  4'd10: begin	  
		ans_matrix[8]<=ans_matrix[8]+true_element[10]*true_element[24];
        ans_matrix[9]<=ans_matrix[9]+true_element[10]*true_element[25];
        ans_matrix[10]<=ans_matrix[10]+true_element[10]*true_element[26];
        ans_matrix[11]<=ans_matrix[11]+true_element[10]*true_element[27];
		mul_counter<=4'd11;
      end
      4'd11: begin	  
		ans_matrix[12]<=ans_matrix[12]+true_element[14]*true_element[24];
        ans_matrix[13]<=ans_matrix[13]+true_element[14]*true_element[25];
        ans_matrix[14]<=ans_matrix[14]+true_element[14]*true_element[26];
        ans_matrix[15]<=ans_matrix[15]+true_element[14]*true_element[27];
        mul_counter<=4'd12;
      end
      4'd12: begin	 
        ans_matrix[0]<=ans_matrix[0]+true_element[3]*true_element[28];
        ans_matrix[1]<=ans_matrix[1]+true_element[3]*true_element[29];
        ans_matrix[2]<=ans_matrix[2]+true_element[3]*true_element[30];
        ans_matrix[3]<=ans_matrix[3]+true_element[3]*true_element[31];
		mul_counter<=4'd13;
      end
      4'd13: begin	 	  
		ans_matrix[4]<=ans_matrix[4]+true_element[7]*true_element[28];
        ans_matrix[5]<=ans_matrix[5]+true_element[7]*true_element[29];
        ans_matrix[6]<=ans_matrix[6]+true_element[7]*true_element[30];
        ans_matrix[7]<=ans_matrix[7]+true_element[7]*true_element[31];
		mul_counter<=4'd14;
      end
      4'd14: begin	 	  
	   ans_matrix[8]<=ans_matrix[8]+true_element[11]*true_element[28];
       ans_matrix[9]<=ans_matrix[9]+true_element[11]*true_element[29];
       ans_matrix[10]<=ans_matrix[10]+true_element[11]*true_element[30];
       ans_matrix[11]<=ans_matrix[11]+true_element[11]*true_element[31];
	   mul_counter<=4'd15;
	  end
      4'd15: begin	
		ans_matrix[12]<=ans_matrix[12]+true_element[15]*true_element[28];
        ans_matrix[13]<=ans_matrix[13]+true_element[15]*true_element[29];
        ans_matrix[14]<=ans_matrix[14]+true_element[15]*true_element[30];
        ans_matrix[15]<=ans_matrix[15]+true_element[15]*true_element[31];
        cal_done<=1'd1;
      end
	  endcase
    end
  end
end
 
integer idx4;
 
always @(posedge clk) begin
  if (~reset_n) begin
	divide_done<=1'd0;
	for (idx4 = 16; idx4 < 147; idx4 = idx4 + 1) data[idx4] = 8'd0;
  end  
  else begin
    if(P==S_MAIN_DIVIDE && (!divide_done)) begin
      data[18]<=ans_matrix[0][17:16]+"0";
      data[19]<=((ans_matrix[0][15:12] > 9)? "7" : "0") + ans_matrix[0][15:12];
      data[20]<=((ans_matrix[0][11:8] > 9)? "7" : "0") + ans_matrix[0][11:8];
      data[21]<=((ans_matrix[0][7:4] > 9)? "7" : "0") + ans_matrix[0][7:4];
      data[22]<=((ans_matrix[0][3:0] > 9)? "7" : "0") + ans_matrix[0][3:0];
      data[25]<=ans_matrix[1][17:16]+"0";
      data[26]<=((ans_matrix[1][15:12] > 9)? "7" : "0") + ans_matrix[1][15:12];
      data[27]<=((ans_matrix[1][11:8] > 9)? "7" : "0") + ans_matrix[1][11:8];
      data[28]<=((ans_matrix[1][7:4] > 9)? "7" : "0") + ans_matrix[1][7:4];
      data[29]<=((ans_matrix[1][3:0] > 9)? "7" : "0") + ans_matrix[1][3:0];
      data[32]<=ans_matrix[2][17:16]+"0";
      data[33]<=((ans_matrix[2][15:12] > 9)? "7" : "0") + ans_matrix[2][15:12];
      data[34]<=((ans_matrix[2][11:8] > 9)? "7" : "0") + ans_matrix[2][11:8];
      data[35]<=((ans_matrix[2][7:4] > 9)? "7" : "0") + ans_matrix[2][7:4];
      data[36]<=((ans_matrix[2][3:0] > 9)? "7" : "0") + ans_matrix[2][3:0];
      data[39]<=ans_matrix[3][17:16]+"0";
      data[40]<=((ans_matrix[3][15:12] > 9)? "7" : "0") + ans_matrix[3][15:12];
      data[41]<=((ans_matrix[3][11:8] > 9)? "7" : "0") + ans_matrix[3][11:8];
      data[42]<=((ans_matrix[3][7:4] > 9)? "7" : "0") + ans_matrix[3][7:4];
      data[43]<=((ans_matrix[3][3:0] > 9)? "7" : "0") + ans_matrix[3][3:0];
      data[50]<=ans_matrix[4][17:16]+"0";
      data[51]<=((ans_matrix[4][15:12] > 9)? "7" : "0") + ans_matrix[4][15:12];
      data[52]<=((ans_matrix[4][11:8] > 9)? "7" : "0") + ans_matrix[4][11:8];
      data[53]<=((ans_matrix[4][7:4] > 9)? "7" : "0") + ans_matrix[4][7:4];
      data[54]<=((ans_matrix[4][3:0] > 9)? "7" : "0") + ans_matrix[4][3:0];
      data[57]<=ans_matrix[5][17:16]+"0";
      data[58]<=((ans_matrix[5][15:12] > 9)? "7" : "0") + ans_matrix[5][15:12];
      data[59]<=((ans_matrix[5][11:8] > 9)? "7" : "0") + ans_matrix[5][11:8];
      data[60]<=((ans_matrix[5][7:4] > 9)? "7" : "0") + ans_matrix[5][7:4];
      data[61]<=((ans_matrix[5][3:0] > 9)? "7" : "0") + ans_matrix[5][3:0];
      data[64]<=ans_matrix[6][17:16]+"0";
      data[65]<=((ans_matrix[6][15:12] > 9)? "7" : "0") + ans_matrix[6][15:12];
      data[66]<=((ans_matrix[6][11:8] > 9)? "7" : "0") + ans_matrix[6][11:8];
      data[67]<=((ans_matrix[6][7:4] > 9)? "7" : "0") + ans_matrix[6][7:4];
      data[68]<=((ans_matrix[6][3:0] > 9)? "7" : "0") + ans_matrix[6][3:0];
      data[71]<=ans_matrix[7][17:16]+"0";
      data[72]<=((ans_matrix[7][15:12] > 9)? "7" : "0") + ans_matrix[7][15:12];
      data[73]<=((ans_matrix[7][11:8] > 9)? "7" : "0") + ans_matrix[7][11:8];
      data[74]<=((ans_matrix[7][7:4] > 9)? "7" : "0") + ans_matrix[7][7:4];
      data[75]<=((ans_matrix[7][3:0] > 9)? "7" : "0") + ans_matrix[7][3:0];
      data[82]<=ans_matrix[8][17:16]+"0";
      data[83]<=((ans_matrix[8][15:12] > 9)? "7" : "0") + ans_matrix[8][15:12];
      data[84]<=((ans_matrix[8][11:8] > 9)? "7" : "0") + ans_matrix[8][11:8];
      data[85]<=((ans_matrix[8][7:4] > 9)? "7" : "0") + ans_matrix[8][7:4];
      data[86]<=((ans_matrix[8][3:0] > 9)? "7" : "0") + ans_matrix[8][3:0];
      data[89]<=ans_matrix[9][17:16]+"0";
      data[90]<=((ans_matrix[9][15:12] > 9)? "7" : "0") + ans_matrix[9][15:12];
      data[91]<=((ans_matrix[9][11:8] > 9)? "7" : "0") + ans_matrix[9][11:8];
      data[92]<=((ans_matrix[9][7:4] > 9)? "7" : "0") + ans_matrix[9][7:4];
      data[93]<=((ans_matrix[9][3:0] > 9)? "7" : "0") + ans_matrix[9][3:0];
      data[96]<=ans_matrix[10][17:16]+"0";
      data[97]<=((ans_matrix[10][15:12] > 9)? "7" : "0") + ans_matrix[10][15:12];
      data[98]<=((ans_matrix[10][11:8] > 9)? "7" : "0") + ans_matrix[10][11:8];
      data[99]<=((ans_matrix[10][7:4] > 9)? "7" : "0") + ans_matrix[10][7:4];
      data[100]<=((ans_matrix[10][3:0] > 9)? "7" : "0") + ans_matrix[10][3:0];
      data[103]<=ans_matrix[11][17:16]+"0";
      data[104]<=((ans_matrix[11][15:12] > 9)? "7" : "0") + ans_matrix[11][15:12];
      data[105]<=((ans_matrix[11][11:8] > 9)? "7" : "0") + ans_matrix[11][11:8];
      data[106]<=((ans_matrix[11][7:4] > 9)? "7" : "0") + ans_matrix[11][7:4];
      data[107]<=((ans_matrix[11][3:0] > 9)? "7" : "0") + ans_matrix[11][3:0];
      data[114]<=ans_matrix[12][17:16]+"0";
      data[115]<=((ans_matrix[12][15:12] > 9)? "7" : "0") + ans_matrix[12][15:12];
      data[116]<=((ans_matrix[12][11:8] > 9)? "7" : "0") + ans_matrix[12][11:8];
      data[117]<=((ans_matrix[12][7:4] > 9)? "7" : "0") + ans_matrix[12][7:4];
      data[118]<=((ans_matrix[12][3:0] > 9)? "7" : "0") + ans_matrix[12][3:0];
      data[121]<=ans_matrix[13][17:16]+"0";
      data[122]<=((ans_matrix[13][15:12] > 9)? "7" : "0") + ans_matrix[13][15:12];
      data[123]<=((ans_matrix[13][11:8] > 9)? "7" : "0") + ans_matrix[13][11:8];
      data[124]<=((ans_matrix[13][7:4] > 9)? "7" : "0") + ans_matrix[13][7:4];
      data[125]<=((ans_matrix[13][3:0] > 9)? "7" : "0") + ans_matrix[13][3:0];
      data[128]<=ans_matrix[14][17:16]+"0";
      data[129]<=((ans_matrix[14][15:12] > 9)? "7" : "0") + ans_matrix[14][15:12];
      data[130]<=((ans_matrix[14][11:8] > 9)? "7" : "0") + ans_matrix[14][11:8];
      data[131]<=((ans_matrix[14][7:4] > 9)? "7" : "0") + ans_matrix[14][7:4];
      data[132]<=((ans_matrix[14][3:0] > 9)? "7" : "0") + ans_matrix[14][3:0];
      data[135]<=ans_matrix[15][17:16]+"0";
      data[136]<=((ans_matrix[15][15:12] > 9)? "7" : "0") + ans_matrix[15][15:12];
      data[137]<=((ans_matrix[15][11:8] > 9)? "7" : "0") + ans_matrix[15][11:8];
      data[138]<=((ans_matrix[15][7:4] > 9)? "7" : "0") + ans_matrix[15][7:4];
      data[139]<=((ans_matrix[15][3:0] > 9)? "7" : "0") + ans_matrix[15][3:0];
	   { data[16], data[48], data[80], data[112] }  
  <= {"[[[[" };
  { data[17], data[24], data[31], data[38], data[44], data[49], data[56], data[63],
    data[70], data[76], data[81], data[88], data[95], data[102], data[108], data[113],
    data[120], data[127], data[134], data[140]     }
  <= {"                    "};
  { data[23], data[30], data[37], data[55], data[62], data[69], data[87], data[94],
    data[101], data[119], data[126], data[133]}
  <= {",,,,,,,,,,,,"};
  { data[45], data[77], data[109], data[141] }  
  <= {"]]]]" };
  { data[46], data[78], data[110], data[142],data[144]}  
  <= {8'h0D,8'h0D,8'h0D,8'h0D,8'h0D };
  { data[47], data[79], data[111], data[143],data[145],data[146]}  
  <= {8'h0A,8'h0A,8'h0A,8'h0A,8'h0A,8'h00 };
      divide_done<=1'd1;
    end
  end
end
// ------------------------------------------------------------------------

// FSM output logics: print string control signals.
assign print_enable =  (P == S_MAIN_DIVIDE && P_next == S_MAIN_HELLO) ;
assign print_done = (tx_byte == 8'h0);


// End of the FSM of the print string controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the controller to send a string to the UART.
always @(posedge clk) begin
  if (~reset_n) Q <= S_UART_IDLE;
  else Q <= Q_next;
end

always @(*) begin // FSM next-state logic
  case (Q)
    S_UART_IDLE: // wait for the print_string flag
      if (print_enable) Q_next = S_UART_WAIT;
      else Q_next = S_UART_IDLE;
    S_UART_WAIT: // wait for the transmission of current data byte begins
      if (is_transmitting == 1) Q_next = S_UART_SEND;
      else Q_next = S_UART_WAIT;
    S_UART_SEND: // wait for the transmission of current data byte finishes
      if (is_transmitting == 0) Q_next = S_UART_INCR; // transmit next character
      else Q_next = S_UART_SEND;
    S_UART_INCR:
      if (tx_byte == 8'h0) Q_next = S_UART_IDLE; // string transmission ends
      else Q_next = S_UART_WAIT;
  endcase
end

// FSM output logics
assign transmit = (Q_next == S_UART_WAIT || print_enable);
assign tx_byte = data[send_counter];

// UART send_counter control circuit
always @(posedge clk) begin
  if (~reset_n) send_counter <= PROMPT_STR;
  else begin  
	case (P_next)
    S_MAIN_WAIT_KEY: send_counter <= PROMPT_STR;
    default: send_counter <= send_counter + (Q_next == S_UART_INCR);
    endcase
  end
end
// End of the FSM of the print string controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// The following logic stores the UART input in a temporary buffer.
// ------------------------------------------------------------------------

always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 0;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level == 1 && prev_btn_level == 0)? 1 : 0;

endmodule
