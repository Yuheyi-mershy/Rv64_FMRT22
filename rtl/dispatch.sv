/******************************************************************************
 * Filename: dispatch.sv
 * Author: FMRT22-HYC
 * Create date: 2026.03.30
 * Description: Dispatch instructions to different FUs (pure combinational)
 ***************************************************************************/
module dispatch (
    // 时钟与复位（保留但未使用，组合逻辑不需要）
    input  logic        clk,
    input  logic        reset,
    
    // 来自解码/重命名阶段的两条指令
    input  logic        dispatch_valid_i1,
    input  inst_packet_t dispatch_inst_i1,
    input  logic        dispatch_valid_i2,
    input  inst_packet_t dispatch_inst_i2,
    
    // 各功能单元指令队列（IQ）满标志
    input  logic        iq_alu_full_i,
    input  logic        iq_mdu_full_i,
    input  logic        iq_bru_full_i,
    input  logic        iq_lsu_full_i,
    
    // 输出：向 ALU 流水线发送的指令
    output logic        alu_pipe_valid_o0,
    output inst_packet_t alu_pipe_inst_o0,
    output logic        alu_pipe_valid_o1,
    output inst_packet_t alu_pipe_inst_o1,
    
    // 输出：向 MDU 流水线发送的指令
    output logic        mdu_pipe_valid_o0,
    output inst_packet_t mdu_pipe_inst_o0,
    output logic        mdu_pipe_valid_o1,
    output inst_packet_t mdu_pipe_inst_o1,
    
    // 输出：向 BRU 流水线发送的指令
    output logic        bru_pipe_valid_o0,
    output inst_packet_t bru_pipe_inst_o0,
    output logic        bru_pipe_valid_o1,
    output inst_packet_t bru_pipe_inst_o1,
    
    // 输出：向 LSU 流水线发送的指令
    output logic        lsu_pipe_valid_o0,
    output inst_packet_t lsu_pipe_inst_o0,
    output logic        lsu_pipe_valid_o1,
    output inst_packet_t lsu_pipe_inst_o1,
    
    // 输出：分发暂停信号
    output logic        dispatch_stall_o
);

// ==================== 内部信号定义 ====================
logic [1:0] target_fu1, target_fu2;
logic can_dispatch1, can_dispatch2;
logic all_can_dispatch;

// ==================== 组合逻辑：判断每条指令能否分发 ====================
always_comb begin
    can_dispatch1 = 1'b0;
    target_fu1    = 2'b00;
    if (dispatch_valid_i1) begin
        case (dispatch_inst_i1.fu_select)
            4'b1000: begin target_fu1 = 2'b00; can_dispatch1 = ~iq_alu_full_i; end
            4'b0100: begin target_fu1 = 2'b01; can_dispatch1 = ~iq_mdu_full_i; end
            4'b0010: begin target_fu1 = 2'b10; can_dispatch1 = ~iq_bru_full_i; end
            4'b0001: begin target_fu1 = 2'b11; can_dispatch1 = ~iq_lsu_full_i; end
            default: can_dispatch1 = 1'b0;
        endcase
    end

    can_dispatch2 = 1'b0;
    target_fu2    = 2'b00;
    if (dispatch_valid_i2) begin
        case (dispatch_inst_i2.fu_select)
            4'b1000: begin target_fu2 = 2'b00; can_dispatch2 = ~iq_alu_full_i; end
            4'b0100: begin target_fu2 = 2'b01; can_dispatch2 = ~iq_mdu_full_i; end
            4'b0010: begin target_fu2 = 2'b10; can_dispatch2 = ~iq_bru_full_i; end
            4'b0001: begin target_fu2 = 2'b11; can_dispatch2 = ~iq_lsu_full_i; end
            default: can_dispatch2 = 1'b0;
        endcase
    end
end

// ==================== 原子分发逻辑 ====================
always_comb begin
    all_can_dispatch = 1'b1;
    if (dispatch_valid_i1 && !can_dispatch1) all_can_dispatch = 1'b0;
    if (dispatch_valid_i2 && !can_dispatch2) all_can_dispatch = 1'b0;
