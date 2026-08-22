/******************************************************************************
 * Filename: PRF.sv
 * Author: FMRT22-HYC
 * Create date: 2025.12.19
 * Description: physical register file
 * Modify date: 2026.3.23
 * ***************************************************************************/
module PRF #(
    parameter int PHY_REG_NUM    = 64,      // 物理寄存器总数（32映射+32空闲）
    parameter int REG_DATA_WIDTH = 64,      // 寄存器数据位宽（64bit）
    parameter int REG_ADDR_WIDTH = 6        // 物理寄存器地址位宽（6bit对应0~63）
)(
    input  logic                                      clk,            // 时钟信号
    input  logic                                      reset,          // 复位信号
    // 流水线控制信号
    input  logic                                      stall,          // 流水线暂停（高电平有效）
    // ---------------------- IQ就绪位访问接口（仅读，4个端口） ----------------------
    input  logic [REG_ADDR_WIDTH-1:0]                 iq_ready_rd_addr0,  // IQ就绪位读地址0
    input  logic [REG_ADDR_WIDTH-1:0]                 iq_ready_rd_addr1,  // IQ就绪位读地址1
    input  logic [REG_ADDR_WIDTH-1:0]                 iq_ready_rd_addr2,  // IQ就绪位读地址2
    input  logic [REG_ADDR_WIDTH-1:0]                 iq_ready_rd_addr3,  // IQ就绪位读地址3
    output logic                                      iq_ready_rd_data0,  // IQ就绪位读数据0
    output logic                                      iq_ready_rd_data1,  // IQ就绪位读数据1
    output logic                                      iq_ready_rd_data2,  // IQ就绪位读数据2
    output logic                                      iq_ready_rd_data3,  // IQ就绪位读数据3
    // ---------------------- 各功能部件ready-bit置位接口 ----------------------
    // ALU就绪位置位（有效信号+物理寄存器号）
    input  logic                                      alu_ready_en,       // ALU就绪位置位有效
    input  logic [REG_ADDR_WIDTH-1:0]                 alu_ready_pr,       // ALU待置位的物理寄存器号
    // MDU拆分为乘法/除法独立就绪位置位
    input  logic                                      mdu_mul_ready_en,   // MDU乘法就绪位置位有效
    input  logic [REG_ADDR_WIDTH-1:0]                 mdu_mul_ready_pr,   // MDU乘法待置位的物理寄存器号
    input  logic                                      mdu_div_ready_en,   // MDU除法就绪位置位有效
    input  logic [REG_ADDR_WIDTH-1:0]                 mdu_div_ready_pr,   // MDU除法待置位的物理寄存器号
    // BRU就绪位置位（有效信号+物理寄存器号）
    input  logic                                      bru_ready_en,       // BRU就绪位置位有效
    input  logic [REG_ADDR_WIDTH-1:0]                 bru_ready_pr,       // BRU待置位的物理寄存器号
    // LSU就绪位置位（有效信号+物理寄存器号）
    input  logic                                      lsu_ready_en,       // LSU就绪位置位有效
    input  logic [REG_ADDR_WIDTH-1:0]                 lsu_ready_pr,       // LSU待置位的物理寄存器号
    // ---------------------- 执行单元数据访问接口（独立信号，LSU 3个读端口） ----------------------
    // ALU：2读1写（固定）
    input  logic [REG_ADDR_WIDTH-1:0]                 alu_rd_addr0,       // ALU读地址0
    input  logic [REG_ADDR_WIDTH-1:0]                 alu_rd_addr1,       // ALU读地址1
    output logic [REG_DATA_WIDTH-1:0]                 alu_rd_data0,       // ALU读数据0
    output logic [REG_DATA_WIDTH-1:0]                 alu_rd_data1,       // ALU读数据1
    input  logic [REG_ADDR_WIDTH-1:0]                 alu_wr_addr,        // ALU写地址
    input  logic [REG_DATA_WIDTH-1:0]                 alu_wr_data,        // ALU写数据
    input  logic                                      alu_wr_en,          // ALU写使能
    // MDU：4读2写（乘除法并行，固定）
    input  logic [REG_ADDR_WIDTH-1:0]                 mdu_rd_addr0,       // MDU读地址0
    input  logic [REG_ADDR_WIDTH-1:0]                 mdu_rd_addr1,       // MDU读地址1
    input  logic [REG_ADDR_WIDTH-1:0]                 mdu_rd_addr2,       // MDU读地址2
    input  logic [REG_ADDR_WIDTH-1:0]                 mdu_rd_addr3,       // MDU读地址3
    output logic [REG_DATA_WIDTH-1:0]                 mdu_rd_data0,       // MDU读数据0
    output logic [REG_DATA_WIDTH-1:0]                 mdu_rd_data1,       // MDU读数据1
    output logic [REG_DATA_WIDTH-1:0]                 mdu_rd_data2,       // MDU读数据2
    output logic [REG_DATA_WIDTH-1:0]                 mdu_rd_data3,       // MDU读数据3
    input  logic [REG_ADDR_WIDTH-1:0]                 mdu_wr_addr0,       // MDU写地址0（乘法）
    input  logic [REG_ADDR_WIDTH-1:0]                 mdu_wr_addr1,       // MDU写地址1（除法）
    input  logic [REG_DATA_WIDTH-1:0]                 mdu_wr_data0,       // MDU写数据0（乘法）
    input  logic [REG_DATA_WIDTH-1:0]                 mdu_wr_data1,       // MDU写数据1（除法）
    input  logic                                      mdu_wr_en0,         // MDU写使能0（乘法）
    input  logic                                      mdu_wr_en1,         // MDU写使能1（除法）
    // BRU：2读1写（固定）
    input  logic [REG_ADDR_WIDTH-1:0]                 bru_rd_addr0,       // BRU读地址0
    input  logic [REG_ADDR_WIDTH-1:0]                 bru_rd_addr1,       // BRU读地址1
    output logic [REG_DATA_WIDTH-1:0]                 bru_rd_data0,       // BRU读数据0
    output logic [REG_DATA_WIDTH-1:0]                 bru_rd_data1,       // BRU读数据1
    input  logic [REG_ADDR_WIDTH-1:0]                 bru_wr_addr,        // BRU写地址
    input  logic [REG_DATA_WIDTH-1:0]                 bru_wr_data,        // BRU写数据
    input  logic                                      bru_wr_en,          // BRU写使能
    // LSU：3读1写（修正为3个读端口）
    input  logic [REG_ADDR_WIDTH-1:0]                 lsu_rd_addr0,       // LSU读地址0
    input  logic [REG_ADDR_WIDTH-1:0]                 lsu_rd_addr1,       // LSU读地址1
    input  logic [REG_ADDR_WIDTH-1:0]                 lsu_rd_addr2,       // LSU读地址2（新增）
    output logic [REG_DATA_WIDTH-1:0]                 lsu_rd_data0,       // LSU读数据0
    output logic [REG_DATA_WIDTH-1:0]                 lsu_rd_data1,       // LSU读数据1
    output logic [REG_DATA_WIDTH-1:0]                 lsu_rd_data2,       // LSU读数据2（新增）
    input  logic [REG_ADDR_WIDTH-1:0]                 lsu_wr_addr,        // LSU写地址
    input  logic [REG_DATA_WIDTH-1:0]                 lsu_wr_data,        // LSU写数据
    input  logic                                      lsu_wr_en,          // LSU写使能
    // ---------------------- 分支恢复/指令退休接口（ready-bit置0，支持单/双路） ----------------------
    input  logic                                      recover_en,         // 分支恢复使能（高电平有效）
    input  logic [REG_ADDR_WIDTH-1:0]                 recover_pr0,        // 恢复物理寄存器0（Rd_new）
    input  logic [REG_ADDR_WIDTH-1:0]                 recover_pr1,        // 恢复物理寄存器1（Rd_new）
    input  logic                                      recover_pr1_en,     // 恢复寄存器1使能（新增：1=有效，0=仅操作pr0）
    input  logic                                      retire_en,          // 指令退休使能（高电平有效）
    input  logic [REG_ADDR_WIDTH-1:0]                 retire_pr0,         // 退休物理寄存器0（Rd_old）
    input  logic [REG_ADDR_WIDTH-1:0]                 retire_pr1,         // 退休物理寄存器1（Rd_old）
    input  logic                                      retire_pr1_en       // 退休寄存器1使能（新增：1=有效，0=仅操作pr0）
);

