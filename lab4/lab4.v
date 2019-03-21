`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of CS, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2017/04/27 15:06:57
// Design Name: UART I/O example for Arty
// Module Name: lab4
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

module lab4(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,
  input  uart_rx,
  output uart_tx
);

localparam [2:0] S_MAIN_INIT = 0, S_MAIN_PROMPT = 1,
                 S_MAIN_WAIT_KEY = 2, S_MAIN_PROMPT2 = 3,S_MAIN_WAIT_KEY2=4,S_MAIN_CAL=5,S_MAIN_ANS=6;
localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
                 S_UART_SEND = 2, S_UART_INCR = 3;

// declare system variables
wire print_enable, print_done;
wire enter_pressed;
reg [6:0] send_counter;
reg [2:0] P, P_next;
reg [1:0] Q, Q_next;
reg [23:0] init_counter;
reg [15:0] num1;
reg [15:0] num2;
reg [15:0] temp;
reg [15:0] ans;
reg cal_done;
// declare UART signals
wire transmit;
wire received;
wire [7:0] rx_byte;
reg  [7:0] rx_temp;
wire [7:0] tx_byte;
wire is_receiving;
wire is_transmitting;
wire recv_error;

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

// Initializes some strings.
// System Verilog has an easier way to initialize an array,
// but we are using Verilog 2005 :(
//
localparam MEM_SIZE = 92;
localparam PROMPT_STR = 0;
localparam PROMPT2_STR = 35;
localparam ANS_STR = 71;
reg [7:0] data[0:MEM_SIZE-1];

initial begin
  { data[ 0], data[ 1], data[ 2], data[ 3], data[ 4], data[ 5], data[ 6], data[ 7],
    data[ 8], data[ 9], data[10], data[11], data[12], data[13], data[14], data[15],
    data[ 16], data[ 17], data[18], data[19], data[20], data[21], data[22], data[23],
    data[ 24], data[ 25], data[26], data[27], data[28], data[29], data[30], data[31],
    data[ 32], data[ 33], data[34]}
  <= { 8'h0D, 8'h0A, "Enter the first decimal number: ", 8'h00 };

  { data[35], data[36], data[37], data[38], data[39], data[40], data[41], data[42], data[43],data[44],
    data[45], data[46], data[47], data[48], data[49], data[50], data[51], data[52], data[53],data[54],
    data[55], data[56], data[57], data[58], data[59], data[60], data[61], data[62], data[63],data[64],
    data[65], data[66], data[67], data[68], data[69], data[70]}

  <= { 8'h0D, 8'h0A, "Enter the second decimal number: ",8'h00 };
  
  { data[71], data[72], data[73], data[74], data[75], data[76], data[77], data[78], data[79],data[80],
    data[81], data[82], data[83], data[84], data[85], data[86], data[91]} 
  <={ 8'h0D, 8'h0A, "The GCD is: 0x",8'h00 };
end

// Combinational I/O logics
assign usr_led = usr_btn;
assign enter_pressed = (rx_temp == 8'h0D);

// ------------------------------------------------------------------------
// Main FSM that reads the UART input and triggers
// the output of the string "Hello, World!".
always @(posedge clk) begin
  if (~reset_n) P <= S_MAIN_INIT;
  else P <= P_next;
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // Delay 10 us.
	   if (init_counter < 1000) P_next = S_MAIN_INIT;
		else P_next = S_MAIN_PROMPT;
    S_MAIN_PROMPT: // Print the prompt1 message.
      if (print_done) P_next = S_MAIN_WAIT_KEY;
      else P_next = S_MAIN_PROMPT;
    S_MAIN_WAIT_KEY: // wait for first decimal number.
      if (enter_pressed) P_next = S_MAIN_PROMPT2;
      else P_next = S_MAIN_WAIT_KEY;
    S_MAIN_PROMPT2: // Print the prompt2 message.
      if (print_done) P_next = S_MAIN_WAIT_KEY2;
      else P_next = S_MAIN_PROMPT2;
    S_MAIN_WAIT_KEY2: // wait for second decimal number.
      if (enter_pressed) P_next = S_MAIN_CAL;
      else P_next = S_MAIN_WAIT_KEY2;
    S_MAIN_CAL: // caculate gcd.
      if (cal_done) P_next = S_MAIN_ANS;
      else P_next = S_MAIN_CAL;
    S_MAIN_ANS: // print answer.
      if (print_done) P_next = S_MAIN_INIT;
      else P_next = S_MAIN_ANS;
  endcase
end

// FSM output logics: print string control signals.
assign print_enable = (P != S_MAIN_PROMPT && P_next == S_MAIN_PROMPT) || (P == S_MAIN_WAIT_KEY && P_next == S_MAIN_PROMPT2) 
                        || (P == S_MAIN_CAL && P_next == S_MAIN_ANS);
assign print_done = (tx_byte == 8'h0);

// Initialization counter.
always @(posedge clk) begin
  if (P == S_MAIN_INIT) init_counter <= init_counter + 1;
  else init_counter <= 0;
end
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
assign transmit = (P == S_MAIN_WAIT_KEY || P == S_MAIN_WAIT_KEY2)? received : (Q_next == S_UART_WAIT || print_enable);
assign tx_byte = (P == S_MAIN_WAIT_KEY || P == S_MAIN_WAIT_KEY2)? rx_byte : data[send_counter];

// UART send_counter control circuit
always @(posedge clk) begin
  case (P_next)
    S_MAIN_INIT: send_counter <= PROMPT_STR;
    S_MAIN_WAIT_KEY: send_counter <= PROMPT2_STR;
    S_MAIN_WAIT_KEY2: send_counter <=ANS_STR;
    S_MAIN_CAL: send_counter <=ANS_STR;
    default: send_counter <= send_counter + (Q_next == S_UART_INCR);
  endcase
end
// End of the FSM of the print string controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// The following logic stores the UART input in a temporary buffer.
// The input character will stay in the buffer for one clock cycle.
// store the two decimal numbers
// caculate gcd
always @(posedge clk) begin
  if (~reset_n) begin
    num1<=16'd0;
    num2<=16'd0;
    ans<=16'd0;
    cal_done<=1'b0;
  end
  else begin
    rx_temp <= (received)? rx_byte : 8'h0;
    case(P)
      S_MAIN_INIT:begin 
        num1<=16'd0;
        num2<=16'd0;
        cal_done<=1'b0;
      end
      S_MAIN_WAIT_KEY:num1<=(received && rx_byte!=8'h0D)? num1*10+(rx_byte-8'd48) :num1;
      S_MAIN_WAIT_KEY2:num2<=(received && rx_byte!=8'h0D)? num2*10+(rx_byte-8'd48) :num2;
      S_MAIN_CAL:begin
        if(num2>num1)begin
          num1<=num2;
          num2<=num1;
        end
        else if(num2!=16'd0) begin
          num1<=num1-num2;
        end
        else begin
          ans<=num1;
          cal_done<=1'b1;
        end
      end

    endcase
  end
end
// ------------------------------------------------------------------------


//generate gcd to the expect output form
always @(posedge clk) begin
  if (~reset_n) begin
    data[87]<=8'd0;
    data[88]<=8'd0;
    data[89]<=8'd0;
    data[90]<=8'd0;
  end
  else begin
    if(ans[15:12]>=4'd0 && 4'd9>=ans[15:12])
      data[87]<=ans[15:12]+8'd48;
    else
      data[87]<=ans[15:12]+8'd55;
    if(ans[11:8]>=4'd0 && 4'd9>=ans[11:8])
      data[88]<=ans[11:8]+8'd48;
    else
      data[88]<=ans[11:8]+8'd55;
    if(ans[7:4]>=4'd0 && 4'd9>=ans[7:4])
      data[89]<=ans[7:4]+8'd48;
    else
      data[89]<=ans[7:4]+8'd55;
    if(ans[3:0]>=4'd0 && 4'd9>=ans[3:0])
      data[90]<=ans[3:0]+8'd48;
    else
      data[90]<=ans[3:0]+8'd55;
    end
end

endmodule
