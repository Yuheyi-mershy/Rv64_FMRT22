module select_prf(
    input logic clk,
    input logic reset,

    input logic [5:0] rs1_number_select,
    input logic [63:0] imm_select,
    input logic [5:0] dest_number_select,
    input logic [6:0] rob_id_select,
    input logic [3:0] lsu_control_select,
    input logic reg_write_select,
    input logic instr_valid_select,
    input logic bru_recovery,
    input logic [3:0] grant_select,
    input logic fsm_free,
    input logic sb_full,

    output logic [5:0] rs1_number_prf,
    output logic [63:0] imm_prf,
    output logic [5:0] dest_number_prf,
    output logic [6:0] rob_id_prf,
    output logic [3:0] lsu_control_prf,
    output logic reg_write_prf,
    output logic [3:0] grant_prf,
    output logic instr_valid_prf,
    
    // PRF占用信号输出（供IQ4使用）
    output logic prf_occupied,
    
    // 完成信号
    input logic complete_load,
    input logic complete_store,
    input logic [3:0] grant_load,
    input logic [3:0] grant_store
);

    // 内部寄存器
    logic [5:0] rs1_number_reg;
    logic [63:0] imm_reg;
    logic [5:0] dest_number_reg;
    logic [6:0] rob_id_reg;
    logic [3:0] lsu_control_reg;
    logic reg_write_reg;
    logic [3:0] grant_reg;
    logic valid_reg;
    
    // 边沿检测信号
    logic complete_load_ff, complete_store_ff;
    logic complete_load_pulse, complete_store_pulse;
    
    // Grant更新逻辑
    logic [3:0] grant_next;
    logic complete1, complete2;
    logic [2:0] c1, c2, c3;
    logic [3:0] current_grant;
    logic output_this_cycle;
    
    // 判断是否应该锁存新指令
    // IQ4已经保证了一次只有一条load，所以这里直接接收
    logic load_condition;
    assign load_condition = instr_valid_select && (~lsu_control_select[3]) && 
                            !bru_recovery && !sb_full;
    
    // 判断当前周期是否应该输出指令
    assign output_this_cycle = fsm_free && valid_reg;
    
    // 输出PRF占用信号
    assign prf_occupied = valid_reg;
    
    // 边沿检测，确保完成信号只触发一次
    always_ff @(posedge clk) begin
        if (reset || bru_recovery || sb_full) begin
            complete_load_ff <= 1'b0;
            complete_store_ff <= 1'b0;
        end
        else begin
            complete_load_ff <= complete_load;
            complete_store_ff <= complete_store;
        end
    end
    
    assign complete_load_pulse = complete_load && ~complete_load_ff;
    assign complete_store_pulse = complete_store && ~complete_store_ff;
    
    // 完成信号赋值（使用脉冲信号）
    assign complete1 = complete_load_pulse;
    assign complete2 = complete_store_pulse;
    
    // c1, c2赋值（取低3位）
    assign c1 = grant_load[2:0];
    assign c2 = grant_store[2:0];
    
    // 选择当前有效的grant值用于c3
    // 当有有效指令时使用grant_reg，否则使用grant_select
    assign current_grant = valid_reg ? grant_reg : grant_select;
    assign c3 = current_grant[2:0];
    
    // 根据完成信号和比较结果计算新的grant值
    always_comb begin
        grant_next = grant_reg;
        
        // 情况1: 只有Load完成
        if (complete1 && ~complete2) begin
            if(current_grant[3]) begin
                if (c1 > c3) begin
                    grant_next = grant_reg;
                end
                else begin
                    grant_next = (grant_reg >= 4'd1) ? (grant_reg - 4'd1) : 4'd0;
                end
            end
            else begin
                grant_next = 4'd0;
            end
        end
        // 情况2: 只有Store完成
        else if (~complete1 && complete2) begin
            if(grant_reg[3]) begin
                if (c2 > c3) begin
                    grant_next = grant_reg;
                end
                else begin
                    grant_next = (grant_reg >= 4'd1) ? (grant_reg - 4'd1) : 4'd0;
                end
            end
            else begin
                grant_next = 4'd0;
            end
        end
        // 情况3: Load和Store都完成
        else if (complete1 && complete2) begin
            if (c1 > c2) begin
                if(grant_reg[3]) begin
                    if(c3 > c1) begin                 
                        grant_next = (grant_reg >= 4'd2) ? (grant_reg - 4'd2) : 4'd0;
                    end
                    else if(c3 < c2) begin
                        grant_next = grant_reg;
                    end
                    else begin                        
                        grant_next = (grant_reg >= 4'd1) ? (grant_reg - 4'd1) : 4'd0;
                    end
                end
                else begin
                    grant_next = 4'd0;
                end
            end
            else begin
                if(grant_reg[3]) begin
                    if(c3 > c2) begin
                        grant_next = (grant_reg >= 4'd2) ? (grant_reg - 4'd2) : 4'd0;
                    end
                    else if(c3 < c1) begin
                        grant_next = grant_reg;
                    end
                    else begin
                        grant_next = (grant_reg >= 4'd1) ? (grant_reg - 4'd1) : 4'd0;
                    end
                end
                else begin
                    grant_next = 4'd0;
                end
            end
        end
        else begin
            grant_next = grant_reg;
        end
    end
    
    // 主状态机
    always_ff @(posedge clk) begin
        if (reset || bru_recovery || sb_full) begin
            // 复位或异常
            rs1_number_reg <= 6'b0;
            imm_reg <= 64'd0;
            dest_number_reg <= 6'b0;
            rob_id_reg <= 7'b0;
            lsu_control_reg <= 4'b0;
            reg_write_reg <= 1'b0;
            grant_reg <= 4'b0;
            valid_reg <= 1'b0;
        end
        else begin
            // 优先级1: 新指令到来（IQ4保证了一次只有一条，所以直接覆盖）
            if (load_condition) begin
                rs1_number_reg <= rs1_number_select;
                imm_reg <= imm_select;
                dest_number_reg <= dest_number_select;
                rob_id_reg <= rob_id_select;
                lsu_control_reg <= lsu_control_select;
                reg_write_reg <= reg_write_select;
                grant_reg <= grant_select;
                valid_reg <= 1'b1;
            end
            // 优先级2: 输出指令（立即清除valid）
            else if (output_this_cycle) begin
                valid_reg <= 1'b0;
            end
            // 优先级3: 更新grant（仅在valid有效时）
            else if ((complete1 || complete2) && valid_reg) begin
                grant_reg <= grant_next;
            end
        end
    end
    
    // 输出
    assign rs1_number_prf = rs1_number_reg;
    assign imm_prf = imm_reg;
    assign dest_number_prf = dest_number_reg;
    assign rob_id_prf = rob_id_reg;
    assign lsu_control_prf = lsu_control_reg;
    assign reg_write_prf = reg_write_reg;
    assign grant_prf = grant_reg;
    assign instr_valid_prf = valid_reg && fsm_free;
    
endmodule

