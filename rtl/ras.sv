

module ras #(
  parameter PC_WIDTH = 64,
  parameter DEPTH    = 16
)(
  input  logic                 clk,
  input  logic                 reset,

  /* ================= IF ================= */
  input  logic                 if_br,
  input  logic [2:0]           br_pre,       // 010: CALL, 100: RETURN
  input  logic [PC_WIDTH-1:0]  br_pc,

  /* ================= Decode ================= */
  input  logic                 dec_recover,
  input  logic [1:0]           dec_vec,
  input  logic [4:0]           d_ras_count_0,
  input  logic [4:0]           d_ras_count_1,

  /* ================= BRU ================= */
  input  logic                 bru_mispredict,
  input  logic [4:0]           bru_seq,

  /* ================= Commit ================= */
  input  logic                 ret_commit,

  /* ================= 输出 ================= */
  output logic [PC_WIDTH-1:0]  ras_pc,
  output logic                 ras_recover_complete,
  output logic [4:0]           seq_alloc
);

  /* =====================================================
   * 1. seq 分配
   * ===================================================== */
 
  always_ff @(posedge clk) begin
    if (reset)
      seq_alloc <= 5'b0;
    else if (if_br && br_pre != 3'b100)
      seq_alloc <= seq_alloc + 1;
  end

  /* =====================================================
   * 2. RAS（architectural） 单指针
   * ===================================================== */
  logic [PC_WIDTH-1:0] ras_addr [DEPTH-1:0];
  logic [4:0]          ras_seq  [DEPTH-1:0];
  logic [$clog2(DEPTH):0] ras_sp;

  wire ras_full  = (ras_sp == DEPTH);
  wire ras_empty = (ras_sp == 0);

  /* =====================================================
   * 3. RAS_recover（双指针）
   * ===================================================== */
  logic [PC_WIDTH-1:0] rasr_addr [DEPTH-1:0];
  logic [4:0]          rasr_seq  [DEPTH-1:0];

  logic [$clog2(DEPTH):0] rasr_head; // commit 消费
  logic [$clog2(DEPTH):0] rasr_tail; // push / rollback

  wire rasr_empty = (rasr_head == rasr_tail);

  /* =====================================================
   * 4. seq 比较
   * ===================================================== */
  function automatic seq_greater;
    input [4:0] a, b;
  begin
    if (a[4] == b[4])
      seq_greater = (a[3:0] > b[3:0]);
    else
      seq_greater = (a[3:0] < b[3:0]);
  end
  endfunction

  /* =====================================================
   * 5. 主逻辑
   * ===================================================== */
  integer new_tail;
  integer new_sp;


  always_ff @(posedge clk) begin
    if (reset) begin
      ras_sp  <= 0;
      rasr_head <= 0;
      rasr_tail <= 0;
      ras_pc  <= 0;
      ras_recover_complete <= 0;
    end
    else begin

      ras_recover_complete <= 0;
      
      /* ================================================= */
      /* =============== 1. BRU Recovery ================= */
      /* ================================================= */
      if (0) begin
        integer idx;
        integer write_sp;
        integer temp_tail;

        new_sp   = ras_sp;
        new_tail = rasr_tail;

        // 删 RAS
        while (new_sp > 0 &&
               seq_greater(ras_seq[new_sp-1], bru_seq)) begin
          new_sp = new_sp - 1;
        end

        // 删 RASR
        while (new_tail > rasr_head &&
               seq_greater(rasr_seq[new_tail-1], bru_seq)) begin
          new_tail = new_tail - 1;
        end

        temp_tail = new_tail;
        write_sp  = new_sp;

        // 回填
        for (idx = new_tail-1; idx >= rasr_head; idx = idx - 1) begin
          if (!seq_greater(rasr_seq[idx], bru_seq)) begin
            if (write_sp < DEPTH) begin
              ras_addr[write_sp] <= rasr_addr[idx];
              ras_seq [write_sp] <= rasr_seq[idx];
              write_sp = write_sp + 1;
              temp_tail = temp_tail - 1;
            end
          end
        end

        ras_sp    <= write_sp;
        rasr_tail <= temp_tail;

        if (temp_tail == rasr_head)
          ras_recover_complete <= 1'b1;
      end

      /* ================================================= */
      /* =============== 2. Decode Recovery ============== */
      /* ================================================= */
      else if (0) begin
        integer idx;
        integer write_sp;
        integer temp_tail;
        logic [4:0] rec_seq;

        // ✔ 选择 younger（必须这样）
        if (dec_vec[1])
          rec_seq = d_ras_count_1;
        else if (dec_vec[0])
          rec_seq = d_ras_count_0;
        else
          rec_seq = 5'b0;

        new_sp   = ras_sp;
        new_tail = rasr_tail;

        // 删 RAS
        while (new_sp > 0 &&
               seq_greater(ras_seq[new_sp-1], rec_seq)) begin
          new_sp = new_sp - 1;
        end

        // 删 RASR
        while (new_tail > rasr_head &&
               seq_greater(rasr_seq[new_tail-1], rec_seq)) begin
          new_tail = new_tail - 1;
        end

        temp_tail = new_tail;
        write_sp  = new_sp;

        // 回填
        for (idx = new_tail-1; idx >= rasr_head; idx = idx - 1) begin
          if (!seq_greater(rasr_seq[idx], rec_seq)) begin
            if (write_sp < DEPTH) begin
              ras_addr[write_sp] <= rasr_addr[idx];
              ras_seq [write_sp] <= rasr_seq[idx];
              write_sp = write_sp + 1;
              temp_tail = temp_tail - 1;
            end
          end
        end

        ras_sp    <= write_sp;
        rasr_tail <= temp_tail;

        if (temp_tail == rasr_head)
          ras_recover_complete <= 1'b1;
      end

      /* ================================================= */
      /* =============== 3. 正常路径 ===================== */
      /* ================================================= */
      else begin
      /* ================= CALL ================= */
      if (if_br && br_pre == 3'b010) begin
        if (!ras_full) begin
          ras_addr[ras_sp] <= br_pc + 4;
          ras_seq [ras_sp] <= seq_alloc;
          ras_sp <= ras_sp + 1;
        end
      end

      /* ================= RETURN 预测 ================= */
      if (if_br && br_pre == 3'b100 && ras_sp > 0 && rasr_tail < DEPTH) begin
      logic [PC_WIDTH-1:0] top_addr;
      logic [4:0]          top_seq;

        top_addr = ras_addr[ras_sp-1];
        top_seq  = ras_seq [ras_sp-1];

        ras_sp <= ras_sp - 1;

        rasr_addr[rasr_tail] <= top_addr;
        rasr_seq [rasr_tail] <= top_seq;
        rasr_tail <= rasr_tail + 1;

        ras_pc <= top_addr;
	  end
    /* ---------- commit ---------- */
      if (ret_commit && !rasr_empty) begin
      rasr_head <= rasr_head + 1;
  end   
  end
end
end

endmodule

