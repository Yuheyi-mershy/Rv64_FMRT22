module iq1(
    input logic clk,
    input logic reset,
    input logic [6:0] rob_id1,
    input logic [6:0] rob_id2,
    input logic [5:0] rs1_number1,//第一条指令的源1
    input logic [5:0] rs2_number1,//第一条指令的源2
    input logic [5:0] rs1_number2,//第二条指令的源1
    input logic [5:0] rs2_number2,//第二条指令的源2
    input logic [63:0] imm1,
    input logic [63:0] imm2,
    input logic [5:0] rd_number1,
    input logic [5:0] rd_number2,
    input logic [3:0] alu_control1,
    input logic [3:0] alu_control2,
    input logic reg_write1,
    input logic reg_write2,
    input logic [1:0] instr_type1,
    input logic [1:0] instr_type2,
    input logic instr_valid1,
    input logic instr_valid2,
    input logic bru_recovery,
    input logic [6:0] bru_rob_id,

    input logic [6:0] bus_bru,
    input logic [6:0] bus_lsu,
    input logic [6:0] bus_mul,
    input logic [6:0] bus_div,
    //另一个依靠自己传给自己alu的

    //读指令的源寄存器的有效位
    input logic rs1_valid1,
    input logic rs1_valid2,
    input logic rs2_valid1,
    input logic rs2_valid2,
   
    output logic [5:0] rs1_number_select,
    output logic [5:0] rs2_number_select,
    output logic [63:0] imm_select,
    output logic [5:0] rd_number_select,
    output logic [6:0] rob_id_select,
    output logic [3:0] alu_control_select,
    output logic reg_write_select,
    output logic [1:0] instr_type_select,
    output logic iq1_full,
    output logic instr_valid_select,
    output logic [6:0] bus_alu,

    input logic stall,
    output logic write_ok1,
    output logic write_ok2
);
    
    // ==================== 信号声明 ====================
    logic [1:0] count_temp;                    // 加法器
    logic [3:0] tail;               // 写指针
    logic [3:0] re_num;                   // 保留站剩余表项
    logic [7:0][98:0] alu_rs;             // 保留站有8个表项，每个长度是98
    logic [3:0] i;
    logic [7:0][98:0] compressed_rs,compressed_rs_out;      // 压缩后的数组
    logic [1:0] ins_valid1, ins_valid2;
    logic [7:0] request;
    logic [3:0] pointer;
    logic [7:0] press;
    logic [3:0] tail_poinpointer;
    logic [3:0] grant;
    logic [3:0] tail_next,tail_pointer_new,tail_after_press;  
    logic [98:0]alu_rs1,alu_rs2;
    
    assign alu_rs1={1'b1, rob_id1, rs1_valid1, rs1_number1,rs2_valid1, rs2_number1, imm1, rd_number1, reg_write1,alu_control1, instr_type1};
    assign alu_rs2={1'b1, rob_id2, rs1_valid2, rs1_number2,rs2_valid2, rs2_number2, imm2, rd_number2, reg_write2,alu_control2, instr_type2};
    
    always_comb begin
        if(stall& (!iq1_full)) begin
	    write_ok1 = 1;
 	    write_ok2 = 1;
        end else begin
	    write_ok1 = 0;
 	    write_ok2 = 0;		
        end
    end
	    



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
        output [3:0] grant,
        output [7:0] press
    );
        //当bru_recovery信号为0的时候,考虑仲裁//
        if (bru_recovery == 0) begin
            // 产生了仲裁信息
            casez(request)
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
            //产生了压缩信息
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
    input logic [7:0][98:0] compressed_rs_in,
    input logic bru_recovery_in,
    input logic [6:0] bru_rob_id_in,
    input logic [3:0] tail_pointer_old,
    output logic [3:0] tail_pointer_new,
    output logic [7:0][98:0] compressed_rs_out
);
    integer i;
    logic [3:0] temp_tail;
    logic old;
    // 初始化
    temp_tail = tail_pointer_old;
    compressed_rs_out = compressed_rs_in;
    
    // 恢复逻辑
    if (bru_recovery_in) begin
        for (i = tail_pointer_old; i > 0; i = i - 1) begin
             old = (compressed_rs_in[i-1][97] == bru_rob_id_in[6]) ?
		         (compressed_rs_in[i-1][96:91] > bru_rob_id_in[5:0]) :
		         (compressed_rs_in[i-1][96:91] < bru_rob_id_in[5:0]);
		    
            if (old) begin
                compressed_rs_out[i-1][98] = 1'b0;
                temp_tail = temp_tail - 4'd1;  // 使用临时变量，不修改输入
            end 
            else begin
                break;
            end
        end
    end
    
    // 唤醒逻辑
    for (i = 0; i < 8; i = i + 1) begin
        if (compressed_rs_in[i][98]) begin  // 只处理有效条目
            if (compressed_rs_in[i][1:0] == 2'b00) begin  // R类型
                compressed_rs_out[i][90] = equa_func(
                    bus_alu_in, bus_bru_in, bus_lsu_in, bus_mul_in,bus_div_in,
                    compressed_rs_in[i][89:84], compressed_rs_in[i][98], compressed_rs_in[i][90]
                );
                compressed_rs_out[i][83] = equa_func(
                    bus_alu_in, bus_bru_in, bus_lsu_in, bus_mul_in, bus_div_in,
                    compressed_rs_in[i][82:77], compressed_rs_in[i][98], compressed_rs_in[i][83]
                );
            end
            else if (compressed_rs_in[i][1:0] == 2'b01) begin  // I类型
                compressed_rs_out[i][90] = equa_func(
                    bus_alu_in, bus_bru_in, bus_lsu_in,bus_mul_in,bus_div_in,
                    compressed_rs_in[i][89:84], compressed_rs_in[i][98], compressed_rs_in[i][90]
                );
                compressed_rs_out[i][83] = 1'b0;
            end
            else begin  // U类型
                compressed_rs_out[i][90] = 1'b0;
                compressed_rs_out[i][83] = 1'b0;
            end
        end
    end
    tail_pointer_new = temp_tail;  // 最后赋值
endfunction
    
function automatic void press_func(
    input logic [7:0][98:0]alu_rs_i,    
    input logic [7:0] press,
    input logic [3:0] tail_pointer,
    input logic [98:0]new_entry,
    output logic [7:0][98:0] alu_rs_o,  
    output logic [3:0] tail_pointer_next
);
    logic  press_valid;
    press_valid = |press[7:0];
    
        for (int i = 0; i < 8; i++) begin
            if (i < 7) begin
                // 使用三目运算符实现2选1多路器
                // press[i]=1: 选择下一个位置的条目（压缩）
                // press[i]=0: 选择当前位置的条目（保持）
                alu_rs_o[i] = press[i] ? alu_rs_i[i+1] : alu_rs_i[i];
            end 
            else begin
                // 最后一个位置
                // press[7]=1: 插入新条目,
                // press[7]=0: 保持原条目
                alu_rs_o[i] = press[7] ? new_entry : alu_rs_i[7];
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

        // 计算count和iq1_full
        ins_valid1 = instr_valid1 ? 2'b01 : 2'b00;
        ins_valid2 = instr_valid2 ? 2'b01 : 2'b00;
        count_temp = ins_valid1 + ins_valid2;
        re_num = 4'd8 - tail_next;
        if (count_temp< re_num) begin
            iq1_full = 1'b0;
        end else begin
            iq1_full = 1'b1;
        end

        // Step 1: 计算上个周期的request
        for (int i = 0; i < 8; i = i + 1) begin
            if (alu_rs[i][1:0] == 2'b00) begin  // R类型
                request[i] = alu_rs[i][98] & alu_rs[i][90] & alu_rs[i][83];
            end else if (alu_rs[i][1:0] == 2'b01) begin  // I类型
                request[i] = alu_rs[i][98] & alu_rs[i][90];
            end else begin  // U类型
                request[i] = alu_rs[i][98];
            end
        end
        
        // Step 2: 仲裁 - 调用select函数
        select_func(
              .request(request),
              .bru_recovery(bru_recovery),
              .grant(grant),
              .press(press)
         );
        //step 3: 发射
            if (grant[3]) begin
                instr_valid_select= 1'b1;
                rs1_number_select= alu_rs[grant[2:0]][89:84];
                rs2_number_select= alu_rs[grant[2:0]][82:77];
                rd_number_select= alu_rs[grant[2:0]][12:7];
                imm_select= alu_rs[grant[2:0]][76:13];
                rob_id_select= alu_rs[grant[2:0]][97:91];
                alu_control_select= alu_rs[grant[2:0]][5:2];
                reg_write_select= alu_rs[grant[2:0]][6];
                instr_type_select= alu_rs[grant[2:0]][1:0];
            end 
            else begin
                instr_valid_select= 1'b0;
                rs1_number_select= 6'd0;
                rs2_number_select= 6'd0;
                rd_number_select= 6'd0;
                imm_select= 64'd0;
                rob_id_select= 7'd0;
                alu_control_select= 4'd0;
                reg_write_select= 1'b0;
                instr_type_select= 2'b00;
            end
        // Step 4: 计算bus_alu
        if (grant[3]) begin
            bus_alu = {1'd1,alu_rs[grant[2:0]][12:7]};
        end 
        else begin
            bus_alu = 7'd0;
        end

        // Step 5: 压缩 - 调用press函数
        press_func(
           .alu_rs_i(alu_rs),    
           .press(press),
           .tail_pointer(tail),
           .new_entry(99'd0),
           .alu_rs_o(compressed_rs),  
           .tail_pointer_next(tail_after_press)
        );
  
        // Step 4: 唤醒 - 调用wake函数
        wake_func(
            // ✅ 唯一修改：无环 + 支持本周期唤醒
            .bus_alu_in( grant[3] ? alu_rs[grant[2:0]][12:7] : 6'd0 ),
            
            .bus_bru_in(bus_bru[5:0]),
            .bus_lsu_in(bus_lsu[5:0]),
            .bus_mul_in(bus_mul[5:0]),
            .bus_div_in(bus_div[5:0]),
            .compressed_rs_in(compressed_rs),
            .bru_recovery_in(bru_recovery),
            .bru_rob_id_in(bru_rob_id),
            .tail_pointer_old(tail_after_press),
            .tail_pointer_new(tail_pointer_new),
            .compressed_rs_out(compressed_rs_out)
        ); 
             tail_next=tail_pointer_new;
    end
    // ==================== 时序逻辑部分,先压缩，再唤醒，减少工作量 ====================
    always_ff @(posedge clk) begin
            if (reset) begin
                // 复位所有寄存器
                for (int i = 0; i < 8; i = i + 1) begin
                     alu_rs[i] <= 99'd0;
                end
                tail <= 4'b0000;
         
            end 
            else begin 
               // 直接使用已经包含唤醒更新的压缩数组
                for (int i = 0; i < 8; i = i + 1) begin
                     alu_rs[i] <= compressed_rs_out[i];
                end
    
               // 现在进行写IQ
                if (bru_recovery == 1'b0) begin
                    if (iq1_full == 1'b0) begin
                        if (count_temp== 2'b00) begin
                            // nothing
                            tail<=tail_next;
                     
                        end 
                        else if (count_temp== 2'b01) begin
                            if (instr_valid1) begin
                                alu_rs[tail_next] <=alu_rs1;
                                tail <= tail_next+ 4'd1;
                             
                            end 
                            else if (instr_valid2) begin
                                alu_rs[tail_next] <=alu_rs2;
                                tail <= tail_next+ 4'd1;
                               
                            end
                        end 
                        else begin  // count == 2'b10
                        // 写入两条指令
                            alu_rs[tail_next] <=alu_rs1;
                            alu_rs[tail_next+ 4'd1] <=alu_rs2;
                            tail <= tail_next+ 4'd2;
                        
                        end
                    end
                    // IQ满的时候，不写入指令
                    else     begin
                            tail<=tail_next;
                        
                    end
                end
                else   begin
                    //bru_recovery==1'd1,也不用写IQ
                     tail<=tail_next;
              
                end
            end
    end
endmodule
