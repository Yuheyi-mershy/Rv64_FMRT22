module select_prf_alu(
    input logic clk,
    input logic reset,
    input logic [5:0] rs1_number_select,
    input logic [5:0] rs2_number_select,
    input logic [63:0] imm_select,
    input logic [5:0] rd_number_select,
    input logic [6:0] rob_id_select,  // 改为7位以匹配IQ输出
    input logic [3:0] alu_control_select,
    input logic reg_write_select,
    input logic [1:0] instr_type_select,
    input logic instr_valid_select,
    input logic bru_recovery,
    input logic [6:0] bru_rob_id,
    output logic [5:0] rs1_number_prf,
    output logic [5:0] rs2_number_prf,
    output logic [63:0] imm_prf,
    output logic [5:0] rd_number_prf,
    output logic [6:0] rob_id_prf,  // 改为7位
    output logic [3:0] alu_control_prf,
    output logic reg_write_prf,
    output logic [1:0] instr_type_prf,
    output logic instr_valid_prf
);
    logic flush, stall;
    
    brurecovery_alu bru_re(bru_recovery, bru_rob_id, rob_id_select, flush, stall);
    
    always_ff @(posedge clk) begin
        if(reset) begin
            rs1_number_prf <= 6'b000000;
            rs2_number_prf <= 6'b000000;
            rd_number_prf <= 6'b000000;
            rob_id_prf <= 7'b0000000;
            reg_write_prf <= 1'b0;
            instr_type_prf <= 2'b00;
            alu_control_prf <= 4'b0000;
            imm_prf <= 64'd0;
            instr_valid_prf <= 1'b0;           
        end
        else if(flush) begin
            rs1_number_prf <= 6'b000000;
            rs2_number_prf <= 6'b000000;
            rd_number_prf <= 6'b000000;
            rob_id_prf <= 7'b0000000;
            reg_write_prf <= 1'b0;
            instr_type_prf <= 2'b00;
            alu_control_prf <= 4'b0000;
            imm_prf <= 64'd0;
            instr_valid_prf <= 1'b0;   
        end
        else if(~stall) begin
            rs1_number_prf <= rs1_number_select;
            rs2_number_prf <= rs2_number_select;
            rd_number_prf <= rd_number_select;
            rob_id_prf <= rob_id_select;
            reg_write_prf <= reg_write_select;
            instr_type_prf <= instr_type_select;
            alu_control_prf <= alu_control_select;
            imm_prf <= imm_select;
            instr_valid_prf <= instr_valid_select;    
        end
    end
endmodule
