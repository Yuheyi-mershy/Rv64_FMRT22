module select_prf_sw(
    input logic clk,
    input logic reset,

    input logic [5:0] rs1_number_select,
    input logic [63:0] imm_select,
    input logic [5:0] dest_number_select,
    input logic [6:0] rob_id_select,
    input logic [3:0] lsu_control_select,
    input logic reg_write_select,
    input logic instr_valid_select,
    input logic bru_recovery,
    input logic [3:0] grant_select,
    input logic sb_full,

    output logic [5:0] rs1_number_prf,
    output logic [63:0] imm_prf,
    output logic [5:0] dest_number_prf,
    output logic [6:0] rob_id_prf,
    output logic [3:0] lsu_control_prf,
    output logic reg_write_prf,
    output logic [3:0] grant_prf,
    output logic instr_valid_prf
);

    always_ff @(posedge clk) begin
        if(reset | sb_full | bru_recovery|(~lsu_control_select[3])) begin
            rs1_number_prf <= 6'b000000;
            imm_prf <= 64'd0;
            dest_number_prf <= 6'b000000;
            rob_id_prf <= 7'b0000000;
            reg_write_prf <= 1'b0;
            lsu_control_prf <= 4'b0000;
            instr_valid_prf <= 1'b0;   
            grant_prf <= 4'd0;        
        end
        else  begin
            rs1_number_prf <= rs1_number_select;
            imm_prf <= imm_select;
            dest_number_prf <= dest_number_select;
            rob_id_prf <= rob_id_select;
            reg_write_prf <= reg_write_select;
            lsu_control_prf <= lsu_control_select;
            instr_valid_prf <= instr_valid_select;
            grant_prf <= grant_select;
        end
    end
    
endmodule
