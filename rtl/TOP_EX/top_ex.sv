module top_ex(
    input logic clk,
    input logic reset,
    
     // ==================== PRF相关输入（来自ROB）====================
    // 分支恢复接口
    input logic                                      recover_pr0_en,
    input logic [5:0]                                recover_pr0,
    input logic [5:0]                                recover_pr1,
    input logic                                      recover_pr1_en,
    // 指令退休接口
    input logic                                      retire_en_rob,
    input logic [5:0]                                retire_pr0,
    input logic [5:0]                                retire_pr1,
    input logic                                      retire_pr1_en,

    // ==================== 来自前端/译码器的输入（外界信号）====================
    //ALU相关的输入（来自前端/译码器）
    input logic [6:0] alu_rob_id1,
    input logic [6:0] alu_rob_id2,
    input logic [5:0] alu_rs1_number1,
    input logic [5:0] alu_rs2_number1,
    input logic [5:0] alu_rs1_number2,
    input logic [5:0] alu_rs2_number2,
    input logic [63:0] alu_imm1,
    input logic [63:0] alu_imm2,
    input logic [5:0] alu_rd_number1,
    input logic [5:0] alu_rd_number2,
    input logic [3:0] alu_control1,
    input logic [3:0] alu_control2,
    input logic alu_reg_write1,
    input logic alu_reg_write2,
    input logic [1:0] alu_instr_type1,
    input logic [1:0] alu_instr_type2,
    input logic alu_instr_valid1,
    input logic alu_instr_valid2,
    
    // BRU相关输入（来自前端/译码器）
    input logic [6:0] bru_rob_id1,
    input logic [6:0] bru_rob_id2,
    input logic [4:0] bru_bob_id1,
    input logic [4:0] bru_bob_id2,
    input logic [5:0] bru_rs1_number1,
    input logic [5:0] bru_rs2_number1,
    input logic [5:0] bru_rs1_number2,
    input logic [5:0] bru_rs2_number2,
    input logic [5:0] bru_rd_number1,
    input logic [5:0] bru_rd_number2,
    input logic [2:0] bru_control1,
    input logic [2:0] bru_control2,
    input logic bru_reg_write1,
    input logic bru_reg_write2,
    input logic [1:0] bru_instr_type1,
    input logic [1:0] bru_instr_type2,
    input logic bru_instr_valid1,
    input logic bru_instr_valid2,
    input logic [7:0] bru_GHR_value_prf,
    input logic [7:0] bru_CPHT_GPHT_index_prf,
    input logic [7:0] bru_BPHT_index_prf,
    input logic bru_GPHT_pre_taken_prf,
    input logic bru_BPHT_pre_taken_prf,
    input logic bru_is_return_prf,
    input logic [63:0] bru_pre_adr_prf,
    input logic [63:0] bru_dec_adr_prf,
    input logic [63:0] bru_pc_prf,
    input logic bru_btb_hit_prf,
    input logic [4:0] bru_RAS_count_prf,
    input logic bru_pre_taken_prf,
    input logic complete_fentch,
    input logic complete_rob,
    
    // LSU相关输入（来自前端/译码器）
    input logic [6:0] lsu_rob_id1,
    input logic [6:0] lsu_rob_id2,
    input logic [63:0] lsu_imm1,
    input logic [63:0] lsu_imm2,
    input logic [5:0] lsu_rs1_number1,
    input logic [5:0] lsu_rs2_number1,
    input logic [5:0] lsu_rs1_number2,
    input logic [5:0] lsu_rs2_number2,
    input logic [5:0] lsu_rd_number1,
    input logic [5:0] lsu_rd_number2,
    input logic [3:0] lsu_control1,
    input logic [3:0] lsu_control2,
    input logic lsu_reg_write1,
    input logic lsu_reg_write2,
    input logic [1:0] lsu_instr_type1,
    input logic [1:0] lsu_instr_type2,
    input logic lsu_instr_valid1,
    input logic lsu_instr_valid2,
    input logic [63:0] cache_data,           // Cache读出的数据
    input logic cache_valid,                   // Cache命中信号
    input logic [1:0] retire_en_sw,             // ROB传过来的退休store数量
    input logic cache_hit,

    // MDU相关输入（来自前端/译码器）
    input logic [6:0] mdu_rob_id1,
    input logic [6:0] mdu_rob_id2,
    input logic [5:0] mdu_rs1_number1,
    input logic [5:0] mdu_rs2_number1,
    input logic [5:0] mdu_rs1_number2,
    input logic [5:0] mdu_rs2_number2,
    input logic [5:0] mdu_rd_number1,
    input logic [5:0] mdu_rd_number2,
    input logic [3:0] mdu_control1,
    input logic [3:0] mdu_control2,
    input logic mdu_reg_write1,
    input logic mdu_reg_write2,
    input logic mdu_instr_valid1,
    input logic mdu_instr_valid2,
    
    // ==================== 输出到外部的信号 ====================
    // ALU输出
    output logic [6:0] alu_rob_id_wb,     
    output logic alu_complete_wb,          
    output logic alu_iq1_full,             
    
    // BRU输出（给ROB和BOB）
    output logic [6:0] bru_rob_id_wb,
    output logic bru_complete_wb,
    output logic bru_iq2_full,
    output logic [4:0] bru_bob_id_prf,
    output logic [4:0] BOB_id_wb,
    output logic [63:0] BOB_pc_wb,
    output logic [63:0] adr_wb,
    output logic bru_recovery_wb,
    output logic btb_wirte_wb,
    output logic [4:0] RAS_count_wb,
    output logic taken_wb,
    output logic [7:0] GPHT_CPHT_index_wb,
    output logic [7:0] BPHT_index_wb,
    output logic [7:0] GHR_wb,
    output logic is_return_wb,
    output logic is_b_type_wb,
    output logic [1:0] G_or_B_wb,
    
    // LSU状态输出
    output logic lsu_iq4_full,                // LSU IQ4满信号
    output logic [63:0] retire_data_sb,      // Store退休数据
    output logic [1:0] store_type_end,       // Store类型
    output logic ld_en_end,                  // Load使能
    output logic st_en_end,                  // Store使能
    output logic [6:0] load_rob_id,          // Load指令的ROB编号
    output logic complete_load_end,          // Load指令完成信号
    output logic complete_store_end,         // Store指令完成信号
    output logic [6:0] lsu_sw_rob_id,        // Store指令的ROB编号
    output logic cache_ready,
    output logic [63:0]D_VA,
    output logic [63:0]D_VA_ST,

    // MDU输出
    output logic mdu_iq3_full,
    output logic        mdu_div_complete,
    output logic [6:0]  mdu_div_rob_wb,
    output logic [6:0]  mdu_mul_rob_wb,
    output logic        mdu_mul_complete_wb,
    input  logic        stall,
    output logic        write_ok1,
    output logic        write_ok2,
    output logic        write_ok3,
    output logic        write_ok4
);

    // ==================== 内部信号声明 ====================
    
    // 源寄存器有效位（内部信号）
    logic alu_rs1_valid1;
    logic alu_rs1_valid2;
    logic alu_rs2_valid1;
    logic alu_rs2_valid2;
    logic bru_rs1_valid1;
    logic bru_rs1_valid2;
    logic bru_rs2_valid1;
    logic bru_rs2_valid2;
    logic lsu_rs1_valid1;
    logic lsu_rs1_valid2;
    logic lsu_rs2_valid1;
    logic lsu_rs2_valid2;
    logic mdu_rs1_valid1;
    logic mdu_rs1_valid2;
    logic mdu_rs2_valid1;
    logic mdu_rs2_valid2;
    
    // 来自其他单元的总线用于唤醒（内部）
    logic [6:0] bus_bru;
    logic [6:0] bus_lsu;          // LSU唤醒总线（内部）
    logic [6:0] bus_mul;
    logic [6:0] bus_div;
    logic [6:0] bus_alu;
    
    // 来自其他执行单元写回阶段的结果值（用于转发）
    logic [63:0] bru_value_wb;
    logic [63:0] mul_value_wb;
    logic [63:0] div_value_wb;
    logic [63:0] lsu_value_wb;
    logic [63:0] alu_value_wb;
    
    // 来自其他执行单元写回阶段的结果（用于转发）
    logic [5:0] bru_rd_wb;
    logic [5:0] mul_rd_wb;
    logic [5:0] div_rd_wb;
    logic [5:0] lsu_rd_wb;
    logic [5:0] alu_rd_wb;

    // 来自物理寄存器堆的值
    logic [63:0] alu_prf_rs1_value;
    logic [63:0] alu_prf_rs2_value;
    logic [63:0] bru_prf_rs1_value;
    logic [63:0] bru_prf_rs2_value;
    logic [63:0] lsu_prf_rs1_value_lw;
    logic [63:0] lsu_prf_rs1_value_sw;
    logic [63:0] lsu_prf_rs2_value_sw;
    logic [63:0] mdu_div_rs1_value;
    logic [63:0] mdu_div_rs2_value;
    logic [63:0] mdu_mul_rs1_value;
    logic [63:0] mdu_mul_rs2_value;

    // 输出到物理寄存器堆的寄存器号
    logic [5:0] alu_rs1_number_prf;
    logic [5:0] alu_rs2_number_prf;
    logic [5:0] bru_rs1_number_prf;
    logic [5:0] bru_rs2_number_prf;
    logic [5:0] lsu_rs1_number_prf;
    logic [5:0] lsu_rs1_number_prf_sw;
    logic [5:0] lsu_rs2_number_prf_sw;
    logic [5:0] mdu_div_rs1_prf;
    logic [5:0] mdu_div_rs2_prf;
    logic [5:0] mdu_mul_rs1_prf;
    logic [5:0] mdu_mul_rs2_prf;
   
    // 输出到PRF的写回信号
    logic alu_reg_write_wb;
    logic bru_reg_write_wb;
    logic lsu_reg_write_wb;
    logic mul_reg_write_wb;         
    logic div_reg_write_wb;         

    // PRF内部信号
    logic [5:0] iq_ready_rd_addr0;
    logic [5:0] iq_ready_rd_addr1;
    logic [5:0] iq_ready_rd_addr2;
    logic [5:0] iq_ready_rd_addr3;
    logic iq_ready_rd_data0;
    logic iq_ready_rd_data1;
    logic iq_ready_rd_data2;
    logic iq_ready_rd_data3;
    

    // ==================== PRF的ready  bit的读的选择逻辑 ====================
    always_comb begin
        // 第一组：选择第一条有效指令
        case ({alu_instr_valid1, bru_instr_valid1, lsu_instr_valid1, mdu_instr_valid1})
            4'b1000 : begin  // ALU有效
                iq_ready_rd_addr0 = alu_rs1_number1;
                iq_ready_rd_addr1 = alu_rs2_number1;
            end
            4'b0100 : begin  // BRU有效
                iq_ready_rd_addr0 = bru_rs1_number1;
                iq_ready_rd_addr1 = bru_rs2_number1;
            end
            4'b0010 : begin  // LSU有效
                iq_ready_rd_addr0 = lsu_rs1_number1;
                iq_ready_rd_addr1 = lsu_rs2_number1;
            end
            4'b0001 : begin  // MDU有效
                iq_ready_rd_addr0 = mdu_rs1_number1;
                iq_ready_rd_addr1 = mdu_rs2_number1;
            end
            default : begin
                iq_ready_rd_addr0 = 6'b0;
                iq_ready_rd_addr1 = 6'b0;
            end
        endcase
        
        // 第二组：选择第二条有效指令
        case ({alu_instr_valid2, bru_instr_valid2, lsu_instr_valid2, mdu_instr_valid2})
            4'b1000 : begin  // ALU有效
                iq_ready_rd_addr2 = alu_rs1_number2;
                iq_ready_rd_addr3 = alu_rs2_number2;
            end
            4'b0100 : begin  // BRU有效
                iq_ready_rd_addr2 = bru_rs1_number2;
                iq_ready_rd_addr3 = bru_rs2_number2;
            end
            4'b0010 : begin  // LSU有效
                iq_ready_rd_addr2 = lsu_rs1_number2;
                iq_ready_rd_addr3 = lsu_rs2_number2;
            end
            4'b0001 : begin  // MDU有效
                iq_ready_rd_addr2 =  mdu_rs1_number2;
                iq_ready_rd_addr3 =  mdu_rs2_number2;
            end
            default : begin
                iq_ready_rd_addr2 = 6'b0;
                iq_ready_rd_addr3 = 6'b0;
            end
        endcase    
    end
     // ALU有效位赋值
    assign alu_rs1_valid1 = iq_ready_rd_data0;
    assign alu_rs2_valid1 = iq_ready_rd_data1;
    assign alu_rs1_valid2 = iq_ready_rd_data2;
    assign alu_rs2_valid2 = iq_ready_rd_data3;

    // BRU有效位赋值
    assign bru_rs1_valid1 = iq_ready_rd_data0;
    assign bru_rs2_valid1 = iq_ready_rd_data1;
    assign bru_rs1_valid2 = iq_ready_rd_data2;
    assign bru_rs2_valid2 = iq_ready_rd_data3;

    // LSU有效位赋值
    assign lsu_rs1_valid1 = iq_ready_rd_data0;
    assign lsu_rs2_valid1 = iq_ready_rd_data1;
    assign lsu_rs1_valid2 = iq_ready_rd_data2;
    assign lsu_rs2_valid2 = iq_ready_rd_data3;

    // MDU有效位赋值
    assign mdu_rs1_valid1 = iq_ready_rd_data0;
    assign mdu_rs2_valid1 = iq_ready_rd_data1;
    assign mdu_rs1_valid2 = iq_ready_rd_data2;
    assign mdu_rs2_valid2 = iq_ready_rd_data3;
    // ==================== ALU 模块实例化 ====================
    top_alu u_alu_top (
        // 时钟和复位
        .clk                    (clk),
        .reset                  (reset),
        
        // 来自前端/译码器的输入（外界信号）
        .alu_rob_id1            (alu_rob_id1),
        .alu_rob_id2            (alu_rob_id2),
        .alu_rs1_number1        (alu_rs1_number1),
        .alu_rs2_number1        (alu_rs2_number1),
        .alu_rs1_number2        (alu_rs1_number2),
        .alu_rs2_number2        (alu_rs2_number2),
        .alu_imm1               (alu_imm1),
        .alu_imm2               (alu_imm2),
        .alu_rd_number1         (alu_rd_number1),
        .alu_rd_number2         (alu_rd_number2),
        .alu_control1           (alu_control1),
        .alu_control2           (alu_control2),
        .alu_reg_write1         (alu_reg_write1),
        .alu_reg_write2         (alu_reg_write2),
        .alu_instr_type1        (alu_instr_type1),
        .alu_instr_type2        (alu_instr_type2),
        .alu_instr_valid1       (alu_instr_valid1),
        .alu_instr_valid2       (alu_instr_valid2),
        
        // 源寄存器有效位（内部信号）
        .alu_rs1_valid1         (alu_rs1_valid1),
        .alu_rs1_valid2         (alu_rs1_valid2),
        .alu_rs2_valid1         (alu_rs2_valid1),
        .alu_rs2_valid2         (alu_rs2_valid2),
        
        // 来自其他单元的总线用于唤醒（内部信号）
        .bus_bru                (bus_bru),
        .bus_lsu                (bus_lsu),
        .bus_mul                (bus_mul),
        .bus_div                (bus_div),
        
        // 来自分支恢复单元（内部信号）
        .bru_recovery           (bru_recovery_wb),
        .bru_rob_id             (bru_rob_id_wb),
        
        // 来自物理寄存器堆的值（内部信号）
        .alu_prf_rs1_value      (alu_prf_rs1_value),
        .alu_prf_rs2_value      (alu_prf_rs2_value),
        
        // 输出到物理寄存器堆的寄存器号（内部信号）
        .alu_rs1_number_prf     (alu_rs1_number_prf),
        .alu_rs2_number_prf     (alu_rs2_number_prf),
        
        // 来自其他执行单元写回阶段的结果（用于转发）（内部信号）
        .bru_rd_wb              (bru_rd_wb),
        .mul_rd_wb              (mul_rd_wb),
        .div_rd_wb              (div_rd_wb),
        .lsu_rd_wb              (lsu_rd_wb),
        
        // 来自其他执行单元写回阶段的结果值（用于转发）（内部信号）
        .bru_value_wb           (bru_value_wb),
        .mul_value_wb           (mul_value_wb),
        .div_value_wb           (div_value_wb),
        .lsu_value_wb           (lsu_value_wb),
        
        // 输出到写回单元
        .alu_rob_id_wb          (alu_rob_id_wb),
        .alu_complete_wb        (alu_complete_wb),
        .alu_rd_wb              (alu_rd_wb),
        .alu_value_wb           (alu_value_wb),
        .alu_reg_write_wb       (alu_reg_write_wb),
        
        // 状态输出
        .alu_iq1_full           (alu_iq1_full),
        .bus_alu                (bus_alu),
	.stall                  (stall),
	.write_ok1            	(write_ok1),
	.write_ok2            	(write_ok2)
    );
 
    
    // ==================== BRU 模块实例化 ====================
    top_bru u_top_bru (
        .clk                        (clk),
        .reset                      (reset),
        
        // 来自前端/译码器的输入
        .bru_rob_id1                (bru_rob_id1),
        .bru_rob_id2                (bru_rob_id2),
        .bru_bob_id1                (bru_bob_id1),
        .bru_bob_id2                (bru_bob_id2),
        .bru_rs1_number1            (bru_rs1_number1),
        .bru_rs2_number1            (bru_rs2_number1),
        .bru_rs1_number2            (bru_rs1_number2),
        .bru_rs2_number2            (bru_rs2_number2),
        .bru_rd_number1             (bru_rd_number1),
        .bru_rd_number2             (bru_rd_number2),
        .bru_control1               (bru_control1),
        .bru_control2               (bru_control2),
        .bru_reg_write1             (bru_reg_write1),
        .bru_reg_write2             (bru_reg_write2),
        .bru_instr_type1            (bru_instr_type1),
        .bru_instr_type2            (bru_instr_type2),
        .bru_instr_valid1           (bru_instr_valid1),
        .bru_instr_valid2           (bru_instr_valid2),
        .bru_rs1_valid1             (bru_rs1_valid1),
        .bru_rs1_valid2             (bru_rs1_valid2),
        .bru_rs2_valid1             (bru_rs2_valid1),
        .bru_rs2_valid2             (bru_rs2_valid2),
        
        // 来自其他单元的总线用于唤醒
        .bus_alu                    (bus_alu),
        .bus_mul                    (bus_mul),
        .bus_div                    (bus_div),
        .bus_lsu                    (bus_lsu),
        
        // BOB相关输入信号
        .bru_GHR_value_prf          (bru_GHR_value_prf),
        .bru_CPHT_GPHT_index_prf    (bru_CPHT_GPHT_index_prf),
        .bru_BPHT_index_prf         (bru_BPHT_index_prf),
        .bru_GPHT_pre_taken_prf     (bru_GPHT_pre_taken_prf),
        .bru_BPHT_pre_taken_prf     (bru_BPHT_pre_taken_prf),
        .bru_is_return_prf          (bru_is_return_prf),
        .bru_pre_adr_prf            (bru_pre_adr_prf),
        .bru_dec_adr_prf            (bru_dec_adr_prf),
        .bru_pc_prf                 (bru_pc_prf),
        .bru_btb_hit_prf            (bru_btb_hit_prf),
        .bru_RAS_count_prf          (bru_RAS_count_prf),
        .bru_pre_taken_prf          (bru_pre_taken_prf),
        
        // 来自物理寄存器堆的值
        .bru_prf_rs1_value          (bru_prf_rs1_value),
        .bru_prf_rs2_value          (bru_prf_rs2_value),
        
        // 来自其他执行单元写回阶段的结果（用于转发）
        .alu_value_wb               (alu_value_wb),
        .mul_value_wb               (mul_value_wb),
        .div_value_wb               (div_value_wb),
        .lsu_value_wb               (lsu_value_wb),
        
        // 来自其他执行单元写回阶段的rd值（用于转发）
        .alu_rd_wb                  (alu_rd_wb),
        .mul_rd_wb                  (mul_rd_wb),
        .div_rd_wb                  (div_rd_wb),
        .lsu_rd_wb                  (lsu_rd_wb),
        
        // 恢复完成信号输入
        .complete_fentch            (complete_fentch),
        .complete_rob               (complete_rob),
        
        // 输出到物理寄存器堆的寄存器号
        .bru_rs1_number_prf         (bru_rs1_number_prf),
        .bru_rs2_number_prf         (bru_rs2_number_prf),  
        .bru_bob_id_prf             (bru_bob_id_prf),                    
        
        // 最终完成信号输出（给ROB和BOB）
        .rd_number_wb               (bru_rd_wb),
        .reg_write_wb               (bru_reg_write_wb),
        .bru_rob_id_wb_out          (bru_rob_id_wb),
        .BOB_id_wb                  (BOB_id_wb),
        .BOB_pc_wb                  (BOB_pc_wb),
        .adr_wb                     (adr_wb),
        .bru_recovery_wb            (bru_recovery_wb),
        .btb_wirte_wb               (btb_wirte_wb),
        .rd_value_wb                (bru_value_wb),
        .RAS_count_wb               (RAS_count_wb),
        .taken_wb                   (taken_wb),
        .GPHT_CPHT_index_wb         (GPHT_CPHT_index_wb),
        .BPHT_index_wb              (BPHT_index_wb),
        .GHR_wb                     (GHR_wb),
        .is_return_wb               (is_return_wb),
        .is_b_type_wb               (is_b_type_wb),
        .G_or_B_wb                  (G_or_B_wb),
        .complete_wb                (bru_complete_wb),
        
        // 状态输出
        .bru_iq2_full               (bru_iq2_full),
        .bus_bru                    (bus_bru),
	.stall 			    (stall),
	.write_ok3		    (write_ok3),
	.write_ok4		    (write_ok4)
    );
    
  
    
    // ==================== LSU 模块实例化 ====================
    top_lsu u_top_lsu (
        .clk                        (clk),
        .reset                      (reset),
        
        // 来自前端/译码器的输入
        .lsu_rob_id1                (lsu_rob_id1),
        .lsu_rob_id2                (lsu_rob_id2),
        .lsu_imm1                   (lsu_imm1),
        .lsu_imm2                   (lsu_imm2),
        .lsu_rs1_number1            (lsu_rs1_number1),
        .lsu_rs2_number1            (lsu_rs2_number1),
        .lsu_rs1_number2            (lsu_rs1_number2),
        .lsu_rs2_number2            (lsu_rs2_number2),
        .lsu_rd_number1             (lsu_rd_number1),
        .lsu_rd_number2             (lsu_rd_number2),
        .lsu_control1               (lsu_control1),
        .lsu_control2               (lsu_control2),
        .lsu_reg_write1             (lsu_reg_write1),
        .lsu_reg_write2             (lsu_reg_write2),
        .lsu_instr_type1            (lsu_instr_type1),
        .lsu_instr_type2            (lsu_instr_type2),
        .lsu_instr_valid1           (lsu_instr_valid1),
        .lsu_instr_valid2           (lsu_instr_valid2),
        
        // 寄存器有效信号
        .lsu_rs1_valid1             (lsu_rs1_valid1),
        .lsu_rs1_valid2             (lsu_rs1_valid2),
        .lsu_rs2_valid1             (lsu_rs2_valid1),
        .lsu_rs2_valid2             (lsu_rs2_valid2),
        
        // 转发总线
        .bus_alu                    (bus_alu),
        .bus_mul                    (bus_mul),
        .bus_div                    (bus_div),
        .bus_bru                    (bus_bru),
        
        // 异常和恢复
        .bru_recovery               (bru_recovery_wb),
        .bru_rob_id                 (bru_rob_id_wb),
        .retire_en                  (retire_en_sw),      // 连接到顶层输入
        
        // 来自其他执行单元写回阶段的结果
        .alu_value_wb               (alu_value_wb),
        .bru_value_wb               (bru_value_wb),
        .mul_value_wb               (mul_value_wb),
        .div_value_wb               (div_value_wb),
        .alu_rd_wb                  (alu_rd_wb),
        .bru_rd_wb                  (bru_rd_wb),
        .mul_rd_wb                  (mul_rd_wb),
        .div_rd_wb                  (div_rd_wb),
        
        // 来自物理寄存器堆的值
        .lsu_prf_rs1_value_lw       (lsu_prf_rs1_value_lw),
        .lsu_prf_rs1_value_sw       (lsu_prf_rs1_value_sw),
        .lsu_prf_rs2_value_sw       (lsu_prf_rs2_value_sw),
        
        // 输出到物理寄存器堆的寄存器号
        .lsu_rs1_number_prf         (lsu_rs1_number_prf),
        .lsu_rs1_number_prf_sw      (lsu_rs1_number_prf_sw),
        .lsu_rs2_number_prf_sw      (lsu_rs2_number_prf_sw),
        
        // WB接口输出（给ROB）
        .lsu_reg_write_wb           (lsu_reg_write_wb),
        .lsu_value_wb_end           (lsu_value_wb),
        .lsu_rd_wb                  (lsu_rd_wb),
        .load_rob_id                (load_rob_id),
        .complete_load_end          (complete_load_end),
        .complete_store_end         (complete_store_end),
        .lsu_sw_rob_id              (lsu_sw_rob_id),
        
        // 状态信号
        .lsu_iq4_full               (lsu_iq4_full),
        
        // 输出给CACHE
        .cache_data                 (cache_data),
        .cache_valid                (cache_valid),
        .cache_ready                (cache_ready),
        .cache_hit                  (cache_hit),
        .retire_data_sb             (retire_data_sb),
        .store_type_end             (store_type_end),
        .ld_en_end                  (ld_en_end),
        .st_en_end                  (st_en_end),
        .bus_lsu                    (bus_lsu),
        .D_VA                       (D_VA),
        .address_store_adr          (D_VA_ST)                                              
    );  
    

    // ==================== MDU 模块实例化（完整修复）====================
    top_mdu u_top_mdu (
        .clk                    (clk),
        .reset                  (reset),
        .mdu_rob_id1            (mdu_rob_id1),
        .mdu_rob_id2            (mdu_rob_id2),
        .mdu_rs1_number1        (mdu_rs1_number1),
        .mdu_rs2_number1        (mdu_rs2_number1),
        .mdu_rs1_number2        (mdu_rs1_number2),
        .mdu_rs2_number2        (mdu_rs2_number2),
        .mdu_rd_number1         (mdu_rd_number1),
        .mdu_rd_number2         (mdu_rd_number2),
        .mdu_control1           (mdu_control1),
        .mdu_control2           (mdu_control2),
        .mdu_reg_write1         (mdu_reg_write1),
        .mdu_reg_write2         (mdu_reg_write2),
        .mdu_instr_valid1       (mdu_instr_valid1),
        .mdu_instr_valid2       (mdu_instr_valid2),
        .bru_recovery           (bru_recovery_wb),
        .bru_rob_id             (bru_rob_id_wb),
        .bus_bru                (bus_bru),
        .bus_lsu                (bus_lsu),
        .bus_alu                (bus_alu),
        .mdu_mul_bus_wake       (bus_mul),
        .mdu_div_bus_wake       (bus_div),
        
        // PRU 读数据
        .mdu_div_rs1_value      (mdu_div_rs1_value),
        .mdu_div_rs2_value      (mdu_div_rs2_value),
        .mdu_mul_rs1_value      (mdu_mul_rs1_value),
        .mdu_mul_rs2_value      (mdu_mul_rs2_value),
        
        // 数据转发
        .alu_value_wb           (alu_value_wb),
        .bru_value_wb           (bru_value_wb),
        .mul_value_wb           (mul_value_wb),
        .div_value_wb           (div_value_wb),
        .lsu_value_wb           (lsu_value_wb),
        
        // 寄存器号转发
        .alu_rd_wb              (alu_rd_wb),
        .bru_rd_wb              (bru_rd_wb),
        .lsu_rd_wb              (lsu_rd_wb),
        
        // 寄存器有效信号
        .mdu_rs1_valid1         (mdu_rs1_valid1),
        .mdu_rs1_valid2         (mdu_rs1_valid2),
        .mdu_rs2_valid1         (mdu_rs2_valid1),
        .mdu_rs2_valid2         (mdu_rs2_valid2),
        
        // 流水线满信号
        .mdu_iq3_full           (mdu_iq3_full),
        
        // PRF 读地址
        .mdu_div_rs1_prf        (mdu_div_rs1_prf),
        .mdu_div_rs2_prf        (mdu_div_rs2_prf),
        .mdu_mul_rs1_prf        (mdu_mul_rs1_prf),
        .mdu_mul_rs2_prf        (mdu_mul_rs2_prf),
        
        // DIV 输出
        .mdu_div_result         (div_value_wb),
        .mdu_div_reg_write      (div_reg_write_wb),
        .mdu_div_rd_number      (div_rd_wb),
        .mdu_div_complete       (mdu_div_complete),
        .mdu_div_rob_wb         (mdu_div_rob_wb),
        
        // MUL 输出
        .mdu_mul_rd_wb          (mul_rd_wb),
        .mdu_mul_rob_wb         (mdu_mul_rob_wb),
        .mdu_mul_reg_wb         (mul_reg_write_wb),
        .mdu_mul_result_wb      (mul_value_wb),
        .mdu_mul_complete_wb    (mdu_mul_complete_wb)
    );
 
 
    // ==================== PRF 模块实例化 ====================
    PRF #(.PHY_REG_NUM    (64),.REG_DATA_WIDTH (64),.REG_ADDR_WIDTH (6)) 
    u_PRF (
        .clk                    (clk),
        .reset                  (reset),
        .stall                  (bru_recovery_wb),
        
        // IQ就绪位访问接口,
        .iq_ready_rd_addr0      (iq_ready_rd_addr0),
        .iq_ready_rd_addr1      (iq_ready_rd_addr1),
        .iq_ready_rd_addr2      (iq_ready_rd_addr2),
        .iq_ready_rd_addr3      (iq_ready_rd_addr3),
        
        //ready  bit
        .iq_ready_rd_data0      (iq_ready_rd_data0),
        .iq_ready_rd_data1      (iq_ready_rd_data1),
        .iq_ready_rd_data2      (iq_ready_rd_data2),
        .iq_ready_rd_data3      (iq_ready_rd_data3),
        
        // 各功能部件ready-bit置位接口写
        .alu_ready_en           (bus_alu[6]),
        .alu_ready_pr           (bus_alu[5:0]),
        .mdu_mul_ready_en       (bus_mul[6]),
        .mdu_mul_ready_pr       (bus_mul[5:0]),
        .mdu_div_ready_en       (bus_div[6]),
        .mdu_div_ready_pr       (bus_div[5:0]),
        .bru_ready_en           (bus_bru[6]),
        .bru_ready_pr           (bus_bru[5:0]),
        .lsu_ready_en           (bus_lsu[6]),
        .lsu_ready_pr           (bus_lsu[5:0]),
        
        // ALU接口
        .alu_rd_addr0           (alu_rs1_number_prf),
        .alu_rd_addr1           (alu_rs2_number_prf),
        .alu_rd_data0           (alu_prf_rs1_value),
        .alu_rd_data1           (alu_prf_rs2_value),
        .alu_wr_addr            (alu_rd_wb),
        .alu_wr_data            (alu_value_wb),
        .alu_wr_en              (alu_reg_write_wb),
        
        // MDU接口
        .mdu_rd_addr0           (mdu_mul_rs1_prf),
        .mdu_rd_addr1           (mdu_mul_rs2_prf),
        .mdu_rd_addr2           (mdu_div_rs1_prf),
        .mdu_rd_addr3           (mdu_div_rs2_prf),
        .mdu_rd_data0           (mdu_mul_rs1_value),
        .mdu_rd_data1           (mdu_mul_rs2_value),
        .mdu_rd_data2           (mdu_div_rs1_value),
        .mdu_rd_data3           (mdu_div_rs2_value),
        .mdu_wr_addr0           (mul_rd_wb),
        .mdu_wr_addr1           (div_rd_wb),
        .mdu_wr_data0           (mul_value_wb),
        .mdu_wr_data1           (div_value_wb),
        .mdu_wr_en0             (mul_reg_write_wb),
        .mdu_wr_en1             (div_reg_write_wb),
        
        // BRU接口
        .bru_rd_addr0           (bru_rs1_number_prf),
        .bru_rd_addr1           (bru_rs2_number_prf),
        .bru_rd_data0           (bru_prf_rs1_value),
        .bru_rd_data1           (bru_prf_rs2_value),
        .bru_wr_addr            (bru_rd_wb),
        .bru_wr_data            (bru_value_wb),
        .bru_wr_en              (bru_reg_write_wb),
        
        // LSU接口
        .lsu_rd_addr0           (lsu_rs1_number_prf),
        .lsu_rd_addr1           (lsu_rs1_number_prf_sw),
        .lsu_rd_addr2           (lsu_rs2_number_prf_sw),
        .lsu_rd_data0           (lsu_prf_rs1_value_lw),
        .lsu_rd_data1           (lsu_prf_rs1_value_sw),
        .lsu_rd_data2           (lsu_prf_rs2_value_sw),
        .lsu_wr_addr            (lsu_rd_wb),
        .lsu_wr_data            (lsu_value_wb),
        .lsu_wr_en              (lsu_reg_write_wb),
        
        // 分支恢复/指令退休接口
        .recover_pr0_en         (recover_pr0_en),
        .recover_pr0            (recover_pr0),
        .recover_pr1            (recover_pr1),
        .recover_pr1_en         (recover_pr1_en),
        
        .retire_pr0_en          (retire_en_rob),
        .retire_pr0             (retire_pr0),
        .retire_pr1             (retire_pr1),
        .retire_pr1_en          (retire_pr1_en)
    );
endmodule

