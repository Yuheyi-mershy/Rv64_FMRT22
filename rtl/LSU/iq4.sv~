module iq4(
    input logic clk,
    input logic reset,
    input logic [6:0] rob_id1,
    input logic [6:0] rob_id2,
    input logic [63:0] imm1,
    input logic [63:0] imm2,
    input logic [5:0] rs1_number1,
    input logic [5:0] rs2_number1,
    input logic [5:0] rs1_number2,
    input logic [5:0] rs2_number2,
    input logic [5:0] rd_number1,
    input logic [5:0] rd_number2,
    input logic [3:0] lsu_control1,
    input logic [3:0] lsu_control2,
    input logic reg_write1,
    input logic reg_write2,
    input logic [1:0] instr_type1,
    input logic [1:0] instr_type2,
    input logic instr_valid1,
    input logic instr_valid2,
    input logic bru_recovery,
    input logic [6:0] bru_rob_id,
    
    input logic [6:0] bus_alu,
    input logic [6:0] bus_mul,
    input logic [6:0] bus_div,
    input logic [6:0] bus_bru,
    input logic [6:0] bus_lsu,
    
    input logic rs1_valid1,
    input logic rs1_valid2,
    input logic rs2_valid1,
    input logic rs2_valid2,
    
    input logic complete_sb_wb,
    input logic complete_load_wb,
    input logic sb_full,
    input logic fsm_free,
    input logic [3:0] complete_grant1,
    input logic [3:0] complete_grant2,
    
    // 新增：PRF状态信号
    input logic prf_occupied,  // PRF是否被占用（valid_reg）
    
    output logic [5:0] rs1_number_select,
    output logic [63:0] imm_select,
    output logic [5:0] dest_number_select,
    output logic [6:0] rob_id_select,
    output logic [3:0] lsu_control_select,
    output logic reg_write_select,
    output logic iq4_full,
    output logic [3:0] grant_select,
    output logic instr_valid_select
);
    
    // ==================== 信号声明 ====================
    logic [1:0] count_temp;
    logic [3:0] tail;
    logic [3:0] re_num;       // [表情] 组合逻辑
    logic [3:0] re_num_end;
    logic [7:0][91:0] lsu_rs;
    logic [7:0][91:0] compressed_rs, compressed_rs_out;
    logic [1:0] ins_valid1, ins_valid2;
    logic [7:0] request;
    logic [7:0] type_vec;
    logic [3:0] head;
    logic [3:0] grant,grant_new;
    logic [3:0] pointer_end;
    logic [3:0] tail_next, tail_pointer_new, tail_after_press, head_pointer_next, head_next, head_pointer_new;
    logic [91:0] lsu_rs1, lsu_rs2;
    logic [5:0] dest_number1, dest_number2;
    
    assign dest_number1 = (lsu_control1[3]) ? rs2_number1 : rd_number1;
    assign dest_number2 = (lsu_control2[3]) ? rs2_number2 : rd_number2;
    
    assign lsu_rs1 = {1'b1, rob_id1, rs1_valid1, rs1_number1, imm1, dest_number1, rs2_valid1, reg_write1, lsu_control1, 1'd0};
    assign lsu_rs2 = {1'b1, rob_id2, rs1_valid2, rs1_number2, imm2, dest_number2, rs2_valid2, reg_write2, lsu_control2, 1'd0};
    
    // ==================== 函数声明 ====================
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
        if (!entry_valid) begin
            return 1'b0;
        end 
        else if (initial_valid) begin
            return 1'b1;
        end 
        else begin
            return ((bus_alu == rs_number) && (bus_alu != 6'd0)) ||
                   ((bus_bru == rs_number) && (bus_bru != 6'd0)) ||
                   ((bus_lsu == rs_number) && (bus_lsu != 6'd0)) ||
                   ((bus_mul == rs_number) && (bus_mul != 6'd0)) ||
                   ((bus_div == rs_number) && (bus_div != 6'd0));
        end
    endfunction

    function automatic void select_func(
        input [7:0] request,
        input [7:0] type_vec,
        input logic bru_recovery,
        input [3:0] pointer,
        output [3:0] grant,
        output [3:0] pointer_end
    );
        logic all_load;
        logic head_is_store;
        int idx;
        
        grant = 4'b0;
        pointer_end = pointer;
        
        all_load = ~(|type_vec[7:0]);
        head_is_store = type_vec[pointer];
        
        if (bru_recovery) begin
            grant = 4'b0;
            pointer_end = pointer;
        end
        else begin
            if (all_load) begin
                casez (request)
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
                
                if (grant[3]) begin
                    pointer_end = pointer + 4'd1;
                end
            end
            else begin
                if (head_is_store) begin
                    if (request[pointer]) begin
                        grant = 4'd8 + pointer;
                        pointer_end = pointer + 4'd1;
                    end
                end
                else begin
                    for (idx = pointer; idx < 8; idx++) begin
                        if (type_vec[idx] == 1'b1) begin
                            grant = 4'b0;
                            pointer_end = pointer;
                            break;
                        end
                        else if (request[idx] == 1'b1) begin
                            grant = 4'd8 + idx;
                            pointer_end = idx + 1;
                            break;
                        end
                        else if (idx == 7) begin
                            grant = 4'b0;
                            pointer_end = pointer;
                        end
                    end
                end
            end
        end
    endfunction
    
    function automatic void press_func(
        input logic [7:0][91:0] lsu_rs_i, 
        input logic complete1,
        input logic complete2,
        input logic [3:0] grant1,
        input logic [3:0] grant2,
        input logic [3:0] tail_pointer,
        input logic [91:0] new_entry,
        input logic [3:0] grant_select_press,
        input logic [3:0] pointer_head,
        output logic [7:0][91:0] lsu_rs_o,  
        output logic [3:0] tail_pointer_next,
        output logic [3:0] head_pointer_next,
        output logic [3:0] grant_new
    );
        logic [7:0] press1, press2;
        logic [3:0] c1, c2, c3;
        int idx;
        logic [2:0] grant_idx;
        logic [7:0][91:0] lsu_rs_i_temp;
        
        c1 = grant1[2:0];
        c2 = grant2[2:0];
        c3 = pointer_head[2:0];
        
        case(grant1)
            4'b1000: press1 = 8'b1111_1111;
            4'b1001: press1 = 8'b1111_1110;                
            4'b1010: press1 = 8'b1111_1100;
            4'b1011: press1 = 8'b1111_1000;
            4'b1100: press1 = 8'b1111_0000;
            4'b1101: press1 = 8'b1110_0000;
            4'b1110: press1 = 8'b1100_0000;                
            4'b1111: press1 = 8'b1000_0000;
            default: press1 = 8'b0000_0000;
        endcase
        
        case(grant2)
            4'b1000: press2 = 8'b1111_1111;
            4'b1001: press2 = 8'b1111_1110;                
            4'b1010: press2 = 8'b1111_1100;
            4'b1011: press2 = 8'b1111_1000;
            4'b1100: press2 = 8'b1111_0000;
            4'b1101: press2 = 8'b1110_0000;
            4'b1110: press2 = 8'b1100_0000;                
            4'b1111: press2 = 8'b1000_0000;
            default: press2 = 8'b0000_0000;
        endcase
        
        grant_idx = grant_select_press[2:0];
        lsu_rs_i_temp = lsu_rs_i;
        
        if(grant_select_press[3]) begin
            lsu_rs_i_temp[grant_idx][0] = 1'd1;
        end
        
        if (complete1 && ~complete2) begin
            for (idx = 0; idx < 8; idx++) begin
                if (idx < 7) begin
                    lsu_rs_i_temp[idx] = press1[idx] ? lsu_rs_i_temp[idx+1] : lsu_rs_i_temp[idx];
                end 
                else begin
                    lsu_rs_i_temp[idx] = press1[7] ? new_entry : lsu_rs_i_temp[7];
                end
            end
            tail_pointer_next = tail_pointer - 4'd1;
            if(grant_select_press[3]) begin
                if (c1 > c3) begin
                    head_pointer_next = pointer_head;
                    grant_new = grant_select_press;
                end
                else begin
                    head_pointer_next = pointer_head - 4'd1;
                    grant_new = grant_select_press - 4'd1;
                end
            end
            else begin
                grant_new = 4'd0;
                head_pointer_next = ((pointer_head[2:0]) > c1) ? pointer_head - 4'd1 : pointer_head;
            end
        end
        else if (~complete1 && complete2) begin
            for (idx = 0; idx < 8; idx++) begin
                if (idx < 7) begin
                    lsu_rs_i_temp[idx] = press2[idx] ? lsu_rs_i_temp[idx+1] : lsu_rs_i_temp[idx];
                end else begin
                    lsu_rs_i_temp[idx] = press2[7] ? new_entry : lsu_rs_i_temp[7];
                end
            end
            tail_pointer_next = tail_pointer - 4'd1;
            
            if(grant_select_press[3]) begin
                if (c2 > c3) begin
                    head_pointer_next = pointer_head;
                    grant_new = grant_select_press;
                end
                else begin
                    head_pointer_next = pointer_head - 4'd1;
                    grant_new = grant_select_press - 4'd1;
                end
            end
            else begin
                grant_new = 4'd0;
                head_pointer_next = ((pointer_head[2:0]) > c2) ? pointer_head - 4'd1 : pointer_head;
            end
        end
        else if (complete1 && complete2) begin
            if (c1 > c2) begin
                for (idx = c2; idx < c1; idx++) begin
                    lsu_rs_i_temp[idx] = lsu_rs_i_temp[idx+1];
                end
                for (idx = c1+1; idx < 9; idx++) begin
                    if(idx == 8) begin
                        lsu_rs_i_temp[idx-2] = new_entry;
                    end
                    else begin
                        lsu_rs_i_temp[idx-2] = lsu_rs_i_temp[idx];
                    end
                end
                if(grant_select_press[3]) begin
                    if(c3 > c1) begin
                        head_pointer_next = pointer_head - 4'd2;
                        grant_new = grant_select_press - 4'd2;
                    end
                    else if(c3 < c2) begin
                        head_pointer_next = pointer_head;
                        grant_new = grant_select_press;
                    end
                    else begin
                        head_pointer_next = pointer_head - 4'd1;
                        grant_new = grant_select_press - 4'd1;
                    end
                end
                else begin
                    grant_new = 4'd0;
                    head_pointer_next = ((pointer_head[2:0]) > c2) ? ((((pointer_head[2:0]) > c1) ? pointer_head - 4'd2 : pointer_head - 4'd1)) : pointer_head;
                end
            end 
            else begin
                for (idx = c1; idx < c2; idx++) begin
                    lsu_rs_i_temp[idx] = lsu_rs_i_temp[idx+1];
                end
                for (idx = c2+1; idx < 9; idx++) begin
                    if(idx == 8) begin
                        lsu_rs_i_temp[idx-2] = new_entry;
                    end
                    else begin
                        lsu_rs_i_temp[idx-2] = lsu_rs_i_temp[idx];
                    end
                end
                if(grant_select_press[3]) begin
                    if(c3 > c2) begin
                        head_pointer_next = pointer_head - 4'd2;
                        grant_new = grant_select_press - 4'd2;
                    end
                    else if(c3 < c1) begin
                        head_pointer_next = pointer_head;
                        grant_new = grant_select_press;
                    end
                    else begin
                        head_pointer_next = pointer_head - 4'd1;
                        grant_new = grant_select_press - 4'd1;
                    end
                end
                else begin
                    grant_new = 4'd0;
                    head_pointer_next = ((pointer_head[2:0]) > c1) ? ((((pointer_head[2:0]) > c2) ? pointer_head - 4'd2 : pointer_head - 4'd1)) : pointer_head;
                end
            end
            tail_pointer_next = tail_pointer - 4'd2;    
        end
        else begin
            tail_pointer_next = tail_pointer;
            head_pointer_next = pointer_head;
            grant_new = grant_select_press;
        end
        lsu_rs_o = lsu_rs_i_temp;
    endfunction

	 function automatic void wake_func(
	    input [5:0] bus_alu_in,
	    input [5:0] bus_bru_in,
	    input [5:0] bus_lsu_in,
	    input [5:0] bus_mul_in,
	    input [5:0] bus_div_in,
	    input logic [7:0][91:0] compressed_rs_in,
	    input logic bru_recovery_in,
	    input logic [6:0] bru_rob_id_in,
	    input logic sb_full_in,
	    input logic [3:0] tail_pointer_old,
	    input logic [3:0] pointer_end_old,
	    output logic [3:0] tail_pointer_new,
	    output logic [3:0] head_pointer_new,
	    output logic [7:0][91:0] compressed_rs_out
	);
	    int idx;
	    logic [3:0] temp_tail;
	    logic [3:0] remove_cnt;   // 统计要删除几条（只统计，不边循环边减）
	    logic old;
	    
	    temp_tail = tail_pointer_old;
	    compressed_rs_out = compressed_rs_in;
	    head_pointer_new = pointer_end_old;
	    remove_cnt = 4'd0;       // 初始化计数器

	    // ==================== 恢复 / 清空逻辑 ====================
	    if (bru_recovery_in || sb_full_in) begin
		head_pointer_new = 4'd0;
		
		// 第一步：遍历 + 标记删除 + 统计数量（不修改指针！）
		for (idx = 0; idx < temp_tail; idx++) begin
		    // 先计算 old
		    old = (compressed_rs_in[idx][90] == bru_rob_id_in[6]) ?
		         (compressed_rs_in[idx][89:84] > bru_rob_id_in[5:0]) :
		         (compressed_rs_in[idx][89:84] < bru_rob_id_in[5:0]);
		    
		    // 错误路径指令：无效化
		    if (bru_recovery_in && old) begin
		        compressed_rs_out[idx][91] = 1'b0;
		        remove_cnt = remove_cnt + 4'd1;  // [表情] 只统计，不立刻减指针
		    end
		    
		    // 通用清空标志
		    if (sb_full_in || bru_recovery_in) begin
		        compressed_rs_out[idx][0] = 1'b0;
		    end
		end
	    end

	    // ==================== 唤醒逻辑（不变） ====================
	    for (idx = 0; idx < 8; idx++) begin
		if (compressed_rs_in[idx][91]) begin
		    if (compressed_rs_in[idx][4]) begin
		        compressed_rs_out[idx][83] = equa_func(
		            bus_alu_in, bus_bru_in, bus_lsu_in, bus_mul_in, bus_div_in,
		            compressed_rs_in[idx][82:77], compressed_rs_in[idx][91], compressed_rs_out[idx][83]
		        );
		        compressed_rs_out[idx][6] = equa_func(
		            bus_alu_in, bus_bru_in, bus_lsu_in, bus_mul_in, bus_div_in,
		            compressed_rs_in[idx][12:7], compressed_rs_in[idx][91], compressed_rs_out[idx][6]
		        );
		    end
		    else begin
		        compressed_rs_out[idx][83] = equa_func(
		            bus_alu_in, bus_bru_in, bus_lsu_in, bus_mul_in, bus_div_in,
		            compressed_rs_in[idx][82:77], compressed_rs_in[idx][91], compressed_rs_out[idx][83]
		        );
		        compressed_rs_out[idx][6] = 1'b0;
		    end
		end
	    end

	    // ==================== 【最终】统一计算新尾指针 ====================
	    // 删除了几条，指针就减几
	    tail_pointer_new = temp_tail - remove_cnt;

	endfunction
 
    // ==================== 组合逻辑 ====================
    always_comb begin
        // ------------------------------
        // [表情] re_num 改为纯组合逻辑
        // ------------------------------
         re_num = 4'd8 - tail_next;

        ins_valid1 = instr_valid1 ? 2'b01 : 2'b00;
        ins_valid2 = instr_valid2 ? 2'b01 : 2'b00;
        count_temp = ins_valid1 + ins_valid2;
        
        if (count_temp < re_num) begin
            iq4_full = 1'b0;
        end else begin
            iq4_full = 1'b1;
        end

        // request & type_vec
        for (int idx = 0; idx < 8; idx = idx + 1) begin
            if (~lsu_rs[idx][4]) begin
                request[idx] = lsu_rs[idx][91] & lsu_rs[idx][83] & fsm_free & (~lsu_rs[idx][0]) & (~sb_full) & (~prf_occupied);
            end else begin
                request[idx] = lsu_rs[idx][91] & lsu_rs[idx][83] & lsu_rs[idx][6] & (~lsu_rs[idx][0]) & (~sb_full);
            end
            type_vec[idx] = lsu_rs[idx][4];
        end

        // 仲裁
        select_func(request, type_vec, bru_recovery, head, grant, pointer_end);
        
        // 压缩
        press_func(lsu_rs, complete_load_wb, complete_sb_wb, 
                   complete_grant1, complete_grant2, tail, 91'd0, grant, pointer_end,
                   compressed_rs, tail_after_press, head_pointer_next, grant_new);
        
        // 发射
        if (grant_new[3]) begin
            instr_valid_select = 1'b1;
            rs1_number_select = compressed_rs[grant_new[2:0]][82:77];
            dest_number_select = compressed_rs[grant_new[2:0]][12:7];
            rob_id_select = compressed_rs[grant_new[2:0]][90:84];
            lsu_control_select = compressed_rs[grant_new[2:0]][4:1];
            reg_write_select = compressed_rs[grant_new[2:0]][5];
            imm_select = compressed_rs[grant_new[2:0]][76:13];
            grant_select = grant_new;
        end else begin
            instr_valid_select = 1'b0;
            rs1_number_select = 6'd0;
            dest_number_select = 6'd0;
            rob_id_select = 7'd0;
            lsu_control_select = 4'd0;
            reg_write_select = 1'd0;
            imm_select = 64'd0;
            grant_select = 4'd0;
        end

        // 唤醒
        wake_func(
            bus_alu, bus_bru, bus_lsu, bus_mul, bus_div,
            compressed_rs, bru_recovery, bru_rob_id, sb_full,
            tail_after_press, head_pointer_next, tail_pointer_new, head_pointer_new, compressed_rs_out
        );
        
        tail_next = tail_pointer_new;
        head_next = head_pointer_new;
    end

    // ==================== 时序逻辑 ====================
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int idx = 0; idx < 8; idx = idx + 1) begin
                lsu_rs[idx] <= 91'd0;
            end
            tail <= 4'b0000;
            head <= 4'b0000;
           
        end 
        else begin 
            for (int idx = 0; idx < 8; idx = idx + 1) begin
                lsu_rs[idx] <= compressed_rs_out[idx];
            end
            head <= head_next;
     
            
            if (bru_recovery == 1'b0) begin
                if (!iq4_full) begin
                    if (count_temp == 2'd0) begin
                        tail <= tail_next;
                    end 
                    else if (count_temp == 2'd1) begin
                        if (instr_valid1) begin
                            lsu_rs[tail_next] <= lsu_rs1;
                            tail <= tail_next + 4'd1;
                        end 
                        else if (instr_valid2) begin
                            lsu_rs[tail_next] <= lsu_rs2;
                            tail <= tail_next + 4'd1;
                        end
                    end 
                    else begin
                        lsu_rs[tail_next] <= lsu_rs1;
                        lsu_rs[tail_next + 4'd1] <= lsu_rs2;
                        tail <= tail_next + 4'd2;
                    end
                end
                else begin
                    tail <= tail_next;
                end
            end
            else begin
                tail <= tail_next;
            end
        end
    end
endmodule

