module alu(
   input logic [2:0] forward1,
   input logic [2:0] forward2,
   input logic [1:0] instr_type_ex,
   input logic [3:0] alu_control_ex,
   input logic [63:0] ex_rs1_value,
   input logic [63:0] ex_rs2_value,
   input logic [63:0] alu_value_wb,
   input logic [63:0] bru_value_wb,
   input logic [63:0] mul_value_wb,
   input logic [63:0] div_value_wb,
   input logic [63:0] lsu_value_wb,
   input logic [63:0] imm_ex,
   input logic instr_valid_ex,
   output logic complete_ex,
   output logic [63:0] value_ex
);
  logic s1, s2;
  logic [63:0] src1, src2, op1, op2;
  
  // s1信号的选择逻辑
  always_comb begin
    case(instr_type_ex)
       2'b00: s1 = 1'b1;
       2'b01: s1 = 1'b1;
       2'b10: s1 = 1'b0;
       default: s1 = 1'b0;
    endcase
  end
  
  // s2信号的选择逻辑
  always_comb begin
    case(instr_type_ex)
       2'b00: s2 = 1'b1;
       2'b01: s2 = 1'b0;
       2'b10: s2 = 1'b0;
       default: s2 = 1'b0;  // 修复：应该是 1'b0
    endcase
  end
  
  // OP1和OP2的选择
  mux6_alu #(64) OP1(ex_rs1_value, alu_value_wb, bru_value_wb, mul_value_wb, div_value_wb, lsu_value_wb, forward1, op1);
  mux6_alu #(64) OP2(ex_rs2_value, alu_value_wb, bru_value_wb, mul_value_wb, div_value_wb, lsu_value_wb, forward2, op2);
  
  // src1和src2的选择
  mux2_alu #(64) SRC1(op1, 64'd0, s1, src1);
  mux2_alu #(64) SRC2(op2, imm_ex, s2, src2);
  
  // ALU部件运算
  aluex aluresult(src1, src2, alu_control_ex, instr_valid_ex, value_ex, complete_ex);

endmodule
