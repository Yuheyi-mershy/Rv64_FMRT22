module ifu_top(
    input  logic clk,
    input  logic reset,


    input  logic ic_valid,
    input  logic [127:0] ic_line,
    input  logic [11:0] br_type_out,
    output logic [63:0] pc_q,
    output logic mem_req,
    output logic ib_ready,

    // IF/ID Interface
    input  wire         if_ready,
    output reg  [1:0]   ib_valid,
    output reg  [31:0]  if_instr0,
    output reg  [31:0]  if_instr1,
    output reg  [4:0]   if_bob_id0,//输出到IF/ID的D端
    output reg  [4:0]   if_bob_id1,
    input  logic [4:0]  bob_id_d0,//从IF/ID Q端输入到bob
    input  logic [4:0]  bob_id_d1,

    // Decode Interface
    input  logic        dec_wr_en_0,
    input  logic [63:0] DE_adr_0,

    input  logic        dec_wr_en_1,
    input  logic [63:0] DE_adr_1,

    input  logic        dec_recover,
    input  logic [1:0]  dec_vec,
 // input logic [63:0]  de_pc,
    
    output logic [63:0] d_pc_0,
    output logic [63:0] d_pc_1,
    output logic [63:0] d_pre_addr_0,
    output logic [63:0] d_pre_addr_1,
    output logic        d_pre_dir_0,
    output logic        d_pre_dir_1,
    output logic [63:0] d_de_adr_0,
    output logic [63:0] d_de_adr_1,
    output logic [7:0]  d_ghr_old_0,
    output logic [7:0]  d_ghr_old_1,
    output logic [7:0]  d_g_idx_0,
    output logic [7:0]  d_g_idx_1,
    output logic [7:0]  d_b_idx_0,
    output logic [7:0]  d_b_idx_1,
    output logic        d_g_dir_0,
    output logic        d_g_dir_1,
    output logic        d_b_dir_0,
    output logic        d_b_dir_1,
    output logic        d_btb_hit_0,
    output logic        d_btb_hit_1,
    output logic [4:0]  d_ras_count_0,
    output logic [4:0]  d_ras_count_1,
    output logic        d_read_ras_0,
    output logic        d_read_ras_1,//是RETURN指令

    // Prf Interface
    input  logic [4:0]  bob_id_p,
    output logic [63:0] p_pc,
    output logic [63:0] p_pre_addr,
    output logic        p_pre_dir,
    output logic [63:0] p_de_adr,
    output logic [7:0]  p_ghr_old,
    output logic [7:0]  p_g_idx,
    output logic [7:0]  p_b_idx,
    output logic        p_g_dir,
    output logic        p_b_dir,
    output logic        p_btb_hit,
    output logic [4:0]  p_ras_count,
    output logic        p_read_ras,

    // BRU/Commit
    input  logic        BRU_complete,
    input  logic        BRU_recovery,
    input  logic [4:0]  bob_bru_id,
    input  logic        btb_recover,
    //input  logic [63:0] btb_write_pc,
    input  logic [63:0] btb_write_target, 
    input  logic [63:0] bru_pc,//和btb_write_pc是同一个信号
    input  logic        dir_right_pre,
    input  logic [7:0]  bob_g_index_commit,
    input  logic [7:0]  bob_b_index_commit,
    input  logic [7:0]  bob_c_index_commit,
    input  logic [7:0]  bob_ghr_old,
    input  logic bob_g_dir_in,
    input  logic bob_b_dir_in,
    input  logic [4:0] bru_ras_count,
    input  logic ret_commit ,//read_ras
    input  logic bru_if_b,//是B格式类型的指令
    output logic ib_full,
    output logic bob_full,
    output logic ras_recover_complete,
    input  wire  recoverib_complete
);


//1
    logic [2:0]  br_pre;
    logic [2:0]  num;
    logic [63:0] btb_pre_pc;
    logic [63:0] ras_pc;
    logic [63:0] next_pc;
    logic [63:0] de_pc;
    
    always_comb begin
        if (dec_vec[0])
            de_pc = DE_adr_0;
        else
            de_pc = DE_adr_1;
    end
//2
    logic [63:0] br_pc;
    logic [1:0]  br_logic;
    logic        pc_read_btb;
    logic        if_br;
    logic        read_ras;
