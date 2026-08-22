module bob #(
    parameter BOB_DEPTH = 16,
    parameter PTR_WIDTH = 4
)(
    input  logic clk,
    input  logic reset,

    /* ================= IF ================= */
    input  logic        if_br,
    input  logic [63:0] PC_br,
    input  logic        pre_dir,
    input  logic [63:0] pre_addr,
    input  logic [7:0]  GHR_old,
    input  logic [7:0]  G_index,
    input  logic [7:0]  B_index,
    input  logic        G_dir,
    input  logic        B_dir,
    input  logic        BTB_hit,
    input  logic [4:0]  ras_count,
    input  logic        read_ras,  //加上是return指令这一列

    /* ================= Decode ================= */
  
    input  logic        dec_recovery,
    input  logic [1:0]  dec_vec,//如果bit[1]为1，则第二条指令恢复，如果bit[0]为1，则第一条指令恢复

    input  logic        dec_wr_en_0,
    input  logic [63:0] DE_adr_0,

    input  logic        dec_wr_en_1,
    input  logic [63:0] DE_adr_1,

    /* ================= Read ================= */
    input  logic [4:0] bob_id_d0,
    input  logic [4:0] bob_id_d1,
    input  logic [4:0] bob_id_p,

    /* ================= BRU ================= */
    input  logic        BRU_complete,
    input  logic        BRU_recovery,
    input  logic [4:0]  bob_bru_id,

    /* ================= Output ================= */
    output logic        bob_empty,
    output logic        bob_full,
    output logic        bob_stall,
    output logic [4:0]  bob_alloc_id,

    /* ---- D ---- */
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
    output logic        d_read_ras_1,

    /* ---- P ---- */
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
    output logic        p_read_ras
);

    /* ============================================================ */
    /* 表项定义*/
    /* ============================================================ */
    typedef struct packed {
        logic        page;

        logic [63:0] pc;
        logic [63:0] pre_addr;
        logic        pre_dir;

        logic [63:0] de_adr;

        logic [7:0]  ghr_old;
        logic [7:0]  g_idx;
        logic [7:0]  b_idx;
        logic        g_dir;
        logic        b_dir;

        logic        btb_hit;
        logic [4:0]  ras_count;

        logic        read_ras;

    } bob_entry_t;

    bob_entry_t table [BOB_DEPTH-1:0];

    /* ============================================================ */
    /* FIFO 指针 */
    /* ============================================================ */
    logic [PTR_WIDTH-1:0] head_ptr, tail_ptr;
    logic head_page, tail_page;

    assign bob_empty = (head_ptr == tail_ptr) && (head_page == tail_page);
    assign bob_full  = (head_ptr == tail_ptr) && (head_page != tail_page);
    assign bob_stall = bob_full;

    assign bob_alloc_id = {tail_page, tail_ptr};

    /* ============================================================ */
    /* 写逻辑 */
    /* ============================================================ */
    integer i;

    always_ff @(posedge clk) begin
        if (reset) begin
            head_ptr  <= 0;
            tail_ptr  <= 0;
            head_page <= 0;
            tail_page <= 0;
        end
        else begin
    
            /* ===================================================== */
            /* =============== 1. BRU Recovery（最高优先级） ========= */
            /* ===================================================== */
            if (BRU_recovery) begin
                logic [PTR_WIDTH-1:0] rec_ptr;
                logic rec_page;
    
                rec_ptr  = bob_bru_id[3:0];
                rec_page = bob_bru_id[4];
    
                for (int i = 0; i < BOB_DEPTH; i++) begin
                    if (!(i == rec_ptr && table[i].page == rec_page)) begin
                        table[i] <= '0;
                    end
                end
    
                if (rec_ptr == BOB_DEPTH-1) begin
                    tail_ptr  <= 0;
                    tail_page <= ~rec_page;
                end else begin
                    tail_ptr  <= rec_ptr + 1;
                    tail_page <= rec_page;
                end
	 	
		 
            end
            
           
    
            /* ===================================================== */
            /* =============== 2. Decode Recovery =================== */
            /* ===================================================== */
            else if (dec_recovery) begin
		
                logic [PTR_WIDTH-1:0] rec_ptr;
                logic rec_page;
    
                logic [PTR_WIDTH-1:0] old_tail_ptr;
                logic old_tail_page;

                 if (dec_wr_en_0) begin
                    if (table[bob_id_d0[3:0]].page == bob_id_d0[4]) begin
                        table[bob_id_d0[3:0]].de_adr <= DE_adr_0;
                    end
                end
    
                if (dec_wr_en_1) begin
                    if (table[bob_id_d1[3:0]].page == bob_id_d1[4]) begin
                        table[bob_id_d1[3:0]].de_adr <= DE_adr_1;
                    end
                end
                // 保存旧 tail
                old_tail_ptr  = tail_ptr;
                old_tail_page = tail_page;
    
                // 选择恢复 ID（建议优先 younger，这里先按你原逻辑）
                if (dec_vec[0]) begin
                    rec_ptr  = bob_id_d0[3:0];
                    rec_page = bob_id_d0[4];
                end
                else if (dec_vec[1]) begin
                    rec_ptr  = bob_id_d1[3:0];
                    rec_page = bob_id_d1[4];
                end
                else begin
                    rec_ptr  = head_ptr;
                    rec_page = head_page;
                end
    
                // 清除 (rec_ptr, old_tail]
                for (int j = 0; j < BOB_DEPTH; j++) begin
                    logic in_range;
    
                    if (rec_page == old_tail_page) begin
                        in_range = (j > rec_ptr) && (j <= old_tail_ptr);
                    end
                    else begin
                        in_range = (j > rec_ptr) || (j <= old_tail_ptr);
                    end
    
                    if (in_range) begin
                        if (table[j].page == old_tail_page ||
                            table[j].page == rec_page) begin
                            table[j] <= '0;
                        end
	      
                    end
		if (BRU_complete && !bob_empty) begin
            
                    if (bob_bru_id == {head_page, head_ptr}) begin
                    if (head_ptr == BOB_DEPTH-1) begin
                        head_ptr  <= 0;
                        head_page <= ~head_page;
                    end else begin
                        head_ptr <= head_ptr + 1;
                    end
                end
                end
    
                // tail = rec + 1
                if (rec_ptr == BOB_DEPTH-1) begin
                    tail_ptr  <= 0;
                    tail_page <= ~rec_page;
                end else begin
                    tail_ptr  <= rec_ptr + 1;
                    tail_page <= rec_page;
                end
            end
   end
    
            /* ===================================================== */
            /* =============== 3. 正常路径 =========================== */
            /* ===================================================== */
            else begin
    
                /* ---------- IF 分配 ---------- */
                if (if_br && !bob_full) begin
                    table[tail_ptr] <= '{
                        page      : tail_page,
    
                        pc        : PC_br,
                        pre_addr  : pre_addr,
                        pre_dir   : pre_dir,
    
                        de_adr    : 64'b0,
    
                        ghr_old   : GHR_old,
                        g_idx     : G_index,
                        b_idx     : B_index,
                        g_dir     : G_dir,
                        b_dir     : B_dir,
    
                        btb_hit   : BTB_hit,
                        ras_count : ras_count,
                        read_ras  : read_ras
                    };
    
                    if (tail_ptr == BOB_DEPTH-1) begin
                        tail_ptr  <= 0;
                        tail_page <= ~tail_page;
                    end else begin
                        tail_ptr <= tail_ptr + 1;
                    end
                end
    
                /* ---------- Decode 回填（双端口） ---------- */
                if (dec_wr_en_0) begin
                    if (table[bob_id_d0[3:0]].page == bob_id_d0[4]) begin
                        table[bob_id_d0[3:0]].de_adr <= DE_adr_0;
                    end
                end
    
                if (dec_wr_en_1) begin
                    if (table[bob_id_d1[3:0]].page == bob_id_d1[4]) begin
                        table[bob_id_d1[3:0]].de_adr <= DE_adr_1;
                    end
                end
    
                /* ---------- Commit ---------- */
                if (BRU_complete && !bob_empty) begin
            
                   
                    if (head_ptr == BOB_DEPTH-1) begin
                        head_ptr  <= 0;
                        head_page <= ~head_page;
                    end else begin
                        head_ptr <= head_ptr + 1;
                    end
            end
            end
        end
    end
    

    /* ============================================================ */
    /* 读函数 */
    /* ============================================================ */
    function automatic bob_entry_t read_entry(input logic [4:0] id);
        bob_entry_t tmp;
        tmp = table[id[3:0]];

        if (!(tmp.page == id[4])) begin
            tmp = '0;
        end

        return tmp;
    endfunction

    /* ---------- D ---------- */
    bob_entry_t e0;
    bob_entry_t e1;
    always_comb begin
        // 读取第一条指令
        
        e0 = read_entry(bob_id_d0);
    
        d_pc_0        = e0.pc;
        d_pre_addr_0  = e0.pre_addr;
        d_pre_dir_0   = e0.pre_dir;
        d_de_adr_0    = e0.de_adr;
        d_ghr_old_0   = e0.ghr_old;
        d_g_idx_0     = e0.g_idx;
        d_b_idx_0     = e0.b_idx;
        d_g_dir_0     = e0.g_dir;
        d_b_dir_0     = e0.b_dir;
        d_btb_hit_0   = e0.btb_hit;
        d_ras_count_0 = e0.ras_count;
        d_read_ras_0  = e0.read_ras;
    
        // 读取第二条指令
     
        e1 = read_entry(bob_id_d1);
    
        d_pc_1        = e1.pc;
        d_pre_addr_1  = e1.pre_addr;
        d_pre_dir_1   = e1.pre_dir;
        d_de_adr_1    = e1.de_adr;
        d_ghr_old_1   = e1.ghr_old;
        d_g_idx_1     = e1.g_idx;
        d_b_idx_1     = e1.b_idx;
        d_g_dir_1     = e1.g_dir;
        d_b_dir_1     = e1.b_dir;
        d_btb_hit_1   = e1.btb_hit;
        d_ras_count_1 = e1.ras_count;
        d_read_ras_1  = e1.read_ras;
    end
    

    /* ---------- P ---------- */
    always_comb begin
        bob_entry_t e;
        e = read_entry(bob_id_p);

        p_pc        = e.pc;
        p_pre_addr  = e.pre_addr;
        p_pre_dir   = e.pre_dir;
        p_de_adr    = e.de_adr;
        p_ghr_old   = e.ghr_old;
        p_g_idx     = e.g_idx;
        p_b_idx     = e.b_idx;
        p_g_dir     = e.g_dir;
        p_b_dir     = e.b_dir;
        p_btb_hit   = e.btb_hit;
        p_ras_count = e.ras_count;
        p_read_ras  = e.read_ras;
    end

endmodule

