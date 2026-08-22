/******************************************************************************
 * Filename: pipeline_reg_vr.sv
 * Author: FMRT22-HYC
 * Create date: 2026.03.30
 * Description: 双发射通用流水线寄存器，支持 valid-ready 握手协议
 *              自带 flush(清空)、stall(暂停) 功能
 ***************************************************************************/
module pipeline_reg #(
    parameter DATA_WID = 128  // 数据位宽可配置
)(
    // 时钟复位
    input  logic                 clk,
    input  logic                 reset,
    
    // 流水线控制信号
    input  logic                 flush,      // 高电平冲刷：valid 置0
    input  logic                 stall,      // 高电平暂停：寄存器保持不变
    
    // ==================== 上游输入端口（valid-ready）====================
    input  logic                 valid_i1,   // 槽1 输入有效
    input  logic [DATA_WID-1:0]  data_i1,    // 槽1 数据
    
    input  logic                 valid_i2,   // 槽2 输入有效
    input  logic [DATA_WID-1:0]  data_i2,    // 槽2 数据
    
    output logic                 ready_o,    // 向上游反馈：本级可以接收数据
    
    // ==================== 下游输出端口（valid-ready）====================
    output logic                 valid_o1,   // 槽1 输出有效
    output logic [DATA_WID-1:0]  data_o1,    // 槽1 数据
    
    output logic                 valid_o2,   // 槽2 输出有效
    output logic [DATA_WID-1:0]  data_o2,    // 槽2 数据
    
    input  logic                 ready_i     // 来自下游：下游可以接收数据
);

// ==================== 核心握手逻辑 ====================
// 本级寄存器可以接收新数据的条件：未暂停 + 下游可以接收
assign ready_o = ~stall & ready_i;

// ==================== 时序逻辑：寄存器打拍 ====================
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        valid_o1 <= 1'b0;
        data_o1  <= '0;
        valid_o2 <= 1'b0;
        data_o2  <= '0;
    end else begin
        if (flush) begin
            // 冲刷：所有指令置无效
            valid_o1 <= 1'b0;
            data_o1  <= '0;
            valid_o2 <= 1'b0;
            data_o2  <= '0;
        end else if (~stall) begin
            // 未暂停时：只有握手成功（本级ready=1）才更新数据
            if (ready_o) begin
                valid_o1 <= valid_i1;
                data_o1  <= data_i1;
                valid_o2 <= valid_i2;
                data_o2  <= data_i2;
            end
            // 未握手成功：保持原有输出不变
        end
        // stall=1 时完全保持所有输出不变
    end
end

endmodule