// -------------------------- 内部存储阵列定义 --------------------------
// 64x64bit物理寄存器数值存储：0~31映射逻辑寄存器，32~63为空闲寄存器
logic [PHY_REG_NUM-1:0][REG_DATA_WIDTH-1:0] phy_reg_data;
// 64x1bit就绪位阵列：1=数值有效可访问，0=数值无效不可访问
logic [PHY_REG_NUM-1:0]                     phy_reg_ready;

// -------------------------- 时序逻辑：数据写回+ready-bit置位/置0 --------------------------
// 使用独立的always块处理不同的操作，确保正确的优先级
// 1. 数据写回（独立处理，不受recover/retire影响，但受stall影响）
always_ff @(posedge clk) begin
    if (!reset && !stall && !recover_en) begin
        // 数据写回（受stall和recover控制）
        if (mdu_wr_en0) phy_reg_data[mdu_wr_addr0] <= mdu_wr_data0;
        if (mdu_wr_en1) phy_reg_data[mdu_wr_addr1] <= mdu_wr_data1;
        if (bru_wr_en)  phy_reg_data[bru_wr_addr]   <= bru_wr_data;
        if (lsu_wr_en)  phy_reg_data[lsu_wr_addr]   <= lsu_wr_data;
        if (alu_wr_en)  phy_reg_data[alu_wr_addr]   <= alu_wr_data;
    end
