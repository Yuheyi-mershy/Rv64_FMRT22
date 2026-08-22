module select_prf_div(
    input logic clk,
    input logic reset,

    input logic [5:0] rs1_number_select,
    input logic [5:0] rs2_number_select,
    input logic [5:0] rd_number_select,
    input logic [6:0] rob_id_select,
    input logic [3:0] mdu_control_select,
    input logic reg_write_select,
    input logic instr_valid_select,
    input logic bru_recovery,
    input logic [6:0] bru_rob_id,  // 修正为7位
    input logic fsm_free,

    output logic [5:0] rs1_number_prf,
    output logic [5:0] rs2_number_prf,
    output logic [5:0] rd_number_prf,
    output logic [6:0] rob_id_prf,
    output logic [3:0] mdu_control_prf,
    output logic reg_write_prf,
    output logic instr_valid_prf,
    
    // PRF占用信号输出（供IQ3使用）
    output logic prf_occupied,
    
    // 除法完成信号（从状态机来）
    input logic div_complete
);

    // 内部寄存器
    logic [5:0] rs1_number_reg;
    logic [5:0] rs2_number_reg;
    logic [5:0] rd_number_reg;
    logic [6:0] rob_id_reg;
    logic [3:0] mdu_control_reg;
    logic reg_write_reg;
    logic valid_reg;
    
    // 边沿检测信号
    logic div_complete_ff;
    logic div_complete_pulse;
    
    // 分支恢复信号
    logic flush, stall;
    
    // 判断指令类型
    logic is_div_instruction;
    logic load_condition;
    
    assign is_div_instruction = mdu_control_select[3];
    
    // 分支恢复检测模块实例化
    brurecovery_mul bru_re(
        .bru_recovery(bru_recovery),
        .bru_rob_id(bru_rob_id),
        .rob_id(rob_id_reg),  // 注意：端口名应该是fu_rob_id，不是rob_id
        .flush(flush),
        .stall(stall)
    );
    
    // 锁存条件：只有在非分支恢复且非停顿状态下才能接收新指令
    assign load_condition = instr_valid_select && !bru_recovery && !stall;
    
    // 输出PRF占用信号
    assign prf_occupied = valid_reg;
    
    // 边沿检测，确保完成信号只触发一次
    always_ff @(posedge clk) begin
        if (reset || bru_recovery) begin
            div_complete_ff <= 1'b0;
        end
        else begin
            div_complete_ff <= div_complete;
        end
    end
    
    assign div_complete_pulse = div_complete && ~div_complete_ff;
    
    // 主状态机
    always_ff @(posedge clk) begin
        if (reset) begin
            // 复位时清零
            rs1_number_reg <= 6'b0;
            rs2_number_reg <= 6'b0;
            rd_number_reg <= 6'b0;
            rob_id_reg <= 7'b0;
            mdu_control_reg <= 4'b0;
            reg_write_reg <= 1'b0;
            valid_reg <= 1'b0;
        end
        else if (flush) begin
            // 分支刷新：清除当前槽内的指令（错误路径）
            rs1_number_reg <= 6'b0;
            rs2_number_reg <= 6'b0;
            rd_number_reg <= 6'b0;
            rob_id_reg <= 7'b0;
            mdu_control_reg <= 4'b0;
            reg_write_reg <= 1'b0;
            valid_reg <= 1'b0;
        end
        else if (~stall) begin
            // 非停顿状态：可以接收新指令
            if (load_condition) begin
                rs1_number_reg <= rs1_number_select;
                rs2_number_reg <= rs2_number_select;
                rd_number_reg <= rd_number_select;
                rob_id_reg <= rob_id_select;
                mdu_control_reg <= mdu_control_select;
                reg_write_reg <= reg_write_select;
                valid_reg <= 1'b1;
            end
            // 输出指令后清除valid（发射时清除）
            else if (fsm_free && valid_reg) begin
                if (mdu_control_reg[3]) begin  // DIV指令
                    if (div_complete_pulse) begin
                        valid_reg <= 1'b0;
                    end
                end
                else begin  // MUL指令
                    valid_reg <= 1'b0;
                end
            end
        end
        // stall状态：保持当前值，不接收新指令
    end
    
    // 输出
    assign rs1_number_prf = rs1_number_reg;
    assign rs2_number_prf = rs2_number_reg;
    assign rd_number_prf = rd_number_reg;
    assign rob_id_prf = rob_id_reg;
    assign mdu_control_prf = mdu_control_reg;
    assign reg_write_prf = reg_write_reg;
    assign instr_valid_prf = valid_reg && fsm_free && ~flush && ~stall;
    
endmodule
