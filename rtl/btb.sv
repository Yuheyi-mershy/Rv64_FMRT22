module btb #(

  parameter PC_WIDTH = 64,

  parameter SETS     = 16,   // 16 组

  parameter WAYS     = 2     // 2 路组相联

)(

  input  logic                  clk,



  /* ================= IF 阶段：读 BTB ================= */

  input  logic                  if_br,     // 是否为分支指令

  input  logic [2:0]            br_pre,    // 预解码分支类型

  input  logic [PC_WIDTH-1:0]   br_pc,     // 当前分支指令 PC
  input  logic [2:0]            num,       // 当前周期取指数


  output logic                  BTB_hit,   // BTB 是否命中

  output logic [PC_WIDTH-1:0]   BTB_dataout, // 预测目标地址（miss 时为 0）



  /* ================= BRU 阶段：写 BTB ================= */

  input  logic                  btb_recover,       // BRU 判定后写 BTB

  input  logic [PC_WIDTH-1:0]   btb_write_pc,       // 分支指令 PC

  input  logic [PC_WIDTH-1:0]   btb_write_target    // 实际跳转目标

);



  /* ====================================================

   * 参数计算

   * ==================================================== */

  localparam INDEX_WIDTH = 4;               // pc[5:2]

  localparam TAG_WIDTH   = PC_WIDTH - 6;    // pc[63:6]



  /* ====================================================

   * BTB 存储结构

   * ==================================================== */

  logic [TAG_WIDTH-1:0]  tag_array    [SETS-1:0][WAYS-1:0];

  logic [PC_WIDTH-1:0]   target_array [SETS-1:0][WAYS-1:0];

  logic                  valid_array  [SETS-1:0][WAYS-1:0];



  // 每组一个简单 LRU（1 bit，轮转替换）

  logic lru [SETS-1:0];



  /* ====================================================

   * IF 阶段：BTB 读（组合逻辑）

   * ==================================================== */

  wire [INDEX_WIDTH-1:0] rd_index = br_pc[5:2];

  wire [TAG_WIDTH-1:0]   rd_tag   = br_pc[63:6];



  integer i;



  always @(*) begin

    BTB_hit     = 1'b0;

    BTB_dataout = br_pc + 4;  // 默认顺序流


    //读BTB
    // 只有 if_br=1 且不是 RET、AUIPC/ 不预测 才查 BTB

    if (if_br && br_pre != 3'b100 && br_pre != 3'b101) begin

        for (i = 0; i < WAYS; i = i + 1) begin

            if (!BTB_hit &&

                valid_array[rd_index][i] &&

                tag_array[rd_index][i] == rd_tag) begin

              BTB_hit     = 1'b1;

              BTB_dataout = target_array[rd_index][i];

            end
        end
    end
end


  /* ====================================================

   * BRU 阶段：BTB 写（时序逻辑）

   * ==================================================== */

  wire [INDEX_WIDTH-1:0] wr_index = btb_write_pc[5:2];

  wire [TAG_WIDTH-1:0]   wr_tag   = btb_write_pc[63:6];



  integer w;





always @(posedge clk) begin

  if (btb_recover) begin
    
    logic hit_next;

    hit_next = 1'b0;



    for (w = 0; w < WAYS; w = w + 1) begin

      if (valid_array[wr_index][w] &&

          tag_array[wr_index][w] == wr_tag) begin

        target_array[wr_index][w] <= btb_write_target;

        hit_next = 1'b1;

        if (w == 0)
        lru[wr_index] <= 1'b1;
      else
        lru[wr_index] <= 1'b0;

      end

    end



    if (!hit_next) begin

      valid_array [wr_index][lru[wr_index]] <= 1'b1;

      tag_array   [wr_index][lru[wr_index]] <= wr_tag;

      target_array[wr_index][lru[wr_index]] <= btb_write_target;

      lru[wr_index] <= ~lru[wr_index];

    end

  end

end



  /* ====================================================

   * 初始化：BTB 为空

   * ==================================================== */

  integer s, k;

  initial begin

    for (s = 0; s < SETS; s = s + 1) begin

      lru[s] = 1'b0;

      for (k = 0; k < WAYS; k = k + 1) begin

        valid_array [s][k] = 1'b0;

        tag_array   [s][k] = {TAG_WIDTH{1'b0}};

        target_array[s][k] = {PC_WIDTH{1'b0}};

      end

    end

  end



endmodule