//3
    logic        br_dir;
    logic [7:0]  bob_g_index_pre;
    logic [7:0]  bob_b_index_pre;
    logic [7:0]  bob_c_index_pre;
    logic        bob_g_dir;
    logic        bob_b_dir;
    logic [7:0]  bob_old_ghr;
    logic [7:0] d_ghr_old;
    assign d_ghr_old = dec_vec[0] ? d_ghr_old_0 : d_ghr_old_1;
//4
    logic        BTB_hit;
    logic [4:0]  seq_alloc;//新加的
//5
//6
    //logic [63:0] pre_addr; //预测地址就是next_pc
    logic bob_empty;
    logic bob_stall;
    logic [4:0] bob_alloc_id;

//7
    logic [5:0] used_cnt_dbg;
    logic [5:0] free_cnt_dbg;
   
    logic ib_empty;

// ------------------- 模块实例化 -------------------
    if_pc_ctrl #(
        .PC_WIDTH(64),
        .BOOT_PC(64'h0000_0000)
    ) if_pc_ctrl_inst (
        .clk(clk),
        .reset(reset),
        .pc_q(pc_q),
        .icache_resp_valid(ic_valid),
        .br_pre(br_pre),
        .num(num),
        .pre_dir(br_dir),
        .btb_pre_pc(btb_pre_pc),
        .ras_pc(ras_pc),
        .dec_recover(dec_recover),
        .de_pc(de_pc),
        .bru_recover(BRU_recovery),
        .bru_pc(btb_write_target),
        .ib_full(ib_full),
        .memory_request(mem_req),
        .next_pc(next_pc)
    );

    pre_decode pre_decode_inst (
        .ic_dataout_val(ic_valid),
        .br_type_out(br_type_out),
        .pc(pc_q),
        .num(num),
        .br_pc(br_pc),
        .br_logic(br_logic),
        .pc_read_btb(pc_read_btb),
        .br_type(br_pre),
        .if_br(if_br),
        .read_ras(read_ras)
    );

    tournament_predictor u_tournament_predictor (
        .clk(clk),
        .rst_n(!reset),
    
        .if_br(if_br),
        .PC(pc_q),
        .br_logic(br_logic),
        .br_type(br_pre),
        .br_dir(br_dir),

        .dec_recover(dec_recover),
        .dec_ghr_old(d_ghr_old),

        .br_complete(BRU_complete),
        .bru_recover(BRU_recovery),
        .dir_right_pre(dir_right_pre),
    
        .bob_g_index_pre(bob_g_index_pre),
        .bob_b_index_pre(bob_b_index_pre),
        .bob_c_index_pre(bob_c_index_pre),
        .bob_g_dir(bob_g_dir),
        .bob_b_dir(bob_b_dir),
        .bob_old_ghr(bob_old_ghr),
    
        .bob_g_index_commit(bob_g_index_commit),
        .bob_b_index_commit(bob_b_index_commit),
        .bob_c_index_commit(bob_c_index_commit),
        .bob_ghr_old(bob_ghr_old),
        .bob_g_dir_in(bob_g_dir_in),
        .bob_b_dir_in(bob_b_dir_in),
        .bob_br_pc(bru_pc),
        .bru_if_b(bru_if_b)
    );
    
    btb u_btb (
        .clk(clk),
        .if_br(if_br),
        .br_pre(br_pre),
        .br_pc(br_pc),
        .num(num),
        .BTB_hit(BTB_hit),
        .BTB_dataout(btb_pre_pc),

        .btb_recover(btb_recover),
        .btb_write_pc(bru_pc),
        .btb_write_target(btb_write_target)
    );

    ras u_ras (
        .clk(clk),
        .reset(reset),

        .if_br(if_br),
        .br_pre(br_pre),
        .br_pc(br_pc),
        .dec_recover(dec_recover),
        .dec_vec(dec_vec),
        .d_ras_count_0(d_ras_count_0),
        .d_ras_count_1(d_ras_count_1),
        .bru_mispredict(BRU_recovery),
        .bru_seq(bru_ras_count),
        .ret_commit(ret_commit),
        .ras_pc(ras_pc),
        .ras_recover_complete(ras_recover_complete),
        .seq_alloc(seq_alloc)
    );

    // ------------------- 模块实例化 -------------------
    bob u_bob (
        .clk(clk),
        .reset(reset),

        .if_br(if_br),
        .PC_br(br_pc),
        .pre_dir(br_dir),
        .pre_addr(next_pc),
        .GHR_old(bob_old_ghr),
        .G_index(bob_g_index_pre),
        .B_index(bob_b_index_pre),
        .G_dir(bob_g_dir),
        .B_dir(bob_b_dir),
        .BTB_hit(BTB_hit),
        .ras_count(seq_alloc),
        .read_ras(read_ras),

        
        .dec_recovery(dec_recover),
        .dec_vec(dec_vec),
        .dec_wr_en_0(dec_wr_en_0),
        .DE_adr_0(DE_adr_0),
        .dec_wr_en_1(dec_wr_en_1),
        .DE_adr_1(DE_adr_1),

        
        .bob_id_d0(bob_id_d0),
        .bob_id_d1(bob_id_d1),
        .bob_id_p(bob_id_p),
        
        
        .BRU_complete(BRU_complete),
        .BRU_recovery(BRU_recovery),
        .bob_bru_id(bob_bru_id),

        
        .bob_empty(bob_empty),
        .bob_full(bob_full),
        .bob_stall(bob_stall),
        .bob_alloc_id(bob_alloc_id),

        
        .d_pc_0        (d_pc_0),
        .d_pc_1        (d_pc_1),

        .d_pre_addr_0  (d_pre_addr_0),
        .d_pre_addr_1  (d_pre_addr_1),

        .d_pre_dir_0   (d_pre_dir_0),
        .d_pre_dir_1   (d_pre_dir_1),

        .d_de_adr_0    (d_de_adr_0),
        .d_de_adr_1    (d_de_adr_1),

        .d_ghr_old_0   (d_ghr_old_0),
        .d_ghr_old_1   (d_ghr_old_1),

        .d_g_idx_0     (d_g_idx_0),
        .d_g_idx_1     (d_g_idx_1),

        .d_b_idx_0     (d_b_idx_0),
        .d_b_idx_1     (d_b_idx_1),

        .d_g_dir_0     (d_g_dir_0),
        .d_g_dir_1     (d_g_dir_1),

        .d_b_dir_0     (d_b_dir_0),
        .d_b_dir_1     (d_b_dir_1),

        .d_btb_hit_0   (d_btb_hit_0),
        .d_btb_hit_1   (d_btb_hit_1),

        .d_ras_count_0 (d_ras_count_0),
        .d_ras_count_1 (d_ras_count_1),

        .d_read_ras_0  (d_read_ras_0),
        .d_read_ras_1  (d_read_ras_1),


        
        .p_pc(p_pc),
        .p_pre_addr(p_pre_addr),
        .p_pre_dir(p_pre_dir),
        .p_de_adr(p_de_adr),
        .p_ghr_old(p_ghr_old),
        .p_g_idx(p_g_idx),
        .p_b_idx(p_b_idx),
        .p_g_dir(p_g_dir),
        .p_b_dir(p_b_dir),
        .p_btb_hit(p_btb_hit),
        .p_ras_count(p_ras_count),
        .p_read_ras(p_read_ras)
    );

    instr_buffer u_instr_buffer (
        .clk(clk),
        .rst_n(!reset),
        .pc(pc_q),
    
        
        .ic_valid(ic_valid),
        .ic_line(ic_line),
        .ic_bob_id_0(bob_alloc_id),
        .ic_bob_id_1(bob_alloc_id),
        .ic_bob_id_2(bob_alloc_id),
        .ic_bob_id_3(bob_alloc_id),
        .ic_num(num),
        .ib_ready(ib_ready),
    
    
        .ib_valid(ib_valid),
        .if_ready(if_ready),
        .if_instr0(if_instr0),
        .if_instr1(if_instr1),
        .if_bob_id0(if_bob_id0),
        .if_bob_id1(if_bob_id1),
    
        
        .bru_recover(BRU_recovery),
        .dec_recover(dec_recover),
        .recoverib_complete(recoverib_complete),
    
        
        .used_cnt_dbg(used_cnt_dbg),
        .free_cnt_dbg(free_cnt_dbg),
        .ib_full(ib_full),
        .ib_empty(ib_empty)
    );
    
endmodule
