typedef struct packed {
    logic [3:0]  ctrl_signal;   // 功能单元内部控制信号（如ALU操作码）
    logic [1:0]  inst_type;     // 指令类型（R/I/S/B等）
    logic [3:0]  fu_select;     // 功能单元选择（4'b1000=ALU, 0100=MDU, 0010=BRU, 0001=LSU）
    logic        inst_valid;    // 指令有效标志
    logic        rs1_valid;     // 源寄存器1有效标志
    logic        rs2_valid;     // 源寄存器2有效标志
    logic        rd_valid;      // 目的寄存器有效标志
    logic [63:0] immediate;     // 立即数（或分支目标地址）
    logic [5:0]  rs1_phys;      // 物理寄存器地址（RS1）
    logic [5:0]  rs2_phys;      // 物理寄存器地址（RS2）
    logic [5:0]  rd_phys;       // 物理寄存器地址（RD）
    logic [6:0]  rob_id;        // 重排序缓冲区条目ID
    logic [4:0]  BOB_id;        // 分支顺序缓冲区条目ID
} inst_packet_t;

module RV64IM (
    input  logic clk,
    input  logic reset,
    
    // 处理器接口 - 指令侧
    output logic [38:0] I_VA,       // 指令虚拟地址
    output logic IT_req_in,         // 指令缓存请求
    output logic IC_dataout_rdy,    // 处理器准备好接收指令
    input logic I_hit,              // 指令命中
    input logic [127:0] I_data_out, // 指令数据输出
    input logic [11:0] Br_type_out, // 分支类型输出
    input logic IC_dataout_val,     // 用于IB
    
    // 处理器接口 - 数据侧
    output logic [38:0] D_VA,          // 数据虚拟地址
    output logic [63:0] St_data,       // Store指令的写操作数
    output logic [1:0] St_type,        // Store指令的写操作类型
    output logic Ld_en,               // Load指令访问信号
    output logic St_en,               // Store指令访问信号（来自SB，受ROB控制）
    output logic DC_dataout_rdy,      // 流水线输入
    input logic D_hit,              // 数据命中
    input logic [63:0] D_data_out,   // 数据输出
    input logic DC_dataout_val,     // 流水线输出
    output logic [38:0] SD_VA,
    // 外部控制信号
    output logic pause_signal,         // （暂停信号）
    output logic BRU_recovery
);

    // IF/ID Interface
    wire         if_ready;
    reg  [1:0]   ib_valid;
    reg  [31:0]  if_instr0;
    reg  [31:0]  if_instr1;
    reg  [4:0]   if_bob_id0;//输出到IF/ID的D端
    reg  [4:0]   if_bob_id1;
    logic [4:0]  bob_id_d0;//从IF/ID Q端输入到bob
    logic [4:0]  bob_id_d1;

    // Decode Interface
    logic        dec_wr_en_0;
    logic [63:0] DE_adr_0;

    logic        dec_wr_en_1;
    logic [63:0] DE_adr_1;

    logic        dec_recover;
    logic [1:0]  dec_vec;
    // input logic [63:0]  de_pc,
    
    logic [63:0] d_pc_0;
    logic [63:0] d_pc_1;
    logic [63:0] d_pre_addr_0;
    logic [63:0] d_pre_addr_1;
    logic        d_pre_dir_0;
    logic        d_pre_dir_1;
    logic [63:0] d_de_adr_0;
    logic [63:0] d_de_adr_1;
    logic [7:0]  d_ghr_old_0;
    logic [7:0]  d_ghr_old_1;
    logic [7:0]  d_g_idx_0;
    logic [7:0]  d_g_idx_1;
    logic [7:0]  d_b_idx_0;
    logic [7:0]  d_b_idx_1;
    logic        d_g_dir_0;
    logic        d_g_dir_1;
    logic        d_b_dir_0;
    logic        d_b_dir_1;
    logic        d_btb_hit_0;
    logic        d_btb_hit_1;
    logic [4:0]  d_ras_count_0;
    logic [4:0]  d_ras_count_1;
    logic        d_read_ras_0;
    logic        d_read_ras_1;//是RETURN指令

    // Prf Interface
    logic [4:0]  bob_id_p;
    logic [63:0] p_pc;
    logic [63:0] p_pre_addr;
    logic        p_pre_dir;
    logic [63:0] p_de_adr;
    logic [7:0]  p_ghr_old;
    logic [7:0]  p_g_idx;
    logic [7:0]  p_b_idx;
    logic        p_g_dir;
    logic        p_b_dir;
    logic        p_btb_hit;
    logic [4:0]  p_ras_count;
    logic        p_read_ras;

    // BRU/Commit
    logic        BRU_complete;
    
    logic [4:0]  bob_bru_id;
    logic        btb_recover;
    //input  logic [63:0] btb_write_pc,
    logic [63:0] btb_write_target;//跳转的地址
    logic [63:0] bru_pc;//索引的PC
    logic        dir_right_pre;
    logic [7:0]  GPHT_CPHT_index_wb;
    logic [7:0]  bob_b_index_commit;
  
    logic [7:0]  bob_ghr_old;
    logic [1:0]G_or_B_wb;
    logic [4:0] bru_ras_count;
    logic ret_commit ;//read_ras
    logic bru_if_b;//是B格式类型的指令
    logic ib_full;
    logic bob_full;
    logic ras_recover_complete;
    wire  recoverib_complete;

    logic [63:0]PC_ifu;
    logic [63:0]address_end;//EX阶段对外输出的地址

    //IF_ID
    logic flush_if_id;
    logic inst1_in_valid;
    logic inst2_in_valid;
    logic [31:0] inst1;
    logic [31:0] inst2;
    logic id_rr_ready_o;
    
    //rename use (execution unit)
    logic          complete_en_alu;
    logic [6:0]    complete_id_alu;
    logic [6:0]    complete_id_bru;
    logic          complete_en_lsu_load;
    logic [6:0]    complete_id_lsu_load;
    logic          complete_en_lsu_store;
    logic [6:0]    complete_id_lsu_store;
    logic          complete_en_mdu_mul;
    logic [6:0]    complete_id_mdu_mul;
    logic          complete_en_mdu_div;
    logic [6:0]    complete_id_mdu_div;

    //Rename Stage Outputs (to free list / PRF / ROB)
    logic          stall_id_rr;
    logic [1:0]    retire_memwrite_cnt;
    logic          retire_en_1;
    logic [5:0]    retire_rd_old_1;
    logic          retire_rd_en_1;
    logic          retire_en_2;
    logic [5:0]    retire_rd_old_2;
    logic          retire_rd_en_2;
    logic          recover_valid_1;
    logic          recover_rd_en_1;
    logic [5:0]    recover_rd_new_1;
    logic          recover_valid_2;
    logic          recover_rd_en_2;
    logic [5:0]    recover_rd_new_2;
    logic          recover_complete;

    // dispatch use (execution units)
    logic          iq_alu_full_i;
    logic          iq_mdu_full_i;
    logic          iq_bru_full_i;
    logic          iq_lsu_full_i;
    logic          dispatch_iq_ready_o;

    // Dispatch Stage Outputs
    logic          alu_pipe_valid_o0;
    inst_packet_t  alu_pipe_inst_o0;
    logic          alu_pipe_valid_o1;
    inst_packet_t  alu_pipe_inst_o1;
    logic          mdu_pipe_valid_o0;
    inst_packet_t  mdu_pipe_inst_o0;
    logic          mdu_pipe_valid_o1;
    inst_packet_t  mdu_pipe_inst_o1;
    logic          bru_pipe_valid_o0;
    inst_packet_t  bru_pipe_inst_o0;
    logic          bru_pipe_valid_o1;
    inst_packet_t  bru_pipe_inst_o1;
    logic          lsu_pipe_valid_o0;
    inst_packet_t  lsu_pipe_inst_o0;
    logic          lsu_pipe_valid_o1;
    inst_packet_t  lsu_pipe_inst_o1;
    logic          dispatch_stall_o;

    //dispatch_iq_reg
    logic [3:0]    alu1_ctrl_signal_q;
    logic [1:0]    alu1_inst_type_q;
    logic [3:0]    alu1_fu_select_q;
    logic          alu1_inst_valid_q;
    logic          alu1_rs1_valid_q;
    logic          alu1_rs2_valid_q;
    logic          alu1_rd_valid_q;
    logic [63:0]   alu1_immediate_q;
    logic [5:0]    alu1_rs1_phys_q;
    logic [5:0]    alu1_rs2_phys_q;
    logic [5:0]    alu1_rd_phys_q;
    logic [6:0]    alu1_rob_id_q;
    logic [4:0]    alu1_BOB_id_q;

    logic [3:0]    alu2_ctrl_signal_q;
    logic [1:0]    alu2_inst_type_q;
    logic [3:0]    alu2_fu_select_q;
    logic          alu2_inst_valid_q;
    logic          alu2_rs1_valid_q;
    logic          alu2_rs2_valid_q;
    logic          alu2_rd_valid_q;
    logic [63:0]   alu2_immediate_q;
    logic [5:0]    alu2_rs1_phys_q;
    logic [5:0]    alu2_rs2_phys_q;
    logic [5:0]    alu2_rd_phys_q;
    logic [6:0]    alu2_rob_id_q;
    logic [4:0]    alu2_BOB_id_q;

    logic [3:0]    bru1_ctrl_signal_q;
    logic [1:0]    bru1_inst_type_q;
    logic [3:0]    bru1_fu_select_q;
    logic          bru1_inst_valid_q;
    logic          bru1_rs1_valid_q;
    logic          bru1_rs2_valid_q;
    logic          bru1_rd_valid_q;
    logic [63:0]   bru1_immediate_q;
    logic [5:0]    bru1_rs1_phys_q;
    logic [5:0]    bru1_rs2_phys_q;
    logic [5:0]    bru1_rd_phys_q;
    logic [6:0]    bru1_rob_id_q;
    logic [4:0]    bru1_BOB_id_q;
    
    logic [3:0]    bru2_ctrl_signal_q;
    logic [1:0]    bru2_inst_type_q;
    logic [3:0]    bru2_fu_select_q;
    logic          bru2_inst_valid_q;
    logic          bru2_rs1_valid_q;
    logic          bru2_rs2_valid_q;
    logic          bru2_rd_valid_q;
    logic [63:0]   bru2_immediate_q;
    logic [5:0]    bru2_rs1_phys_q;
    logic [5:0]    bru2_rs2_phys_q;
    logic [5:0]    bru2_rd_phys_q;
    logic [6:0]    bru2_rob_id_q;
    logic [4:0]    bru2_BOB_id_q;

    logic [3:0]    mdu1_ctrl_signal_q;
    logic [1:0]    mdu1_inst_type_q;
    logic [3:0]    mdu1_fu_select_q;
    logic          mdu1_inst_valid_q;
    logic          mdu1_rs1_valid_q;
    logic          mdu1_rs2_valid_q;
    logic          mdu1_rd_valid_q;
    logic [63:0]   mdu1_immediate_q;
    logic [5:0]    mdu1_rs1_phys_q;
    logic [5:0]    mdu1_rs2_phys_q;
    logic [5:0]    mdu1_rd_phys_q;
    logic [6:0]    mdu1_rob_id_q;
    logic [4:0]    mdu1_BOB_id_q;

    logic [3:0]    mdu2_ctrl_signal_q;
    logic [1:0]    mdu2_inst_type_q;
    logic [3:0]    mdu2_fu_select_q;
    logic          mdu2_inst_valid_q;
    logic          mdu2_rs1_valid_q;
    logic          mdu2_rs2_valid_q;
    logic          mdu2_rd_valid_q;
    logic [63:0]   mdu2_immediate_q;
    logic [5:0]    mdu2_rs1_phys_q;
    logic [5:0]    mdu2_rs2_phys_q;
    logic [5:0]    mdu2_rd_phys_q;
    logic [6:0]    mdu2_rob_id_q;
    logic [4:0]    mdu2_BOB_id_q;

    logic [3:0]    lsu1_ctrl_signal_q;
    logic [1:0]    lsu1_inst_type_q;
    logic [3:0]    lsu1_fu_select_q;
    logic          lsu1_inst_valid_q;
    logic          lsu1_rs1_valid_q;
    logic          lsu1_rs2_valid_q;
    logic          lsu1_rd_valid_q;
    logic [63:0]   lsu1_immediate_q;
    logic [5:0]    lsu1_rs1_phys_q;
    logic [5:0]    lsu1_rs2_phys_q;
    logic [5:0]    lsu1_rd_phys_q;
    logic [6:0]    lsu1_rob_id_q;
    logic [4:0]    lsu1_BOB_id_q;

    logic [3:0]    lsu2_ctrl_signal_q;
    logic [1:0]    lsu2_inst_type_q;
    logic [3:0]    lsu2_fu_select_q;
    logic          lsu2_inst_valid_q;
    logic          lsu2_rs1_valid_q;
    logic          lsu2_rs2_valid_q;
    logic          lsu2_rd_valid_q;
    logic [63:0]   lsu2_immediate_q;
    logic [5:0]    lsu2_rs1_phys_q;
    logic [5:0]    lsu2_rs2_phys_q;
    logic [5:0]    lsu2_rd_phys_q;
    logic [6:0]    lsu2_rob_id_q;
    logic [4:0]    lsu2_BOB_id_q;

    logic [63:0]sd_VA;


    logic write_ok1;
    logic write_ok2;

    assign I_VA = PC_ifu[38:0]; 
    assign  D_VA=address_end[38:0];
    assign SD_VA= sd_VA[38:0];
    
    ifu_top ifu(clk,reset,
            I_hit&IC_dataout_val,I_data_out,Br_type_out,
            PC_ifu,IT_req_in,IC_dataout_rdy,
            if_ready,ib_valid,if_instr0,if_instr1,if_bob_id0,if_bob_id1,bob_id_d0,bob_id_d1,
            dec_wr_en_0,DE_adr_0,dec_wr_en_1,DE_adr_1,dec_recover,dec_vec,
            d_pc_0,d_pc_1,d_pre_addr_0,d_pre_addr_1,d_pre_dir_0,d_pre_dir_1,d_de_adr_0,d_de_adr_1,d_ghr_old_0,d_ghr_old_1,d_g_idx_0,d_g_idx_1,d_b_idx_0,d_b_idx_1,d_g_dir_0,d_g_dir_1,d_b_dir_0,d_b_dir_1,d_btb_hit_0,d_btb_hit_1,d_ras_count_0,d_ras_count_1,d_read_ras_0,d_read_ras_1,
            bob_id_p,p_pc,p_pre_addr,p_pre_dir,p_de_adr,p_ghr_old,p_g_idx,p_b_idx,p_g_dir,p_b_dir,p_btb_hit,p_ras_count,p_read_ras,
            BRU_complete,BRU_recovery,bob_bru_id,btb_recover,
            btb_write_target,bru_pc,dir_right_pre,GPHT_CPHT_index_wb,bob_b_index_commit,GPHT_CPHT_index_wb,bob_ghr_old,
            G_or_B_wb[1],G_or_B_wb[0],bru_ras_count,ret_commit ,bru_if_b,ib_full,bob_full,ras_recover_complete,recoverib_complete);
    

    assign flush_if_id = dec_recover | BRU_recovery;

    pipeline_reg #(
        .DATA_WID(37)
    )if_id_reg (
            clk,reset,flush_if_id,stall_id_rr,
            ib_valid[0],{if_bob_id0,if_instr0},
            ib_valid[1],{if_bob_id1,if_instr1},
            if_ready,
            inst1_in_valid,{bob_id_d0,inst1},
            inst2_in_valid,{bob_id_d1,inst2},
            id_rr_ready_o
    );

    rename_top rename(
            clk,reset,
            inst1,inst2,d_pc_0,d_pc_1,d_pre_dir_0,d_pre_dir_1,d_btb_hit_0,d_btb_hit_1,inst1_in_valid & ~dispatch_stall_o,inst2_in_valid & ~dispatch_stall_o,bob_id_d0,bob_id_d1,
            dec_wr_en_0,DE_adr_0,dec_wr_en_1,DE_adr_1,dec_recover,dec_vec,id_rr_ready_o,
            complete_en_alu,complete_id_alu,BRU_complete,complete_id_bru,complete_en_lsu_load,complete_id_lsu_load,complete_en_lsu_store,complete_id_lsu_store,complete_en_mdu_mul,complete_id_mdu_mul,complete_en_mdu_div,complete_id_mdu_div,BRU_recovery,complete_id_bru,
            stall_id_rr,retire_memwrite_cnt,retire_en_1,retire_rd_old_1,retire_rd_en_1,retire_en_2,retire_rd_old_2,retire_rd_en_2,recover_valid_1,recover_rd_en_1,recover_rd_new_1,recover_valid_2,recover_rd_en_2,recover_rd_new_2,recover_complete,
            iq_alu_full_i,iq_mdu_full_i,iq_bru_full_i,iq_lsu_full_i,dispatch_iq_ready_o,
            alu_pipe_valid_o0,alu_pipe_inst_o0,alu_pipe_valid_o1,alu_pipe_inst_o1,mdu_pipe_valid_o0,mdu_pipe_inst_o0,mdu_pipe_valid_o1,mdu_pipe_inst_o1,bru_pipe_valid_o0,bru_pipe_inst_o0,bru_pipe_valid_o1,bru_pipe_inst_o1,lsu_pipe_valid_o0,lsu_pipe_inst_o0,lsu_pipe_valid_o1,lsu_pipe_inst_o1,dispatch_stall_o
    );

    dispatch_iq_reg alu1_iq_reg(
            clk,reset,BRU_recovery,dispatch_stall_o, 
            alu_pipe_inst_o0.ctrl_signal,alu_pipe_inst_o0.inst_type,alu_pipe_inst_o0.fu_select,alu_pipe_valid_o0,alu_pipe_inst_o0.rs1_valid,alu_pipe_inst_o0.rs2_valid,alu_pipe_inst_o0.rd_valid,alu_pipe_inst_o0.immediate,alu_pipe_inst_o0.rs1_phys,alu_pipe_inst_o0.rs2_phys,alu_pipe_inst_o0.rd_phys,alu_pipe_inst_o0.rob_id,alu_pipe_inst_o0.BOB_id,            
            alu1_dispatch_iq_ready_o,
            alu1_ctrl_signal_q,alu1_inst_type_q,alu1_fu_select_q,alu1_inst_valid_q,alu1_rs1_valid_q,alu1_rs2_valid_q,alu1_rd_valid_q,alu1_immediate_q,alu1_rs1_phys_q,alu1_rs2_phys_q,alu1_rd_phys_q,alu1_rob_id_q,alu1_BOB_id_q,
            ~iq_alu_full_i,write_ok1
    );
    dispatch_iq_reg alu2_iq_reg(
            clk,reset,BRU_recovery,dispatch_stall_o, 
            alu_pipe_inst_o1.ctrl_signal,alu_pipe_inst_o1.inst_type,alu_pipe_inst_o1.fu_select,alu_pipe_valid_o1,alu_pipe_inst_o1.rs1_valid,alu_pipe_inst_o1.rs2_valid,alu_pipe_inst_o1.rd_valid,alu_pipe_inst_o1.immediate,alu_pipe_inst_o1.rs1_phys,alu_pipe_inst_o1.rs2_phys,alu_pipe_inst_o1.rd_phys,alu_pipe_inst_o1.rob_id,alu_pipe_inst_o1.BOB_id,
            alu2_dispatch_iq_ready_o,
            alu2_ctrl_signal_q,alu2_inst_type_q,alu2_fu_select_q,alu2_inst_valid_q,alu2_rs1_valid_q,alu2_rs2_valid_q,alu2_rd_valid_q,alu2_immediate_q,alu2_rs1_phys_q,alu2_rs2_phys_q,alu2_rd_phys_q,alu2_rob_id_q,alu2_BOB_id_q,
            ~iq_alu_full_i,write_ok2
    );  
    dispatch_iq_reg bru1_iq_reg(
            clk,reset,BRU_recovery,dispatch_stall_o, 
            bru_pipe_inst_o0.ctrl_signal,bru_pipe_inst_o0.inst_type,bru_pipe_inst_o0.fu_select,bru_pipe_valid_o0,bru_pipe_inst_o0.rs1_valid,bru_pipe_inst_o0.rs2_valid,bru_pipe_inst_o0.rd_valid,bru_pipe_inst_o0.immediate,bru_pipe_inst_o0.rs1_phys,bru_pipe_inst_o0.rs2_phys,bru_pipe_inst_o0.rd_phys,bru_pipe_inst_o0.rob_id,bru_pipe_inst_o0.BOB_id,
            bru1_dispatch_iq_ready_o,
            bru1_ctrl_signal_q,bru1_inst_type_q,bru1_fu_select_q,bru1_inst_valid_q,bru1_rs1_valid_q,bru1_rs2_valid_q,bru1_rd_valid_q,bru1_immediate_q,bru1_rs1_phys_q,bru1_rs2_phys_q,bru1_rd_phys_q,bru1_rob_id_q,bru1_BOB_id_q,
            ~iq_bru_full_i,write_ok3
    );
    dispatch_iq_reg bru2_iq_reg(
            clk,reset,BRU_recovery,dispatch_stall_o, 
            bru_pipe_inst_o1.ctrl_signal,bru_pipe_inst_o1.inst_type,bru_pipe_inst_o1.fu_select,bru_pipe_valid_o1,bru_pipe_inst_o1.rs1_valid,bru_pipe_inst_o1.rs2_valid,bru_pipe_inst_o1.rd_valid,bru_pipe_inst_o1.immediate,bru_pipe_inst_o1.rs1_phys,bru_pipe_inst_o1.rs2_phys,bru_pipe_inst_o1.rd_phys,bru_pipe_inst_o1.rob_id,bru_pipe_inst_o1.BOB_id,
            bru2_dispatch_iq_ready_o,
            bru2_ctrl_signal_q,bru2_inst_type_q,bru2_fu_select_q,bru2_inst_valid_q,bru2_rs1_valid_q,bru2_rs2_valid_q,bru2_rd_valid_q,bru2_immediate_q,bru2_rs1_phys_q,bru2_rs2_phys_q,bru2_rd_phys_q,bru2_rob_id_q,bru2_BOB_id_q,
            ~iq_bru_full_i,write_ok4
    );
    dispatch_iq_reg mdu1_iq_reg(
            clk,reset,BRU_recovery,dispatch_stall_o, 
            mdu_pipe_inst_o0.ctrl_signal,mdu_pipe_inst_o0.inst_type,mdu_pipe_inst_o0.fu_select,mdu_pipe_valid_o0,mdu_pipe_inst_o0.rs1_valid,mdu_pipe_inst_o0.rs2_valid,mdu_pipe_inst_o0.rd_valid,mdu_pipe_inst_o0.immediate,mdu_pipe_inst_o0.rs1_phys,mdu_pipe_inst_o0.rs2_phys,mdu_pipe_inst_o0.rd_phys,mdu_pipe_inst_o0.rob_id,mdu_pipe_inst_o0.BOB_id,
            mdu1_dispatch_iq_ready_o,
            mdu1_ctrl_signal_q,mdu1_inst_type_q,mdu1_fu_select_q,mdu1_inst_valid_q,mdu1_rs1_valid_q,mdu1_rs2_valid_q,mdu1_rd_valid_q,mdu1_immediate_q,mdu1_rs1_phys_q,mdu1_rs2_phys_q,mdu1_rd_phys_q,mdu1_rob_id_q,mdu1_BOB_id_q,
            ~iq_mdu_full_i,1'b0
    );
    dispatch_iq_reg mdu2_iq_reg(
            clk,reset,BRU_recovery,dispatch_stall_o, 
            mdu_pipe_inst_o1.ctrl_signal,mdu_pipe_inst_o1.inst_type,mdu_pipe_inst_o1.fu_select,mdu_pipe_valid_o1,mdu_pipe_inst_o1.rs1_valid,mdu_pipe_inst_o1.rs2_valid,mdu_pipe_inst_o1.rd_valid,mdu_pipe_inst_o1.immediate,mdu_pipe_inst_o1.rs1_phys,mdu_pipe_inst_o1.rs2_phys,mdu_pipe_inst_o1.rd_phys,mdu_pipe_inst_o1.rob_id,mdu_pipe_inst_o1.BOB_id,
            mdu2_dispatch_iq_ready_o,
            mdu2_ctrl_signal_q,mdu2_inst_type_q,mdu2_fu_select_q,mdu2_inst_valid_q,mdu2_rs1_valid_q,mdu2_rs2_valid_q,mdu2_rd_valid_q,mdu2_immediate_q,mdu2_rs1_phys_q,mdu2_rs2_phys_q,mdu2_rd_phys_q,mdu2_rob_id_q,mdu2_BOB_id_q,
            ~iq_mdu_full_i,1'b0   
    );
    dispatch_iq_reg lsu1_iq_reg(
            clk,reset,BRU_recovery,dispatch_stall_o, 
            lsu_pipe_inst_o0.ctrl_signal,lsu_pipe_inst_o0.inst_type,lsu_pipe_inst_o0.fu_select,lsu_pipe_valid_o0,lsu_pipe_inst_o0.rs1_valid,lsu_pipe_inst_o0.rs2_valid,lsu_pipe_inst_o0.rd_valid,lsu_pipe_inst_o0.immediate,lsu_pipe_inst_o0.rs1_phys,lsu_pipe_inst_o0.rs2_phys,lsu_pipe_inst_o0.rd_phys,lsu_pipe_inst_o0.rob_id,lsu_pipe_inst_o0.BOB_id,
            lsu1_dispatch_iq_ready_o,
            lsu1_ctrl_signal_q,lsu1_inst_type_q,lsu1_fu_select_q,lsu1_inst_valid_q,lsu1_rs1_valid_q,lsu1_rs2_valid_q,lsu1_rd_valid_q,lsu1_immediate_q,lsu1_rs1_phys_q,lsu1_rs2_phys_q,lsu1_rd_phys_q,lsu1_rob_id_q,lsu1_BOB_id_q,
            ~iq_lsu_full_i,1'b0
    );
    dispatch_iq_reg lsu2_iq_reg(
            clk,reset,BRU_recovery,dispatch_stall_o, 
            lsu_pipe_inst_o1.ctrl_signal,lsu_pipe_inst_o1.inst_type,lsu_pipe_inst_o1.fu_select,lsu_pipe_valid_o1,lsu_pipe_inst_o1.rs1_valid,lsu_pipe_inst_o1.rs2_valid,lsu_pipe_inst_o1.rd_valid,lsu_pipe_inst_o1.immediate,lsu_pipe_inst_o1.rs1_phys,lsu_pipe_inst_o1.rs2_phys,lsu_pipe_inst_o1.rd_phys,lsu_pipe_inst_o1.rob_id,lsu_pipe_inst_o1.BOB_id,
            lsu2_dispatch_iq_ready_o,
            lsu2_ctrl_signal_q,lsu2_inst_type_q,lsu2_fu_select_q,lsu2_inst_valid_q,lsu2_rs1_valid_q,lsu2_rs2_valid_q,lsu2_rd_valid_q,lsu2_immediate_q,lsu2_rs1_phys_q,lsu2_rs2_phys_q,lsu2_rd_phys_q,lsu2_rob_id_q,lsu2_BOB_id_q,
            ~iq_lsu_full_i,1'b0
    );

