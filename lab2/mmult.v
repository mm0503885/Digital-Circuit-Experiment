`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/09/19 11:25:45
// Design Name: 
// Module Name: mmult
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


module mmult(
  input  clk,                 // Clock signal
  input  reset_n,             // Reset signal (negative logic)
  input  enable,              // Activation signal for matrix multiplication
  input  [0:9*8-1] A_mat,     // A matrix
  input  [0:9*8-1] B_mat,     // B matrix
  output  valid,               // Signals that the output is valid to read
  output reg [0:9*17-1] C_mat // The result of A x B
);
reg [7:0] A00,A01,A02,A10,A11,A12,A20,A21,A22,B00,B01,B02,B10,B11,B12,B20,B21,B22;
reg [1:0] counter;
reg valid;

always@(posedge clk)
begin
  if(!reset_n)
  begin
    counter<=2'd0;
    C_mat<=153'd0;
    valid<=1'd0;
    A00=A_mat[0:7];
    A01=A_mat[8:15];
    A02=A_mat[16:23];
    A10=A_mat[24:31];
    A11=A_mat[32:39];
    A12=A_mat[40:47];
    A20=A_mat[48:55];
    A21=A_mat[56:63];
    A22=A_mat[64:71];
    B00=B_mat[0:7];
    B01=B_mat[8:15];
    B02=B_mat[16:23];
    B10=B_mat[24:31];
    B11=B_mat[32:39];
    B12=B_mat[40:47];
    B20=B_mat[48:55];
    B21=B_mat[56:63];
    B22=B_mat[64:71];         
   end
   else
   begin
    if(enable)
    begin
      if(counter==2'd0)
      begin
        C_mat[0:16]=A00*B00+A01*B10+A02*B20;
        C_mat[51:67]=A10*B00+A11*B10+A12*B20;  
        C_mat[102:118]=A20*B00+A21*B10+A22*B20;
        counter=counter+1; 
      end
      else if(counter==2'd1)
      begin
        C_mat[17:33]=A00*B01+A01*B11+A02*B21;
        C_mat[68:84]=A10*B01+A11*B11+A12*B21;  
        C_mat[119:135]=A20*B01+A21*B11+A22*B21;
        counter=counter+1; 
      end
      else if(counter==2'd2)
      begin
        C_mat[34:50]=A00*B02+A01*B12+A02*B22;
        C_mat[85:101]=A10*B02+A11*B12+A12*B22;  
        C_mat[136:152]=A20*B02+A21*B12+A22*B22;
        counter=counter+1; 
        valid<=1'd1;
      end
      else 
      begin
        C_mat=C_mat;
      end
   end  
  
  end
  
end

endmodule