end

// 2. ready-bit管理（处理复位、恢复、退休、置位）
always_ff @(posedge clk) begin
    if (reset) begin
        // 复位初始化
        for (int i = 0; i < PHY_REG_NUM; i++) begin
            phy_reg_ready[i] <= (i < 32) ? 1'b1 : 1'b0;
        end
    end else if (recover_en) begin
        // 最高优先级：分支恢复
        phy_reg_ready[recover_pr0] <= 1'b0;
        if (recover_pr1_en) begin
            phy_reg_ready[recover_pr1] <= 1'b0;
        end
    end else if (!stall) begin
        // 流水线正常运行
        
        // 第一步：退休（优先级高于置位）
        if (retire_en) begin
            phy_reg_ready[retire_pr0] <= 1'b0;
            if (retire_pr1_en) begin
                phy_reg_ready[retire_pr1] <= 1'b0;
            end
        end
        
        // 第二步：就绪位置位（退休后执行，但同一个周期内退休优先级更高）
        // 注意：如果退休和置位操作同一个寄存器，退休会覆盖置位
        if (alu_ready_en)     phy_reg_ready[alu_ready_pr]     <= 1'b1;
        if (mdu_mul_ready_en) phy_reg_ready[mdu_mul_ready_pr] <= 1'b1;
        if (mdu_div_ready_en) phy_reg_ready[mdu_div_ready_pr] <= 1'b1;
        if (bru_ready_en)     phy_reg_ready[bru_ready_pr]     <= 1'b1;
        if (lsu_ready_en)     phy_reg_ready[lsu_ready_pr]     <= 1'b1;
    end
    // stall有效时，ready-bit保持不变
end

// ==================== 数据写优先（转发） ====================
function automatic [REG_DATA_WIDTH-1:0] data_forward(
    input [REG_ADDR_WIDTH-1:0] addr
);
    if (mdu_wr_en0 && mdu_wr_addr0 == addr) return mdu_wr_data0;
    else if (mdu_wr_en1 && mdu_wr_addr1 == addr) return mdu_wr_data1;
    else if (bru_wr_en  && bru_wr_addr  == addr) return bru_wr_data;
    else if (lsu_wr_en  && lsu_wr_addr  == addr) return lsu_wr_data;
    else if (alu_wr_en  && alu_wr_addr  == addr) return alu_wr_data;
    else return phy_reg_data[addr];
endfunction

// ==================== 就绪位写优先（转发）====================
function automatic logic ready_forward(
    input [REG_ADDR_WIDTH-1:0] addr
);
    // 同一周期被置位 → 立刻返回1
    if (alu_ready_en     && alu_ready_pr     == addr) return 1'b1;
    if (mdu_mul_ready_en && mdu_mul_ready_pr == addr) return 1'b1;
    if (mdu_div_ready_en && mdu_div_ready_pr == addr) return 1'b1;
    if (bru_ready_en     && bru_ready_pr     == addr) return 1'b1;
    if (lsu_ready_en     && lsu_ready_pr     == addr) return 1'b1;

    // 同一周期被退休/恢复 → 返回0
    if (recover_en && recover_pr0 == addr) return 1'b0;
    if (recover_en && recover_pr1_en && recover_pr1 == addr) return 1'b0;
    if (retire_en  && retire_pr0 == addr) return 1'b0;
    if (retire_en  && retire_pr1_en && retire_pr1 == addr) return 1'b0;

    // 否则返回寄存器值
    return phy_reg_ready[addr];
endfunction

// ==================== 读端口（带数据+就绪位双写优先） ====================
assign alu_rd_data0 = data_forward(alu_rd_addr0);
assign alu_rd_data1 = data_forward(alu_rd_addr1);

assign mdu_rd_data0 = data_forward(mdu_rd_addr0);
assign mdu_rd_data1 = data_forward(mdu_rd_addr1);
assign mdu_rd_data2 = data_forward(mdu_rd_addr2);
assign mdu_rd_data3 = data_forward(mdu_rd_addr3);

assign bru_rd_data0 = data_forward(bru_rd_addr0);
assign bru_rd_data1 = data_forward(bru_rd_addr1);

assign lsu_rd_data0 = data_forward(lsu_rd_addr0);
assign lsu_rd_data1 = data_forward(lsu_rd_addr1);
assign lsu_rd_data2 = data_forward(lsu_rd_addr2);

// ==================== IQ 就绪位（带写优先！）====================
assign iq_ready_rd_data0 = ready_forward(iq_ready_rd_addr0);
assign iq_ready_rd_data1 = ready_forward(iq_ready_rd_addr1);
assign iq_ready_rd_data2 = ready_forward(iq_ready_rd_addr2);
assign iq_ready_rd_data3 = ready_forward(iq_ready_rd_addr3);

endmodule