end

assign dispatch_stall_o = ~all_can_dispatch;

// ==================== ALU 分发通道（纯组合） ====================
always_comb begin
    alu_pipe_valid_o0 = 1'b0;
    alu_pipe_valid_o1 = 1'b0;
    alu_pipe_inst_o0 = '0;
    alu_pipe_inst_o1 = '0;

    if (all_can_dispatch) begin
        if (dispatch_valid_i1 && target_fu1 == 2'b00) begin
            alu_pipe_valid_o0 = 1'b1;
            alu_pipe_inst_o0 = dispatch_inst_i1;
            if (dispatch_valid_i2 && target_fu2 == 2'b00) begin
                alu_pipe_valid_o1 = 1'b1;
                alu_pipe_inst_o1 = dispatch_inst_i2;
            end
        end else if (dispatch_valid_i2 && target_fu2 == 2'b00) begin
            alu_pipe_valid_o1 = 1'b1;
            alu_pipe_inst_o1 = dispatch_inst_i2;
        end
    end
end

// ==================== MDU 分发通道 ====================
always_comb begin
    mdu_pipe_valid_o0 = 1'b0;
    mdu_pipe_valid_o1 = 1'b0;
    mdu_pipe_inst_o0 = '0;
    mdu_pipe_inst_o1 = '0;

    if (all_can_dispatch) begin
        if (dispatch_valid_i1 && target_fu1 == 2'b01) begin
            mdu_pipe_valid_o0 = 1'b1;
            mdu_pipe_inst_o0 = dispatch_inst_i1;
            if (dispatch_valid_i2 && target_fu2 == 2'b01) begin
                mdu_pipe_valid_o1 = 1'b1;
                mdu_pipe_inst_o1 = dispatch_inst_i2;
            end
        end else if (dispatch_valid_i2 && target_fu2 == 2'b01) begin
            mdu_pipe_valid_o1 = 1'b1;
            mdu_pipe_inst_o1 = dispatch_inst_i2;
        end
    end
end

// ==================== BRU 分发通道 ====================
always_comb begin
    bru_pipe_valid_o0 = 1'b0;
    bru_pipe_valid_o1 = 1'b0;
    bru_pipe_inst_o0 = '0;
    bru_pipe_inst_o1 = '0;

    if (all_can_dispatch) begin
        if (dispatch_valid_i1 && target_fu1 == 2'b10) begin
            bru_pipe_valid_o0 = 1'b1;
            bru_pipe_inst_o0 = dispatch_inst_i1;
            if (dispatch_valid_i2 && target_fu2 == 2'b10) begin
                bru_pipe_valid_o1 = 1'b1;
                bru_pipe_inst_o1 = dispatch_inst_i2;
            end
        end else if (dispatch_valid_i2 && target_fu2 == 2'b10) begin
            bru_pipe_valid_o1 = 1'b1;
            bru_pipe_inst_o1 = dispatch_inst_i2;
        end
    end
end

// ==================== LSU 分发通道 ====================
always_comb begin
    lsu_pipe_valid_o0 = 1'b0;
    lsu_pipe_valid_o1 = 1'b0;
    lsu_pipe_inst_o0 = '0;
    lsu_pipe_inst_o1 = '0;

    if (all_can_dispatch) begin
        if (dispatch_valid_i1 && target_fu1 == 2'b11) begin
            lsu_pipe_valid_o0 = 1'b1;
            lsu_pipe_inst_o0 = dispatch_inst_i1;
            if (dispatch_valid_i2 && target_fu2 == 2'b11) begin
                lsu_pipe_valid_o1 = 1'b1;
                lsu_pipe_inst_o1 = dispatch_inst_i2;
            end
        end else if (dispatch_valid_i2 && target_fu2 == 2'b11) begin
            lsu_pipe_valid_o1 = 1'b1;
            lsu_pipe_inst_o1 = dispatch_inst_i2;
        end
    end
end

endmodule