logic ready_o0, ready_o1;

always_comb begin
    // o0 group
    if (alu_pipe_valid_o0)
        ready_o0 = alu1_dispatch_iq_ready_o;
    else if (bru_pipe_valid_o0)
        ready_o0 = bru1_dispatch_iq_ready_o;
    else if (mdu_pipe_valid_o0)
        ready_o0 = mdu1_dispatch_iq_ready_o;
    else if (lsu_pipe_valid_o0)
        ready_o0 = lsu1_dispatch_iq_ready_o;
    else
        ready_o0 = 1'b1;

    // o1 group
    if (alu_pipe_valid_o1)
        ready_o1 = alu2_dispatch_iq_ready_o;
    else if (bru_pipe_valid_o1)
        ready_o1 = bru2_dispatch_iq_ready_o;
    else if (mdu_pipe_valid_o1)
        ready_o1 = mdu2_dispatch_iq_ready_o;
    else if (lsu_pipe_valid_o1)
        ready_o1 = lsu2_dispatch_iq_ready_o;
    else
        ready_o1 = 1'b1;
end

assign dispatch_iq_ready_o = ready_o0 & ready_o1;


// ==================== EX阶段实例化（已插入）====================
top_ex u_top_ex (
    .clk                        (clk),
    .reset                      (reset),
    
    //ROB的输出
    .recover_pr0_en             (recover_rd_en_1),
    .recover_pr0                (recover_rd_new_1),
    .recover_pr1                (recover_rd_new_2),
    .recover_pr1_en             (recover_rd_en_2),
    .retire_en_rob              (retire_rd_en_1),
    .retire_pr0                 (retire_rd_old_1),
    .retire_pr1                 (retire_rd_old_2),
    .retire_pr1_en              (retire_rd_en_2),
    
    //派遣对于ALU
    .alu_rob_id1                (alu1_rob_id_q),
    .alu_rob_id2                (alu2_rob_id_q),
    .alu_rs1_number1            (alu1_rs1_phys_q),
    .alu_rs2_number1            (alu1_rs2_phys_q),
    .alu_rs1_number2            (alu2_rs1_phys_q),
    .alu_rs2_number2            (alu2_rs2_phys_q),
    .alu_imm1                   (alu1_immediate_q),
    .alu_imm2                   (alu2_immediate_q),
    .alu_rd_number1             (alu1_rd_phys_q),
    .alu_rd_number2             (alu2_rd_phys_q),
    .alu_control1               (alu1_ctrl_signal_q),
    .alu_control2               (alu2_ctrl_signal_q),
    .alu_reg_write1             (alu1_rd_valid_q),
    .alu_reg_write2             (alu2_rd_valid_q),
    .alu_instr_type1            (alu1_inst_type_q),
    .alu_instr_type2            (alu2_inst_type_q),
    .alu_instr_valid1           (alu1_inst_valid_q),
    .alu_instr_valid2           (alu2_inst_valid_q),
    
    //派遣对于BRU
    .bru_rob_id1                (bru1_rob_id_q),
    .bru_rob_id2                (bru2_rob_id_q),
    .bru_bob_id1                (bru1_BOB_id_q),
    .bru_bob_id2                (bru2_BOB_id_q),
    .bru_rs1_number1            (bru1_rs1_phys_q),
    .bru_rs2_number1            (bru1_rs2_phys_q),
    .bru_rs1_number2            (bru2_rs1_phys_q),
    .bru_rs2_number2            (bru2_rs2_phys_q),
    .bru_rd_number1             (bru1_rd_phys_q),
    .bru_rd_number2             (bru2_rd_phys_q),
    .bru_control1               (bru1_ctrl_signal_q[2:0]),
    .bru_control2               (bru2_ctrl_signal_q[2:0]),
    .bru_reg_write1             (bru1_rd_valid_q),
    .bru_reg_write2             (bru2_rd_valid_q),
    .bru_instr_type1            (bru1_inst_type_q),
    .bru_instr_type2            (bru2_inst_type_q),
    .bru_instr_valid1           (bru1_inst_valid_q),
    .bru_instr_valid2           (bru2_inst_valid_q),
    .bru_GHR_value_prf          (p_ghr_old),
    .bru_CPHT_GPHT_index_prf    (p_g_idx),
    .bru_BPHT_index_prf         (p_b_idx),
    .bru_GPHT_pre_taken_prf     (p_g_dir),
    .bru_BPHT_pre_taken_prf     (p_b_dir),
    .bru_is_return_prf          (p_read_ras),
    .bru_pre_adr_prf            (p_pre_addr),
    .bru_dec_adr_prf            (p_de_adr),
    .bru_pc_prf                 (p_pc),
    .bru_btb_hit_prf            (p_btb_hit),
    .bru_RAS_count_prf          (p_ras_count),
    .bru_pre_taken_prf          (p_pre_dir),
    .complete_fentch            (1'b1),
    .complete_rob               (recover_complete),
    
    //派遣对于LSU
    .lsu_rob_id1                (lsu1_rob_id_q),
    .lsu_rob_id2                (lsu2_rob_id_q),
    .lsu_imm1                   (lsu1_immediate_q),
    .lsu_imm2                   (lsu2_immediate_q),
    .lsu_rs1_number1            (lsu1_rs1_phys_q),
    .lsu_rs2_number1            (lsu1_rs2_phys_q),
    .lsu_rs1_number2            (lsu2_rs1_phys_q),
    .lsu_rs2_number2            (lsu2_rs2_phys_q),
    .lsu_rd_number1             (lsu1_rd_phys_q),
    .lsu_rd_number2             (lsu2_rd_phys_q),
    .lsu_control1               (lsu1_ctrl_signal_q),
    .lsu_control2               (lsu2_ctrl_signal_q),
    .lsu_reg_write1             (lsu1_rd_valid_q),
    .lsu_reg_write2             (lsu2_rd_valid_q),
    .lsu_instr_type1            (lsu1_inst_type_q),
    .lsu_instr_type2            (lsu2_inst_type_q),
    .lsu_instr_valid1           (lsu1_inst_valid_q),
    .lsu_instr_valid2           (lsu2_inst_valid_q),
    .cache_data                 (D_data_out),
    .cache_valid                (DC_dataout_val),
    .retire_en_sw               (retire_memwrite_cnt),
    .cache_hit                  (D_hit),
    
    //派遣对于MDU
    .mdu_rob_id1                (mdu1_rob_id_q),
    .mdu_rob_id2                (mdu2_rob_id_q),
    .mdu_rs1_number1            (mdu1_rs1_phys_q),
    .mdu_rs2_number1            (mdu1_rs2_phys_q),
    .mdu_rs1_number2            (mdu2_rs1_phys_q),
    .mdu_rs2_number2            (mdu2_rs2_phys_q),
    .mdu_rd_number1             (mdu1_rd_phys_q),
    .mdu_rd_number2             (mdu2_rd_phys_q),
    .mdu_control1               (mdu1_ctrl_signal_q),
    .mdu_control2               (mdu2_ctrl_signal_q),
    .mdu_reg_write1             (mdu1_rd_valid_q),
    .mdu_reg_write2             (mdu2_rd_valid_q),
    .mdu_instr_valid1           (mdu1_inst_valid_q),
    .mdu_instr_valid2           (mdu2_inst_valid_q),
     
    // ==================== 输出到外部的信号（已全部实例化）====================
    //ALU的输出
    .alu_rob_id_wb              (complete_id_alu),
    .alu_complete_wb            (complete_en_alu),
    .alu_iq1_full               (iq_alu_full_i),
    
    //BRU的输出
    .bru_rob_id_wb              (complete_id_bru),
    .bru_complete_wb            (BRU_complete),
    .bru_iq2_full               (iq_bru_full_i),
    .bru_bob_id_prf             (bob_id_p),   //输出给BOB在PRF阶段
    .BOB_id_wb                  (bob_bru_id), //wb阶段输出给BOB前端
    .BOB_pc_wb                  (bru_pc),     //这个是索引的PC
    .adr_wb                     (btb_write_target), //这个是要跳转的地址
    .bru_recovery_wb            (BRU_recovery),
    .btb_wirte_wb               (btb_recover),
    .RAS_count_wb               (bru_ras_count),
    .taken_wb                   (dir_right_pre),
    .GPHT_CPHT_index_wb         (GPHT_CPHT_index_wb),
    .BPHT_index_wb              (bob_b_index_commit),
    .GHR_wb                     (bob_ghr_old),
    .is_return_wb               (ret_commit),
    .is_b_type_wb               (bru_if_b),
    .G_or_B_wb                  (G_or_B_wb),
    
    //LSU的输出
    .lsu_iq4_full               (iq_lsu_full_i),
    .D_VA                       (address_end),
    .retire_data_sb             (St_data),
    .store_type_end             (St_type),
    .ld_en_end                  (Ld_en),
    .st_en_end                  (St_en),
    .cache_ready                (DC_dataout_rdy),
    .load_rob_id                (complete_id_lsu_load),
    .complete_load_end          (complete_en_lsu_load),
    .complete_store_end         (complete_en_lsu_store),
    .lsu_sw_rob_id              (complete_id_lsu_store),
    .D_VA_ST                    (sd_VA),
                                                                 
    
    //MDU的输出
    .mdu_iq3_full               (iq_mdu_full_i),
    .mdu_div_complete           (complete_en_mdu_div),
    .mdu_div_rob_wb             (complete_id_mdu_div),
    .mdu_mul_rob_wb             (complete_id_mdu_mul),
    .mdu_mul_complete_wb        (complete_en_mdu_mul),
    .stall                      (dispatch_stall_o),
    .write_ok1                  (write_ok1),
    .write_ok2                  (write_ok2),
    .write_ok3                  (write_ok3),
    .write_ok4                  (write_ok4)
);
    
assign recoverib_complete =1'b1;
assign pause_signal = ib_full | dec_recover | BRU_recovery | bob_full;

endmodule

