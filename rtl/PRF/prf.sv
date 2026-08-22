module PRF #(
    parameter int PHY_REG_NUM    = 64,
    parameter int REG_DATA_WIDTH = 64,
    parameter int REG_ADDR_WIDTH = 6
)(
    input  logic clk,
    input  logic reset,
    input  logic stall,

    // IQ 就绪位读端口
    input  logic [REG_ADDR_WIDTH-1:0] iq_ready_rd_addr0,
    input  logic [REG_ADDR_WIDTH-1:0] iq_ready_rd_addr1,
    input  logic [REG_ADDR_WIDTH-1:0] iq_ready_rd_addr2,
    input  logic [REG_ADDR_WIDTH-1:0] iq_ready_rd_addr3,
    output logic                      iq_ready_rd_data0,
    output logic                      iq_ready_rd_data1,
    output logic                      iq_ready_rd_data2,
    output logic                      iq_ready_rd_data3,

    // 就绪位置位
    input  logic                      alu_ready_en,
    input  logic [REG_ADDR_WIDTH-1:0] alu_ready_pr,
    input  logic                      mdu_mul_ready_en,
    input  logic [REG_ADDR_WIDTH-1:0] mdu_mul_ready_pr,
    input  logic                      mdu_div_ready_en,
    input  logic [REG_ADDR_WIDTH-1:0] mdu_div_ready_pr,
    input  logic                      bru_ready_en,
    input  logic [REG_ADDR_WIDTH-1:0] bru_ready_pr,
    input  logic                      lsu_ready_en,
    input  logic [REG_ADDR_WIDTH-1:0] lsu_ready_pr,

    // ALU
    input  logic [REG_ADDR_WIDTH-1:0] alu_rd_addr0,
    input  logic [REG_ADDR_WIDTH-1:0] alu_rd_addr1,
    output logic [REG_DATA_WIDTH-1:0] alu_rd_data0,
    output logic [REG_DATA_WIDTH-1:0] alu_rd_data1,
    input  logic [REG_ADDR_WIDTH-1:0] alu_wr_addr,
    input  logic [REG_DATA_WIDTH-1:0] alu_wr_data,
    input  logic                      alu_wr_en,

    // MDU
    input  logic [REG_ADDR_WIDTH-1:0] mdu_rd_addr0,
    input  logic [REG_ADDR_WIDTH-1:0] mdu_rd_addr1,
    input  logic [REG_ADDR_WIDTH-1:0] mdu_rd_addr2,
    input  logic [REG_ADDR_WIDTH-1:0] mdu_rd_addr3,
    output logic [REG_DATA_WIDTH-1:0] mdu_rd_data0,
    output logic [REG_DATA_WIDTH-1:0] mdu_rd_data1,
    output logic [REG_DATA_WIDTH-1:0] mdu_rd_data2,
    output logic [REG_DATA_WIDTH-1:0] mdu_rd_data3,
    input  logic [REG_ADDR_WIDTH-1:0] mdu_wr_addr0,
    input  logic [REG_DATA_WIDTH-1:0] mdu_wr_data0,
    input  logic                      mdu_wr_en0,
    input  logic [REG_ADDR_WIDTH-1:0] mdu_wr_addr1,
    input  logic [REG_DATA_WIDTH-1:0] mdu_wr_data1,
    input  logic                      mdu_wr_en1,

    // BRU
    input  logic [REG_ADDR_WIDTH-1:0] bru_rd_addr0,
    input  logic [REG_ADDR_WIDTH-1:0] bru_rd_addr1,
    output logic [REG_DATA_WIDTH-1:0] bru_rd_data0,
    output logic [REG_DATA_WIDTH-1:0] bru_rd_data1,
    input  logic [REG_ADDR_WIDTH-1:0] bru_wr_addr,
    input  logic [REG_DATA_WIDTH-1:0] bru_wr_data,
    input  logic                      bru_wr_en,

    // LSU
    input  logic [REG_ADDR_WIDTH-1:0] lsu_rd_addr0,
    input  logic [REG_ADDR_WIDTH-1:0] lsu_rd_addr1,
    input  logic [REG_ADDR_WIDTH-1:0] lsu_rd_addr2,
    output logic [REG_DATA_WIDTH-1:0] lsu_rd_data0,
    output logic [REG_DATA_WIDTH-1:0] lsu_rd_data1,
    output logic [REG_DATA_WIDTH-1:0] lsu_rd_data2,
    input  logic [REG_ADDR_WIDTH-1:0] lsu_wr_addr,
    input  logic [REG_DATA_WIDTH-1:0] lsu_wr_data,
    input  logic                      lsu_wr_en,

    // 恢复 & 退休
    input  logic                      recover_pr0_en,
    input  logic [REG_ADDR_WIDTH-1:0] recover_pr0,
    input  logic [REG_ADDR_WIDTH-1:0] recover_pr1,
    input  logic                      recover_pr1_en,
    input  logic                      retire_pr0_en,
    input  logic [REG_ADDR_WIDTH-1:0] retire_pr0,
    input  logic [REG_ADDR_WIDTH-1:0] retire_pr1,
    input  logic                      retire_pr1_en
);

