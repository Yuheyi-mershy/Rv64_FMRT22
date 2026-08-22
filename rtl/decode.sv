/******************************************************************************
 * Filename:decode.sv
 * Author:FMRT22-HYC
 * Create date:2025.12.04 20:00 ~ 12.05 15:00
 * Rewrite date:2026.03.30
 *      Fixed immediate and address calculation bugs
 *      Added dec_recover_vec to indicate which instruction needs recovery
 *      Added dec_data2/dec_data_valid2 to support dual write to BOB
 * Description:Implementation of decode 
 * ***************************************************************************/
 module decode #(
    parameter INST_WIDTH   = 32,     // 指令宽度
    parameter PC_WIDTH     = 64,     // PC宽度（64位系统）
    parameter CTRL_SIG_WIDTH_ALU = 4,  // ALU类FU控制信号宽度
    parameter CTRL_SIG_WIDTH_MDU = 4,  // MDU类FU控制信号宽度
    parameter CTRL_SIG_WIDTH_BRU = 3,  // BRU类FU控制信号宽度（分支指令）
    parameter CTRL_SIG_WIDTH_LSU = 4,  // LSU类FU控制信号宽度（加载存储）
    parameter FU_WIDTH     = 4,      // 功能单元选择宽度（4bit识别4类FU）
    parameter OPCODE_WIDTH = 7,      // 操作码宽度
    parameter FUNCT3_WIDTH = 3,      // funct3宽度
    parameter FUNCT7_WIDTH = 7,      // funct7宽度
    parameter REG_ADDR_WIDTH = 5     // 寄存器地址宽度（RV64为5bit，对应32个通用寄存器）
)(
    input  logic                      clk,            // 时钟
    input  logic                      reset,          // 异步复位
    input  logic [INST_WIDTH-1:0]     inst1,          // 第一条指令（来自IB）
    input  logic [INST_WIDTH-1:0]     inst2,          // 第二条指令（来自IB）
    input  logic [PC_WIDTH-1:0]       pc1,            // 第一条指令PC
    input  logic [PC_WIDTH-1:0]       pc2,            // 第二条指令PC
    input  logic                      BOB_pred_taken1, // BOB中第一条指令预测方向
    input  logic                      BOB_pred_taken2, // BOB中第二条指令预测方向
    input  logic                      BOB_btb_hit1,    // BOB中第一条指令BTB是否命中
    input  logic                      BOB_btb_hit2,    // BOB中第二条指令BTB是否命中
    // 输入指令有效信号（高有效）
    input  logic                      inst1_in_valid, // 第一条输入指令是否有效
    input  logic                      inst2_in_valid, // 第二条输入指令是否有效
    
    // 输出接口 
    output logic [REG_ADDR_WIDTH-1:0] rs1_1,          // 第一条指令源寄存器1地址
    output logic [REG_ADDR_WIDTH-1:0] rs2_1,          // 第一条指令源寄存器2地址
    output logic [REG_ADDR_WIDTH-1:0] rd_1,           // 第一条指令目的寄存器地址
    output logic [REG_ADDR_WIDTH-1:0] rs1_2,          // 第二条指令源寄存器1地址
    output logic [REG_ADDR_WIDTH-1:0] rs2_2,          // 第二条指令源寄存器2地址
    output logic [REG_ADDR_WIDTH-1:0] rd_2,           // 第二条指令目的寄存器地址
    output logic                      wen_1,          // 第一条指令寄存器写使能（是否有Rd）
    output logic                      wen_2,          // 第二条指令寄存器写使能
    
    output logic                      rs1_exist1,     // 第一条指令RS1是否存在
    output logic                      rs2_exist1,     // 第一条指令RS2是否存在
    output logic                      rs1_exist2,     // 第二条指令RS1是否存在
    output logic                      rs2_exist2,     // 第二条指令RS2是否存在
    output logic                      memwrite1,      // 第一条指令存储器写信号
    output logic                      memwrite2,      // 第二条指令存储器写信号
    output logic                      dec_data_valid, // 第一条指令dec_data有效信号（送到BOB）
    output logic [PC_WIDTH-1:0]       dec_data,       // 第一条指令修正后的PC地址或立即数（送到BOB）
    output logic                      dec_data_valid2,// 第二条指令dec_data有效信号（送到BOB）
    output logic [PC_WIDTH-1:0]       dec_data2,      // 第二条指令修正后的PC地址或立即数（送到BOB）
    output logic                      dec_recover,    // 恢复信号（地址错误时）—— 保留兼容，等价于 |dec_recover_vec
    output logic [1:0]                dec_recover_vec,// 恢复向量 [0]指令1需恢复，[1]指令2需恢复
    output logic [CTRL_SIG_WIDTH_ALU-1:0] ctrl_sig_alu1, // ALU类控制信号
    output logic [CTRL_SIG_WIDTH_ALU-1:0] ctrl_sig_alu2, // ALU类控制信号
    output logic [CTRL_SIG_WIDTH_MDU-1:0] ctrl_sig_mdu1, // MDU类控制信号
    output logic [CTRL_SIG_WIDTH_MDU-1:0] ctrl_sig_mdu2, // MDU类控制信号
    output logic [CTRL_SIG_WIDTH_BRU-1:0] ctrl_sig_bru1, // BRU类控制信号
    output logic [CTRL_SIG_WIDTH_BRU-1:0] ctrl_sig_bru2, // BRU类控制信号
    output logic [CTRL_SIG_WIDTH_LSU-1:0] ctrl_sig_lsu1, // LSU类控制信号
    output logic [CTRL_SIG_WIDTH_LSU-1:0] ctrl_sig_lsu2, // LSU类控制信号
    output logic [FU_WIDTH-1:0]      fu_sel1,        // 第一条指令FU选择
    output logic [FU_WIDTH-1:0]      fu_sel2,        // 第二条指令FU选择
    output logic [PC_WIDTH-1:0]      imm1,           // 第一条指令立即数
    output logic [PC_WIDTH-1:0]      imm2,           // 第二条指令立即数
    output logic [1:0]               inst_type1,     // 第一条指令类型
    output logic [1:0]               inst_type2,     // 第二条指令类型
    output logic                     inst1_valid,    // 第一条指令输出有效
    output logic                     inst2_valid     // 第二条指令输出有效
);

