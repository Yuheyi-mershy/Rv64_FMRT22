module bru_ex(

    //从PRF输出用于判断执行的信号 
    input logic [1:0] instr_type_ex,
    input logic reg_write_ex,
    input logic [2:0] bru_control_ex,
    input logic [6:0] rob_id_ex,
    input logic instr_valid_ex, 
   
    //数据来源于BOB
    input logic [63:0] pc_ex,   
    input logic [63:0] pre_adr_ex,
    input logic pre_taken_ex,
    input logic [63:0] dec_adr_ex,
    input logic GPHT_pre_taken_ex,
    input logic BPHT_pre_taken_ex,
    input logic btb_hit_ex,
    input logic is_return_ex,
   

    //用以转发的内容
    input logic [63:0] rs1_value_ex,  
    input logic [63:0] rs2_value_ex,
    input logic [63:0] alu_value_wb,            // ALU部件传过来的值
    input logic [63:0] bru_value_wb,            // BRU阶段值
    input logic [63:0] mul_value_wb,            // MUL阶段值
    input logic [63:0] div_value_wb,            // DIV部件传过来的值
    input logic [63:0] lsu_value_wb,            // LSU阶段值
    input logic [2:0] forward1,
    input logic [2:0] forward2,
    
    //用于输出
    output logic complete_ex,
    output logic [63:0] adr_ex,  
    output logic bru_recovery_ex,
    output logic btb_wirte_ex,
    output logic [63:0] rd_value_ex,
    output logic [1:0] G_or_B_ex,
    output logic is_btype,
    output logic reg_write_en1,
    output logic taken_ex
);

    logic [63:0] src1;
    logic [63:0] src2, op2;
    logic [63:0] addr_temp;
    logic taken_temp;
    logic s1;   //判断BRU第二个操作数
    logic s2;   //判断MUX3/RD的操作数
    logic [1:0] s3; //判断真正的PC
    logic s4;     //判断地址预测正确否
    logic s5;    //判断预测方向正确否
    logic s6;   //判断RD寄存器写的值
    logic s7;   //判断真正的方向
    logic [63:0] rd_src_temp;
    logic [63:0]rd_2;  // 添加缺失的信号
    logic adr_correct, direct_correct;
    logic pre_adr_correct, pre_direct_correct;
    logic pre_adr_correct_temp, pre_direct_correct_temp;
    logic ss1, ss2;
    logic complete_temp;
    
    //定义s1,s2,s3,s4,s5,s6,s7信号;
    assign s1 = (instr_type_ex == 2'b10);
    assign is_btype =(instr_type_ex == 2'b11);
    assign s2 = ((instr_type_ex == 2'b11) & (~taken_temp));
    assign s4 = (instr_type_ex == 2'b10);
    assign s5 = (instr_type_ex == 2'b11);
    assign s6 = (instr_type_ex == 2'b01);
    assign s7 = (instr_type_ex == 2'b01);
    assign reg_write_en1 = reg_write_ex & instr_valid_ex;
    
    always_comb begin
       if(instr_type_ex == 2'b11) begin
          s3 = 2'b10;
       end
       else if(instr_type_ex == 2'b10) begin
          s3 = 2'b01;
       end
       else begin
          s3 = 2'b00;
       end
    end
    
    // 数据转发 - 源操作数1的选择
    mux6_bru #(64) SRC1(
        .a0(rs1_value_ex),
        .a1(alu_value_wb),
        .a2(bru_value_wb),
        .a3(mul_value_wb),
        .a4(div_value_wb),
        .a5(lsu_value_wb),
        .forward(forward1),
        .b(src1)
    );
    
    // 数据转发 - 源操作数2的选择
    mux6_bru #(64) OP2(
        .a0(rs2_value_ex),
        .a1(alu_value_wb),
        .a2(bru_value_wb),
        .a3(mul_value_wb),
        .a4(div_value_wb),
        .a5(lsu_value_wb),
        .forward(forward2), 
        .b(op2)             
    );

    // 第二个操作数的选择
    mux2_bru #(64) SRC2(
        .a(op2),
        .b(dec_adr_ex), //对B格式来说是src2,对于其他的格式主要是JALR来说是imm
        .select(s1),
        .c(src2)
    );

    // BRU计算核心
    bru_core bru_inst(  // 实例化名称改为 bru_inst
        .src1(src1),
        .src2(src2),
        .bru_control(bru_control_ex),
        .addr(addr_temp),
        .taken(taken_temp),
        .complete(complete_temp)
    );

      // 决定RD寄存器的一个值
    assign rd_src_temp = pc_ex + 64'd4;
    mux2_bru #(.WIDTH(64)) value(
        .a(dec_adr_ex),
        .b(rd_src_temp),
        .select(s2),
        .c(rd_2)
    );
    
    mux3_bru #(64) true_adr( 
        .a(dec_adr_ex),
        .b(addr_temp),
        .c(rd_2),
        .select(s3),
        .d(adr_ex)
    );
    
    // 选择真正的方向
mux2_bru #(1) true_direct(
    .a(taken_temp),  // 【不是AUIPC】→ 输出正确的分支/跳转结果
    .b(1'b0),        // 【是AUIPC】→ 输出0
    .select(s7),     // s7=1 → AUIPC，选0；s7=0 → 选正确结果
    .c(taken_ex)
);

    // 地址比较器和方向比较器
    assign adr_correct = (pre_adr_ex == adr_ex);
    assign direct_correct = (pre_taken_ex == taken_ex);

    // 判断方向预测正确否，地址预测正确否 - 修正：使用 .WIDTH(1)
    mux2_bru #(.WIDTH(1)) correct_adr(
        .a(adr_correct),
        .b(1'b1),
        .select(~s4),
        .c(pre_adr_correct)
    );
    
    mux2_bru #(.WIDTH(1)) correct_direct(
        .a(direct_correct),
        .b(1'b1),
        .select(~s5),
        .c(pre_direct_correct)
    );

    // 定义PC_recovery信号
    assign pre_adr_correct_temp = ~pre_adr_correct;
    assign pre_direct_correct_temp = ~pre_direct_correct;
    assign bru_recovery_ex = ((pre_adr_correct_temp) | (pre_direct_correct_temp)) & instr_valid_ex;
    
    // 定义真正的目的寄存器的内容 - 修正：使用 .WIDTH(64)
    mux2_bru #(.WIDTH(64)) rd_value_mux(
        .a(adr_ex),
        .b(rd_2),
        .select(~s6),
        .c(rd_value_ex)
    );
    // 定义了BTB的恢复信号产生
    assign ss1 = pre_adr_correct_temp & btb_hit_ex & (~is_return_ex);
    assign ss2 = (~btb_hit_ex) & (taken_ex) & (~is_return_ex);
    assign btb_wirte_ex = instr_valid_ex & (ss1 | ss2);
   

    assign G_or_B_ex = {GPHT_pre_taken_ex, BPHT_pre_taken_ex};

    // 定义complete信号
    assign complete_ex = complete_temp & instr_valid_ex;

endmodule
