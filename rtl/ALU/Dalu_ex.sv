module aluex(
   input logic [63:0] op1,
   input logic [63:0] op2,
   input logic [3:0] alu_control_ex,
   input logic instr_valid_ex,
   output logic [63:0] value_ex,
   output logic complete_ex
);
  logic [4:0] shamt;
  logic [5:0] shamt_2;
  logic [31:0] opp1, opp2, result1;
  logic [63:0] result;
  logic [62:0] number1, number2;
  logic [19:0] u_imm;
  logic [31:0] temp;
  logic complete;
  
  // 确定移位量
  assign shamt = op2[4:0];
  assign shamt_2 = op2[5:0];
  
  // 确定32位操作的字
  assign opp1 = op1[31:0];
  assign opp2 = op2[31:0];
  
  // 确定无符号比较的低62位
  assign number1 = op1[62:0];
  assign number2 = op2[62:0];
  
  // 确定U格式的立即数低20位
  assign u_imm = op2[19:0];
  
  // 定义complete信号
  assign complete_ex = instr_valid_ex & complete;
  assign value_ex = result;
  
  // alu_control_ex 编码:
  // 0000: LUI
  // 0001: ADD/ADDI
  // 0010: SUB
  // 0011: SLL/SLLI
  // 0100: SLT/SLTI
  // 0101: SLTU/SLTIU
  // 0110: XOR/XORI
  // 0111: SRL/SRLI
  // 1000: SRA/SRAI
  // 1001: OR/ORI
  // 1010: AND/ANDI
  // 1011: ADDW/ADDIW
  // 1100: SUBW
  // 1101: SLLW/SLLIW
  // 1110: SRLW/SRLIW
  // 1111: SRAW/SRAIW
  
  // 运算逻辑的实现   
  always_comb begin
    // 初始化
    result = 64'b0;
    complete = 1'b0;
    result1 = 32'b0;
    
    case (alu_control_ex)
      // LUI
      4'b0000: begin
        result1 = op2;
        result = op2;
        complete = 1'b1;
      end
      
      // ADD/ADDI
      4'b0001: begin
        result = op1 + op2;
        complete = 1'b1;
      end
      
      // SUB
      4'b0010: begin
        result = op1 - op2;
        complete = 1'b1;
      end
      
      // SLL/SLLI
      4'b0011: begin
        result = op1 << shamt_2;
        complete = 1'b1;
      end
      
      // SLT/SLTI
      4'b0100: begin
        if (op1[63] > op2[63]) begin
          result = 64'd1;
        end
        else if (op1[63] < op2[63]) begin
          result = 64'd0;
        end
        else if (number1 < number2) begin
          result = 64'd1;
        end
        else begin
          result = 64'd0;
        end
        complete = 1'b1;
      end
      
      // SLTU/SLTIU
      4'b0101: begin
        if ((op1[63] == 1'b1) & (op2[63] == 1'b0)) begin
          result = 64'd0;
        end
        else if ((op1[63] == 1'b0) & (op2[63] == 1'b1)) begin
          result = 64'd1;
        end
        else if (number1 < number2) begin
          result = 64'd1;
        end
        else begin
          result = 64'd0;
        end
        complete = 1'b1;
      end
      
      // XOR/XORI
      4'b0110: begin
        result = op1 ^ op2;
        complete = 1'b1;
      end
      
      // SRL/SRLI
      4'b0111: begin
        result = op1 >> shamt_2;
        complete = 1'b1;
      end
      
      // SRA/SRAI
      4'b1000: begin
        result = $signed(op1) >>> shamt_2;
        complete = 1'b1;
      end
      
      // OR/ORI
      4'b1001: begin
        result = op1 | op2;
        complete = 1'b1;
      end
      
      // AND/ANDI
      4'b1010: begin
        result = op1 & op2;
        complete = 1'b1;
      end
      
      // ADDW/ADDIW
      4'b1011: begin
        result1 = opp1 + opp2;
        result = {{32{result1[31]}}, result1};
        complete = 1'b1;
      end
      
      // SUBW
      4'b1100: begin
        result1 = opp1 - opp2;
        result = {{32{result1[31]}}, result1};
        complete = 1'b1;
      end
      
      // SLLW/SLLIW
      4'b1101: begin
        temp = opp1 << shamt;
        result = {{32{temp[31]}}, temp};
        complete = 1'b1;
      end
      
      // SRLW/SRLIW
      4'b1110: begin
        result1 = opp1 >> shamt;
        result = {{32{result1[31]}}, result1};
        complete = 1'b1;
      end
      
      // SRAW/SRAIW
      4'b1111: begin
        temp = $signed(opp1) >>> shamt;
        result = {{32{temp[31]}}, temp};
        complete = 1'b1;
      end
      
      default: begin
        result = 64'b0;
        complete = 1'b0;
      end
    endcase
  end
endmodule
