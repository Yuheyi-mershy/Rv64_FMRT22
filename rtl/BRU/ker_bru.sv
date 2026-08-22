module bru_core(
    input logic [63:0]src1,
    input logic [63:0]src2,
    input logic [2:0]bru_control,
    output logic [63:0]addr,
    output logic taken,
    output logic complete
);
    always_comb  begin
       complete=1'b0;
       case(bru_control)    
         //BEQ
         3'b000: begin
             taken=(src1==src2)?1'b1:1'b0;
             addr=64'd0;    //之后会在外面的模块里正确的选择这个地址
             complete=1'b1;
          end
         //BNE
         3'b001:begin
             taken=(src1!=src2)?1'b1:1'b0;
             addr=64'd0;    //之后会在外面的模块里正确的选择这个地址
             complete=1'b1;
          end
         //JALR:
         3'b010: begin
             taken=1'b1;
             addr=(src1+src2)&(64'hffff_ffff_ffff_fffe);  // 修改：adr -> addr
             complete=1'b1;
          end
         //BLT:
         3'b100:begin
            if(src1[63]>src2[63])  begin
                 taken=1'b1;
                 complete=1'b1;
                 addr=64'd0;
            end
            else if(src1[63]<src2[63])  begin
                 taken=1'b0;
                 complete=1'b1;
                 addr=64'd0;
            end
            else   begin
               taken=(src1[62:0]<src2[62:0])?1'b1:1'b0;
               complete=1'b1;
               addr=64'd0;
            end
          end
         //BGE
         3'b101:begin
            if(src2[63]>src1[63])  begin
                 taken=1'b1;
                 complete=1'b1;
            end
            else if(src2[63]<src1[63])  begin
                 taken=1'b0;
                 complete=1'b1;
            end
            else   begin
               taken=((src2[62:0]<src1[62:0])|(src2[62:0]==src1[62:0]))?1'b1:1'b0;
               complete=1'b1;
            end
            addr=64'd0;
          end
         //BLTU
         3'b110: begin
            if(src1[63]<src2[63])  begin
                 taken=1'b1;
                 complete=1'b1;
                 addr=64'd0;
            end
            else if(src1[63]>src2[63])  begin
                 taken=1'b0;
                 complete=1'b1;
                 addr=64'd0;
            end
            else   begin
                 taken=(src1[62:0]<src1[62:0])?1'b1:1'b0;
                 complete=1'b1;
                 addr=64'd0;
            end
          end
         //BGEU
         3'b111: begin
          if(src2[63]<src1[63])  begin
                 taken=1'b1;
                 complete=1'b1;
                 addr=64'd0;
            end
            else if(src2[63]>src1[63])  begin
                 taken=1'b0;
                 complete=1'b1;
                 addr=64'd0;
            end
            else   begin
               taken=((src2[62:0]<src1[62:0])|(src2[62:0]==src1[62:0]))?1'b1:1'b0;
               complete=1'b1;
               addr=64'd0;
            end
          end
         //JAL/AUIPC/其他
          default:  begin
             taken=1'b1;
             addr=64'd0;   
             complete=1'b1; 
          end
       endcase  // 添加这行
    end  // always_comb 块结束

endmodule  // 模块结束
