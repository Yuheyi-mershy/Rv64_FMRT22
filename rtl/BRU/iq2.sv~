module iq2(
    input logic clk,
    input logic reset,
    input logic [6:0] rob_id1,
    input logic [6:0] rob_id2,
    input logic [4:0] bob_id1,
    input logic [4:0] bob_id2,
    input logic [5:0] rs1_number1,
    input logic [5:0] rs2_number1,
    input logic [5:0] rs1_number2,
    input logic [5:0] rs2_number2,
    input logic [5:0] rd_number1,
    input logic [5:0] rd_number2,
    input logic [2:0] bru_control1,
    input logic [2:0] bru_control2,
    input logic reg_write1,
    input logic reg_write2,
    input logic [1:0] instr_type1,
    input logic [1:0] instr_type2,
    input logic instr_valid1,
    input logic instr_valid2,
    input logic bru_recovery,
    
    input logic [6:0] bus_alu,
    input logic [6:0] bus_mul,
    input logic [6:0] bus_div,
    input logic [6:0] bus_lsu,

    input logic rs1_valid1,
    input logic rs1_valid2,
    input logic rs2_valid1,
    input logic rs2_valid2,
     
    output logic [5:0] rs1_number_select,
    output logic [5:0] rs2_number_select,
    output logic [5:0] rd_number_select,
    output logic [6:0] rob_id_select,
    output logic [4:0] bob_id_select,
    output logic [2:0] bru_control_select,
    output logic reg_write_select,
    output logic [1:0] instr_type_select,
    output logic iq2_full,
    output logic instr_valid_select,
    output logic [6:0] bus_valid_bru,

    input logic stall,
    output logic write_ok3,
    output logic write_ok4
);
    
    // ==================== 信号定义 ====================
    logic [1:0] count_temp;
    logic [2:0] tail;              // 真正的写指针
    logic [2:0] free_space;        // 剩余空间
    logic [3:0][38:0] bru_rs;      // 保留站存储
    
    // 流水线中间变量
    logic [3:0] request;
    logic [2:0] grant;
    logic [3:0] press;
    logic [3:0][38:0] after_press;
    logic [2:0] tail_after_press;
    logic [3:0][38:0] after_wake;
    logic [2:0] tail_final;
    
    logic [38:0] bru_rs1, bru_rs2;

    // 打包指令
    assign bru_rs1 = {1'b1, rob_id1, bob_id1, rs1_valid1, rs1_number1, rs2_valid1, rs2_number1, rd_number1, instr_type1, reg_write1, bru_control1};
    assign bru_rs2 = {1'b1, rob_id2, bob_id2, rs1_valid2, rs1_number2, rs2_valid2, rs2_number2, rd_number2, instr_type2, reg_write2, bru_control2};
    
    // 写握手
    assign write_ok3 = stall && !iq2_full;
    assign write_ok4 = stall && !iq2_full;

// ==================== 函数 ====================
function automatic logic equa_func(
    input [5:0] bus_alu, bus_bru, bus_lsu, bus_mul, bus_div,
    input [5:0] rs,
    input logic vld, ini_vld
);
    if (!vld) return 0;
    if (ini_vld) return 1;
    return ((bus_bru==rs&&bus_bru!=0)||(bus_alu==rs&&bus_alu!=0)||
            (bus_lsu==rs&&bus_lsu!=0)||(bus_mul==rs&&bus_mul!=0)||(bus_div==rs&&bus_div!=0));
endfunction

function automatic void press_func(
    input [3:0][38:0] i_rs, input [3:0] press, input [2:0] i_tail,
    output [3:0][38:0] o_rs, output [2:0] o_tail
);
    o_rs = i_rs;
    if (|press) begin
        o_rs[0] = i_rs[1];
        o_rs[1] = i_rs[2];
        o_rs[2] = i_rs[3];
        o_rs[3] = 0;
        o_tail = i_tail - 1;
    end else begin
        o_tail = i_tail;
    end
endfunction

// ==================== 组合逻辑：仲裁 → 压缩 → 唤醒 ====================
always_comb begin
    // 1. 仲裁
    for(int i=0;i<4;i++) begin
        if(bru_rs[i][5:4]==2'b11) request[i] = bru_rs[i][38] & bru_rs[i][25] & bru_rs[i][18];
        else if(bru_rs[i][5:4]==2'b10) request[i] = bru_rs[i][38] & bru_rs[i][25];
        else request[i] = bru_rs[i][38];
    end

    grant = 0;
    press = 0;
    if(!bru_recovery && request[0]) begin
        grant = 3'b100;
        press = 4'b1111;
    end

    // 2. 压缩
    press_func(bru_rs, press, tail, after_press, tail_after_press);

    // 3. 唤醒
    after_wake = after_press;
    tail_final = tail_after_press;
    
    if(bru_recovery) begin
        for(int i=tail_after_press;i>0;i--) begin
            after_wake[i-1][38] = 0;
            tail_final--;
        end
    end

    for(int i=0;i<4;i++) begin
        if(after_press[i][38]) begin
            if(after_press[i][5:4]==2'b11) begin
                after_wake[i][25] = equa_func(bus_alu[5:0],(grant[2]&&bru_rs[grant[1:0]][5:4]!=2'b11)?bru_rs[grant[1:0]][11:6]:6'd0,bus_lsu[5:0],bus_mul[5:0],bus_div[5:0],after_press[i][24:19],after_press[i][38],after_press[i][25]);
                after_wake[i][18] = equa_func(bus_alu[5:0],(grant[2]&&bru_rs[grant[1:0]][5:4]!=2'b11)?bru_rs[grant[1:0]][11:6]:6'd0,bus_lsu[5:0],bus_mul[5:0],bus_div[5:0],after_press[i][17:12],after_press[i][38],after_press[i][18]);
            end else if(after_press[i][5:4]==2'b10) begin
                after_wake[i][25] = equa_func(bus_alu[5:0],(grant[2]&&bru_rs[grant[1:0]][5:4]!=2'b11)?bru_rs[grant[1:0]][11:6]:6'd0,bus_lsu[5:0],bus_mul[5:0],bus_div[5:0],after_press[i][24:19],after_press[i][38],after_press[i][25]);
                after_wake[i][18] = 0;
            end else begin
                after_wake[i][25] = 0;
                after_wake[i][18] = 0;
            end
        end
    end

    // 4. 发射输出
    if(grant[2]) begin
        instr_valid_select = 1;
        rs1_number_select = bru_rs[grant[1:0]][24:19];
        rs2_number_select = bru_rs[grant[1:0]][17:12];
        rd_number_select = bru_rs[grant[1:0]][11:6];
        rob_id_select = bru_rs[grant[1:0]][37:31];
        bob_id_select = bru_rs[grant[1:0]][30:26];
        bru_control_select = bru_rs[grant[1:0]][2:0];
        reg_write_select = bru_rs[grant[1:0]][3];
        instr_type_select = bru_rs[grant[1:0]][5:4];
    end else begin
        instr_valid_select = 0;
        rs1_number_select = 0;
        rs2_number_select = 0;
        rd_number_select = 0;
        rob_id_select = 0;
        bob_id_select = 0;
        bru_control_select = 0;
        reg_write_select = 0;
        instr_type_select = 0;
    end

    bus_valid_bru = (grant[2] && bru_rs[grant[1:0]][5:4]!=2'b11) ? {1'b1, bru_rs[grant[1:0]][11:6]} : 0;

    // 5. 有效指令数
    count_temp = 0;
    if(instr_valid1) count_temp++;
    if(instr_valid2) count_temp++;

    // 6. 剩余空间 + 满信号
    free_space = 4 - tail_final;
    iq2_full = (count_temp > free_space);
end

// ==================== 时序逻辑：最后写入 ====================
always_ff @(posedge clk) begin
    if(reset) begin
        bru_rs <= 0;
        tail <= 0;
    end else begin
        // 先把 仲裁+压缩+唤醒 的结果存回去
        bru_rs <= after_wake;

        // 最后写入新指令
        if(!bru_recovery && !iq2_full) begin
            if(count_temp == 1) begin
                bru_rs[tail_final] <= instr_valid1 ? bru_rs1 : bru_rs2;
                tail <= tail_final + 1;
            end else if(count_temp == 2) begin
                bru_rs[tail_final]   <= bru_rs1;
                bru_rs[tail_final+1] <= bru_rs2;
                tail <= tail_final + 2;
            end else begin
                tail <= tail_final;
            end
        end else begin
            tail <= tail_final;
        end
    end
end

endmodule