// 指令字段提取 
logic [OPCODE_WIDTH-1:0]  opcode1;
logic [FUNCT3_WIDTH-1:0]  funct3_1;
logic [FUNCT7_WIDTH-1:0]  funct7_1;
logic [REG_ADDR_WIDTH-1:0] rs1_1_raw;
logic [REG_ADDR_WIDTH-1:0] rs2_1_raw;
logic [REG_ADDR_WIDTH-1:0] rd_1_raw;

logic [OPCODE_WIDTH-1:0]  opcode2;
logic [FUNCT3_WIDTH-1:0]  funct3_2;
logic [FUNCT7_WIDTH-1:0]  funct7_2;
logic [REG_ADDR_WIDTH-1:0] rs1_2_raw;
logic [REG_ADDR_WIDTH-1:0] rs2_2_raw;
logic [REG_ADDR_WIDTH-1:0] rd_2_raw;

// 指令字段提取赋值
always_comb begin
    if(inst1_in_valid) begin
        opcode1 = inst1[6:0];
        funct3_1 = inst1[14:12];
        funct7_1 = inst1[31:25];
        rs1_1_raw = inst1[19:15];
        rs2_1_raw = inst1[24:20];
        rd_1_raw  = inst1[11:7];
    end else begin
        opcode1 = '0;
        funct3_1 = '0;
        funct7_1 = '0;
        rs1_1_raw = '0;
        rs2_1_raw = '0;
        rd_1_raw = '0;
    end
end

always_comb begin
    if(inst2_in_valid) begin
        opcode2 = inst2[6:0];
        funct3_2 = inst2[14:12];
        funct7_2 = inst2[31:25];
        rs1_2_raw = inst2[19:15];
        rs2_2_raw = inst2[24:20];
        rd_2_raw  = inst2[11:7];
    end else begin
        opcode2 = '0;
        funct3_2 = '0;
        funct7_2 = '0;
        rs1_2_raw = '0;
        rs2_2_raw = '0;
        rd_2_raw = '0;
    end
end

// 功能单元（FU）类型定义
typedef enum logic [FU_WIDTH-1:0] {
    FU_ALU    = 4'b1000,  // ALU：算术/逻辑指令
    FU_MDU    = 4'b0100,  // MDU：乘法/除法指令
    FU_BRU    = 4'b0010,  // BRU：分支/跳转指令
    FU_LSU    = 4'b0001   // LSU：加载/存储指令
} fu_type_t;

// 内部信号
logic [PC_WIDTH-1:0]  calc_pc1;        // 第一条指令计算的目标地址（B/JAL）
logic [PC_WIDTH-1:0]  calc_pc2;        // 第二条指令计算的目标地址（B/JAL）
logic [PC_WIDTH-1:0]  calc_imm1;       // 第一条指令立即数
logic [PC_WIDTH-1:0]  calc_imm2;       // 第二条指令立即数
logic [PC_WIDTH-1:0]  auipc_result1;   // AUIPC计算结果（PC+imm）
logic [PC_WIDTH-1:0]  auipc_result2;   // AUIPC计算结果（PC+imm）
logic [PC_WIDTH-1:0]  jalr_imm1;       // JALR立即数（拓展后）
logic [PC_WIDTH-1:0]  jalr_imm2;       // JALR立即数（拓展后）

// 分支指令分类
logic                 is_branch1;      // 第一条指令是否为B格式分支
logic                 is_branch2;      // 第二条指令是否为B格式分支
logic                 is_jal1;         // 第一条指令是否为JAL
logic                 is_jal2;         // 第二条指令是否为JAL
logic                 is_jalr1;        // 第一条指令是否为JALR
logic                 is_jalr2;        // 第二条指令是否为JALR
logic                 is_auipc1;       // 第一条指令是否为AUIPC
logic                 is_auipc2;       // 第二条指令是否为AUIPC

// 分支处理相关信号
logic                 need_calc_addr1; // 第一条指令是否需要计算地址
logic                 need_calc_addr2; // 第二条指令是否需要计算地址

// RS1/RS2存在信号内部变量
logic                 rs1_exist1_int;
logic                 rs2_exist1_int;
logic                 rs1_exist2_int;
logic                 rs2_exist2_int;

// 控制信号内部变量
logic [CTRL_SIG_WIDTH_ALU-1:0] ctrl_alu1;
logic [CTRL_SIG_WIDTH_ALU-1:0] ctrl_alu2;
logic [CTRL_SIG_WIDTH_MDU-1:0] ctrl_mdu1;
logic [CTRL_SIG_WIDTH_MDU-1:0] ctrl_mdu2;
logic [CTRL_SIG_WIDTH_BRU-1:0] ctrl_bru1;
logic [CTRL_SIG_WIDTH_BRU-1:0] ctrl_bru2;
logic [CTRL_SIG_WIDTH_LSU-1:0] ctrl_lsu1;
logic [CTRL_SIG_WIDTH_LSU-1:0] ctrl_lsu2;

logic                 wen_1_int;
logic                 wen_2_int;

