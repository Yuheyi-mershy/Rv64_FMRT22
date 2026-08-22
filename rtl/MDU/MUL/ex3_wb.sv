module ex3_wb(
    input  logic        clk,
    input  logic        reset,
    input  logic        reg_write_ex3,          // 寄存器写使能
    input  logic [5:0]  rd_number_ex3,          // RD寄存器编号
    input  logic [63:0] result_ex3,             // 计算结果
    input  logic        bru_recovery,           // 分支恢复信号
    input  logic [6:0]  bru_rob_id,             // 分支ROB ID
    input  logic [6:0]  rob_id_ex3,             // 当前指令ROB ID
    input  logic        complete_ex3,           // 指令完成信号
    input  logic [3:0]  mdu_control_ex3,        // MDU控制信号
    output logic [5:0]  rd_number_wb,           // WB阶段RD编号
    output logic [6:0]  rob_id_wb,              // WB阶段ROB ID
    output logic        reg_write_wb,           // WB阶段寄存器写使能
    output logic [63:0] result_wb,              // WB阶段结果
    output logic        complete_wb             // WB阶段完成信号
);
    
    // 定义冲突处理信号
    logic flush, stall;
    
    // 分支恢复检测模块实例化 - 修正端口连接
    brurecovery_mul bru_re(
        .bru_recovery(bru_recovery),
        .bru_rob_id(bru_rob_id),
        .rob_id(rob_id_ex3),      
        .flush(flush),
        .stall(stall)
    );
    
    // 流水线寄存器：EX3 -> WB
    always_ff @(posedge clk) begin
        if (reset | flush | mdu_control_ex3[3]) begin
            // 复位或冲刷或乘法取消时清零
            rd_number_wb   <= 6'd0;
            rob_id_wb      <= 7'd0;
            reg_write_wb   <= 1'd0;
            result_wb      <= 64'd0;
            complete_wb    <= 1'd0;
        end
        else if (~stall) begin
            // 非阻塞时传递信号
            rd_number_wb   <= rd_number_ex3;
            rob_id_wb      <= rob_id_ex3;
            reg_write_wb   <= reg_write_ex3;
            result_wb      <= result_ex3;
            complete_wb    <= complete_ex3;
        end
        // stall时保持原有值
    end
    
endmodule
