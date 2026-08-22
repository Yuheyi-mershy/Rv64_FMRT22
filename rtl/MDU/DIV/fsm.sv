module fsm_div(
    //时序控制的信号
    input logic clk,
    input logic reset,
    
    //用于分支错误信号恢复
    input logic bru_recovery,  

    //从select_prf槽过来的信息
    input logic [5:0] prf_rs1,
    input logic [5:0] prf_rs2,
    input logic [5:0] rd_number, 
    input logic reg_write,       
    input logic [3:0] mdu_control,
    input logic instr_valid,
    input logic [6:0] rob_id,
    
    //用于转发的物理寄存器
    input logic [5:0] alu_rd,
    input logic [5:0] bru_rd,
    input logic [5:0] mul_rd,
    input logic [5:0] div_rd,
    input logic [5:0] lsu_rd,
    
    //用于转发的数据来源
    input logic [63:0] rs1_value, 
    input logic [63:0] rs2_value,   
    input logic [63:0] alu_value_wb, 
    input logic [63:0] bru_value_wb,
    input logic [63:0] mul_value_wb,
    input logic [63:0] div_value_wb,
    input logic [63:0] lsu_value_wb,
    
    //输出信号
    output logic [63:0] result_reg,
    output logic        reg_write_end,   
    output logic [5:0]  rd_number_end, 
    output logic complete_end,  
    output logic fsm_free_state_end,
    output logic [6:0] rob_id_wb,
    output logic [6:0] bus_div_wake  // 7位：{valid, rd[5:0]}
);
    
    // 内部信号
    logic [2:0] forward1, forward2;
    logic [2:0] current_state;
    logic [2:0] next_state;
    logic [63:0] op1, op2;
    logic [63:0] op1_reg, op2_reg;
    logic [63:0] result_ex;
    logic fsm_free_state;
    logic instr_valid_end;
    logic div_32, div_32_end;
    logic div_64;
    logic sign;
    logic [3:0] control_reg;
    logic [3:0] mdu_control_end;
    logic complete;
    
    // 除法专用信号
    logic [63:0] dividend;        // 被除数（绝对值）
    logic [63:0] divisor;         // 除数（绝对值）
    logic [31:0] dividend_32, divisor_32;
    logic [31:0] dividend_reg1, divisor_reg1;
    logic [63:0] dividend_reg2, divisor_reg2;
    
    // 迭代计数器
    logic [5:0] count_out1, count_in1;
    logic [6:0] count_out2, count_in2;
    
    // 数据寄存器
    logic [63:0] data_in1, data_out1;
    logic [127:0] data_in2, data_out2;
    
    // 临时结果
    logic [64:0] result_temp_1, result_temp_temp_1;
    logic [128:0] result_temp_2, result_temp_temp_2;
    
    // 32位除法信号
    logic [31:0] A_part, Q_part;
    logic [31:0] A_shifted;
    logic [31:0] A_after_operation;
    
    // 64位除法信号
    logic [63:0] B_part, Q_part_2;
    logic [63:0] B_shifted;
    logic [63:0] B_after_operation;
    
    // 新增：用于存储移位后的值
    logic [31:0] Q_shifted;
    logic [63:0] Q_shifted_2;
    
    // 商和余数的最后变量
    logic [31:0] final_remainder, final_remainder_temp;
    logic [31:0] final_quotient, final_quotient_temp;
    logic [63:0] final_remainder_64, final_remainder_64_temp;
    logic [63:0] final_quotient_64, final_quotient_64_temp;
    logic [31:0] final_remainder_32_temp;
    
    // 符号位
    logic Q_32_sign, Q_64_sign, REM_32_sign, REM_64_sign;
    logic op1_sign, op2_sign;
    
    // 异常判断信号
    logic flag_32, flag_64;
    logic MIN_32, MIN_64;
    logic divisor_32_flag, divisor_64_flag;
    logic ZERO_32, ZERO_64;
    logic exception_32, exception_64;
    
    // 新增：保存从select_prf过来的信息
    logic [5:0] rd_number_reg;
    logic reg_write_reg;
    
    // 指令类型判断
    assign div_32 = ((mdu_control == 4'b1100) || (mdu_control == 4'b1101) || 
                     (mdu_control == 4'b1110) || (mdu_control == 4'b1111)) ? 1'b1 : 1'b0;
    assign div_64 = ~div_32;
    
    // 操作数符号
    assign op1_sign = (div_32) ? op1[31] : op1[63];
    assign op2_sign = (div_32) ? op2[31] : op2[63];
    
    // 符号位计算
    assign Q_64_sign = op1[63] ^ op2[63];
    assign Q_32_sign = op1[31] ^ op2[31];
    assign REM_64_sign = op1[63];
    assign REM_32_sign = op1[31];
    
    // 绝对值处理
    assign dividend = sign ? ((op1[63] == 1'b1) ? (~op1 + 64'd1) : op1) : op1;
    assign divisor = sign ? ((op2[63] == 1'b1) ? (~op2 + 64'd1) : op2) : op2;
    assign dividend_32 = sign ? ((op1[31] == 1'b1) ? (~op1[31:0] + 32'd1) : op1[31:0]) : op1[31:0];
    assign divisor_32 = sign ? ((op2[31] == 1'b1) ? (~op2[31:0] + 32'd1) : op2[31:0]) : op2[31:0];

    // 分离寄存器-32
    assign A_part = data_out1[63:32];
    assign Q_part = data_out1[31:0];
    assign A_shifted = {A_part[30:0], Q_part[31]};
    
    // 分离寄存器-64
    assign B_part = data_out2[127:64];
    assign Q_part_2 = data_out2[63:0];
    assign B_shifted = {B_part[62:0], Q_part_2[63]};
    
    // -------------------------- 转发逻辑 ------------------------------------
    // 产生 forward1 信号
    always_comb begin
        forward1 = 3'b000;
        if((prf_rs1 == alu_rd) && (alu_rd != 6'd0) && reg_write_reg) begin
            forward1 = 3'b001;  // 从ALU转发
        end
        else if((prf_rs1 == bru_rd) && (bru_rd != 6'd0) && reg_write_reg) begin
            forward1 = 3'b010;  // 从BRU转发
        end
        else if((prf_rs1 == mul_rd) && (mul_rd != 6'd0) && reg_write_reg) begin
            forward1 = 3'b011;  // 从MUL转发
        end
        else if((prf_rs1 == div_rd) && (div_rd != 6'd0) && reg_write_reg) begin
            forward1 = 3'b100;  // 从DIV转发
        end
        else if((prf_rs1 == lsu_rd) && (lsu_rd != 6'd0) && reg_write_reg) begin
            forward1 = 3'b101;  // 从LSU转发
        end
        else begin
            forward1 = 3'b000;  // 不转发，使用原始值
        end
    end
    
    // 产生 forward2 信号
    always_comb begin
        forward2 = 3'b000;
        if((prf_rs2 == alu_rd) && (alu_rd != 6'd0) && reg_write_reg) begin
            forward2 = 3'b001;
        end
        else if((prf_rs2 == bru_rd) && (bru_rd != 6'd0) && reg_write_reg) begin
            forward2 = 3'b010;  
        end
        else if((prf_rs2 == mul_rd) && (mul_rd != 6'd0) && reg_write_reg) begin
            forward2 = 3'b011;
        end
        else if((prf_rs2 == div_rd) && (div_rd != 6'd0) && reg_write_reg) begin
            forward2 = 3'b100;  
        end
        else if((prf_rs2 == lsu_rd) && (lsu_rd != 6'd0) && reg_write_reg) begin
            forward2 = 3'b101;
        end
        else begin
            forward2 = 3'b000;
        end
    end
    
    // -------------------------- 状态寄存器 ------------------------------------
    always_ff @(posedge clk) begin
        if(reset) begin
            current_state <= 3'b000;
            fsm_free_state_end <= 1'b0;
            instr_valid_end <= 1'b0;
            div_32_end <= 1'b0;
            mdu_control_end <= 4'd0;
            op1_reg <= 64'd0;
            rob_id_wb<=7'd0;
            op2_reg <= 64'd0;
            count_out1 <= 6'd0;
            count_out2 <= 7'd0;
            data_out1 <= 64'd0;
            data_out2 <= 128'd0;
            divisor_reg1 <= 32'd0;
            divisor_reg2 <= 64'd0;
            dividend_reg1 <= 32'd0;
            dividend_reg2 <= 64'd0;
            control_reg <= 4'd0;
            result_temp_temp_1 <= 65'd0;
            result_temp_temp_2 <= 129'd0;
            result_reg <= 64'd0;
            reg_write_end <= 1'b0;
            complete_end <= 1'b0;
            rd_number_reg <= 6'd0;
            reg_write_reg <= 1'b0;
            rd_number_end <= 6'd0;
        end
        else begin
            current_state <= next_state;
            fsm_free_state_end <= fsm_free_state;
            complete_end <= complete & instr_valid_end;
            
            // 只在IDLE状态且有效指令时，保存从select_prf过来的信息
            if((current_state == 3'b000) && mdu_control[3] && instr_valid) begin
                op1_reg <= op1;
                op2_reg <= op2;
                control_reg <= mdu_control;
                divisor_reg1 <= divisor_32;
                divisor_reg2 <= divisor;
                dividend_reg1 <= dividend_32;
                dividend_reg2 <= dividend;
                instr_valid_end <= instr_valid;
                div_32_end <= div_32;
                mdu_control_end <= mdu_control;
                rob_id_wb<=rob_id;
                
                // 保存从select_prf槽过来的信息
                rd_number_reg <= rd_number;
                reg_write_reg <= reg_write;
            end
            
            // 更新计数器
            count_out1 <= count_in1;
            count_out2 <= count_in2;
            
            // 更新数据寄存器
            data_out1 <= data_in1;
            data_out2 <= data_in2;
            
            // 更新临时结果
            result_temp_temp_1 <= result_temp_1;
            result_temp_temp_2 <= result_temp_2;
            
            // 更新结果寄存器
            result_reg <= result_ex;
            reg_write_end <= reg_write_reg & instr_valid_end;
            rd_number_end <= rd_number_reg;
        end
    end
    
    // -------------------------- 唤醒总线输出（你要的功能！）-------------------------
    // 只有 有效指令 + 真正完成 时，才唤醒总线
    assign bus_div_wake = (complete_end & reg_write_end) ? {1'b1, rd_number_end} : 7'd0;
    
    // -------------------------- 状态机组合逻辑 --------------------------
    always_comb begin
        // 默认值
        next_state = current_state;
        fsm_free_state = 1'b0;
        complete = 1'b0;
        result_ex = 64'd0;
        data_in1 = data_out1;
        data_in2 = data_out2;
        count_in1 = count_out1;
        count_in2 = count_out2;
        result_temp_1 = result_temp_temp_1;
        result_temp_2 = result_temp_temp_2;
        sign = ((control_reg == 4'b1000) || (control_reg == 4'b1100) || 
                (control_reg == 4'b1010) || (control_reg == 4'b1110));
        
        // 计算 Q_shifted 和 Q_shifted_2
        Q_shifted = {Q_part[30:0], 1'b0};
        Q_shifted_2 = {Q_part_2[62:0], 1'b0};
        
        case(current_state)
            //==========================================
            // 000: IDLE - 空闲状态
            //==========================================
            3'b000: begin
                if(bru_recovery) begin
                    next_state = 3'b000;
                    fsm_free_state = 1'b1;
                end
                else if(mdu_control[3] && instr_valid) begin
                    next_state = 3'b001;
                    fsm_free_state = 1'b0;
                     case(forward1)
                        3'b000: op1 = rs1_value;       // 原始值
                        3'b001: op1 = alu_value_wb;    // ALU写回值
                        3'b010: op1 = bru_value_wb;    // BRU写回值
                        3'b011: op1 = mul_value_wb;    // MUL写回值
                        3'b100: op1 = div_value_wb;    // DIV写回值
                        3'b101: op1 = lsu_value_wb;    // LSU写回值
                        default: op1 = rs1_value;      // 默认值
                    endcase
                    case(forward2)
                        3'b000: op2 = rs2_value;       // 原始值
                        3'b001: op2 = alu_value_wb;    // ALU写回值
                        3'b010: op2 = bru_value_wb;    // BRU写回值
                        3'b011: op2 = mul_value_wb;    // MUL写回值
                        3'b100: op2 = div_value_wb;    // DIV写回值
                        3'b101: op2 = lsu_value_wb;    // LSU写回值
                        default: op2 = rs2_value;      // 默认值    
                    endcase
                end
                else begin
                    next_state = 3'b000;
                    fsm_free_state = 1'b1;
                end
            end
            
            //==========================================
            // 001: RESET - 初始化状态
            //==========================================
            3'b001: begin
                if(bru_recovery) begin
                    next_state = 3'b000;
                    fsm_free_state = 1'b1;
                end
                else if(div_32_end) begin
                    data_in1 = {32'd0, dividend_reg1};
                    count_in1 = 6'd32;
                    next_state = 3'b100;
                    fsm_free_state = 1'b0;
                end
                else begin
                    data_in2 = {64'd0, dividend_reg2};
                    count_in2 = 7'd64;
                    next_state = 3'b010;
                    fsm_free_state = 1'b0;
                end
            end
            
            //==========================================
            // 100: DIV_32 - 32位除法迭代
            //==========================================
            3'b100: begin
                if(bru_recovery) begin
                    next_state = 3'b000;
                    fsm_free_state = 1'b1;
                end
                else begin
                    // 第一次迭代时检查异常
                    if(count_out1 == 6'd32) begin
                        flag_32 = (32'hffffffff == divisor_reg1);
                        MIN_32 = (32'h80000000 == dividend_reg1);
                        divisor_32_flag = (32'd1 == divisor_reg1);
                        ZERO_32 = (32'd0 == divisor_reg1);
                        exception_32 = (sign) ? (ZERO_32 | (MIN_32 & flag_32)) : ZERO_32;
                        
                        if(exception_32) begin
                            case(control_reg)
                                4'b1100: result_ex = (ZERO_32) ? 64'hffffffffffffffff : 64'hffffffff80000000;
                                4'b1101: result_ex = 64'h00000000FFFFFFFF;
                                4'b1110: result_ex = (ZERO_32) ? {{33{dividend_reg1[31]}}, dividend_reg1} : 64'd0;
                                4'b1111: result_ex = {{32{1'b0}}, dividend_reg1};
                                default: result_ex = 64'd0;
                            endcase
                            next_state = 3'b000;
                            fsm_free_state = 1'b1;
                            complete = 1'b1;
                        end
                        else if(divisor_32_flag) begin
                            case(control_reg)
                                4'b1100: result_ex = {{32{dividend_reg1[31]}}, dividend_reg1};
                                4'b1101: result_ex = {{32{1'b0}}, dividend_reg1};
                                4'b1110: result_ex = 64'd0;
                                4'b1111: result_ex = 64'd0;
                                default: result_ex = 64'd0;
                            endcase
                            next_state = 3'b000;
                            fsm_free_state = 1'b1;
                            complete = 1'b1;
                        end
                        else begin
                            // 正常除法迭代
                            if (A_shifted[31] == 1'b0) begin
                                A_after_operation = A_shifted - divisor_reg1;
                            end 
                            else begin
                                A_after_operation = A_shifted + divisor_reg1;
                            end
                            
                            // 设置 Q_shifted 的最低位
                            Q_shifted[0] = (A_after_operation[31] == 1'b0) ? 1'b1 : 1'b0;
                            
                            data_in1 = {A_after_operation, Q_shifted};
                            count_in1 = count_out1 - 6'd1;
                            next_state = 3'b100;
                            fsm_free_state = 1'b0;
                        end
                    end
                    else begin
                        // 正常除法迭代
                        if (A_shifted[31] == 1'b0) begin
                            A_after_operation = A_shifted - divisor_reg1;
                        end 
                        else begin
                            A_after_operation = A_shifted + divisor_reg1;
                        end
                        
                        // 设置 Q_shifted 的最低位
                        Q_shifted[0] = (A_after_operation[31] == 1'b0) ? 1'b1 : 1'b0;
                        
                        data_in1 = {A_after_operation, Q_shifted};
                        count_in1 = count_out1 - 6'd1;
                        
                        if(count_in1 == 6'd0) begin
                            next_state = 3'b011;
                            fsm_free_state = 1'b0;
                            result_temp_1 = {data_in1, data_in1[63]};
                            complete = 1'b0;
                        end
                        else begin
                            next_state = 3'b100;
                            fsm_free_state = 1'b0;
                        end
                    end
                end
            end
            
            //==========================================
            // 010: DIV_64 - 64位除法迭代
            //==========================================
            3'b010: begin
                if(bru_recovery) begin
                    next_state = 3'b000;
                    fsm_free_state = 1'b1;   
                end
                else begin
                    // 第一次迭代时检查异常
                    if(count_out2 == 7'd64) begin
                        flag_64 = (64'hffffffffffffffff == divisor_reg2);
                        MIN_64 = (64'h8000000000000000 == dividend_reg2);
                        divisor_64_flag = (64'd1 == divisor_reg2);
                        ZERO_64 = (64'd0 == divisor_reg2);
                        exception_64 = (sign) ? (ZERO_64 | (MIN_64 & flag_64)) : ZERO_64;
                        
                        if(exception_64) begin
                            case(control_reg)
                                4'b1000: result_ex = (ZERO_64) ? 64'hffffffffffffffff : 64'h8000000000000000;
                                4'b1001: result_ex = 64'hffffffffffffffff;
                                4'b1010: result_ex = (ZERO_64) ? dividend_reg2 : 64'd0;
                                4'b1011: result_ex = dividend_reg2;
                                default: result_ex = 64'd0;
                            endcase
                            next_state = 3'b000;
                            fsm_free_state = 1'b1;
                            complete = 1'b1;
                        end
                        else if(divisor_64_flag) begin
                            case(control_reg)
                                4'b1000: result_ex = dividend_reg2;
                                4'b1001: result_ex = dividend_reg2;
                                4'b1010: result_ex = 64'd0;
                                4'b1011: result_ex = 64'd0;
                                default: result_ex = 64'd0;
                            endcase
                            next_state = 3'b000;
                            fsm_free_state = 1'b1;
                            complete = 1'b1;
                        end
                        else begin
                            // 正常除法迭代
                            if (B_shifted[63] == 1'b0) begin
                                B_after_operation = B_shifted - divisor_reg2;
                            end 
                            else begin
                                B_after_operation = B_shifted + divisor_reg2;
                            end
                            
                            // 设置 Q_shifted_2 的最低位
                            Q_shifted_2[0] = (B_after_operation[63] == 1'b0) ? 1'b1 : 1'b0;
                            
                            data_in2 = {B_after_operation, Q_shifted_2};
                            count_in2 = count_out2 - 7'd1;
                            next_state = 3'b010;
                            fsm_free_state = 1'b0;
                        end
                    end
                    else begin
                        // 正常除法迭代
                        if (B_shifted[63] == 1'b0) begin
                            B_after_operation = B_shifted - divisor_reg2;
                        end 
                        else begin
                            B_after_operation = B_shifted + divisor_reg2;
                        end
                        
                        // 设置 Q_shifted_2 的最低位
                        Q_shifted_2[0] = (B_after_operation[63] == 1'b0) ? 1'b1 : 1'b0;
                        
                        data_in2 = {B_after_operation, Q_shifted_2};
                        count_in2 = count_out2 - 7'd1;
                        
                        if(count_in2 == 7'd0) begin
                            next_state = 3'b011;
                            fsm_free_state = 1'b0;
                            result_temp_2 = {data_in2, data_in2[127]};
                            complete = 1'b0;
                        end
                        else begin
                            next_state = 3'b010;
                            fsm_free_state = 1'b0;
                        end
                    end
                end
            end

            //==========================================
            // 011: CORRECT - 符号修正
            //==========================================
            3'b011: begin
                if(bru_recovery) begin
                    next_state = 3'b000;
                    fsm_free_state = 1'b1;
                end
                else begin
                    final_remainder_temp = (result_temp_temp_1[64]) ? (A_part + divisor_reg1) : A_part;
                    final_quotient_temp = Q_part;
                    final_remainder_64_temp = (result_temp_temp_2[128]) ? (B_part + divisor_reg2) : B_part;
                    final_quotient_64_temp = Q_part_2;
                    final_remainder_32_temp = final_remainder_temp;

                    final_quotient_64 = (Q_64_sign) ? (~final_quotient_64_temp + 64'd1) : final_quotient_64_temp;
                    final_remainder_64 = (REM_64_sign) ? (-final_remainder_64_temp) : final_remainder_64_temp;
                    final_remainder = (REM_32_sign) ? (-final_remainder_temp) : final_remainder_32_temp;
                    final_quotient = (Q_32_sign) ? (-final_quotient_temp) : final_quotient_temp;
                    
                    case(control_reg)
                        4'b1100: result_ex = {{32{Q_32_sign}}, final_quotient};
                        4'b1101: result_ex = {{32{1'b0}}, final_quotient};
                        4'b1110: result_ex = {{32{REM_32_sign}}, final_remainder};
                        4'b1111: result_ex = {{32{1'b0}}, final_remainder};
                        4'b1000: result_ex = {Q_64_sign, final_quotient_64[62:0]};
                        4'b1001: result_ex = {1'b0, final_quotient_64[62:0]};
                        4'b1010: result_ex = {REM_64_sign, final_remainder_64[62:0]};
                        4'b1011: result_ex = {1'b0, final_remainder_64[62:0]};
                        default: result_ex = 64'd0;
                    endcase
                    
                    next_state = 3'b000;
                    fsm_free_state = 1'b1;
                    complete = 1'b1;
                end
            end
            
            default: begin
                next_state = 3'b000;
                fsm_free_state = 1'b1;
            end
        endcase
    end

endmodule