// ==============================================================================
// 1. 指令类型识别
// ==============================================================================
always_comb begin
    // 第一条指令类型
    if(!inst1_in_valid) begin
        inst_type1 = 2'b00;
    end else begin
        case(opcode1)
            7'b0110011, 7'b0111011: inst_type1 = 2'b00; // R型
            7'b0010011, 7'b0011011: inst_type1 = 2'b01; // I型
            7'b1100111:             inst_type1 = 2'b10; // JALR
            7'b1100011:             inst_type1 = 2'b11; // B型
            7'b1101111:             inst_type1 = 2'b00; // JAL
            7'b0010111:             inst_type1 = 2'b01; // AUIPC
            7'b0110111:             inst_type1 = 2'b11; // LUI
            7'b0000011, 7'b0100011: inst_type1 = 2'b11; // 加载/存储
            default:                inst_type1 = 2'b00;
        endcase
    end

    // 第二条指令类型
    if(!inst2_in_valid) begin
        inst_type2 = 2'b00;
    end else begin
        case(opcode2)
            7'b0110011, 7'b0111011: inst_type2 = 2'b00;
            7'b0010011, 7'b0011011: inst_type2 = 2'b01;
            7'b1100111:             inst_type2 = 2'b10;
            7'b1100011:             inst_type2 = 2'b11;
            7'b1101111:             inst_type2 = 2'b00;
            7'b0010111:             inst_type2 = 2'b01;
            7'b0110111:             inst_type2 = 2'b11;
            7'b0000011, 7'b0100011: inst_type2 = 2'b11;
            default:                inst_type2 = 2'b00;
        endcase
    end
end

// ==============================================================================
// 2. 分支指令分类
// ==============================================================================
always_comb begin
    // 第一条指令
    is_branch1 = 1'b0;
    is_jal1 = 1'b0;
    is_jalr1 = 1'b0;
    is_auipc1 = 1'b0;
    if(inst1_in_valid) begin
        case(opcode1)
            7'b1100011: is_branch1 = 1'b1;  // B格式
            7'b1101111: is_jal1 = 1'b1;     // JAL
            7'b1100111: is_jalr1 = 1'b1;    // JALR
            7'b0010111: is_auipc1 = 1'b1;   // AUIPC
            default: ;
        endcase
    end

    // 第二条指令
    is_branch2 = 1'b0;
    is_jal2 = 1'b0;
    is_jalr2 = 1'b0;
    is_auipc2 = 1'b0;
    if(inst2_in_valid) begin
        case(opcode2)
            7'b1100011: is_branch2 = 1'b1;
            7'b1101111: is_jal2 = 1'b1;
            7'b1100111: is_jalr2 = 1'b1;
            7'b0010111: is_auipc2 = 1'b1;
            default: ;
        endcase
    end
end

