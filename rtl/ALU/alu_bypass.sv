module  bypass_alu(
    input logic [5:0]prf_rs1,
    input logic [5:0]prf_rs2,
    input logic [5:0]alu_rd,
    input logic [5:0]bru_rd,
    input logic [5:0]mul_rd,
    input logic [5:0]div_rd,
    input logic [5:0]lsu_rd,
    input logic reg_write_ex,
    output logic [2:0]forward1,
    output logic [2:0]forward2
);
    
    //产生 forward1信号
    always_comb begin
        if((prf_rs1==alu_rd)&(alu_rd!=0)&(reg_write_ex)) begin
             forward1=3'b001;
        end
        else if((prf_rs1==bru_rd)&(bru_rd!=0)&(reg_write_ex)) begin
             forward1=3'b010;  
        end
        else  if((prf_rs1==mul_rd)&(mul_rd!=0)&(reg_write_ex)) begin
              forward1=3'b011;
        end
        else if((prf_rs1==div_rd)&(div_rd!=0)&(reg_write_ex))begin
             forward1=3'b100;  
        end
        else if((prf_rs1==lsu_rd)&(lsu_rd!=0)&(reg_write_ex))begin
             forward1=3'b101;
        end
        else begin
             forward1=3'b000;
        end
    end
    
    //产生 forward2信号
    always_comb begin
        if((prf_rs2==alu_rd)&(alu_rd!=0)&(reg_write_ex)) begin
             forward2=3'b001;
        end
        else if((prf_rs2==bru_rd)&(bru_rd!=0)&(reg_write_ex)) begin
             forward2=3'b010;  
        end
        else  if((prf_rs2==mul_rd)&(mul_rd!=0)&(reg_write_ex)) begin
              forward2=3'b011;
        end
        else if((prf_rs2==div_rd)&(div_rd!=0)&(reg_write_ex))begin
             forward2=3'b100;  
        end
        else if((prf_rs2==lsu_rd)&(lsu_rd!=0)&(reg_write_ex))begin
             forward2=3'b101;
        end
        else begin
             forward2=3'b000;
        end
    end
endmodule
