/******************************************************************************
 * Filename:SRAT.sv
 * Author:FMRT22-HYC
 * Create date:2025.12.11
 * Description:SRAM-Based RAT 
 * ***************************************************************************/
module SRAT #(
    parameter LOGIC_REG_NUM  = 32,      // 逻辑寄存器数量（x0-x31）
    parameter LOGIC_REG_WID  = 5,
    parameter PHY_REG_WID    = 6,       // 物理寄存器号宽度（64个物理寄存器：2^6）
    parameter PHY_REG_NUM    = 64       // 物理寄存器总数（64）
)
(
    input  logic   clk,
    input  logic   reset,
    
    // ============ 指令1 ============
    input  logic                         inst1_valid,        // 指令1 整体有效
    input  logic [4:0]                   inst1_rs1,          // 指令1 源寄存器1
    input  logic                         rs1_valid_1,        // 指令1 rs1 有效
    input  logic [4:0]                   inst1_rs2,          // 指令1 源寄存器2
    input  logic                         rs2_valid_1,        // 指令1 rs2 有效
    input  logic [4:0]                   inst1_rd,           // 指令1 目的寄存器
    input  logic                         rd_valid_1,         // 指令1 rd 有效
    input  logic [PHY_REG_WID-1:0]       inst1_new_phy,      // 指令1 新分配的物理寄存器
    
    // ============ 指令2 ============
    input  logic                         inst2_valid,        // 指令2 整体有效
    input  logic [4:0]                   inst2_rs1,          // 指令2 源寄存器1
    input  logic                         rs1_valid_2,        // 指令2 rs1 有效
    input  logic [4:0]                   inst2_rs2,          // 指令2 源寄存器2
    input  logic                         rs2_valid_2,        // 指令2 rs2 有效
    input  logic [4:0]                   inst2_rd,           // 指令2 目的寄存器
    input  logic                         rd_valid_2,         // 指令2 rd 有效
    input  logic [PHY_REG_WID-1:0]       inst2_new_phy,      // 指令2 新分配的物理寄存器
    
    // ============ 重命名控制 ============
    input  logic                         rename_en_1,        // 指令1 重命名使能
    input  logic                         rename_en_2,        // 指令2 重命名使能
    
    // ============ 恢复端口 ============

    input  logic 			 bru_recovery,
    input  logic                         recover_en_1,       // 指令1 恢复使能
    input  logic [4:0]                   recover_addr_1,     // 指令1 恢复的逻辑地址
    input  logic [PHY_REG_WID-1:0]       recover_phy_1,      // 指令1 恢复的物理寄存器
    
    input  logic                         recover_en_2,       // 指令2 恢复使能
    input  logic [4:0]                   recover_addr_2,     // 指令2 恢复的逻辑地址
    input  logic [PHY_REG_WID-1:0]       recover_phy_2,      // 指令2 恢复的物理寄存器
    
    // ============ Free List状态 ============
    input  logic                         free_list_null,     // Free List为空信号（当free_list为空时暂停分配）
    input  logic                         rob_full,

    // ============ 输出端口 ============
    // 指令1
    output logic [PHY_REG_WID-1:0]       inst1_rs1_phy,      // rs1物理寄存器
    output logic [PHY_REG_WID-1:0]       inst1_rs2_phy,      // rs2物理寄存器
    output logic [PHY_REG_WID-1:0]       inst1_old_phy,      // rd旧物理寄存器（用于释放）
    
    // 指令2
    output logic [PHY_REG_WID-1:0]       inst2_rs1_phy,      // rs1物理寄存器
    output logic [PHY_REG_WID-1:0]       inst2_rs2_phy,      // rs2物理寄存器
    output logic [PHY_REG_WID-1:0]       inst2_old_phy       // rd旧物理寄存器（用于释放）
);

    // ========================================================
    // 内部信号
    // ========================================================
    
    logic [PHY_REG_WID-1:0] srat_array [LOGIC_REG_NUM-1:0];
    
    // 从SRAT数组读取的值（总是读取数组的当前值）
    logic [PHY_REG_WID-1:0] srat_read_1_rs1, srat_read_1_rs2, srat_read_1_rd;
    logic [PHY_REG_WID-1:0] srat_read_2_rs1, srat_read_2_rs2, srat_read_2_rd;
    
    // 内部相关性检测信号
    logic raw_detect_rs1;  // 指令2的rs1与指令1的rd RAW相关
    logic raw_detect_rs2;  // 指令2的rs2与指令1的rd RAW相关
    logic waw_detect;      // 指令2的rd与指令1的rd WAW相关
    
    // 写控制信号
    logic inst1_should_write;
    logic inst2_should_write;
    
    
    // ========================================================
    // 相关性检查
    // ========================================================
    always_comb begin
      
        
        // 从SRAT数组读取当前值（不管是否有恢复操作）
        srat_read_1_rs1 = srat_array[inst1_rs1];
        srat_read_1_rs2 = srat_array[inst1_rs2];
        srat_read_1_rd  = srat_array[inst1_rd];
        
        srat_read_2_rs1 = srat_array[inst2_rs1];
        srat_read_2_rs2 = srat_array[inst2_rs2];
        srat_read_2_rd  = srat_array[inst2_rd];
        
        // 内部相关性检测
        raw_detect_rs1 = 1'b0;
        raw_detect_rs2 = 1'b0;
        waw_detect = 1'b0;
        
        // 只有两条指令都有效且没有恢复操作时才检查相关性
        if (inst1_valid && inst2_valid && !bru_recovery && !free_list_null && !rob_full) begin
            // 检查RAW相关：inst2.rs1/rs2 == inst1.rd
            if (rd_valid_1 && (inst1_rd != 5'b0)) begin
                // 检查rs1
                if (rs1_valid_2 && (inst1_rd == inst2_rs1)) begin
                    raw_detect_rs1 = 1'b1;
                end
                
                // 检查rs2
                if (rs2_valid_2 && (inst1_rd == inst2_rs2)) begin
                    raw_detect_rs2 = 1'b1;
                end
            end
            
            // 检查WAW相关：inst2.rd == inst1.rd
            if (rd_valid_1 && rd_valid_2 && (inst1_rd == inst2_rd) && (inst1_rd != 5'b0)) begin
                waw_detect = 1'b1;
            end
        end
    end
    
    // ========================================================
    // 输出逻辑（修复版本）
    // ========================================================
    always_comb begin
        // 初始化输出
        inst1_rs1_phy = '0;
        inst1_rs2_phy = '0;
        inst1_old_phy = '0;
        inst2_rs1_phy = '0;
        inst2_rs2_phy = '0;
        inst2_old_phy = '0;
        
        // ---- 指令1输出 ----
        if (inst1_valid) begin
            // rs1：从SRAT数组读取
            if (rs1_valid_1) begin
                inst1_rs1_phy = (inst1_rs1 == 5'b0) ? '0 : srat_read_1_rs1;
            end
            
            // rs2：从SRAT数组读取
            if (rs2_valid_1) begin
                inst1_rs2_phy = (inst1_rs2 == 5'b0) ? '0 : srat_read_1_rs2;
            end
            
            // rd旧值
            if (rd_valid_1) begin
                inst1_old_phy = (inst1_rd == 5'b0) ? '0 : srat_read_1_rd;
            end
        end
        
        // ---- 指令2输出 ----
        if (inst2_valid) begin
            // rs1：如果有RAW相关，使用指令1的新值；否则从SRAT数组读取
            if (rs1_valid_2) begin
                if (inst2_rs1 == 5'b0) begin
                    inst2_rs1_phy = '0;
                end else if (raw_detect_rs1 && !bru_recovery) begin  // 恢复期间不使用转发
                    inst2_rs1_phy = inst1_new_phy;  // RAW转发
                end else begin
                    inst2_rs1_phy = srat_read_2_rs1;
                end
            end
            
            // rs2：如果有RAW相关，使用指令1的新值；否则从SRAT数组读取
            if (rs2_valid_2) begin
                if (inst2_rs2 == 5'b0) begin
                    inst2_rs2_phy = '0;
                end else if (raw_detect_rs2 && !bru_recovery) begin  // 恢复期间不使用转发
                    inst2_rs2_phy = inst1_new_phy;  // RAW转发
                end else begin
                    inst2_rs2_phy = srat_read_2_rs2;
                end
            end
            
            // rd旧值
            if (rd_valid_2) begin
                if (inst2_rd == 5'b0) begin
                    inst2_old_phy = '0;
                end else if (waw_detect && !bru_recovery) begin  // 恢复期间不使用WAW处理
                    // WAW相关：指令2的old_phy应该是指令1的新物理寄存器
                    inst2_old_phy = inst1_new_phy;
                end else begin
                    inst2_old_phy = srat_read_2_rd;
                end
            end
        end
    end
    
    // ========================================================
    // 写控制逻辑
    // ========================================================
    always_comb begin
        // 如果正在进行恢复操作或者free_list空的时候，禁用所有正常写操作
        if (bru_recovery || free_list_null  || rob_full) begin
            inst1_should_write = 1'b0;
            inst2_should_write = 1'b0;
        end else begin
            // 正常模式下的写控制
            // 指令1：有WAW相关且指令2有效时不写入SRAT（由指令2覆盖）
            inst1_should_write = inst1_valid && rd_valid_1 && rename_en_1 && 
                                !(waw_detect && inst2_valid && rd_valid_2);
            
            // 指令2：总是写入（如果是WAW相关，会覆盖指令1）
            inst2_should_write = inst2_valid && rd_valid_2 && rename_en_2;
        end
    end
    
    // ========================================================
    // SRAT数组更新逻辑
    // ========================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            // 复位逻辑：初始化所有逻辑寄存器到对应的物理寄存器
            for (int i = 0; i < LOGIC_REG_NUM; i = i + 1) begin
                srat_array[i] <= PHY_REG_WID'(i);
            end
        end else begin
            // ---- 恢复写（最高优先级） ----
            if (recover_en_1 && recover_en_2 && recover_addr_1 == recover_addr_2 && recover_addr_1 != 5'b0) begin
                srat_array[recover_addr_2] <= recover_phy_2;
            end else begin
                // 恢复端口1
                if (recover_en_1 && (recover_addr_1 != 5'b0)) begin
                    srat_array[recover_addr_1] <= recover_phy_1;
                end
                
                // 恢复端口2（检查是否与端口1冲突）
                if (recover_en_2 && (recover_addr_2 != 5'b0)) begin
                    srat_array[recover_addr_2] <= recover_phy_2;
                end 
            end
            
            // ---- 正常重命名写（只有在没有恢复操作时才执行） ----
            if (!recover_en_1 && !recover_en_2 && !free_list_null && !rob_full) begin
                // 指令2写（优先于指令1，处理WAW相关）
                if (inst2_should_write && (inst2_rd != 5'b0)) begin
                    srat_array[inst2_rd] <= inst2_new_phy;
                end
                
                // 指令1写（如果与指令2WAW相关，会被覆盖）
                if (inst1_should_write && (inst1_rd != 5'b0)) begin
                    // 只有当指令2不写同一个寄存器时才写入
                    if (!(inst2_should_write && (inst2_rd == inst1_rd))) begin
                        srat_array[inst1_rd] <= inst1_new_phy;
                    end
                end
            end
        end
    end

endmodule
