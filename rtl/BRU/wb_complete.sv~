module wb_complete(
    input logic [5:0] rd_number_wb,
    input logic reg_write_wb,
    input logic [6:0] bru_rob_id_wb,   //当前BR指令的rob_id
    input logic [4:0] BOB_id_wb,
    input logic [63:0] BOB_pc_wb,
    input logic [63:0] adr_wb,        //给PC/BTB
    input logic bru_recovery_wb,
    input logic btb_wirte_wb,
    input logic [63:0] rd_value_wb,
    input logic [4:0] RAS_count_wb,
    input logic instr_valid_wb,
    input logic taken_wb,
    input logic [7:0] GPHT_CPHT_index_wb,
    input logic [7:0] BPHT_index_wb,
    input logic [7:0] GHR_wb,
    input logic is_return_wb,
    input logic is_b_type_wb,
    input logic [1:0] G_or_B_wb,
    input logic complete_wb,

    output logic [5:0] rd_number_end,
    output logic reg_write_end,
    output logic [6:0] bru_rob_id_end,
    output logic [4:0] BOB_id_end,
    output logic [63:0] BOB_pc_end,
    output logic [63:0] adr_end,        //给PC/BTB
    output logic bru_recovery_end,
    output logic btb_wirte_end,
    output logic [63:0] rd_value_end,
    output logic [4:0] RAS_count_end,
    output logic taken_end,
    output logic [7:0] GPHT_CPHT_index_end,
    output logic [7:0] BPHT_index_end,
    output logic [7:0] GHR_end,
    output logic is_return_end,
    output logic is_b_type_end,
    output logic [1:0] G_or_B_end,
    output logic complete_end
);

    assign rd_number_end = rd_number_wb;
    assign reg_write_end = reg_write_wb & (~bru_recovery_wb) & instr_valid_wb;
    assign bru_rob_id_end = bru_rob_id_wb;  // 取低6位
    assign BOB_id_end = BOB_id_wb;
    assign BOB_pc_end = BOB_pc_wb;  // 修正: ptab_pc_wb -> BOB_pc_wb
    assign adr_end = adr_wb;
    assign bru_recovery_end = bru_recovery_wb;
    assign btb_wirte_end = btb_wirte_wb & (~bru_recovery_wb);
    assign rd_value_end = rd_value_wb;
    assign RAS_count_end = RAS_count_wb;
    assign taken_end = taken_wb;
    assign GPHT_CPHT_index_end = GPHT_CPHT_index_wb;
    assign BPHT_index_end = BPHT_index_wb;
    assign GHR_end = GHR_wb;
    assign is_return_end = is_return_wb;
    assign is_b_type_end = is_b_type_wb;
    assign G_or_B_end = G_or_B_wb;
    assign complete_end = instr_valid_wb & (~bru_recovery_wb);

endmodule
