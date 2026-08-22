module top_bru(
    input logic clk,
    input logic reset,
    
    // 来自前端/译码器的输入
    input logic [6:0] bru_rob_id1,
    input logic [6:0] bru_rob_id2,
    input logic [4:0] bru_bob_id1,
    input logic [4:0] bru_bob_id2,
    input logic [5:0] bru_rs1_number1,
    input logic [5:0] bru_rs2_number1,
    input logic [5:0] bru_rs1_number2,
    input logic [5:0] bru_rs2_number2,
    input logic [5:0] bru_rd_number1,
    input logic [5:0] bru_rd_number2,
    input logic [2:0] bru_control1,
    input logic [2:0] bru_control2,
    input logic bru_reg_write1,
    input logic bru_reg_write2,
    input logic [1:0] bru_instr_type1,
    input logic [1:0] bru_instr_type2,
    input logic bru_instr_valid1,
    input logic bru_instr_valid2,
    input logic bru_rs1_valid1,
    input logic bru_rs1_valid2,
    input logic bru_rs2_valid1,
    input logic bru_rs2_valid2,
    
    // 来自其他单元的总线用于唤醒
    input logic [6:0] bus_alu,
    input logic [6:0] bus_mul,
    input logic [6:0] bus_div,
    input logic [6:0] bus_lsu,
    
    // BOB相关输入信号
    input logic [7:0] bru_GHR_value_prf,
    input logic [7:0] bru_CPHT_GPHT_index_prf,
    input logic [7:0] bru_BPHT_index_prf,
    input logic bru_GPHT_pre_taken_prf,
    input logic bru_BPHT_pre_taken_prf,
    input logic bru_is_return_prf,
    input logic [63:0] bru_pre_adr_prf,
    input logic [63:0] bru_dec_adr_prf,
    input logic [63:0] bru_pc_prf,
    input logic bru_btb_hit_prf,
    input logic [4:0] bru_RAS_count_prf,
    input logic bru_pre_taken_prf,
    
    // 来自物理寄存器堆的值
    input logic [63:0] bru_prf_rs1_value,
    input logic [63:0] bru_prf_rs2_value,
    
    // 来自其他执行单元写回阶段的结果（用于转发）
    input logic [63:0] alu_value_wb,
    input logic [63:0] mul_value_wb,
    input logic [63:0] div_value_wb,
    input logic [63:0] lsu_value_wb,
    
    // 来自其他执行单元写回阶段的rd值（用于转发）
    input logic [5:0] alu_rd_wb,
    input logic [5:0] mul_rd_wb,
    input logic [5:0] div_rd_wb,
    input logic [5:0] lsu_rd_wb,
    
    // 恢复完成信号输入
    input logic complete_fentch,
    input logic complete_rob,
    
    // 输出到物理寄存器堆的寄存器号
    output logic [5:0] bru_rs1_number_prf,
    output logic [5:0] bru_rs2_number_prf,
    output logic [4:0] bru_bob_id_prf,
    
    // 最终完成信号输出（给ROB和BOB）
    output logic [5:0]rd_number_wb,
    output logic reg_write_wb,
    output logic [6:0] bru_rob_id_wb_out,
    output logic [4:0] BOB_id_wb,
    output logic [63:0] BOB_pc_wb,
    output logic [63:0] adr_wb,
    output logic bru_recovery_wb,
    output logic btb_wirte_wb,
    output logic [63:0] rd_value_wb,
    output logic [4:0] RAS_count_wb,
    output logic taken_wb,
    output logic [7:0] GPHT_CPHT_index_wb,
    output logic [7:0] BPHT_index_wb,
    output logic [7:0] GHR_wb,
    output logic is_return_wb,
    output logic is_b_type_wb,
    output logic [1:0] G_or_B_wb,
    output logic complete_wb,
    
    // 状态输出
    output logic bru_iq2_full,
    output logic [6:0] bus_bru,
    input logic stall,
    output logic write_ok3,
    output logic write_ok4
);

    // ==================== 内部信号声明 ====================
    // IQ2模块到select_prf的连接信号
    logic [5:0] rs1_number_select;
    logic [5:0] rs2_number_select;
    logic [5:0] rd_number_select;
    logic [6:0] rob_id_select;
    logic [4:0] bob_id_select;
    logic [2:0] bru_control_select;
    logic reg_write_select;
    logic [1:0] instr_type_select;
    logic instr_valid_select;
    logic [6:0] bus_valid_bru;
    
    // select_prf到prf_ex的连接信号
    logic [5:0] rs1_number_prf;
    logic [5:0] rs2_number_prf;
    logic [5:0] rd_number_prf;
    logic [6:0] rob_id_prf;
    logic [4:0] bob_id_prf;
    logic [2:0] bru_control_prf;
    logic reg_write_prf;
    logic [1:0] instr_type_prf;
    logic instr_valid_prf;
    
    // prf_ex到bru_ex和ex_wb的连接信号（EX阶段信号）
    logic [6:0] rob_id_ex;
    logic [4:0] bob_id_ex;
    logic [2:0] bru_control_ex;
    logic reg_write_ex;
    logic [1:0] instr_type_ex;
    logic instr_valid_ex;
    logic [7:0] GHR_value_ex;
    logic [7:0] CPHT_GPHT_index_ex;
    logic [7:0] BPHT_index_ex;
    logic GPHT_pre_taken_ex;
    logic BPHT_pre_taken_ex;
    logic is_return_ex;
    logic [63:0] pre_adr_ex;
    logic [63:0] dec_adr_ex;
    logic [63:0] pc_ex;
    logic btb_hit_ex;
    logic [4:0] RAS_count_ex;
    logic pre_taken_ex;
    logic [63:0] rs1_value_ex;
    logic [63:0] rs2_value_ex;
    logic [5:0]rs1_number_ex;      
    logic [5:0]rs2_number_ex;        
     logic [5:0]rd_number_ex;  
    
    // bru_ex输出信号
    logic complete_ex;
    logic [63:0] adr_ex;
    logic bru_recovery_ex;
    logic btb_wirte_ex;
    logic [63:0] rd_value_ex;
    logic [1:0] G_or_B_ex;
    logic is_btype;
    logic reg_write_en1;
    logic taken_ex;
    
    // resolve_bru输出信号
    logic resolve_complete;
    
    // bypass模块输出信号
    logic [2:0] forward1;
    logic [2:0] forward2;
    
    // ex_wb到wb_complete的连接信号（内部信号）
    logic [5:0] rd_number_wb_int;
    logic reg_write_wb_int;
    logic [6:0] rob_id_wb_int;
    logic [4:0] bob_id_wb_int;
    logic [63:0] pc_wb_int;
    logic [63:0] true_adr_wb_int;
    logic bru_recovery_wb_int;
    logic btb_wirte_wb_int;
    logic [63:0] rd_value_wb_int;
    logic [4:0] RAS_count_wb_int;
    logic instr_valid_wb_int;
    logic taken_wb_int;
    logic [7:0] GPHT_CPHT_index_wb_int;
    logic [7:0] BPHT_index_wb_int;
    logic [7:0] GHR_wb_int;
    logic is_return_wb_int;
    logic is_btype_wb_int;
    logic [1:0] G_or_B_wb_int;
    logic complete_wb_int;
   

    // ==================== 模块实例化 ====================
    
    // 实例化IQ2模块
    iq2 u_iq2 (
        .clk                    (clk),
        .reset                  (reset),
        .rob_id1                (bru_rob_id1),
        .rob_id2                (bru_rob_id2),
        .bob_id1                (bru_bob_id1),
        .bob_id2                (bru_bob_id2),
        .rs1_number1            (bru_rs1_number1),
        .rs2_number1            (bru_rs2_number1),
        .rs1_number2            (bru_rs1_number2),
        .rs2_number2            (bru_rs2_number2),
        .rd_number1             (bru_rd_number1),
        .rd_number2             (bru_rd_number2),
        .bru_control1           (bru_control1),
        .bru_control2           (bru_control2),
        .reg_write1             (bru_reg_write1),
        .reg_write2             (bru_reg_write2),
        .instr_type1            (bru_instr_type1),
        .instr_type2            (bru_instr_type2),
        .instr_valid1           (bru_instr_valid1),
        .instr_valid2           (bru_instr_valid2),
        .bru_recovery           (bru_recovery_wb),
        .bus_alu                (bus_alu),
        .bus_mul                (bus_mul),
        .bus_div                (bus_div),
        .bus_lsu                (bus_lsu),
        .rs1_valid1             (bru_rs1_valid1),
        .rs1_valid2             (bru_rs1_valid2),
        .rs2_valid1             (bru_rs2_valid1),
        .rs2_valid2             (bru_rs2_valid2),
        .rs1_number_select      (rs1_number_select),
        .rs2_number_select      (rs2_number_select),
        .rd_number_select       (rd_number_select),
        .rob_id_select          (rob_id_select),
        .bob_id_select          (bob_id_select),
        .bru_control_select     (bru_control_select),
        .reg_write_select       (reg_write_select),
        .instr_type_select      (instr_type_select),
        .iq2_full               (bru_iq2_full),
        .instr_valid_select     (instr_valid_select),
        .bus_valid_bru          (bus_valid_bru),
	.stall                  (stall),
	.write_ok3		(write_ok3),
	.write_ok4		(write_ok4)
    );
    
    // 实例化select_prf模块（寄存器槽）
    select_prf_bru u_select_prf (
        .clk                    (clk),
        .reset                  (reset),
        .rs1_number_select      (rs1_number_select),
        .rs2_number_select      (rs2_number_select),
        .rd_number_select       (rd_number_select),
        .rob_id_select          (rob_id_select),
        .bob_id_select          (bob_id_select),
        .bru_control_select     (bru_control_select),
        .reg_write_select       (reg_write_select),
        .instr_type_select      (instr_type_select),
        .instr_valid_select     (instr_valid_select),
        .bru_recovery           (bru_recovery_wb),
        .rs1_number_prf         (rs1_number_prf),
        .rs2_number_prf         (rs2_number_prf),
        .rd_number_prf          (rd_number_prf),
        .rob_id_prf             (rob_id_prf),
        .bob_id_prf             (bob_id_prf),
        .bru_control_prf        (bru_control_prf),
        .reg_write_prf          (reg_write_prf),
        .instr_type_prf         (instr_type_prf),
        .instr_valid_prf        (instr_valid_prf)
    );
    
    // 将select_prf的部分输出连接到顶层输出（供物理寄存器组读取）
    assign bru_rs1_number_prf = rs1_number_prf;
    assign bru_rs2_number_prf = rs2_number_prf;
    assign bru_bob_id_prf = bob_id_prf;
  
    // 实例化prf_ex模块（寄存器槽）
    prf_ex_bru u_prf_ex (
        .clk                    (clk),
        .reset                  (reset),
        .bru_recovery           (bru_recovery_wb),
        .rs1_number_prf         (rs1_number_prf),
        .rs2_number_prf         (rs2_number_prf),
        .rd_number_prf          (rd_number_prf),
        .rob_id_prf             (rob_id_prf),
        .bob_id_prf             (bob_id_prf),
        .bru_control_prf        (bru_control_prf),
        .reg_write_prf          (reg_write_prf),
        .instr_type_prf         (instr_type_prf),
        .instr_valid_prf        (instr_valid_prf),
        .GHR_value_prf          (bru_GHR_value_prf),
        .CPHT_GPHT_index_prf    (bru_CPHT_GPHT_index_prf),
        .BPHT_index_prf         (bru_BPHT_index_prf),
        .GPHT_pre_taken_prf     (bru_GPHT_pre_taken_prf),
        .BPHT_pre_taken_prf     (bru_BPHT_pre_taken_prf),
        .is_return_prf          (bru_is_return_prf),
        .pre_adr_prf            (bru_pre_adr_prf),
        .dec_adr_prf            (bru_dec_adr_prf),
        .pc_prf                 (bru_pc_prf),
        .btb_hit_prf            (bru_btb_hit_prf),
        .RAS_count_prf          (bru_RAS_count_prf),
        .pre_taken_prf          (bru_pre_taken_prf),
        .rs1_value_prf          (bru_prf_rs1_value),
        .rs2_value_prf          (bru_prf_rs2_value),
        .rob_id_ex              (rob_id_ex),
        .bob_id_ex              (bob_id_ex),
        .bru_control_ex         (bru_control_ex),
        .reg_write_ex           (reg_write_ex),
        .instr_type_ex          (instr_type_ex),
        .instr_valid_ex         (instr_valid_ex),
        .GHR_value_ex           (GHR_value_ex),
        .CPHT_GPHT_index_ex     (CPHT_GPHT_index_ex),
        .BPHT_index_ex          (BPHT_index_ex),
        .GPHT_pre_taken_ex      (GPHT_pre_taken_ex),
        .BPHT_pre_taken_ex      (BPHT_pre_taken_ex),
        .is_return_ex           (is_return_ex),
        .pre_adr_ex             (pre_adr_ex),
        .dec_adr_ex             (dec_adr_ex),
        .pc_ex                  (pc_ex),
        .btb_hit_ex             (btb_hit_ex),
        .RAS_count_ex           (RAS_count_ex),
        .pre_taken_ex           (pre_taken_ex),
        .rs1_value_ex           (rs1_value_ex),
        .rs2_value_ex           (rs2_value_ex),
        .rs1_number_ex          (rs1_number_ex),
        .rs2_number_ex          (rs2_number_ex),
        .rd_number_ex           (rd_number_ex)
    );
    
    // 实例化bypass模块
    bypass_bru u_bypass (
        .prf_rs1                (rs1_number_ex),
        .prf_rs2                (rs2_number_ex),
        .alu_rd                 (alu_rd_wb),
        .bru_rd                 (rd_number_wb),
        .mul_rd                 (mul_rd_wb),
        .div_rd                 (div_rd_wb),
        .lsu_rd                 (lsu_rd_wb),
        .forward1               (forward1),
        .forward2               (forward2)
    );
    
    // 实例化BRU执行部件
    bru_ex u_bru_ex (
        .instr_type_ex          (instr_type_ex),
        .reg_write_ex           (reg_write_ex),
        .bru_control_ex         (bru_control_ex),
        .rob_id_ex              (rob_id_ex),
        .instr_valid_ex         (instr_valid_ex),
        .pc_ex                  (pc_ex),
        .pre_adr_ex             (pre_adr_ex),
        .pre_taken_ex           (pre_taken_ex),
        .dec_adr_ex             (dec_adr_ex),
        .GPHT_pre_taken_ex      (GPHT_pre_taken_ex),
        .BPHT_pre_taken_ex      (BPHT_pre_taken_ex),
        .btb_hit_ex             (btb_hit_ex),
        .is_return_ex           (is_return_ex),
        .rs1_value_ex           (rs1_value_ex),
        .rs2_value_ex           (rs2_value_ex),
        .alu_value_wb           (alu_value_wb),
        .bru_value_wb           (rd_value_wb),
        .mul_value_wb           (mul_value_wb),
        .div_value_wb           (div_value_wb),
        .lsu_value_wb           (lsu_value_wb),
        .forward1               (forward1),
        .forward2               (forward2),
        .complete_ex            (complete_ex),
        .adr_ex                 (adr_ex),
        .bru_recovery_ex        (bru_recovery_ex),
        .btb_wirte_ex           (btb_wirte_ex),
        .rd_value_ex            (rd_value_ex),
        .G_or_B_ex              (G_or_B_ex),
        .is_btype               (is_btype),
        .reg_write_en1          (reg_write_en1),
        .taken_ex               (taken_ex)
    );
    
    // 实例化resolve_bru模块
    resolve_bru u_resolve_bru (
        .complete_fentch        (complete_fentch),
        .complete_rob           (complete_rob),
        .resolve_complete       (resolve_complete)
    );
    
    // 实例化EX/WB槽
    ex_wb_bru u_ex_wb (
        .clk                    (clk),
        .reset                  (reset),
        .rob_id_ex              (rob_id_ex),
        .bob_id_ex              (bob_id_ex),
        .instr_valid_ex         (instr_valid_ex),
        .rd_number_ex           (rd_number_prf),
        .GHR_value_ex           (GHR_value_ex),
        .CPHT_GPHT_index_ex     (CPHT_GPHT_index_ex),
        .BPHT_index_ex          (BPHT_index_ex),
        .is_return_ex           (is_return_ex),
        .pc_ex                  (pc_ex),
        .RAS_count_ex           (RAS_count_ex),
        .complete_ex            (complete_ex),
        .bru_recovery_wb_in     (bru_recovery_wb),
        .true_adr_ex            (adr_ex),
        .bru_recovery_ex        (bru_recovery_ex),
        .btb_wirte_ex           (btb_wirte_ex),
        .rd_value_ex            (rd_value_ex),
        .G_or_B_ex              (G_or_B_ex),
        .is_btype               (is_btype),
        .taken_ex               (taken_ex),
        .reg_write_ex           (reg_write_en1),
        .resolve_complete       (resolve_complete),
        .rob_id_wb              (rob_id_wb_int),
        .bob_id_wb              (bob_id_wb_int),
        .instr_valid_wb         (instr_valid_wb_int),
        .rd_number_wb           (rd_number_wb_int),
        .GHR_value_wb           (GHR_wb_int),
        .CPHT_GPHT_index_wb     (GPHT_CPHT_index_wb_int),
        .BPHT_index_wb          (BPHT_index_wb_int),
        .is_return_wb           (is_return_wb_int),
        .pc_wb                  (pc_wb_int),
        .RAS_count_wb           (RAS_count_wb_int),
        .complete_wb            (complete_wb_int),
        .true_adr_wb            (true_adr_wb_int),
        .bru_recovery_wb        (bru_recovery_wb_int),
        .btb_wirte_wb           (btb_wirte_wb_int),
        .rd_value_wb            (rd_value_wb_int),
        .G_or_B_wb              (G_or_B_wb_int),
        .is_btype_wb            (is_btype_wb_int),
        .taken_wb               (taken_wb_int),
        .reg_write_wb           (reg_write_wb_int)
    );
    
    // 实例化wb_complete模块，其输出作为顶层输出
    wb_complete u_wb_complete (
        .rd_number_wb           (rd_number_wb_int),
        .reg_write_wb           (reg_write_wb_int),
        .bru_rob_id_wb          (rob_id_wb_int),     
        .BOB_id_wb              (bob_id_wb_int),
        .BOB_pc_wb              (pc_wb_int),
        .adr_wb                 (true_adr_wb_int),
        .bru_recovery_wb        (bru_recovery_wb_int),
        .btb_wirte_wb           (btb_wirte_wb_int),
        .rd_value_wb            (rd_value_wb_int),
        .RAS_count_wb           (RAS_count_wb_int),
        .instr_valid_wb         (instr_valid_wb_int),
        .taken_wb               (taken_wb_int),
        .GPHT_CPHT_index_wb     (GPHT_CPHT_index_wb_int),
        .BPHT_index_wb          (BPHT_index_wb_int),
        .GHR_wb                 (GHR_wb_int),
        .is_return_wb           (is_return_wb_int),
        .is_b_type_wb           (is_btype_wb_int),
        .G_or_B_wb              (G_or_B_wb_int),
        .complete_wb            (complete_wb_int),
        .rd_number_end          (rd_number_wb),
        .reg_write_end          (reg_write_wb),
        .bru_rob_id_end         (bru_rob_id_wb_out),
        .BOB_id_end             (BOB_id_wb),
        .BOB_pc_end             (BOB_pc_wb),
        .adr_end                (adr_wb),
        .bru_recovery_end       (bru_recovery_wb),
        .btb_wirte_end          (btb_wirte_wb),
        .rd_value_end           (rd_value_wb),
        .RAS_count_end          (RAS_count_wb),
        .taken_end              (taken_wb),
        .GPHT_CPHT_index_end    (GPHT_CPHT_index_wb),
        .BPHT_index_end         (BPHT_index_wb),
        .GHR_end                (GHR_wb),
        .is_return_end          (is_return_wb),
        .is_b_type_end          (is_b_type_wb),
        .G_or_B_end             (G_or_B_wb),
        .complete_end           (complete_wb)
    );
    
    // 输出总线唤醒信号
    assign bus_bru = bus_valid_bru;

endmodule

