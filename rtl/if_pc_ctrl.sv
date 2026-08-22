module if_pc_ctrl #(
  parameter PC_WIDTH = 64,
  parameter logic [PC_WIDTH-1:0] BOOT_PC = 64'h0000_0000
)(
  input  logic                 clk,
  input  logic                 reset,

  /* ================= IF current PC ================= */
  output logic [PC_WIDTH-1:0]  pc_q,

  /* ================= I-cache / predecode ================= */
  input  logic                 icache_resp_valid,
  input  logic [2:0]           br_pre,
  input  logic [2:0]           num,

  /* ================= Branch predictor ================= */
  input  logic                 pre_dir,
  input  logic [PC_WIDTH-1:0]  btb_pre_pc,
  input  logic [PC_WIDTH-1:0]  ras_pc,

  /* ================= Recover ================= */
  input  logic                 dec_recover,
  input  logic [PC_WIDTH-1:0]  de_pc,

  input  logic                 bru_recover,
  input  logic [PC_WIDTH-1:0]  bru_pc,

  /* ================= Stall ================= */
  input  logic                 ib_full,

  /* ================= Output ================= */
  output logic                 memory_request,
  output logic [PC_WIDTH-1:0]  next_pc
);

  /* ============================================================
   * 1. Next PC（纯组合逻辑）
   * ============================================================ */


  always_comb begin
    next_pc = pc_q;  // 默认保持

    if (icache_resp_valid) begin
      unique case (br_pre)
        3'b000: next_pc = pc_q + (num << 2);

        3'b001: next_pc = pre_dir ? btb_pre_pc
                                 : pc_q + (num << 2);

        3'b010: next_pc = btb_pre_pc; // JAL
        3'b011: next_pc = btb_pre_pc; // CALL
        3'b100: next_pc = ras_pc;     // RET

        3'b101: next_pc = pc_q + (num << 2);

        default: next_pc = pc_q;
      endcase
    end
  end

  /* ============================================================
   * 2. PC register（核心控制）
   * ============================================================ */
  always_ff @(posedge clk) begin
    if (reset) begin
      pc_q <= BOOT_PC;
    end

    // ===== 最高优先级：执行阶段恢复 =====
    else if (bru_recover) begin
      pc_q <= bru_pc;
    end

    // ===== 次优先级：译码阶段恢复 =====
    else if (dec_recover) begin
      pc_q <= de_pc;
    end

    // ===== IB 满：暂停 =====
    else if (ib_full) begin
      pc_q <= pc_q;
    end

    // ===== 正常前进 =====
    else begin
      pc_q <= next_pc;
    end
  end

  /* ============================================================
   * 3. Memory request（关键 gating）
   * ============================================================ */
  assign memory_request = ~(ib_full | bru_recover | dec_recover);

endmodule

