module top_mdu(
    input logic clk,
    input logic reset,
    
    // 来自派遣模块的输入（添加 mdu_ 前缀）
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
    input logic bru_recovery,
    input logic [6:0]bru_rob_id,

    // CDB 总线输入
    input logic [6:0] bus_bru,
    input logic [6:0] bus_lsu,
    input logic [6:0] bus_alu,
    // 唤醒总线输出（添加 mdu_ 前缀）
    output logic [6:0] mdu_mul_bus_wake,
    output logic [6:0] mdu_div_bus_wake,

    // 来自其他执行单元写回阶段的结果（用于转发）
    input logic [5:0] bru_rd_wb,
    input logic [5:0] lsu_rd_wb,
    input logic [5:0] alu_rd_wb,


    // 除法从 PRF 读的值（添加 mdu_ 前缀）
    input logic [63:0] mdu_div_rs1_value,
    input logic [63:0] mdu_div_rs2_value,

    // 乘法从 PRF 读的值（添加 mdu_ 前缀）
    input logic [63:0] mdu_mul_rs1_value,
    input logic [63:0] mdu_mul_rs2_value,
    
    // 来自其他执行单元的结果值（用于转发）
    input logic [63:0] alu_value_wb,
    input logic [63:0] bru_value_wb,
    input logic [63:0] mul_value_wb,
    input logic [63:0] div_value_wb,
    input logic [63:0] lsu_value_wb,
    
    // 源寄存器有效位（添加 mdu_ 前缀）
    input logic mdu_rs1_valid1,
    input logic mdu_rs1_valid2,
    input logic mdu_rs2_valid1,
    input logic mdu_rs2_valid2,
    
    // IQ3 状态输出（添加 mdu_ 前缀）
    output logic mdu_iq3_full,
    
    // 除法 → 输出到 PRF（添加 mdu_ 前缀）
    output logic [5:0] mdu_div_rs1_prf,
    output logic [5:0] mdu_div_rs2_prf,

    // 乘法 → 输出到 PRF（添加 mdu_ 前缀）
    output logic [5:0] mdu_mul_rs1_prf,
    output logic [5:0] mdu_mul_rs2_prf,

    // 除法结果写回（添加 mdu_ 前缀）
    output logic [63:0] mdu_div_result,
    output logic        mdu_div_reg_write,
    output logic [5:0]  mdu_div_rd_number,
    output logic        mdu_div_complete,
    output logic [6:0]  mdu_div_rob_wb,

    // 乘法 WB 阶段输出（写回级）（添加 mdu_ 前缀）
    output logic [5:0]  mdu_mul_rd_wb,
    output logic [6:0]  mdu_mul_rob_wb,
    output logic        mdu_mul_reg_wb,
    output logic [63:0] mdu_mul_result_wb,
    output logic        mdu_mul_complete_wb
);
  
    // ------------------------------
    // 内部信号
    // ------------------------------
    logic [5:0] rs1_number_select;
    logic [5:0] rs2_number_select;
    logic [5:0] rd_number_select;
    logic [6:0] rob_id_select;
    logic [3:0] mdu_control_select;
    logic reg_write_select;
    logic instr_valid_select;
    logic fsm_free;
    
    // 除法 select_prf
    logic [5:0] div_rd_prf;
    logic [6:0] div_rob_prf;
    logic [3:0] div_mdu_ctrl;
    logic       div_reg_wr;
    logic       div_instr_vld;
    logic       div_prf_occupied;
    
    // 乘法 select_prf
    logic [5:0] mul_rd_prf;
    logic [6:0] mul_rob_prf;
    logic [3:0] mul_mdu_ctrl_prf;
    logic       mul_reg_wr_prf;
    logic       mul_instr_vld_prf;
    logic       mul_prf_occupied;

    // 转发控制
    logic [2:0] mul_forward1;
    logic [2:0] mul_forward2;
    
    // 乘法 EX1 内部信号
    logic [5:0]  mul_rs1_ex1;
    logic [5:0]  mul_rs2_ex1;
    logic [5:0]  mul_rd_ex1;
    logic [63:0] mul_rs1_value_ex1;
    logic [63:0] mul_rs2_value_ex1;
    logic [6:0]  mul_rob_id_ex1;
    logic        mul_reg_wr_ex1;
    logic [3:0]  mul_mdu_ctrl_ex1;
    logic        mul_instr_vld_ex1;

    // 乘法运算内部信号
    logic [63:0] op1;
    logic [63:0] op2;
    logic [34:0][127:0] mul_product_ex1;
    logic [7:0][127:0] mul_product_ex1_out;

    // 乘法 EX2 内部信号
    logic [5:0]  mul_rd_ex2;
    logic [6:0]  mul_rob_id_ex2;
    logic        mul_reg_wr_ex2;
    logic [3:0]  mul_mdu_ctrl_ex2;
    logic        mul_instr_vld_ex2;
    logic [34:0][127:0] mul_product_ex2;

    // 乘法 EX3 内部信号
    logic [5:0]  mul_rd_ex3;
    logic [6:0]  mul_rob_id_ex3;
    logic        mul_reg_wr_ex3;
    logic [3:0]  mul_mdu_ctrl_ex3;
    logic        mul_instr_vld_ex3;
    logic [7:0][127:0] mul_product_ex3;
    logic [2:0][127:0] mul_product_32_33_34_ex3;
    
    // 乘法最终结果
    logic [63:0] mul_result_final;
    logic        mul_complete_final;
    
    // ------------------------------
    // IQ3 队列
    // ------------------------------
    iq3 u_iq3 (
        .clk(clk),
        .reset(reset),
        .rob_id1(mdu_rob_id1),
        .rob_id2(mdu_rob_id2),
        .rs1_number1(mdu_rs1_number1),
        .rs2_number1(mdu_rs2_number1),
        .rs1_number2(mdu_rs1_number2),
        .rs2_number2(mdu_rs2_number2),
        .rd_number1(mdu_rd_number1),
        .rd_number2(mdu_rd_number2),
        .mdu_control1(mdu_control1),
        .mdu_control2(mdu_control2),
        .reg_write1(mdu_reg_write1),
        .reg_write2(mdu_reg_write2),
        .instr_valid1(mdu_instr_valid1),
        .instr_valid2(mdu_instr_valid2),
        .bru_recovery(bru_recovery),
        .bru_rob_id(bru_rob_id),
        .bus_bru(bus_bru),
        .bus_lsu(bus_lsu),
        .bus_alu(bus_alu),
        .bus_mul(mdu_mul_bus_wake),
        .bus_div(mdu_div_bus_wake),
        .fsm_free(fsm_free),
        .rs1_valid1(mdu_rs1_valid1),
        .rs1_valid2(mdu_rs1_valid2),
        .rs2_valid1(mdu_rs2_valid1),
        .rs2_valid2(mdu_rs2_valid2),
        .prf_occupied(div_prf_occupied),
        .rs1_number_select(rs1_number_select),
        .rs2_number_select(rs2_number_select),
        .rd_number_select(rd_number_select),
        .rob_id_select(rob_id_select),
        .mdu_control_select(mdu_control_select),
        .reg_write_select(reg_write_select),
        .iq3_full(mdu_iq3_full),
        .instr_valid_select(instr_valid_select)
    );
    
    // ------------------------------
    // 除法专用 select_prf
    // ------------------------------
    select_prf_div u_div_select (
        .clk(clk),
        .reset(reset),
        .rs1_number_select(rs1_number_select),
        .rs2_number_select(rs2_number_select),
        .rd_number_select(rd_number_select),
        .rob_id_select(rob_id_select),
        .mdu_control_select(mdu_control_select),
        .reg_write_select(reg_write_select),
        .instr_valid_select(instr_valid_select),
        .bru_recovery(bru_recovery),
        .bru_rob_id(bru_rob_id),
        .fsm_free(fsm_free),
        .rs1_number_prf(mdu_div_rs1_prf),
        .rs2_number_prf(mdu_div_rs2_prf),
        .rd_number_prf(div_rd_prf),
        .rob_id_prf(div_rob_prf),
        .mdu_control_prf(div_mdu_ctrl),
        .reg_write_prf(div_reg_wr),
        .instr_valid_prf(div_instr_vld),
        .prf_occupied(div_prf_occupied),
        .div_complete(mdu_div_complete)
    );

    // ------------------------------
    // 除法 FSM
    // ------------------------------
    fsm_div u_fsm_div (
        .clk(clk),
        .reset(reset),
        .bru_recovery(bru_recovery),
        .prf_rs1(mdu_div_rs1_prf),
        .prf_rs2(mdu_div_rs2_prf),
        .rd_number(div_rd_prf),
        .rob_id(div_rob_prf),
        .reg_write(div_reg_wr),
        .mdu_control(div_mdu_ctrl),
        .instr_valid(div_instr_vld),
        .alu_rd(bus_alu[5:0]),
        .bru_rd(bus_bru[5:0]),
        .mul_rd(mdu_mul_bus_wake[5:0]),
        .div_rd(mdu_div_bus_wake[5:0]),
        .lsu_rd(bus_lsu[5:0]),
        .rs1_value(mdu_div_rs1_value),
        .rs2_value(mdu_div_rs2_value),
        .alu_value_wb(alu_value_wb),
        .bru_value_wb(bru_value_wb),
        .mul_value_wb(mul_value_wb),
        .div_value_wb(div_value_wb),
        .lsu_value_wb(lsu_value_wb),
        .result_reg(mdu_div_result),
        .reg_write_end(mdu_div_reg_write),
        .rd_number_end(mdu_div_rd_number),
        .complete_end(mdu_div_complete),
        .fsm_free_state_end(fsm_free),
        .rob_id_wb(mdu_div_rob_wb),
        .bus_div_wake(mdu_div_bus_wake)
    );

    // ------------------------------
    // 乘法专用 select_prf
    // ------------------------------
    select_prf_mul u_mul_select (
        .clk(clk),
        .reset(reset),
        .rs1_number_select(rs1_number_select),
        .rs2_number_select(rs2_number_select),
        .rd_number_select(rd_number_select),
        .rob_id_select(rob_id_select),
        .mdu_control_select(mdu_control_select),
        .reg_write_select(reg_write_select),
        .instr_valid_select(instr_valid_select),
        .bru_recovery(bru_recovery),
        .bru_rob_id(bru_rob_id),
        .rs1_number_prf(mdu_mul_rs1_prf),
        .rs2_number_prf(mdu_mul_rs2_prf),
        .rd_number_prf(mul_rd_prf),
        .rob_id_prf(mul_rob_prf),
        .mdu_control_prf(mul_mdu_ctrl_prf),
        .reg_write_prf(mul_reg_wr_prf),
        .instr_valid_prf(mul_instr_vld_prf)
    );

    // ------------------------------
    // 乘法专用 PRF->EX1
    // ------------------------------
    prf_ex1 u_mul_prf_ex1 (
        .clk(clk),
        .reset(reset),
        .mdu_control_prf(mul_mdu_ctrl_prf),
        .reg_write_prf(mul_reg_wr_prf),
        .rs1_number_prf(mdu_mul_rs1_prf),
        .rs2_number_prf(mdu_mul_rs2_prf),
        .rd_number_prf(mul_rd_prf),
        .prf_rs1_value(mdu_mul_rs1_value),
        .prf_rs2_value(mdu_mul_rs2_value),
        .bru_recovery(bru_recovery),
        .bru_rob_id(bru_rob_id),
        .rob_id_prf(mul_rob_prf),
        .instr_valid_prf(mul_instr_vld_prf),
        
        .rs1_number_ex1(mul_rs1_ex1),
        .rs2_number_ex1(mul_rs2_ex1),
        .rd_number_ex1(mul_rd_ex1),
        .ex1_rs1_value(mul_rs1_value_ex1),
        .ex1_rs2_value(mul_rs2_value_ex1),
        .rob_id_ex1(mul_rob_id_ex1),
        .reg_write_ex1(mul_reg_wr_ex1),
        .mdu_control_ex1(mul_mdu_ctrl_ex1),
        .instr_valid_ex1(mul_instr_vld_ex1),
        .bus_mul_wake(mdu_mul_bus_wake)
    );
    
    // ------------------------------
    // 旁路转发 Bypass
    // ------------------------------
   // 实例化BYPASS模块（数据转发控制）
    bypass_mul u_bypass (
        .prf_rs1                (mul_rs1_ex1),
        .prf_rs2                (mul_rs2_ex1),
        .alu_rd                 (alu_rd_wb),
        .bru_rd                 (bru_rd_wb),
        .mul_rd                 (mdu_mul_rd_wb),
        .div_rd                 (mdu_div_rd_number),
        .lsu_rd                 (lsu_rd_wb),
        .reg_write_ex           (mul_reg_wr_ex1),
        .forward1               (mul_forward1),
        .forward2               (mul_forward2)
    );
    
     
    // ------------------------------
    // 数据转发 MUX
    // ------------------------------
    mux6_mul #(64) OP1(
        .a0(mul_rs1_value_ex1),
        .a1(alu_value_wb),
        .a2(bru_value_wb),
        .a3(mul_value_wb),
        .a4(div_value_wb),
        .a5(lsu_value_wb),
        .forward(mul_forward1),
        .b(op1)
    );
    
    mux6_mul #(64) OP2(
        .a0(mul_rs2_value_ex1),
        .a1(alu_value_wb),
        .a2(bru_value_wb),
        .a3(mul_value_wb),
        .a4(div_value_wb),
        .a5(lsu_value_wb),
        .forward(mul_forward2), 
        .b(op2)             
    );
    
    // ------------------------------
    // Booth 乘法器
    // ------------------------------
    booth u_booth_multiplier (
        .A(op1),
        .B(op2),
        .mdu_control_ex1(mul_mdu_ctrl_ex1),
        .product(mul_product_ex1)
    );
    
    // ------------------------------
    // 乘法 EX1 → EX2
    // ------------------------------
    ex1_ex2 u_mul_ex1_ex2 (
        .clk(clk),
        .reset(reset),
        .mdu_control_ex1(mul_mdu_ctrl_ex1),
        .reg_write_ex1(mul_reg_wr_ex1),
        .rd_number_ex1(mul_rd_ex1),
        .product_ex1(mul_product_ex1),
        .bru_recovery(bru_recovery),
        .bru_rob_id(bru_rob_id),
        .rob_id_ex1(mul_rob_id_ex1),
        .instr_valid_ex1(mul_instr_vld_ex1),
        
        .rd_number_ex2(mul_rd_ex2),
        .rob_id_ex2(mul_rob_id_ex2),
        .reg_write_ex2(mul_reg_wr_ex2),
        .mdu_control_ex2(mul_mdu_ctrl_ex2),
        .instr_valid_ex2(mul_instr_vld_ex2),
        .product_ex2(mul_product_ex2)
    );
     
    // ------------------------------
    // 第一次 4-2 压缩
    // ------------------------------
    first_compress compress_one(
        .pp_in_1(mul_product_ex2[31:0]),
        .pp_out_1(mul_product_ex1_out)
    );
    
    // ------------------------------
    // 乘法 EX2 → EX3
    // ------------------------------
    ex2_ex3 u_mul_ex2_ex3 (
        .clk                    (clk),
        .reset                  (reset),
        .mdu_control_ex2        (mul_mdu_ctrl_ex2),
        .reg_write_ex2          (mul_reg_wr_ex2),
        .rd_number_ex2          (mul_rd_ex2),
        .product_ex2            (mul_product_ex1_out),
        .product_32_33_34_ex2   (mul_product_ex2[34:32]),
        .bru_recovery           (bru_recovery),
        .bru_rob_id             (bru_rob_id),
        .rob_id_ex2             (mul_rob_id_ex2),
        .instr_valid_ex2        (mul_instr_vld_ex2),

        .rd_number_ex3          (mul_rd_ex3),
        .rob_id_ex3             (mul_rob_id_ex3),
        .reg_write_ex3          (mul_reg_wr_ex3),
        .mdu_control_ex3        (mul_mdu_ctrl_ex3),
        .instr_valid_ex3        (mul_instr_vld_ex3),
        .product_ex3            (mul_product_ex3),
        .product_32_33_34_ex3   (mul_product_32_33_34_ex3)
    );

    // ------------------------------
    // 第二次压缩 + 最终加法
    // ------------------------------
    second_compress u_second_compress (
        .pp_in_2        (mul_product_ex3),
        .ex3_pp_in      (mul_product_32_33_34_ex3),
        .mdu_control_ex2(mul_mdu_ctrl_ex3),
        .instr_valid_ex3(mul_instr_vld_ex3),
        .result         (mul_result_final),
        .complete_ex3   (mul_complete_final)
    );

    // ------------------------------
    // 乘法 EX3 → WB
    // ------------------------------
    ex3_wb u_mul_ex3_wb (
        .clk            (clk),
        .reset          (reset),
        .reg_write_ex3  (mul_reg_wr_ex3),
        .rd_number_ex3  (mul_rd_ex3),
        .result_ex3     (mul_result_final),
        .bru_recovery   (bru_recovery),
        .bru_rob_id     (bru_rob_id),
        .rob_id_ex3     (mul_rob_id_ex3),
        .complete_ex3   (mul_complete_final),
        .mdu_control_ex3(mul_mdu_ctrl_ex3),

        .rd_number_wb   (mdu_mul_rd_wb),
        .rob_id_wb      (mdu_mul_rob_wb),
        .reg_write_wb   (mdu_mul_reg_wb),
        .result_wb      (mdu_mul_result_wb),
        .complete_wb    (mdu_mul_complete_wb)
    );

endmodule