// ==============================================================================
// 3. 立即数拼接（根据RISC-V规范）
// ==============================================================================
// 第一条指令立即数计算
always_comb begin
    calc_imm1 = '0;
    calc_pc1 = '0;
    auipc_result1 = '0;
    jalr_imm1 = '0;
    
    if(inst1_in_valid) begin
        case(opcode1)
            // I格式指令
            7'b0010011, 7'b0011011, 7'b0000011, 7'b1100111: begin
                // 符号扩展到64位
                calc_imm1 = {{52{inst1[31]}}, inst1[31:20]};
            end
            // S格式
            7'b0100011: begin
                // 拼接 imm[11:5] 和 imm[4:0]
                calc_imm1 = {{52{inst1[31]}}, inst1[31:25], inst1[11:7]};
            end
            // B格式 - 计算目标地址
            7'b1100011: begin
                // 拼接 {imm[12], imm[10:5], imm[4:1], imm[11], 1'b0}
                calc_pc1 = pc1 + {{51{inst1[31]}}, inst1[31], inst1[7], inst1[30:25], inst1[11:8], 1'b0};
                calc_imm1 = calc_pc1;
            end
            // U格式（LUI）
            7'b0110111: begin
                // 高20位立即数，低12位清零
                calc_imm1 = {{32{inst1[31]}}, inst1[31:12], 12'b0};
            end
            // JAL - 计算目标地址
            7'b1101111: begin
                // 拼接 {imm[20], imm[10:1], imm[11], imm[19:12], 1'b0}
                calc_pc1 = pc1 + {{43{inst1[31]}}, inst1[31], inst1[19:12], inst1[20], inst1[30:21], 1'b0};
                calc_imm1 = calc_pc1;
            end
            // AUIPC - 计算PC+imm
            7'b0010111: begin
                // 高20位立即数，低12位清零
                auipc_result1 = pc1 + {{32{inst1[31]}}, inst1[31:12], 12'b0};
                calc_imm1 = auipc_result1;
            end
            default: calc_imm1 = '0;
        endcase
    end
end

// 第二条指令立即数计算
always_comb begin
    calc_imm2 = '0;
    calc_pc2 = '0;
    auipc_result2 = '0;
    jalr_imm2 = '0;
    
    if(inst2_in_valid) begin
        case(opcode2)
            7'b0010011, 7'b0011011, 7'b0000011, 7'b1100111: begin
                calc_imm2 = {{52{inst2[31]}}, inst2[31:20]};
            end
            7'b0100011: begin
                calc_imm2 = {{52{inst2[31]}}, inst2[31:25], inst2[11:7]};
            end
            7'b1100011: begin
                calc_pc2 = pc2 + {{51{inst2[31]}}, inst2[31], inst2[7], inst2[30:25], inst2[11:8], 1'b0};
                calc_imm2 = calc_pc2;
            end
            7'b0110111: begin
                calc_imm2 = {{32{inst2[31]}}, inst2[31:12], 12'b0};
            end
            7'b1101111: begin
                calc_pc2 = pc2 + {{43{inst2[31]}}, inst2[31], inst2[19:12], inst2[20], inst2[30:21], 1'b0};
                calc_imm2 = calc_pc2;
            end
            7'b0010111: begin
                auipc_result2 = pc2 + {{32{inst2[31]}}, inst2[31:12], 12'b0};
                calc_imm2 = auipc_result2;
            end
            default: calc_imm2 = '0;
        endcase
    end
end

// ==============================================================================
// 4. 分支指令处理逻辑
// ==============================================================================
always_comb begin
    // 默认值
    need_calc_addr1 = 1'b0;
    
    if(inst1_in_valid) begin
        if(is_branch1) begin
            if(BOB_pred_taken1) begin
                if(BOB_btb_hit1) begin
                    need_calc_addr1 = 1'b0;
                end else begin
                    need_calc_addr1 = 1'b1;
                end
            end else begin
                need_calc_addr1 = 1'b1;
            end
        end
        else if(is_jal1) begin
            if(BOB_btb_hit1) begin
                need_calc_addr1 = 1'b0;
            end else begin
                need_calc_addr1 = 1'b1;
            end
        end
        else if(is_jalr1) begin
            need_calc_addr1 = 1'b0;
        end
        else if(is_auipc1) begin
            need_calc_addr1 = 1'b0;
        end
    end
    
    // 第二条指令同理
    need_calc_addr2 = 1'b0;
    
    if(inst2_in_valid) begin
        if(is_branch2) begin
            if(BOB_pred_taken2) begin
                if(BOB_btb_hit2) begin
                    need_calc_addr2 = 1'b0;
                end else begin
                    need_calc_addr2 = 1'b1;
                end
            end else begin
                need_calc_addr2 = 1'b1;
            end
        end
        else if(is_jal2) begin
            if(BOB_btb_hit2) begin
                need_calc_addr2 = 1'b0;
            end else begin
                need_calc_addr2 = 1'b1;
            end
        end
        else if(is_jalr2) begin
            need_calc_addr2 = 1'b0;
        end
        else if(is_auipc2) begin
            need_calc_addr2 = 1'b0;
        end
    end
end

// ==============================================================================
// 5. 寄存器译码
// ==============================================================================
always_comb begin
    // 第一条指令默认值
    rs1_1 = '0;
    rs2_1 = '0;
    rd_1  = '0;
    wen_1_int = 1'b0;
    rs1_exist1_int = 1'b0;
    rs2_exist1_int = 1'b0;
    memwrite1 = 1'b0;

    if(inst1_in_valid) begin
        rs1_1 = rs1_1_raw;
        rs2_1 = rs2_1_raw;
        rd_1  = rd_1_raw;
        case(opcode1)
            7'b0110011, 7'b0111011: begin  // R型
                rs1_exist1_int = 1'b1;
                rs2_exist1_int = 1'b1;
                wen_1_int = 1'b1;
            end
            7'b0010011, 7'b0011011: begin  // I型（ALU）
                rs1_exist1_int = 1'b1;
                rs2_exist1_int = 1'b0;
                rs2_1 = '0;
                wen_1_int = 1'b1;
            end
            7'b1100011: begin  // B型
                rs1_exist1_int = 1'b1;
                rs2_exist1_int = 1'b1;
                rd_1 = '0;
                wen_1_int = 1'b0;
            end
            7'b1101111: begin  // JAL
                rs1_exist1_int = 1'b0;
                rs2_exist1_int = 1'b0;
                rs1_1 = '0;
                rs2_1 = '0;
                wen_1_int = 1'b1;
            end
            7'b1100111: begin  // JALR
                rs1_exist1_int = 1'b1;
                rs2_exist1_int = 1'b0;
                rs2_1 = '0;
                wen_1_int = 1'b1;
            end
            7'b0110111: begin  // LUI
                rs1_exist1_int = 1'b0;
                rs2_exist1_int = 1'b0;
                rs1_1 = '0;
                rs2_1 = '0;
                wen_1_int = 1'b1;
            end
            7'b0010111: begin  // AUIPC
                rs1_exist1_int = 1'b0;
                rs2_exist1_int = 1'b0;
                rs1_1 = '0;
                rs2_1 = '0;
                wen_1_int = 1'b1;
            end
            7'b0000011: begin  // 加载
                rs1_exist1_int = 1'b1;
                rs2_exist1_int = 1'b0;
                rs2_1 = '0;
                wen_1_int = 1'b1;
            end
            7'b0100011: begin  // 存储
                rs1_exist1_int = 1'b1;
                rs2_exist1_int = 1'b1;
                rd_1 = '0;
                wen_1_int = 1'b0;
                memwrite1 = 1'b1;
            end
            default: begin
                rs1_exist1_int = 1'b0;
                rs2_exist1_int = 1'b0;
                wen_1_int = 1'b0;
                memwrite1 = 1'b0;
            end
        endcase
    end

    // 第二条指令默认值
    rs1_2 = '0;
    rs2_2 = '0;
    rd_2  = '0;
    wen_2_int = 1'b0;
    rs1_exist2_int = 1'b0;
    rs2_exist2_int = 1'b0;
    memwrite2 = 1'b0;

    if(inst2_in_valid) begin
        rs1_2 = rs1_2_raw;
        rs2_2 = rs2_2_raw;
        rd_2  = rd_2_raw;
        case(opcode2)
            7'b0110011, 7'b0111011: begin
                rs1_exist2_int = 1'b1;
                rs2_exist2_int = 1'b1;
                wen_2_int = 1'b1;
            end
            7'b0010011, 7'b0011011: begin
                rs1_exist2_int = 1'b1;
                rs2_exist2_int = 1'b0;
                rs2_2 = '0;
                wen_2_int = 1'b1;
            end
            7'b1100011: begin
                rs1_exist2_int = 1'b1;
                rs2_exist2_int = 1'b1;
                rd_2 = '0;
                wen_2_int = 1'b0;
            end
            7'b1101111: begin
                rs1_exist2_int = 1'b0;
                rs2_exist2_int = 1'b0;
                rs1_2 = '0;
                rs2_2 = '0;
                wen_2_int = 1'b1;
            end
            7'b1100111: begin
                rs1_exist2_int = 1'b1;
                rs2_exist2_int = 1'b0;
                rs2_2 = '0;
                wen_2_int = 1'b1;
            end
            7'b0110111: begin
                rs1_exist2_int = 1'b0;
                rs2_exist2_int = 1'b0;
                rs1_2 = '0;
                rs2_2 = '0;
                wen_2_int = 1'b1;
            end
            7'b0010111: begin
                rs1_exist2_int = 1'b0;
                rs2_exist2_int = 1'b0;
                rs1_2 = '0;
                rs2_2 = '0;
                wen_2_int = 1'b1;
            end
            7'b0000011: begin
                rs1_exist2_int = 1'b1;
                rs2_exist2_int = 1'b0;
                rs2_2 = '0;
                wen_2_int = 1'b1;
            end
            7'b0100011: begin
                rs1_exist2_int = 1'b1;
                rs2_exist2_int = 1'b1;
                rd_2 = '0;
                wen_2_int = 1'b0;
                memwrite2 = 1'b1;
            end
            default: begin
                rs1_exist2_int = 1'b0;
                rs2_exist2_int = 1'b0;
                wen_2_int = 1'b0;
                memwrite2 = 1'b0;
            end
        endcase
    end
end

// ==============================================================================
// 6. 控制信号与FU选择
// ==============================================================================
// 第一条指令控制信号
always_comb begin
    ctrl_alu1 = '0;
    ctrl_mdu1 = '0;
    ctrl_bru1 = '0;
    ctrl_lsu1 = '0;
    fu_sel1 = FU_ALU;

    if(inst1_in_valid) begin
        case(opcode1)
            7'b0110011: begin  // R型
                if(funct7_1[0] == 1'b1) begin  // MDU
                    fu_sel1 = FU_MDU;
                    case({funct7_1, funct3_1})
                        {7'b0000001, 3'b000}: ctrl_mdu1 = 4'b0000; // MUL
                        {7'b0000001, 3'b001}: ctrl_mdu1 = 4'b0001; // MULH
                        {7'b0000001, 3'b010}: ctrl_mdu1 = 4'b0010; // MULHSU
                        {7'b0000001, 3'b011}: ctrl_mdu1 = 4'b0011; // MULHU
                        {7'b0000001, 3'b100}: ctrl_mdu1 = 4'b1000; // DIV
                        {7'b0000001, 3'b101}: ctrl_mdu1 = 4'b1001; // DIVU
                        {7'b0000001, 3'b110}: ctrl_mdu1 = 4'b1010; // REM
                        {7'b0000001, 3'b111}: ctrl_mdu1 = 4'b1011; // REMU
                        default: ctrl_mdu1 = 4'b0000;
                    endcase
                end else begin  // ALU
                    fu_sel1 = FU_ALU;
                    case({funct7_1, funct3_1})
                        {7'b0000000, 3'b000}: ctrl_alu1 = 4'b0001; // ADD
                        {7'b0100000, 3'b000}: ctrl_alu1 = 4'b0010; // SUB
                        {7'b0000000, 3'b001}: ctrl_alu1 = 4'b0011; // SLL
                        {7'b0000000, 3'b010}: ctrl_alu1 = 4'b0100; // SLT
                        {7'b0000000, 3'b011}: ctrl_alu1 = 4'b0101; // SLTU
                        {7'b0000000, 3'b100}: ctrl_alu1 = 4'b0110; // XOR
                        {7'b0000000, 3'b101}: ctrl_alu1 = 4'b0111; // SRL
                        {7'b0100000, 3'b101}: ctrl_alu1 = 4'b1000; // SRA
                        {7'b0000000, 3'b110}: ctrl_alu1 = 4'b1001; // OR
                        {7'b0000000, 3'b111}: ctrl_alu1 = 4'b1010; // AND
                        default: ctrl_alu1 = 4'b0000;
                    endcase
                end
            end
            7'b0111011: begin  // R型宽
                if(funct7_1[0] == 1'b1) begin  // MDU宽
                    fu_sel1 = FU_MDU;
                    case({funct7_1, funct3_1})
                        {7'b0000001, 3'b000}: ctrl_mdu1 = 4'b0100; // MULW
                        {7'b0000001, 3'b100}: ctrl_mdu1 = 4'b1100; // DIVW
                        {7'b0000001, 3'b101}: ctrl_mdu1 = 4'b1101; // DIVUW
                        {7'b0000001, 3'b110}: ctrl_mdu1 = 4'b1110; // REMW
                        {7'b0000001, 3'b111}: ctrl_mdu1 = 4'b1111; // REMUW
                        default: ctrl_mdu1 = 4'b0000;
                    endcase
                end else begin  // ALU宽
                    fu_sel1 = FU_ALU;
                    case({funct7_1, funct3_1})
                        {7'b0000000, 3'b000}: ctrl_alu1 = 4'b1011; // ADDW
                        {7'b0100000, 3'b000}: ctrl_alu1 = 4'b1100; // SUBW
                        {7'b0000000, 3'b001}: ctrl_alu1 = 4'b1101; // SLLW
                        {7'b0000000, 3'b101}: ctrl_alu1 = 4'b1110; // SRLW
                        {7'b0100000, 3'b101}: ctrl_alu1 = 4'b1111; // SRAW
                        default: ctrl_alu1 = 4'b0000;
                    endcase
                end
            end
            7'b0010011: begin  // I型
                fu_sel1 = FU_ALU;
                case(funct3_1)
                    3'b000: ctrl_alu1 = 4'b0001; // ADDI
                    3'b010: ctrl_alu1 = 4'b0100; // SLTI
                    3'b011: ctrl_alu1 = 4'b0101; // SLTIU
                    3'b100: ctrl_alu1 = 4'b0110; // XORI
                    3'b110: ctrl_alu1 = 4'b1001; // ORI
                    3'b111: ctrl_alu1 = 4'b1010; // ANDI
                    3'b001: ctrl_alu1 = 4'b0011; // SLLI
                    3'b101: ctrl_alu1 = (funct7_1[5] == 1'b0) ? 4'b0111 : 4'b1000; // SRLI/SRAI
                    default: ctrl_alu1 = 4'b0000;
                endcase
            end
            7'b0011011: begin  // I型宽
                fu_sel1 = FU_ALU;
                case(funct3_1)
                    3'b000: ctrl_alu1 = 4'b1011; // ADDIW
                    3'b001: ctrl_alu1 = 4'b1101; // SLLIW
                    3'b101: ctrl_alu1 = (funct7_1[5] == 1'b0) ? 4'b1110 : 4'b1111; // SRLIW/SRAIW
                    default: ctrl_alu1 = 4'b0000;
                endcase
            end
            7'b1100011: begin  // B格式
                fu_sel1 = FU_BRU;
                case(funct3_1)
                    3'b000: ctrl_bru1 = 3'b000; // BEQ
                    3'b001: ctrl_bru1 = 3'b001; // BNE
                    3'b100: ctrl_bru1 = 3'b100; // BLT
                    3'b101: ctrl_bru1 = 3'b101; // BGE
                    3'b110: ctrl_bru1 = 3'b110; // BLTU
                    3'b111: ctrl_bru1 = 3'b111; // BGEU
                    default: ctrl_bru1 = 3'b000;
                endcase
            end
            7'b1101111: begin  // JAL
                fu_sel1 = FU_BRU;
                ctrl_bru1 = 3'b010;
            end
            7'b1100111: begin  // JALR
                fu_sel1 = FU_BRU;
                ctrl_bru1 = 3'b010;
            end
            7'b0010111: begin  // AUIPC
                fu_sel1 = FU_BRU;
                ctrl_bru1 = 3'b011;
            end
            7'b0000011: begin  // load
                fu_sel1 = FU_LSU;
                case(funct3_1)
                    3'b000: ctrl_lsu1 = 4'b0000; // LB
                    3'b001: ctrl_lsu1 = 4'b0001; // LH
                    3'b010: ctrl_lsu1 = 4'b0010; // LW
                    3'b011: ctrl_lsu1 = 4'b0011; // LD
                    3'b100: ctrl_lsu1 = 4'b0100; // LBU
                    3'b101: ctrl_lsu1 = 4'b0101; // LHU
                    3'b110: ctrl_lsu1 = 4'b0110; // LWU
                    default: ctrl_lsu1 = 4'b0000;
                endcase
            end
            7'b0100011: begin  // store
                fu_sel1 = FU_LSU;
                case(funct3_1)
                    3'b000: ctrl_lsu1 = 4'b1000; // SB
                    3'b001: ctrl_lsu1 = 4'b1001; // SH
                    3'b010: ctrl_lsu1 = 4'b1010; // SW
                    3'b011: ctrl_lsu1 = 4'b1011; // SD
                    default: ctrl_lsu1 = 4'b1000;
                endcase
            end
            7'b0110111: begin  // LUI
                fu_sel1 = FU_ALU;
                ctrl_alu1 = 4'b0000;
            end
            default: begin
                fu_sel1 = FU_ALU;
                ctrl_alu1 = 4'b0000;
            end
        endcase
    end
end

// 第二条指令控制信号
always_comb begin
    ctrl_alu2 = '0;
    ctrl_mdu2 = '0;
    ctrl_bru2 = '0;
    ctrl_lsu2 = '0;
    fu_sel2 = FU_ALU;

    if(inst2_in_valid) begin
        case(opcode2)
            7'b0110011: begin  // R型
                if(funct7_2[0] == 1'b1) begin  // MDU
                    fu_sel2 = FU_MDU;
                    case({funct7_2, funct3_2})
                        {7'b0000001, 3'b000}: ctrl_mdu2 = 4'b0000; // MUL
                        {7'b0000001, 3'b001}: ctrl_mdu2 = 4'b0001; // MULH
                        {7'b0000001, 3'b010}: ctrl_mdu2 = 4'b0010; // MULHSU
                        {7'b0000001, 3'b011}: ctrl_mdu2 = 4'b0011; // MULHU
                        {7'b0000001, 3'b100}: ctrl_mdu2 = 4'b1000; // DIV
                        {7'b0000001, 3'b101}: ctrl_mdu2 = 4'b1001; // DIVU
                        {7'b0000001, 3'b110}: ctrl_mdu2 = 4'b1010; // REM
                        {7'b0000001, 3'b111}: ctrl_mdu2 = 4'b1011; // REMU
                        default: ctrl_mdu2 = 4'b0000;
                    endcase
                end else begin  // ALU
                    fu_sel2 = FU_ALU;
                    case({funct7_2, funct3_2})
                        {7'b0000000, 3'b000}: ctrl_alu2 = 4'b0001; // ADD
                        {7'b0100000, 3'b000}: ctrl_alu2 = 4'b0010; // SUB
                        {7'b0000000, 3'b001}: ctrl_alu2 = 4'b0011; // SLL
                        {7'b0000000, 3'b010}: ctrl_alu2 = 4'b0100; // SLT
                        {7'b0000000, 3'b011}: ctrl_alu2 = 4'b0101; // SLTU
                        {7'b0000000, 3'b100}: ctrl_alu2 = 4'b0110; // XOR
                        {7'b0000000, 3'b101}: ctrl_alu2 = 4'b0111; // SRL
                        {7'b0100000, 3'b101}: ctrl_alu2 = 4'b1000; // SRA
                        {7'b0000000, 3'b110}: ctrl_alu2 = 4'b1001; // OR
                        {7'b0000000, 3'b111}: ctrl_alu2 = 4'b1010; // AND
                        default: ctrl_alu2 = 4'b0000;
                    endcase
                end
            end
            7'b0111011: begin  // R型宽
                if(funct7_2[0] == 1'b1) begin  // MDU宽
                    fu_sel2 = FU_MDU;
                    case({funct7_2, funct3_2})
                        {7'b0000001, 3'b000}: ctrl_mdu2 = 4'b0100; // MULW
                        {7'b0000001, 3'b100}: ctrl_mdu2 = 4'b1100; // DIVW
                        {7'b0000001, 3'b101}: ctrl_mdu2 = 4'b1101; // DIVUW
                        {7'b0000001, 3'b110}: ctrl_mdu2 = 4'b1110; // REMW
                        {7'b0000001, 3'b111}: ctrl_mdu2 = 4'b1111; // REMUW
                        default: ctrl_mdu2 = 4'b0000;
                    endcase
                end else begin  // ALU宽
                    fu_sel2 = FU_ALU;
                    case({funct7_2, funct3_2})
                        {7'b0000000, 3'b000}: ctrl_alu2 = 4'b1011; // ADDW
                        {7'b0100000, 3'b000}: ctrl_alu2 = 4'b1100; // SUBW
                        {7'b0000000, 3'b001}: ctrl_alu2 = 4'b1101; // SLLW
                        {7'b0000000, 3'b101}: ctrl_alu2 = 4'b1110; // SRLW
                        {7'b0100000, 3'b101}: ctrl_alu2 = 4'b1111; // SRAW
                        default: ctrl_alu2 = 4'b0000;
                    endcase
                end
            end
            7'b0010011: begin  // I型
                fu_sel2 = FU_ALU;
                case(funct3_2)
                    3'b000: ctrl_alu2 = 4'b0001; // ADDI
                    3'b010: ctrl_alu2 = 4'b0100; // SLTI
                    3'b011: ctrl_alu2 = 4'b0101; // SLTIU
                    3'b100: ctrl_alu2 = 4'b0110; // XORI
                    3'b110: ctrl_alu2 = 4'b1001; // ORI
                    3'b111: ctrl_alu2 = 4'b1010; // ANDI
                    3'b001: ctrl_alu2 = 4'b0011; // SLLI
                    3'b101: ctrl_alu2 = (funct7_2[5] == 1'b0) ? 4'b0111 : 4'b1000; // SRLI/SRAI
                    default: ctrl_alu2 = 4'b0000;
                endcase
            end
            7'b0011011: begin  // I型宽
                fu_sel2 = FU_ALU;
                case(funct3_2)
                    3'b000: ctrl_alu2 = 4'b1011; // ADDIW
                    3'b001: ctrl_alu2 = 4'b1101; // SLLIW
                    3'b101: ctrl_alu2 = (funct7_2[5] == 1'b0) ? 4'b1110 : 4'b1111; // SRLIW/SRAIW
                    default: ctrl_alu2 = 4'b0000;
                endcase
            end
            7'b1100011: begin  // B格式
                fu_sel2 = FU_BRU;
                case(funct3_2)
                    3'b000: ctrl_bru2 = 3'b000; // BEQ
                    3'b001: ctrl_bru2 = 3'b001; // BNE
                    3'b100: ctrl_bru2 = 3'b100; // BLT
                    3'b101: ctrl_bru2 = 3'b101; // BGE
                    3'b110: ctrl_bru2 = 3'b110; // BLTU
                    3'b111: ctrl_bru2 = 3'b111; // BGEU
                    default: ctrl_bru2 = 3'b000;
                endcase
            end
            7'b1101111: begin  // JAL
                fu_sel2 = FU_BRU;
                ctrl_bru2 = 3'b010;
            end
            7'b1100111: begin  // JALR
                fu_sel2 = FU_BRU;
                ctrl_bru2 = 3'b010;
            end
            7'b0010111: begin  // AUIPC
                fu_sel2 = FU_BRU;
                ctrl_bru2 = 3'b011;
            end
            7'b0000011: begin  // load
                fu_sel2 = FU_LSU;
                case(funct3_2)
                    3'b000: ctrl_lsu2 = 4'b0000; // LB
                    3'b001: ctrl_lsu2 = 4'b0001; // LH
                    3'b010: ctrl_lsu2 = 4'b0010; // LW
                    3'b011: ctrl_lsu2 = 4'b0011; // LD
                    3'b100: ctrl_lsu2 = 4'b0100; // LBU
                    3'b101: ctrl_lsu2 = 4'b0101; // LHU
                    3'b110: ctrl_lsu2 = 4'b0110; // LWU
                    default: ctrl_lsu2 = 4'b0000;
                endcase
            end
            7'b0100011: begin  // store
                fu_sel2 = FU_LSU;
                case(funct3_2)
                    3'b000: ctrl_lsu2 = 4'b1000; // SB
                    3'b001: ctrl_lsu2 = 4'b1001; // SH
                    3'b010: ctrl_lsu2 = 4'b1010; // SW
                    3'b011: ctrl_lsu2 = 4'b1011; // SD
                    default: ctrl_lsu2 = 4'b1000;
                endcase
            end
            7'b0110111: begin  // LUI
                fu_sel2 = FU_ALU;
                ctrl_alu2 = 4'b0000;
            end
            default: begin
                fu_sel2 = FU_ALU;
                ctrl_alu2 = 4'b0000;
            end
        endcase
    end
end

// ==============================================================================
// 7. dec_data输出（送到BOB的数据）- 支持双指令
// ==============================================================================
logic [PC_WIDTH-1:0] dec_data1_int, dec_data2_int;
logic dec_data_valid1_int, dec_data_valid2_int;

always_comb begin
    // 第一条指令的数据
    dec_data1_int = '0;
    dec_data_valid1_int = 1'b0;
    if(inst1_in_valid) begin
        if(is_branch1 || is_jal1) begin
            if(need_calc_addr1) begin
                dec_data1_int = calc_pc1;
                dec_data_valid1_int = 1'b1;
            end
        end
        else if(is_jalr1) begin
            dec_data1_int = calc_imm1;
            dec_data_valid1_int = 1'b1;
        end
        else if(is_auipc1) begin
            dec_data1_int = auipc_result1;
            dec_data_valid1_int = 1'b1;
        end
    end

    // 第二条指令的数据
    dec_data2_int = '0;
    dec_data_valid2_int = 1'b0;
    if(inst2_in_valid) begin
        if(is_branch2 || is_jal2) begin
            if(need_calc_addr2) begin
                dec_data2_int = calc_pc2;
                dec_data_valid2_int = 1'b1;
            end
        end
        else if(is_jalr2) begin
            dec_data2_int = calc_imm2;
            dec_data_valid2_int = 1'b1;
        end
        else if(is_auipc2) begin
            dec_data2_int = auipc_result2;
            dec_data_valid2_int = 1'b1;
        end
    end
end

// 输出赋值（保持向后兼容：原端口对应第一条指令）
assign dec_data_valid = dec_data_valid1_int;
assign dec_data       = dec_data1_int;
assign dec_data_valid2 = dec_data_valid2_int;
assign dec_data2       = dec_data2_int;

// ==============================================================================
// 8. 恢复信号处理（新增恢复向量）
// ==============================================================================
logic recover1_raw, recover2_raw;

always_comb begin
    recover1_raw = 1'b0;
    recover2_raw = 1'b0;
    
    // 指令1恢复条件：分支/JAL预测方向为Taken且BTB未命中
    if(inst1_in_valid && (is_branch1 || is_jal1)) begin
        if(BOB_pred_taken1 && !BOB_btb_hit1) begin
            recover1_raw = 1'b1;
        end
    end
    
    // 指令2恢复条件：分支/JAL预测方向为Taken且BTB未命中
    if(inst2_in_valid && (is_branch2 || is_jal2)) begin
        if(BOB_pred_taken2 && !BOB_btb_hit2) begin
            recover2_raw = 1'b1;
        end
    end
end

// 恢复信号只对最终有效的指令产生（仲裁后）
assign dec_recover_vec = {recover2_raw & inst2_valid, recover1_raw & inst1_valid};
assign dec_recover = |dec_recover_vec;          // 保留原恢复信号，兼容旧接口

// ==============================================================================
// 9. 双指令优先级仲裁
// ==============================================================================
always_comb begin
    // 默认值
    inst1_valid = inst1_in_valid;
    inst2_valid = inst2_in_valid;
    
    // 分支预测错误处理：第一条是分支且需要恢复
    if(inst1_in_valid && (is_branch1 || is_jal1) && 
       BOB_pred_taken1 && !BOB_btb_hit1) begin
        inst1_valid = 1'b1;
        inst2_valid = 1'b0;
    end
    // 第一条是分支且不需要恢复，第二条正常
    else if(inst1_in_valid && (is_branch1 || is_jal1) && 
            !(BOB_pred_taken1 && !BOB_btb_hit1)) begin
        inst1_valid = 1'b1;
        inst2_valid = inst2_in_valid;
    end
    // 第一条不是分支，第二条是分支
    else if(inst1_in_valid && inst2_in_valid && 
            !(is_branch1 || is_jal1) && (is_branch2 || is_jal2)) begin
        if(BOB_pred_taken2 && !BOB_btb_hit2) begin
            // 第二条分支预测错误，清空第二条
            inst1_valid = 1'b1;
            inst2_valid = 1'b1;
        end else begin
            inst1_valid = 1'b1;
            inst2_valid = 1'b1;
        end
    end
    // 其他情况保持默认
end

// ==============================================================================
// 10. 最终输出赋值
// ==============================================================================
assign wen_1 = wen_1_int & inst1_valid;
assign wen_2 = wen_2_int & inst2_valid;

assign rs1_exist1 = rs1_exist1_int & inst1_valid;
assign rs2_exist1 = rs2_exist1_int & inst1_valid;
assign rs1_exist2 = rs1_exist2_int & inst2_valid;
assign rs2_exist2 = rs2_exist2_int & inst2_valid;

assign imm1 = calc_imm1;
assign imm2 = calc_imm2;

assign ctrl_sig_alu1 = ctrl_alu1;
assign ctrl_sig_alu2 = ctrl_alu2;
assign ctrl_sig_mdu1 = ctrl_mdu1;
assign ctrl_sig_mdu2 = ctrl_mdu2;
assign ctrl_sig_bru1 = ctrl_bru1;
assign ctrl_sig_bru2 = ctrl_bru2;
assign ctrl_sig_lsu1 = ctrl_lsu1;
assign ctrl_sig_lsu2 = ctrl_lsu2;

endmodule