// -------------------------- 内部存储 --------------------------
logic [PHY_REG_NUM-1:0][REG_DATA_WIDTH-1:0] phy_reg_data;
logic [PHY_REG_NUM-1:0]                     phy_reg_ready;

// -------------------------- 数据写回 --------------------------
always_ff @(posedge clk) begin
    if (reset) begin
        for (int i = 0; i < PHY_REG_NUM; i++) begin
            phy_reg_data[i] <= 0;
        end
    end
    else if (!stall) begin
        if (mdu_wr_en0 && mdu_wr_addr0 != 6'd0)  phy_reg_data[mdu_wr_addr0] <= mdu_wr_data0;
        if (mdu_wr_en1 && mdu_wr_addr1!= 6'd0)  phy_reg_data[mdu_wr_addr1] <= mdu_wr_data1;
        if (bru_wr_en && bru_wr_addr != 6'd0)   phy_reg_data[bru_wr_addr]  <= bru_wr_data;
        if (lsu_wr_en && lsu_wr_addr != 6'd0)   phy_reg_data[lsu_wr_addr]  <= lsu_wr_data;
        if (alu_wr_en && alu_wr_addr != 6'd0)   phy_reg_data[alu_wr_addr]  <= alu_wr_data;
    end
end

// -------------------------- 就绪位控制 --------------------------
always_ff @(posedge clk) begin
    if (reset) begin
        for (int i = 0; i < PHY_REG_NUM; i++) begin
            phy_reg_ready[i] <= (i < 1) ? 1'b1 : 1'b0;
        end
    end
    else if (!stall) begin
        if (retire_pr0_en) begin
            phy_reg_ready[retire_pr0] <= 1'b0;
        end    
	    if (retire_pr1_en) begin
	        phy_reg_ready[retire_pr1] <= 1'b0;
        end

        if (alu_ready_en)     phy_reg_ready[alu_ready_pr]     <= 1'b1;
        if (mdu_mul_ready_en)  phy_reg_ready[mdu_mul_ready_pr] <= 1'b1;
        if (mdu_div_ready_en)  phy_reg_ready[mdu_div_ready_pr] <= 1'b1;
        if (bru_ready_en)      phy_reg_ready[bru_ready_pr]     <= 1'b1;
        if (lsu_ready_en)      phy_reg_ready[lsu_ready_pr]     <= 1'b1;
    end
    else begin
      if (recover_pr0_en) begin
        phy_reg_ready[recover_pr0] <= 1'b0;
      end
        if (recover_pr1_en) begin
	phy_reg_ready[recover_pr1] <= 1'b0;
      end
    end
end

// ==========================================================
// 【最简单写法】所有读数据直接写 assign，没有任何函数！
// ==========================================================

// ALU 读数据
assign alu_rd_data0 = (mdu_wr_en0 && (mdu_wr_addr0 == alu_rd_addr0)) ? mdu_wr_data0 :
                      (mdu_wr_en1 && (mdu_wr_addr1 == alu_rd_addr0)) ? mdu_wr_data1 :
                      (bru_wr_en  && (bru_wr_addr  == alu_rd_addr0)) ? bru_wr_data  :
                      (lsu_wr_en  && (lsu_wr_addr  == alu_rd_addr0)) ? lsu_wr_data  :
                      (alu_wr_en  && (alu_wr_addr  == alu_rd_addr0)) ? alu_wr_data  :
                      phy_reg_data[alu_rd_addr0];

assign alu_rd_data1 = (mdu_wr_en0 && (mdu_wr_addr0 == alu_rd_addr1)) ? mdu_wr_data0 :
                      (mdu_wr_en1 && (mdu_wr_addr1 == alu_rd_addr1)) ? mdu_wr_data1 :
                      (bru_wr_en  && (bru_wr_addr  == alu_rd_addr1)) ? bru_wr_data  :
                      (lsu_wr_en  && (lsu_wr_addr  == alu_rd_addr1)) ? lsu_wr_data  :
                      (alu_wr_en  && (alu_wr_addr  == alu_rd_addr1)) ? alu_wr_data  :
                      phy_reg_data[alu_rd_addr1];

// MDU 读数据
assign mdu_rd_data0 = (mdu_wr_en0 && (mdu_wr_addr0 == mdu_rd_addr0)) ? mdu_wr_data0 :
                      (mdu_wr_en1 && (mdu_wr_addr1 == mdu_rd_addr0)) ? mdu_wr_data1 :
                      (bru_wr_en  && (bru_wr_addr  == mdu_rd_addr0)) ? bru_wr_data  :
                      (lsu_wr_en  && (lsu_wr_addr  == mdu_rd_addr0)) ? lsu_wr_data  :
                      (alu_wr_en  && (alu_wr_addr  == mdu_rd_addr0)) ? alu_wr_data  :
                      phy_reg_data[mdu_rd_addr0];

assign mdu_rd_data1 = (mdu_wr_en0 && (mdu_wr_addr0 == mdu_rd_addr1)) ? mdu_wr_data0 :
                      (mdu_wr_en1 && (mdu_wr_addr1 == mdu_rd_addr1)) ? mdu_wr_data1 :
                      (bru_wr_en  && (bru_wr_addr  == mdu_rd_addr1)) ? bru_wr_data  :
                      (lsu_wr_en  && (lsu_wr_addr  == mdu_rd_addr1)) ? lsu_wr_data  :
                      (alu_wr_en  && (alu_wr_addr  == mdu_rd_addr1)) ? alu_wr_data  :
                      phy_reg_data[mdu_rd_addr1];

assign mdu_rd_data2 = (mdu_wr_en0 && (mdu_wr_addr0 == mdu_rd_addr2)) ? mdu_wr_data0 :
                      (mdu_wr_en1 && (mdu_wr_addr1 == mdu_rd_addr2)) ? mdu_wr_data1 :
                      (bru_wr_en  && (bru_wr_addr  == mdu_rd_addr2)) ? bru_wr_data  :
                      (lsu_wr_en  && (lsu_wr_addr  == mdu_rd_addr2)) ? lsu_wr_data  :
                      (alu_wr_en  && (alu_wr_addr  == mdu_rd_addr2)) ? alu_wr_data  :
                      phy_reg_data[mdu_rd_addr2];

assign mdu_rd_data3 = (mdu_wr_en0 && (mdu_wr_addr0 == mdu_rd_addr3)) ? mdu_wr_data0 :
                      (mdu_wr_en1 && (mdu_wr_addr1 == mdu_rd_addr3)) ? mdu_wr_data1 :
                      (bru_wr_en  && (bru_wr_addr  == mdu_rd_addr3)) ? bru_wr_data  :
                      (lsu_wr_en  && (lsu_wr_addr  == mdu_rd_addr3)) ? lsu_wr_data  :
                      (alu_wr_en  && (alu_wr_addr  == mdu_rd_addr3)) ? alu_wr_data  :
                      phy_reg_data[mdu_rd_addr3];

// BRU 读数据
assign bru_rd_data0 = (mdu_wr_en0 && (mdu_wr_addr0 == bru_rd_addr0)) ? mdu_wr_data0 :
                      (mdu_wr_en1 && (mdu_wr_addr1 == bru_rd_addr0)) ? mdu_wr_data1 :
                      (bru_wr_en  && (bru_wr_addr  == bru_rd_addr0)) ? bru_wr_data  :
                      (lsu_wr_en  && (lsu_wr_addr  == bru_rd_addr0)) ? lsu_wr_data  :
                      (alu_wr_en  && (alu_wr_addr  == bru_rd_addr0)) ? alu_wr_data  :
                      phy_reg_data[bru_rd_addr0];

assign bru_rd_data1 = (mdu_wr_en0 && (mdu_wr_addr0 == bru_rd_addr1)) ? mdu_wr_data0 :
                      (mdu_wr_en1 && (mdu_wr_addr1 == bru_rd_addr1)) ? mdu_wr_data1 :
                      (bru_wr_en  && (bru_wr_addr  == bru_rd_addr1)) ? bru_wr_data  :
                      (lsu_wr_en  && (lsu_wr_addr  == bru_rd_addr1)) ? lsu_wr_data  :
                      (alu_wr_en  && (alu_wr_addr  == bru_rd_addr1)) ? alu_wr_data  :
                      phy_reg_data[bru_rd_addr1];

// LSU 读数据
assign lsu_rd_data0 = (mdu_wr_en0 && (mdu_wr_addr0 == lsu_rd_addr0)) ? mdu_wr_data0 :
                      (mdu_wr_en1 && (mdu_wr_addr1 == lsu_rd_addr0)) ? mdu_wr_data1 :
                      (bru_wr_en  && (bru_wr_addr  == lsu_rd_addr0)) ? bru_wr_data  :
                      (lsu_wr_en  && (lsu_wr_addr  == lsu_rd_addr0)) ? lsu_wr_data  :
                      (alu_wr_en  && (alu_wr_addr  == lsu_rd_addr0)) ? alu_wr_data  :
                      phy_reg_data[lsu_rd_addr0];

assign lsu_rd_data1 = (mdu_wr_en0 && (mdu_wr_addr0 == lsu_rd_addr1)) ? mdu_wr_data0 :
                      (mdu_wr_en1 && (mdu_wr_addr1 == lsu_rd_addr1)) ? mdu_wr_data1 :
                      (bru_wr_en  && (bru_wr_addr  == lsu_rd_addr1)) ? bru_wr_data  :
                      (lsu_wr_en  && (lsu_wr_addr  == lsu_rd_addr1)) ? lsu_wr_data  :
                      (alu_wr_en  && (alu_wr_addr  == lsu_rd_addr1)) ? alu_wr_data  :
                      phy_reg_data[lsu_rd_addr1];

assign lsu_rd_data2 = (mdu_wr_en0 && (mdu_wr_addr0 == lsu_rd_addr2)) ? mdu_wr_data0 :
                      (mdu_wr_en1 && (mdu_wr_addr1 == lsu_rd_addr2)) ? mdu_wr_data1 :
                      (bru_wr_en  && (bru_wr_addr  == lsu_rd_addr2)) ? bru_wr_data  :
                      (lsu_wr_en  && (lsu_wr_addr  == lsu_rd_addr2)) ? lsu_wr_data  :
                      (alu_wr_en  && (alu_wr_addr  == lsu_rd_addr2)) ? alu_wr_data  :
                      phy_reg_data[lsu_rd_addr2];

// ==========================================================
// IQ 就绪位读（最简单写法）
// ==========================================================
assign iq_ready_rd_data0 =
    (recover_pr0_en && (recover_pr0 == iq_ready_rd_addr0)) ? 1'b0 :
    (recover_pr1_en && (recover_pr1 == iq_ready_rd_addr0)) ? 1'b0 :
    (retire_pr0_en && (retire_pr0 == iq_ready_rd_addr0)) ? 1'b0 :
    (retire_pr1_en && (retire_pr1 == iq_ready_rd_addr0)) ? 1'b0 :
    (alu_ready_en && (alu_ready_pr == iq_ready_rd_addr0)) ? 1'b1 :
    (mdu_mul_ready_en && (mdu_mul_ready_pr == iq_ready_rd_addr0)) ? 1'b1 :
    (mdu_div_ready_en && (mdu_div_ready_pr == iq_ready_rd_addr0)) ? 1'b1 :
    (bru_ready_en && (bru_ready_pr == iq_ready_rd_addr0)) ? 1'b1 :
    (lsu_ready_en && (lsu_ready_pr == iq_ready_rd_addr0)) ? 1'b1 :
    phy_reg_ready[iq_ready_rd_addr0];

assign iq_ready_rd_data1 =
    (recover_pr0_en && (recover_pr0 == iq_ready_rd_addr1)) ? 1'b0 :
    (recover_pr1_en && (recover_pr1 == iq_ready_rd_addr1)) ? 1'b0 :
    (retire_pr0_en && (retire_pr0 == iq_ready_rd_addr1)) ? 1'b0 :
    (retire_pr1_en && (retire_pr1 == iq_ready_rd_addr1)) ? 1'b0 :
    (alu_ready_en && (alu_ready_pr == iq_ready_rd_addr1)) ? 1'b1 :
    (mdu_mul_ready_en && (mdu_mul_ready_pr == iq_ready_rd_addr1)) ? 1'b1 :
    (mdu_div_ready_en && (mdu_div_ready_pr == iq_ready_rd_addr1)) ? 1'b1 :
    (bru_ready_en && (bru_ready_pr == iq_ready_rd_addr1)) ? 1'b1 :
    (lsu_ready_en && (lsu_ready_pr == iq_ready_rd_addr1)) ? 1'b1 :
    phy_reg_ready[iq_ready_rd_addr1];

assign iq_ready_rd_data2 =
    (recover_pr0_en && (recover_pr0 == iq_ready_rd_addr2)) ? 1'b0 :
    (recover_pr1_en && (recover_pr1 == iq_ready_rd_addr2)) ? 1'b0 :
    (retire_pr0_en && (retire_pr0 == iq_ready_rd_addr2)) ? 1'b0 :
    (retire_pr1_en && (retire_pr1 == iq_ready_rd_addr2)) ? 1'b0 :
    (alu_ready_en && (alu_ready_pr == iq_ready_rd_addr2)) ? 1'b1 :
    (mdu_mul_ready_en && (mdu_mul_ready_pr == iq_ready_rd_addr2)) ? 1'b1 :
    (mdu_div_ready_en && (mdu_div_ready_pr == iq_ready_rd_addr2)) ? 1'b1 :
    (bru_ready_en && (bru_ready_pr == iq_ready_rd_addr2)) ? 1'b1 :
    (lsu_ready_en && (lsu_ready_pr == iq_ready_rd_addr2)) ? 1'b1 :
    phy_reg_ready[iq_ready_rd_addr2];

assign iq_ready_rd_data3 =
    (recover_pr0_en && (recover_pr0 == iq_ready_rd_addr3)) ? 1'b0 :
    (recover_pr1_en && (recover_pr1 == iq_ready_rd_addr3)) ? 1'b0 :
    (retire_pr0_en && (retire_pr0 == iq_ready_rd_addr3)) ? 1'b0 :
    (retire_pr1_en && (retire_pr1 == iq_ready_rd_addr3)) ? 1'b0 :
    (alu_ready_en && (alu_ready_pr == iq_ready_rd_addr3)) ? 1'b1 :
    (mdu_mul_ready_en && (mdu_mul_ready_pr == iq_ready_rd_addr3)) ? 1'b1 :
    (mdu_div_ready_en && (mdu_div_ready_pr == iq_ready_rd_addr3)) ? 1'b1 :
    (bru_ready_en && (bru_ready_pr == iq_ready_rd_addr3)) ? 1'b1 :
    (lsu_ready_en && (lsu_ready_pr == iq_ready_rd_addr3)) ? 1'b1 :
    phy_reg_ready[iq_ready_rd_addr3];

endmodule
