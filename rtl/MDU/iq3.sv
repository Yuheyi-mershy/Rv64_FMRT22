module iq3(
    input logic clk,
    input logic reset,

    //派遣过来的内容
    input logic [6:0] rob_id1,
    input logic [6:0] rob_id2,
    input logic [5:0] rs1_number1,//第一条指令的源1
    input logic [5:0] rs2_number1,//第一条指令的源2
    input logic [5:0] rs1_number2,//第二条指令的源1
    input logic [5:0] rs2_number2,//第二条指令的源2
    input logic [5:0] rd_number1,
    input logic [5:0] rd_number2,
    input logic [3:0] mdu_control1,
    input logic [3:0] mdu_control2,
    input logic reg_write1,
    input logic reg_write2,
    input logic instr_valid1,
    input logic instr_valid2,
    input logic bru_recovery,
    input logic [6:0] bru_rob_id,
    
    //用于唤醒的CDB内容
    input logic [6:0] bus_bru,
    input logic [6:0] bus_lsu,
    input logic [6:0] bus_alu,
    input logic [6:0] bus_mul,//等乘法执行到第二个周期送给来的
    input logic [6:0] bus_div,//等除法执行完送过来的
    input logic  fsm_free,
    
    //读指令的源寄存器的有效位
    input logic rs1_valid1,
    input logic rs1_valid2,
    input logic rs2_valid1,
    input logic rs2_valid2,
    
    // PRF占用信号（来自select_prf模块）
    input logic prf_occupied,  // 新增：表示DIV槽被占用

    output logic [5:0] rs1_number_select,
    output logic [5:0] rs2_number_select,
    output logic [5:0] rd_number_select,
    output logic [6:0] rob_id_select,
    output logic [3:0] mdu_control_select,
    output logic reg_write_select,
    output logic iq3_full,
    output logic instr_valid_select
);
    
    // ==================== 信号声明 ====================
    logic [1:0] count_temp;                    // 加法器
    logic [3:0] tail;               // 写指针
    logic [3:0] re_num;                   // 保留站剩余表项
    logic [7:0][32:0] mdu_rs;             // 保留站有8个表项，每个长度是33位
    logic [3:0] i;
    logic [7:0][32:0] compressed_rs,compressed_rs_out;      // 压缩后的数组
    logic [1:0] ins_valid1, ins_valid2;
    logic [7:0] request;
    logic [3:0] pointer;
    logic [7:0] press;
    logic [3:0] tail_poinpointer;
    logic [3:0] grant;
    logic [3:0] tail_next,tail_pointer_new,tail_after_press;  
    logic [32:0]mdu_rs1,mdu_rs2;
    
    assign mdu_rs1={1'b1, rob_id1, rs1_valid1, rs1_number1, rs2_valid1, rs2_number1, rd_number1, mdu_control1, reg_write1};
    assign mdu_rs2={1'b1, rob_id2, rs1_valid2, rs1_number2, rs2_valid2, rs2_number2, rd_number2, mdu_control2, reg_write2};
    

// ==================== 函数声明 ====================
    // equa函数 - 用于唤醒逻辑
    function automatic logic equa_func(
        input [5:0] bus_alu,
        input [5:0] bus_bru,
        input [5:0] bus_lsu,
        input [5:0] bus_mul,
        input [5:0] bus_div,
        input [5:0] rs_number,
        input logic entry_valid,
        input logic initial_valid
    );
        logic rs_valid1;
        
        if (!entry_valid) begin
            rs_valid1 = 1'b0;
        end 
        else if (initial_valid) begin
            rs_valid1 = 1'b1;
        end 
        else begin
            rs_valid1 = ((bus_bru == rs_number) && (bus_bru != 6'd0)) ||((bus_alu == rs_number) && (bus_alu != 6'd0)) ||((bus_lsu == rs_number) && (bus_lsu != 6'd0)) ||((bus_mul == rs_number) && (bus_mul != 6'd0))||((bus_div == rs_number) && (bus_div != 6'd0));
        end
        return rs_valid1;
    endfunction
    
    // select模块的内置函数
    function automatic void select_func(
        input [7:0] request,
        input logic bru_recovery,
        input logic prf_occupied,  // 新增参数
        output [3:0] grant,
        output [7:0] press
    );
        logic [7:0] masked_request;  // 屏蔽后的请求信号
        
        // 当bru_recovery信号为0的时候,考虑仲裁//
        if (bru_recovery == 0) begin
            // 如果有DIV指令且PRF被占用，则屏蔽DIV指令的请求
            // 注意：这里假设DIV指令的control[3]=1，需要根据实际编码调整
            masked_request = request;
            if (prf_occupied) begin
                // 屏蔽所有DIV指令的请求（遍历所有表项）
                for (int i = 0; i < 8; i++) begin
                    // 如果该表项是DIV指令（bit3=1），则清除其请求
                    if (mdu_rs[i][3]) begin  // 假设bit3是DIV标志
                        masked_request[i] = 1'b0;
                    end
                end
            end
            
            // 对屏蔽后的请求进行仲裁
            casez(masked_request)
                8'b????_???1: grant = 4'b1000;
                8'b????_??10: grant = 4'b1001;
                8'b????_?100: grant = 4'b1010;
                8'b????_1000: grant = 4'b1011;
                8'b???1_0000: grant = 4'b1100;
                8'b??10_0000: grant = 4'b1101;
                8'b?100_0000: grant = 4'b1110;
                8'b1000_0000: grant = 4'b1111;
                default:      grant = 4'b0000;
            endcase
            
            // 产生压缩信息（基于原始request，因为压缩需要知道哪些位置被发射了）
            case(grant)
                4'b1000: press = 8'b1111_1111;
                4'b1001: press = 8'b1111_1110;
                4'b1010: press = 8'b1111_1100;
                4'b1011: press = 8'b1111_1000;
                4'b1100: press = 8'b1111_0000;
                4'b1101: press = 8'b1110_0000;
                4'b1110: press = 8'b1100_0000;
                4'b1111: press = 8'b1000_0000;
                default: press = 8'b0000_0000;
            endcase
        end
        //当bru_recovery信号为1的时候，不考虑仲裁//
        else begin
             grant = 4'd0;
             press = 8'd0;
        end
    endfunction
    
    // wake模块的内置函数
   function automatic void wake_func(
    input [5:0] bus_alu_in,
    input [5:0] bus_bru_in,
    input [5:0] bus_lsu_in,
    input [5:0] bus_mul_in,
    input [5:0] bus_div_in,
    input logic [7:0][32:0] compressed_rs_in,
    input logic bru_recovery_in,
    input logic [6:0] bru_rob_id_in,
    input logic [3:0] tail_pointer_old,
    output logic [3:0] tail_pointer_new,
    output logic [7:0][32:0] compressed_rs_out
);
    integer i;
    logic [3:0] temp_tail;
    
    // 初始化
    temp_tail = tail_pointer_old;
    compressed_rs_out = compressed_rs_in;
    
    // 恢复逻辑
    if (bru_recovery_in) begin
        for (i = tail_pointer_old; i > 0; i = i - 1) begin
            logic is_newer;
            
            // 判断当前指令是否比分支指令更新
            // compressed_rs_in[i-1][31:25] 是7位ROB ID，[31]是最高位（第7位），[30:25]是低6位
            if (compressed_rs_in[i-1][31] == bru_rob_id_in[6]) begin
                // 同一半区，比较低6位
                is_newer = (compressed_rs_in[i-1][30:25] > bru_rob_id_in[5:0]);
            end
            else begin
                // 不同半区，翻页信号小的更新
                is_newer = (compressed_rs_in[i-1][31] < bru_rob_id_in[6]);
            end
            
            // 如果当前指令比分支指令更新，则清除
            if (is_newer && (compressed_rs_in[i-1][31:25] != bru_rob_id_in)) begin
                compressed_rs_out[i-1][32] = 1'b0;
                temp_tail = temp_tail - 4'd1;
            end 
            else begin
                break;
            end
        end
    end
    for (i = 0; i < temp_tail; i = i + 1) begin
        if (compressed_rs_in[i][32]) begin  // 只处理有效条目                    
            compressed_rs_out[i][24] = equa_func(
                    bus_alu_in, bus_bru_in, bus_lsu_in, bus_mul_in, bus_div_in,
                    compressed_rs_in[i][23:18], compressed_rs_in[i][32], compressed_rs_in[i][24]
                );                   
            compressed_rs_out[i][17] = equa_func(
                   bus_alu_in, bus_bru_in, bus_lsu_in, bus_mul_in, bus_div_in,
                    compressed_rs_in[i][16:11], compressed_rs_in[i][32], compressed_rs_in[i][17]               
             );
        end
    end
    tail_pointer_new = temp_tail;
endfunction
    
function automatic void press_func(
    input logic [7:0][32:0]mdu_rs_i,    
    input logic [7:0] press,
    input logic [3:0] tail_pointer,
    input logic [32:0]new_entry,
    output logic [7:0][32:0] mdu_rs_o,  
    output logic [3:0] tail_pointer_next
);
    logic  press_valid;
    press_valid = |press[7:0];
    
        for (int i = 0; i < 8; i++) begin
            if (i < 7) begin
                mdu_rs_o[i] = press[i] ? mdu_rs_i[i+1] : mdu_rs_i[i];
            end 
            else begin
                mdu_rs_o[i] = press[7] ? new_entry : mdu_rs_i[7];
            end
        end
        
        // 计算新的tail_pointer
        if (press_valid) begin
            tail_pointer_next = tail_pointer - 4'd1;
        end else begin
            tail_pointer_next = tail_pointer;
        end
endfunction
    
    // ==================== 组合逻辑部分 ====================
    always_comb begin

        // 计算count和iq3_full
        ins_valid1 = instr_valid1 ? 2'b01 : 2'b00;
        ins_valid2 = instr_valid2 ? 2'b01 : 2'b00;
        count_temp = ins_valid1 + ins_valid2;
        if((count_temp < re_num) | (count_temp == re_num)) begin
            iq3_full = 1'b0;
        end else begin
            iq3_full = 1'b1;
        end

        // Step 1: 计算上个周期的request
        for (int i = 0; i < 8; i = i + 1) begin
            if (~mdu_rs[i][3]) begin  // MUL类型 (假设bit3=0表示MUL)
                request[i] = mdu_rs[i][32] & mdu_rs[i][17] & mdu_rs[i][24];
            end
            else begin  // DIV类型 (bit3=1表示DIV)
                // DIV指令需要同时满足：有效、源就绪、状态机空闲、且PRF未被占用
                request[i] = mdu_rs[i][32] & mdu_rs[i][17] & mdu_rs[i][24] & fsm_free & ~prf_occupied;
            end
        end
        
        // Step 2: 仲裁 - 调用select函数
        select_func(
              .request(request),
              .bru_recovery(bru_recovery),
              .prf_occupied(prf_occupied),  // 传递PRF占用信号
              .grant(grant),
              .press(press)
         );
         
        // step 3: 发射
        if (grant[3]) begin
            instr_valid_select = 1'b1;
            rs1_number_select = mdu_rs[grant[2:0]][23:18];
            rs2_number_select = mdu_rs[grant[2:0]][16:11];
            rd_number_select = mdu_rs[grant[2:0]][10:5];
            rob_id_select = mdu_rs[grant[2:0]][31:25];
            mdu_control_select = mdu_rs[grant[2:0]][4:1];
            reg_write_select = mdu_rs[grant[2:0]][0];
        end else begin
            instr_valid_select = 1'b0;
            rs1_number_select = 6'd0;
            rs2_number_select = 6'd0;
            rd_number_select = 6'd0;
            rob_id_select = 7'd0;
            mdu_control_select = 4'd0;
            reg_write_select = 1'b0;
        end
        
        // Step 5: 压缩 - 调用press函数
        press_func(
           .mdu_rs_i(mdu_rs),    
           .press(press),
           .tail_pointer(tail),
           .new_entry(33'd0),
           .mdu_rs_o(compressed_rs),  
           .tail_pointer_next(tail_after_press)
        );
  
        // Step 4: 唤醒 - 调用wake函数
        wake_func(
            .bus_alu_in(bus_alu),
            .bus_bru_in(bus_bru),
            .bus_lsu_in(bus_lsu),
            .bus_mul_in(bus_mul),
            .bus_div_in(bus_div),
            .compressed_rs_in(compressed_rs),
            .bru_recovery_in(bru_recovery),
            .bru_rob_id_in(bru_rob_id),
            .tail_pointer_old(tail_after_press),
            .tail_pointer_new(tail_pointer_new),
            .compressed_rs_out(compressed_rs_out)
        ); 
        tail_next = tail_pointer_new;
    end
    
    // ==================== 时序逻辑部分 ====================
    always_ff @(posedge clk) begin
        if (reset) begin
            // 复位所有寄存器
            for (int i = 0; i < 8; i = i + 1) begin
                mdu_rs[i] <= 33'd0;
            end
            tail <= 4'b0000;
            re_num <= 4'b1000;
        end 
        else begin 
            // 直接使用已经包含唤醒更新的压缩数组
            for (int i = 0; i < 8; i = i + 1) begin
                mdu_rs[i] <= compressed_rs_out[i];
            end
    
            // 现在进行写IQ
            if (bru_recovery == 1'b0) begin
                if (iq3_full == 1'b0) begin
                    if (count_temp == 2'b00) begin
                        tail <= tail_next;
                        re_num <= 4'd8 - tail_next;
                    end 
                    else if (count_temp == 2'b01) begin
                        if (instr_valid1) begin
                            mdu_rs[tail_next] <= mdu_rs1;
                            tail <= tail_next + 4'd1;
                            re_num <= 4'd8 - tail_next - 4'd1;
                        end 
                        else if (instr_valid2) begin
                            mdu_rs[tail_next] <= mdu_rs2;
                            tail <= tail_next + 4'd1;
                            re_num <= 4'd8 - tail_next - 4'd1;
                        end
                    end 
                    else begin  // count == 2'b10
                        // 写入两条指令，需要检查是否有足够空间
                        if (tail_next + 4'd2 <= 4'd8) begin
                            mdu_rs[tail_next] <= mdu_rs1;
                            mdu_rs[tail_next + 4'd1] <= mdu_rs2;
                            tail <= tail_next + 4'd2;
                            re_num <= 4'd8 - tail_next - 4'd2;
                        end
                    end
                end
                else begin
                    // IQ满的时候，不写入指令
                    tail <= tail_next;
                    re_num <= 4'd8 - tail_next;
                end
            end
            else begin
                // bru_recovery==1'd1, 也不用写IQ
                tail <= tail_next;
                re_num <= 4'd8 - tail_next;
            end
        end
    end
    
endmodule
