/******************************************************************************
 * Filename: rename_top.sv
 * Author: FMRT22-HYC
 * Create date: 2026.03.30
 * Description: Top module integrating decode, rename, and dispatch stages
 *              with proper pipeline registers.
 *              Modified to fix dec_recover connections, ROB tail_ptr, and pipeline handshake.
 *              Fixed rename packet valid generation (resource check).
 ***************************************************************************/
//typedef struct packed {
//    logic [3:0]  ctrl_signal;
//    logic [1:0]  inst_type;
//    logic [3:0]  fu_select;
//    logic        inst_valid;
//    logic        rs1_valid;
//    logic        rs2_valid;
//    logic        rd_valid;
//    logic [63:0] immediate;
//    logic [5:0]  rs1_phys;
//    logic [5:0]  rs2_phys;
//    logic [5:0]  rd_phys;
//    logic [6:0]  rob_id;
//    logic [4:0]  BOB_id;
//} inst_packet_t;

module rename_top #(
    // Decode stage parameters
    parameter INST_WIDTH       = 32,
    parameter PC_WIDTH         = 64,
    parameter CTRL_SIG_WIDTH_ALU = 4,
    parameter CTRL_SIG_WIDTH_MDU = 4,
    parameter CTRL_SIG_WIDTH_BRU = 3,
    parameter CTRL_SIG_WIDTH_LSU = 4,
    parameter FU_WIDTH         = 4,
    parameter OPCODE_WIDTH     = 7,
    parameter FUNCT3_WIDTH     = 3,
    parameter FUNCT7_WIDTH     = 7,
    parameter REG_ADDR_WIDTH   = 5,
    // Rename stage parameters
    parameter LOGIC_REG_NUM    = 32,
    parameter LOGIC_REG_WID    = 5,
    parameter PHY_REG_WID      = 6,
    parameter PHY_REG_NUM      = 64,
    parameter ROB_ENTRY_NUM    = 64,
    parameter ROB_IDX_WID      = 6,
    parameter ROB_ID_WID       = 7,
    parameter PTR_WIDTH        = 5
)(
    // ============ Clock and Reset ============
    input  logic                     clk,
    input  logic                     reset,

    // ============ Decode Stage Inputs (from IFU) ============
    input  logic [INST_WIDTH-1:0]    inst1,
    input  logic [INST_WIDTH-1:0]    inst2,
    input  logic [PC_WIDTH-1:0]      pc1,
    input  logic [PC_WIDTH-1:0]      pc2,
    input  logic                     BOB_pred_taken1,
    input  logic                     BOB_pred_taken2,
    input  logic                     BOB_btb_hit1,
    input  logic                     BOB_btb_hit2,
    input  logic                     inst1_in_valid,
    input  logic                     inst2_in_valid,
    input  logic [4:0]               BOB_id1,
    input  logic [4:0]               BOB_id2,

    // ============ Decode Stage Outputs ============
    output logic                     dec_data_valid,
    output logic [PC_WIDTH-1:0]      dec_data,
    output logic                     dec_data_valid2,
    output logic [PC_WIDTH-1:0]      dec_data2,
    output logic                     dec_recover,
    output logic [1:0]               dec_recover_vec,
    output logic                     id_rr_ready_o,   // 连接到 IFU 中 IF/ID 寄存器的 ready_i

    // ============ Rename Stage Inputs (from execution) ============
    input  logic                     complete_en_alu,
    input  logic [ROB_ID_WID-1:0]    complete_id_alu,
    input  logic                     complete_en_bru,
    input  logic [ROB_ID_WID-1:0]    complete_id_bru,
    input  logic                     complete_en_lsu_load,
    input  logic [ROB_ID_WID-1:0]    complete_id_lsu_load,
    input  logic                     complete_en_lsu_store,
    input  logic [ROB_ID_WID-1:0]    complete_id_lsu_store,
    input  logic                     complete_en_mdu_mul,
    input  logic [ROB_ID_WID-1:0]    complete_id_mdu_mul,
    input  logic                     complete_en_mdu_div,
    input  logic [ROB_ID_WID-1:0]    complete_id_mdu_div,
    input  logic                     recover_en,
    input  logic [ROB_ID_WID-1:0]    recover_id,

    // ============ Rename Stage Outputs (to free list / PRF / ROB) ============
    output logic                     stall_id_rr,
    output logic [1:0]               retire_memwrite_cnt,
    output logic                     retire_en_1,
    output logic [PHY_REG_WID-1:0]   retire_rd_old_1,
    output logic                     retire_rd_en_1,
    output logic                     retire_en_2,
    output logic [PHY_REG_WID-1:0]   retire_rd_old_2,
    output logic                     retire_rd_en_2,
    output logic                     recover_valid_1,
    output logic                     recover_rd_en_1,
    output logic [PHY_REG_WID-1:0]   recover_rd_new_1,
    output logic                     recover_valid_2,
    output logic                     recover_rd_en_2,
    output logic [PHY_REG_WID-1:0]   recover_rd_new_2,
    output logic                     recover_complete,

    // ============ Dispatch Stage Inputs ============
    input  logic                     iq_alu_full_i,
    input  logic                     iq_mdu_full_i,
    input  logic                     iq_bru_full_i,
    input  logic                     iq_lsu_full_i,
    input  logic                     dispatch_iq_ready_o,
    // ============ Dispatch Stage Outputs ============
    output logic                     alu_pipe_valid_o0,
    output inst_packet_t             alu_pipe_inst_o0,
    output logic                     alu_pipe_valid_o1,
    output inst_packet_t             alu_pipe_inst_o1,
    output logic                     mdu_pipe_valid_o0,
    output inst_packet_t             mdu_pipe_inst_o0,
    output logic                     mdu_pipe_valid_o1,
    output inst_packet_t             mdu_pipe_inst_o1,
    output logic                     bru_pipe_valid_o0,
    output inst_packet_t             bru_pipe_inst_o0,
    output logic                     bru_pipe_valid_o1,
    output inst_packet_t             bru_pipe_inst_o1,
    output logic                     lsu_pipe_valid_o0,
    output inst_packet_t             lsu_pipe_inst_o0,
    output logic                     lsu_pipe_valid_o1,
    output inst_packet_t             lsu_pipe_inst_o1,
    output logic                     dispatch_stall_o
);

    // ============================================================
    // 1. Internal type definitions
    // ============================================================
    typedef struct packed {
        logic [REG_ADDR_WIDTH-1:0] rs1, rs2, rd;
        logic wen;
        logic rs1_exist, rs2_exist;
        logic memwrite;
        logic [CTRL_SIG_WIDTH_ALU-1:0] ctrl_alu;
        logic [CTRL_SIG_WIDTH_MDU-1:0] ctrl_mdu;
        logic [CTRL_SIG_WIDTH_BRU-1:0] ctrl_bru;
        logic [CTRL_SIG_WIDTH_LSU-1:0] ctrl_lsu;
        logic [FU_WIDTH-1:0] fu_sel;
        logic [PC_WIDTH-1:0] imm;
        logic [1:0] inst_type;
        logic [4:0] dec_BOB_id;
    } decode_entry_t;
    // ============================================================
    // 2. Decode -> ID/RR pipeline signals
    // ============================================================
    decode_entry_t decode_entry1, decode_entry2;
    logic decode_inst1_valid, decode_inst2_valid;
    decode_entry_t rr_entry1, rr_entry2;
    logic rr_inst1_valid, rr_inst2_valid;
    logic flush_id_rr;

    // ============================================================
    // 3. Rename stage (combinational) signals
    // ============================================================
    logic [PHY_REG_WID-1:0] srat_rs1_phy1, srat_rs2_phy1, srat_old_phy1;
    logic [PHY_REG_WID-1:0] srat_rs1_phy2, srat_rs2_phy2, srat_old_phy2;

    logic free_alloc_en1, free_alloc_en2;
    logic [PHY_REG_WID-1:0] free_alloc_phy1, free_alloc_phy2;
    logic free_list_null_int;
    logic [PTR_WIDTH:0] free_count;

    logic rob_retire_en1, rob_retire_en2;
    logic [PHY_REG_WID-1:0] rob_retire_rd_old1, rob_retire_rd_old2;
    logic rob_retire_rd_en1, rob_retire_rd_en2;
    logic [1:0] rob_retire_memwrite_cnt;
    logic rob_recover_valid1, rob_recover_valid2;
    logic rob_recover_rd_en1, rob_recover_rd_en2;
    logic [LOGIC_REG_WID-1:0] rob_recover_rd_logic1, rob_recover_rd_logic2;
    logic [PHY_REG_WID-1:0] rob_recover_rd_old1, rob_recover_rd_old2;
    logic [PHY_REG_WID-1:0] rob_recover_rd_new1, rob_recover_rd_new2;
    logic rob_recover_complete;
    logic rob_full_int, rob_empty;
    logic [ROB_ID_WID-1:0] rob_tail_ptr;

    logic rd_valid1, rd_valid2;

    inst_packet_t rename_packet1, rename_packet2;

    // ============================================================
    // 4. RR/Dispatch pipeline registers
    // ============================================================
    inst_packet_t dispatch_packet1, dispatch_packet2;
    logic dispatch_valid1, dispatch_valid2;
    logic stall_rr_dispatch, flush_rr_dispatch;
    logic rr_dispatch_ready_o;
    // ============================================================
    // 5. Instantiate Decode module
    // ============================================================
    decode #(
        .INST_WIDTH(INST_WIDTH),
        .PC_WIDTH(PC_WIDTH),
        .CTRL_SIG_WIDTH_ALU(CTRL_SIG_WIDTH_ALU),
        .CTRL_SIG_WIDTH_MDU(CTRL_SIG_WIDTH_MDU),
        .CTRL_SIG_WIDTH_BRU(CTRL_SIG_WIDTH_BRU),
        .CTRL_SIG_WIDTH_LSU(CTRL_SIG_WIDTH_LSU),
        .FU_WIDTH(FU_WIDTH),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .FUNCT3_WIDTH(FUNCT3_WIDTH),
        .FUNCT7_WIDTH(FUNCT7_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
    ) decode_inst (
        .clk(clk),
        .reset(reset),
        .inst1(inst1),
        .inst2(inst2),
        .pc1(pc1),
        .pc2(pc2),
        .BOB_pred_taken1(BOB_pred_taken1),
        .BOB_pred_taken2(BOB_pred_taken2),
        .BOB_btb_hit1(BOB_btb_hit1),
        .BOB_btb_hit2(BOB_btb_hit2),
        .inst1_in_valid(inst1_in_valid),
        .inst2_in_valid(inst2_in_valid),
        .rs1_1(decode_entry1.rs1),
        .rs2_1(decode_entry1.rs2),
        .rd_1(decode_entry1.rd),
        .rs1_2(decode_entry2.rs1),
        .rs2_2(decode_entry2.rs2),
        .rd_2(decode_entry2.rd),
        .wen_1(decode_entry1.wen),
        .wen_2(decode_entry2.wen),
        .rs1_exist1(decode_entry1.rs1_exist),
        .rs2_exist1(decode_entry1.rs2_exist),
        .rs1_exist2(decode_entry2.rs1_exist),
        .rs2_exist2(decode_entry2.rs2_exist),
        .memwrite1(decode_entry1.memwrite),
        .memwrite2(decode_entry2.memwrite),
        .dec_data_valid(dec_data_valid),
        .dec_data(dec_data),
        .dec_data_valid2(dec_data_valid2),
        .dec_data2(dec_data2),
        .dec_recover(dec_recover),
        .dec_recover_vec(dec_recover_vec),
        .ctrl_sig_alu1(decode_entry1.ctrl_alu),
        .ctrl_sig_alu2(decode_entry2.ctrl_alu),
        .ctrl_sig_mdu1(decode_entry1.ctrl_mdu),
        .ctrl_sig_mdu2(decode_entry2.ctrl_mdu),
        .ctrl_sig_bru1(decode_entry1.ctrl_bru),
        .ctrl_sig_bru2(decode_entry2.ctrl_bru),
        .ctrl_sig_lsu1(decode_entry1.ctrl_lsu),
        .ctrl_sig_lsu2(decode_entry2.ctrl_lsu),
        .fu_sel1(decode_entry1.fu_sel),
        .fu_sel2(decode_entry2.fu_sel),
        .imm1(decode_entry1.imm),
        .imm2(decode_entry2.imm),
        .inst_type1(decode_entry1.inst_type),
        .inst_type2(decode_entry2.inst_type),
        .inst1_valid(decode_inst1_valid),
        .inst2_valid(decode_inst2_valid)
    );
    assign decode_entry1.dec_BOB_id = BOB_id1;
    assign decode_entry2.dec_BOB_id = BOB_id2; 

    // ============================================================
    // 6. ID/RR Pipeline Register
    // ============================================================
    assign stall_id_rr = free_list_null_int | rob_full_int | dispatch_stall_o |recover_en;
    assign flush_id_rr = recover_en;

    pipeline_reg #(
        .DATA_WID($bits(decode_entry_t))
    ) id_rr_reg (
        .clk(clk),
        .reset(reset),
        .stall(stall_id_rr),
        .flush(flush_id_rr),
        .valid_i1(decode_inst1_valid),
        .data_i1(decode_entry1),
        .valid_i2(decode_inst2_valid),
        .data_i2(decode_entry2),
        .ready_i(rr_dispatch_ready_o),          // 下游传过来的
        .valid_o1(rr_inst1_valid),
        .data_o1(rr_entry1),
        .valid_o2(rr_inst2_valid),
        .data_o2(rr_entry2),
        .ready_o(id_rr_ready_o)       //输出给上游        
    );

    // ============================================================
    // 7. Rename Stage (combinational logic)
    // ============================================================
    assign rd_valid1 = rr_entry1.wen & (rr_entry1.rd != 5'b0);
    assign rd_valid2 = rr_entry2.wen & (rr_entry2.rd != 5'b0);

    assign free_alloc_en1 = rr_inst1_valid & rd_valid1 & ~free_list_null_int & ~rob_full_int & ~dispatch_stall_o;
    assign free_alloc_en2 = rr_inst2_valid & rd_valid2 & ~free_list_null_int & ~rob_full_int & ~dispatch_stall_o;

    // Free List instance
    free_list #(
        .LOGIC_REG_NUM(LOGIC_REG_NUM),
        .PHY_REG_NUM(PHY_REG_NUM),
        .PHY_REG_WID(PHY_REG_WID),
        .PTR_WIDTH(PTR_WIDTH)
    ) free_list_inst (
        .clk(clk),
        .reset(reset),
        .alloc_en_1(free_alloc_en1),
        .alloc_en_2(free_alloc_en2),
        .alloc_phy_1(free_alloc_phy1),
        .alloc_phy_2(free_alloc_phy2),
        .free_en_1(rob_retire_rd_en1),
        .free_phy_1(rob_retire_rd_old1),
        .free_en_2(rob_retire_rd_en2),
        .free_phy_2(rob_retire_rd_old2),
	.bru_recovery(recover_en),
        .recover_en_1(rob_recover_valid1 && rob_recover_rd_en1),
        .recover_phy_1(rob_recover_rd_new1),
        .recover_en_2(rob_recover_valid2 && rob_recover_rd_en2),
        .recover_phy_2(rob_recover_rd_new2),
        .rob_full(rob_full_int),
        .free_list_null(free_list_null_int),
        .free_count(free_count)
    );

    // SRAT instance
    SRAT #(
        .LOGIC_REG_NUM(LOGIC_REG_NUM),
        .LOGIC_REG_WID(LOGIC_REG_WID),
        .PHY_REG_WID(PHY_REG_WID),
        .PHY_REG_NUM(PHY_REG_NUM)
    ) srat_inst (
        .clk(clk),
        .reset(reset),
        .inst1_valid(rr_inst1_valid & ~dispatch_stall_o),
        .inst1_rs1(rr_entry1.rs1),
        .rs1_valid_1(rr_entry1.rs1_exist),
        .inst1_rs2(rr_entry1.rs2),
        .rs2_valid_1(rr_entry1.rs2_exist),
        .inst1_rd(rr_entry1.rd),
        .rd_valid_1(rd_valid1),
        .inst1_new_phy(free_alloc_phy1),
        .rename_en_1(free_alloc_en1),        
        .inst2_valid(rr_inst2_valid & ~dispatch_stall_o),
        .inst2_rs1(rr_entry2.rs1),
        .rs1_valid_2(rr_entry2.rs1_exist),
        .inst2_rs2(rr_entry2.rs2),
        .rs2_valid_2(rr_entry2.rs2_exist),
        .inst2_rd(rr_entry2.rd),
        .rd_valid_2(rd_valid2),
        .inst2_new_phy(free_alloc_phy2),
        .rename_en_2(free_alloc_en2),          // 新增连接
	.bru_recovery(recover_en),
        .recover_en_1(rob_recover_valid1 && rob_recover_rd_en1),
        .recover_addr_1(rob_recover_rd_logic1),
        .recover_phy_1(rob_recover_rd_old1),
        .recover_en_2(rob_recover_valid2 && rob_recover_rd_en2),
        .recover_addr_2(rob_recover_rd_logic2),
        .recover_phy_2(rob_recover_rd_old2),
        .free_list_null(free_list_null_int),
        .rob_full(rob_full_int),
        .inst1_rs1_phy(srat_rs1_phy1),
        .inst1_rs2_phy(srat_rs2_phy1),
        .inst1_old_phy(srat_old_phy1),
        .inst2_rs1_phy(srat_rs1_phy2),
        .inst2_rs2_phy(srat_rs2_phy2),
        .inst2_old_phy(srat_old_phy2)
    );

    // ROB instance (now with tail_ptr output)
    ROB #(
        .ROB_ENTRY_NUM(ROB_ENTRY_NUM),
        .ROB_IDX_WID(ROB_IDX_WID),
        .ROB_ID_WID(ROB_ID_WID),
        .LOGIC_REG_WID(LOGIC_REG_WID),
        .PHY_REG_WID(PHY_REG_WID)
    ) rob_inst (
        .clk(clk),
        .reset(reset),
        .rob_wr_en_1(rr_inst1_valid & ~dispatch_stall_o),
        .rob_rd_en_1(rd_valid1),
        .rob_rd_new_1(free_alloc_phy1),
        .rob_rd_old_1(srat_old_phy1),
        .rob_rd_logic_1(rr_entry1.rd),
        .rob_memwrite_1(rr_entry1.memwrite),
        .rob_wr_en_2(rr_inst2_valid & ~dispatch_stall_o),
        .rob_rd_en_2(rd_valid2),
        .rob_rd_new_2(free_alloc_phy2),
        .rob_rd_old_2(srat_old_phy2),
        .rob_rd_logic_2(rr_entry2.rd),
        .rob_memwrite_2(rr_entry2.memwrite),
        .complete_en_alu(complete_en_alu),
        .complete_id_alu(complete_id_alu),
        .complete_en_bru(complete_en_bru),
        .complete_id_bru(complete_id_bru),
        .complete_en_lsu_load(complete_en_lsu_load),
        .complete_id_lsu_load(complete_id_lsu_load),
        .complete_en_lsu_store(complete_en_lsu_store),
        .complete_id_lsu_store(complete_id_lsu_store),
        .complete_en_mdu_mul(complete_en_mdu_mul),
        .complete_id_mdu_mul(complete_id_mdu_mul),
        .complete_en_mdu_div(complete_en_mdu_div),
        .complete_id_mdu_div(complete_id_mdu_div),
        .recover_en(recover_en),
        .recover_id(recover_id),
        .retire_en_1(rob_retire_en1),
        .retire_rd_old_1(rob_retire_rd_old1),
        .retire_rd_en_1(rob_retire_rd_en1),
        .retire_en_2(rob_retire_en2),
        .retire_rd_old_2(rob_retire_rd_old2),
        .retire_rd_en_2(rob_retire_rd_en2),
        .retire_memwrite_cnt(rob_retire_memwrite_cnt),
        .recover_valid_1(rob_recover_valid1),
        .recover_rd_en_1(rob_recover_rd_en1),
        .recover_rd_logic_1(rob_recover_rd_logic1),
        .recover_rd_old_1(rob_recover_rd_old1),
        .recover_rd_new_1(rob_recover_rd_new1),
        .recover_valid_2(rob_recover_valid2),
        .recover_rd_en_2(rob_recover_rd_en2),
        .recover_rd_logic_2(rob_recover_rd_logic2),
        .recover_rd_old_2(rob_recover_rd_old2),
        .recover_rd_new_2(rob_recover_rd_new2),
        .recover_complete(rob_recover_complete),
        .rob_full(rob_full_int),
        .rob_empty(rob_empty),
        .tail_ptr(rob_tail_ptr)            
    );

    always_comb begin
        // Instruction 1
        rename_packet1.inst_valid  = rr_inst1_valid & ~free_list_null_int & ~rob_full_int & ~dispatch_stall_o;
        rename_packet1.fu_select   = rr_entry1.fu_sel;
        rename_packet1.inst_type   = rr_entry1.inst_type;
        rename_packet1.rs1_valid   = rr_entry1.rs1_exist;
        rename_packet1.rs2_valid   = rr_entry1.rs2_exist;
        rename_packet1.rd_valid    = rr_entry1.wen;
        rename_packet1.immediate   = rr_entry1.imm;
        rename_packet1.rs1_phys    = srat_rs1_phy1;
        rename_packet1.rs2_phys    = srat_rs2_phy1;
        rename_packet1.rd_phys     = free_alloc_phy1;
        rename_packet1.rob_id      = rob_tail_ptr;
        rename_packet1.BOB_id      = rr_entry1.dec_BOB_id;
        case (rr_entry1.fu_sel)
            4'b1000: rename_packet1.ctrl_signal = rr_entry1.ctrl_alu;
            4'b0100: rename_packet1.ctrl_signal = rr_entry1.ctrl_mdu;
            4'b0010: rename_packet1.ctrl_signal = rr_entry1.ctrl_bru;
            4'b0001: rename_packet1.ctrl_signal = rr_entry1.ctrl_lsu;
            default: rename_packet1.ctrl_signal = 4'b0;
        endcase

        // Instruction 2
        rename_packet2.inst_valid  = rr_inst2_valid & ~free_list_null_int & ~rob_full_int & ~dispatch_stall_o;
        rename_packet2.fu_select   = rr_entry2.fu_sel;
        rename_packet2.inst_type   = rr_entry2.inst_type;
        rename_packet2.rs1_valid   = rr_entry2.rs1_exist;
        rename_packet2.rs2_valid   = rr_entry2.rs2_exist;
        rename_packet2.rd_valid    = rr_entry2.wen;
        rename_packet2.immediate   = rr_entry2.imm;
        rename_packet2.rs1_phys    = srat_rs1_phy2;
        rename_packet2.rs2_phys    = srat_rs2_phy2;
        rename_packet2.rd_phys     = free_alloc_phy2;
        rename_packet2.rob_id      = rob_tail_ptr + 1'b1;
        rename_packet2.BOB_id      = rr_entry2.dec_BOB_id;
        case (rr_entry2.fu_sel)
            4'b1000: rename_packet2.ctrl_signal = rr_entry2.ctrl_alu;
            4'b0100: rename_packet2.ctrl_signal = rr_entry2.ctrl_mdu;
            4'b0010: rename_packet2.ctrl_signal = rr_entry2.ctrl_bru;
            4'b0001: rename_packet2.ctrl_signal = rr_entry2.ctrl_lsu;
            default: rename_packet2.ctrl_signal = 4'b0;
        endcase
    end

    // ============================================================
    // 8. RR/Dispatch Pipeline Register
    // ============================================================
    assign stall_rr_dispatch = dispatch_stall_o | recover_en;
    assign flush_rr_dispatch = recover_en;

    pipeline_reg #(
        .DATA_WID($bits(inst_packet_t))
    ) rr_dispatch_reg (
        .clk(clk),
        .reset(reset),
        .stall(stall_rr_dispatch),
        .flush(flush_rr_dispatch),
        .valid_i1(rename_packet1.inst_valid),
        .data_i1(rename_packet1),
        .valid_i2(rename_packet2.inst_valid),
        .data_i2(rename_packet2),
        .ready_i(dispatch_iq_ready_o),          // 下游
        .valid_o1(dispatch_valid1),
        .data_o1(dispatch_packet1),
        .valid_o2(dispatch_valid2),
        .data_o2(dispatch_packet2),
        .ready_o(rr_dispatch_ready_o)        //输出到上游       
    );

    // ============================================================
    // 9. Dispatch Module
    // ============================================================
    dispatch dispatch_inst (
        .clk(clk),
        .reset(reset),
        .dispatch_valid_i1(dispatch_valid1),
        .dispatch_inst_i1(dispatch_packet1),
        .dispatch_valid_i2(dispatch_valid2),
        .dispatch_inst_i2(dispatch_packet2),
        .iq_alu_full_i(iq_alu_full_i),
        .iq_mdu_full_i(iq_mdu_full_i),
        .iq_bru_full_i(iq_bru_full_i),
        .iq_lsu_full_i(iq_lsu_full_i),
        .alu_pipe_valid_o0(alu_pipe_valid_o0),
        .alu_pipe_inst_o0(alu_pipe_inst_o0),
        .alu_pipe_valid_o1(alu_pipe_valid_o1),
        .alu_pipe_inst_o1(alu_pipe_inst_o1),
        .mdu_pipe_valid_o0(mdu_pipe_valid_o0),
        .mdu_pipe_inst_o0(mdu_pipe_inst_o0),
        .mdu_pipe_valid_o1(mdu_pipe_valid_o1),
        .mdu_pipe_inst_o1(mdu_pipe_inst_o1),
        .bru_pipe_valid_o0(bru_pipe_valid_o0),
        .bru_pipe_inst_o0(bru_pipe_inst_o0),
        .bru_pipe_valid_o1(bru_pipe_valid_o1),
        .bru_pipe_inst_o1(bru_pipe_inst_o1),
        .lsu_pipe_valid_o0(lsu_pipe_valid_o0),
        .lsu_pipe_inst_o0(lsu_pipe_inst_o0),
        .lsu_pipe_valid_o1(lsu_pipe_valid_o1),
        .lsu_pipe_inst_o1(lsu_pipe_inst_o1),
        .dispatch_stall_o(dispatch_stall_o)
    );

    // ============================================================
    // 10. Output assignments
    // ============================================================
    assign retire_memwrite_cnt = rob_retire_memwrite_cnt;
    assign retire_en_1 = rob_retire_en1;
    assign retire_rd_old_1 = rob_retire_rd_old1;
    assign retire_rd_en_1 = rob_retire_rd_en1;
    assign retire_en_2 = rob_retire_en2;
    assign retire_rd_old_2 = rob_retire_rd_old2;
    assign retire_rd_en_2 = rob_retire_rd_en2;
    assign recover_valid_1 = rob_recover_valid1;
    assign recover_rd_en_1 = rob_recover_rd_en1;
    assign recover_rd_new_1 = rob_recover_rd_new1;
    assign recover_valid_2 = rob_recover_valid2;
    assign recover_rd_en_2 = rob_recover_rd_en2;
    assign recover_rd_new_2 = rob_recover_rd_new2;
    assign recover_complete = rob_recover_complete;

endmodule

