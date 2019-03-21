`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/12/11 14:25:04
// Design Name: 
// Module Name: md5
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


module md5(
      input clk,
      input reset_n,
      input [63:0] password,
	 
	  output [127:0] passwd_hash
      );
	
	

reg [127:0] passwd_hash;

reg [23:0] init_counter;

reg divide_done;

reg f_g_done;

reg loop_done;
reg hash_done;
reg [31:0] w [0:15];

reg [6:0] i;
    
reg [31:0] h0 = 32'h67452301;
reg [31:0] h1 = 32'hefcdab89;
reg [31:0] h2 = 32'h98badcfe;
reg [31:0] h3 = 32'h10325476;

reg [31:0] a,b,c,d,f,g;

reg [31:0] r [0:63];
reg [31:0] k [0:63];

localparam [2:0] S_MAIN_INIT = 0, S_MAIN_DIVIDE = 1,
                 S_MAIN_LOOP1 = 2, S_MAIN_LOOP2 = 3,S_MAIN_HASH=4,S_MAIN_ANS=5;
                 
reg [2:0] P, P_next;

initial begin 
              { r[0],r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9],r[10],r[11],r[12],r[13],r[14],r[15],
                r[16],r[17],r[18],r[19],r[20],r[21],r[22],r[23],r[24],r[25],r[26],r[27],r[28],r[29],r[30],r[31],
                r[32],r[33],r[34],r[35],r[36],r[37],r[38],r[39],r[40],r[41],r[42],r[43],r[44],r[45],r[46],r[47],
                r[48],r[49],r[50],r[51],r[52],r[53],r[54],r[55],r[56],r[57],r[58],r[59],r[60],r[61],r[62],r[63]}
            <={ 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
                5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
                4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
                6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21};

                
              { k[0],k[1],k[2],k[3],k[4],k[5],k[6],k[7],k[8],k[9],k[10],k[11],k[12],k[13],k[14],k[15],
                k[16],k[17],k[18],k[19],k[20],k[21],k[22],k[23],k[24],k[25],k[26],k[27],k[28],k[29],k[30],k[31],
                k[32],k[33],k[34],k[35],k[36],k[37],k[38],k[39],k[40],k[41],k[42],k[43],k[44],k[45],k[46],k[47],
                k[48],k[49],k[50],k[51],k[52],k[53],k[54],k[55],k[56],k[57],k[58],k[59],k[60],k[61],k[62],k[63]}
             <= { 32'hd76aa478, 32'he8c7b756, 32'h242070db, 32'hc1bdceee,
                  32'hf57c0faf, 32'h4787c62a, 32'ha8304613, 32'hfd469501,
                  32'h698098d8, 32'h8b44f7af, 32'hffff5bb1, 32'h895cd7be,
                  32'h6b901122, 32'hfd987193, 32'ha679438e, 32'h49b40821,
                  32'hf61e2562, 32'hc040b340, 32'h265e5a51, 32'he9b6c7aa,
                  32'hd62f105d, 32'h02441453, 32'hd8a1e681, 32'he7d3fbc8,
                  32'h21e1cde6, 32'hc33707d6, 32'hf4d50d87, 32'h455a14ed,
                  32'ha9e3e905, 32'hfcefa3f8, 32'h676f02d9, 32'h8d2a4c8a,
                  32'hfffa3942, 32'h8771f681, 32'h6d9d6122, 32'hfde5380c,
                  32'ha4beea44, 32'h4bdecfa9, 32'hf6bb4b60, 32'hbebfbc70,
                  32'h289b7ec6, 32'heaa127fa, 32'hd4ef3085, 32'h04881d05,
                  32'hd9d4d039, 32'he6db99e5, 32'h1fa27cf8, 32'hc4ac5665,
                  32'hf4292244, 32'h432aff97, 32'hab9423a7, 32'hfc93a039,
                  32'h655b59c3, 32'h8f0ccc92, 32'hffeff47d, 32'h85845dd1,
                  32'h6fa87e4f, 32'hfe2ce6e0, 32'ha3014314, 32'h4e0811a1,
                  32'hf7537e82, 32'hbd3af235, 32'h2ad7d2bb, 32'heb86d391 };
end

always @(posedge clk) begin
  if (~reset_n) P <= S_MAIN_INIT;
  else P <= P_next;
end

always @(posedge clk) begin
  if (P == S_MAIN_INIT) init_counter <= init_counter + 1;
  else init_counter <= 0;
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT:
      if (init_counter < 1000) P_next = S_MAIN_INIT;
	  else P_next = S_MAIN_DIVIDE;
    S_MAIN_DIVIDE:
       P_next<=S_MAIN_LOOP1;
    S_MAIN_LOOP1:
      P_next<=S_MAIN_LOOP2;
    S_MAIN_LOOP2:
	  if(i==7'd63) P_next<=S_MAIN_HASH;
	  else P_next<=S_MAIN_LOOP1;
    S_MAIN_HASH:
      P_next<=S_MAIN_ANS;
    S_MAIN_ANS:
      P_next<=S_MAIN_ANS;
  endcase
end

always @(posedge clk) begin
  if (~reset_n) begin
    {w[0],w[1],w[2],w[3],w[4],w[5],w[6],w[7],
     w[8],w[9],w[10],w[11],w[12],w[13],w[14],w[15] }    
    <= {32'd0,32'd0,32'h00000080,32'd0,32'd0,32'd0,32'd0,32'd0,
        32'd0,32'd0,32'd0,32'd0,32'd0,32'd0,32'h00000040,32'd0};
  end
  else if(P==S_MAIN_DIVIDE) begin
   w[0][31:24]<=password[39:32];
   w[0][23:16]<=password[47:40];
   w[0][15:8]<=password[55:48];
   w[0][7:0]<=password[63:56];
   w[1][31:24]<=password[7:0];
   w[1][23:16]<=password[15:8];
   w[1][15:8]<=password[23:16];
   w[1][7:0]<=password[31:24];
  end
  else begin
    w[0]<=w[0];
  end
end

always @(posedge clk) begin
  if (~reset_n) begin
    i<=7'd0;
  end
  else begin
    if(P==S_MAIN_LOOP2) i<=i+1;
    else i<=i;
  end
end

always @(posedge clk) begin
  if (~reset_n) begin
    f<=32'd0;
    g<=32'd0;
  end
  else if(P==S_MAIN_LOOP1) begin
    if(i<16) begin
      f <= (b & c) | ((~b) & d);
      g <= i;
    end
    else if(i<32) begin
      f <= (d & b) | ((~d) & c);
      g <= (5*i + 1) %16;
    end
    else if(i<48) begin
      f <= b ^ c ^ d;
      g <= (3*i + 5) %16;
    end
    else begin
      f <= c ^ (b | (~d));
      g <= (7*i) %16;
    end
  end
  else begin
    f<=f;
    g<=g;
  end
end

always @(posedge clk) begin
  if (~reset_n) begin
    a<=h0;
    b<=h1;
    c<=h2;
    d<=h3;
  end
  else if(P==S_MAIN_LOOP2) begin
    d <= c;
    c <= b;
    b <= b +(((a + f + k[i] + w[g])<<(r[i])) | ((a + f + k[i] + w[g])>>(32-r[i]))) ;
    a <= d;
  end
  else begin
    a<=a;
    b<=b;
    c<=c;
    d<=d;
  end
end

always @(posedge clk) begin
  if (~reset_n) begin
    h0 <= 32'h67452301;
    h1 <= 32'hefcdab89;
    h2 <= 32'h98badcfe;
    h3 <= 32'h10325476;
    hash_done<=1'b0;
  end
  else if(P==S_MAIN_HASH) begin
    h0 <= h0+a;
    h1 <= h1+b;
    h2 <= h2+c;
    h3 <= h3+d;
    hash_done<=1'b1;
  end
  else begin
    h0 <= h0;
    h1 <= h1;
    h2 <= h2;
    h3 <= h3;
  end
end

always @(posedge clk) begin
  if (~reset_n) begin
    passwd_hash<={128{1'b0}};
  end
  else if (P==S_MAIN_ANS) begin
    passwd_hash[127:120]<=h0[7:0];
	passwd_hash[119:112]<=h0[15:8];
	passwd_hash[111:104]<=h0[23:16];
	passwd_hash[103:96]<=h0[31:24];
    passwd_hash[95:88]<=h1[7:0];
	passwd_hash[87:80]<=h1[15:8];
	passwd_hash[79:72]<=h1[23:16];
	passwd_hash[71:64]<=h1[31:24];
	passwd_hash[63:56]<=h2[7:0];
	passwd_hash[55:48]<=h2[15:8];
	passwd_hash[47:40]<=h2[23:16];
	passwd_hash[39:32]<=h2[31:24];
	passwd_hash[31:24]<=h3[7:0];
	passwd_hash[23:16]<=h3[15:8];
	passwd_hash[15:8]<=h3[23:16];
	passwd_hash[7:0]<=h3[31:24];
  end
  else begin
    passwd_hash<=passwd_hash;
  end
end
    
endmodule
