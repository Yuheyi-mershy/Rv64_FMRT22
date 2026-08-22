module prf_ex_alu(
    input logic clk,
    input logic reset,
    input logic [5:0] rs1_number_prf,
    input logic [5:0] rs2_number_prf,
    input logic [5:0] rd_number_prf,
    input logic [63:0] prf_rs1_value,
    input logic [63:0] prf_rs2_value,
    input logic bru_recovery,
    input logic [6:0] bru_rob_id,
    input logic [6:0] rob_id_prf,
    input logic reg_write_prf,
    input logic [1:0] instr_type_prf,
    input logic [3:0] alu_control_prf,
    input logic [63:0] imm_prf,
    input logic instr_valid_prf,
    output logic [5:0] rs1_number_ex,
    output logic [5:0] rs2_number_ex,
    output logic [5:0] rd_number_ex,
    output logic [63:0] ex_rs1_value,
    output logic [63:0] ex_rs2_value,
    output logic [6:0] rob_id_ex,
    output logic reg_write_ex,
    output logic [1:0] instr_type_ex,
    output logic [3:0] alu_control_ex,
    output logic [63:0] imm_ex,
    output logic instr_valid_ex
);   
    // 定义产生冲突时候的信号
    logic flush, stall;
    brurecovery_alu bru_re(bru_recovery, bru_rob_id, rob_id_prf, flush, stall);
    
    // 正式执行
    always_ff @(posedge clk) begin
        if(reset) begin
            rs1_number_ex <= 6'd0;
            rs2_number_ex <= 6'd0;
            ex_rs1_value <= 64'd0;
            ex_rs2_value <= 64'd0;
            rob_id_ex <= 7'd0;
            reg_write_ex <= 1'd0;
            instr_type_ex <= 2'd0;
            alu_control_ex <= 4'd0;
            imm_ex <= 64'd0;
            instr_valid_ex <= 1'd0;
            rd_number_ex <= 6'd0;
        end
        else if(flush) begin
            rs1_number_ex <= 6'd0;
            rs2_number_ex <= 6'd0;
            ex_rs1_value <= 64'd0;
            ex_rs2_value <= 64'd0;
            rob_id_ex <= 7'd0;
            reg_write_ex <= 1'd0;
            instr_type_ex <= 2'd0;
            alu_control_ex <= 4'd0;
            imm_ex <= 64'd0;
            instr_valid_ex <= 1'd0;
            rd_number_ex <= 6'd0;
        end
        else if(~stall) begin
            rs1_number_ex <= rs1_number_prf;
            rs2_number_ex <= rs2_number_prf;
            ex_rs1_value <= prf_rs1_value;
            ex_rs2_value <= prf_rs2_value;
            rob_id_ex <= rob_id_prf;
            reg_write_ex <= reg_write_prf;
            instr_type_ex <= instr_type_prf;
            alu_control_ex <= alu_control_prf;
            imm_ex <= imm_prf;
            instr_valid_ex <= instr_valid_prf;
            rd_number_ex <= rd_number_prf;  // 修复：去掉6'
        end
    end
endmodule
