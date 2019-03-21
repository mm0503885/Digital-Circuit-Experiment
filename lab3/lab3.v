`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/09/26 15:03:31
// Design Name: 
// Module Name: lab3
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


module lab3(
  input  clk,            // System clock at 100 MHz
  input  reset_n,        // System reset signal, in negative logic
  input  [3:0] usr_btn,  // Four user pushbuttons
  output [3:0] usr_led   // Four yellow LEDs
);

reg signed [3:0] counter;
reg [19:0] d0counter;
reg [19:0] d1counter;
reg [19:0] d2counter;
reg [19:0] d3counter;

reg keep_push0;
reg keep_push1;
reg keep_push2;
reg keep_push3;

reg PMW_on;
reg [2:0] PMW_state;
reg [29:0] PMW_counter;


assign usr_led=(PMW_on)? counter : 0;



always@(posedge clk)
begin
  if(!reset_n)
    begin
      counter<=4'b0;
      d0counter<=20'd0;
      d1counter<=20'd0;
      d2counter<=20'd0;
      d3counter<=20'd0;
      keep_push0<=1'b0;
      keep_push1<=1'b0;
      keep_push2<=1'b0;
      keep_push3<=1'b0;
      PMW_on<=1'b1;
      PMW_state<=3'd4;
      PMW_counter<=30'd0;
    end
  else
    begin
      if(usr_btn[0]==1)
        begin
          d0counter<=d0counter+1;
          if(d0counter>=20'd500_000)
          begin
          if(!keep_push0)
            begin
              if(counter!=4'b1000)
                begin
                counter<=counter-1;
                end
              else
                begin
                counter<=counter;
                end
              d0counter<=20'd0;
              keep_push0<=1'b1;
            end
          end
      end
      else
      begin
        keep_push0<=1'b0;
      end
         
      if(usr_btn[1]==1)
        begin
          d1counter<=d1counter+1;
          if(d1counter>=20'd500_000)
          begin
            if(!keep_push1)
            begin
              if(counter!=4'b0111)
                begin
                counter<=counter+1;
                end
              else
                begin
                counter<=counter;
                end
              d1counter<=20'd0;
              keep_push1<=1'b1;
            end
          end 
        end
      else
        begin
          keep_push1<=1'b0;
        end
      if(usr_btn[2]==1)
        begin
          d2counter<=d2counter+1;
            if(d2counter>=20'd500_000)
              begin
                if(!keep_push2)
                  begin
                    if(PMW_state!=3'b0)
                      begin
                        PMW_state<=PMW_state-1;
                      end
                    else
                      begin
                        PMW_state<=PMW_state;
                      end
                    d2counter<=20'd0;
                    keep_push2<=1'b1;
                  end
              end 
        end
      else
        begin
          keep_push2<=1'b0;
        end
     if(usr_btn[3]==1)
       begin
         d3counter<=d3counter+1;
           if(d3counter>=20'd500_000)
             begin
               if(!keep_push3)
                 begin
                   if(PMW_state!=3'd4)
                     begin
                       PMW_state<=PMW_state+1;
                     end
                   else
                     begin
                       PMW_state<=PMW_state;
                     end
                   d3counter<=20'd0;
                   keep_push3<=1'b1;
                 end
             end 
       end
     else
       begin
         keep_push3<=1'b0;
       end
     if(PMW_state==0)
     begin
       if(PMW_counter!=30'd1000000)
         begin
           PMW_counter<=PMW_counter+1;
           if(PMW_counter>=30'd50000)
             begin
               PMW_on<=0;
             end
           else
             begin
               PMW_on<=1;
             end  
         end
       else
         begin
           PMW_counter<=30'd0;
           PMW_on<=0;
         end  
     end
     if(PMW_state==1)
          begin
            if(PMW_counter!=30'd1000000)
              begin
                PMW_counter<=PMW_counter+1;
                if(PMW_counter>=30'd250000)
                  begin
                    PMW_on<=0;
                  end
                else
                  begin
                    PMW_on<=1;
                  end  
              end
            else
              begin
                PMW_counter<=30'd0;
                PMW_on<=0;
              end  
          end
     if(PMW_state==2)
               begin
                 if(PMW_counter!=30'd1000000)
                   begin
                     PMW_counter<=PMW_counter+1;
                     if(PMW_counter>=30'd500000)
                       begin
                         PMW_on<=0;
                       end
                     else
                       begin
                         PMW_on<=1;
                       end  
                   end
                 else
                   begin
                     PMW_counter<=30'd0;
                     PMW_on<=0;
                   end  
               end  
     if(PMW_state==3)
                    begin
                      if(PMW_counter!=30'd1000000)
                        begin
                          PMW_counter<=PMW_counter+1;
                          if(PMW_counter>=30'd750000)
                            begin
                              PMW_on<=0;
                            end
                          else
                            begin
                              PMW_on<=1;
                            end  
                        end
                      else
                        begin
                          PMW_counter<=30'd0;
                          PMW_on<=0;
                        end  
                    end    
     if(PMW_state==4)
     begin
         if(PMW_counter!=30'd1000000)
         begin
           PMW_counter<=PMW_counter+1;
           PMW_on<=1;
          end  
   
        else
         begin
           PMW_counter<=30'd0;
           PMW_on<=1;
          end  
     end             
                
      
    end   
end


      
  
  


        
      



endmodule
