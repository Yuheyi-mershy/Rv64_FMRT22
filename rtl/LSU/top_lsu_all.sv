module top_lsu(
    input logic clk,
    input logic reset,
    
    // ==================== 来自前端/译码器的输入（添加 lsu_ 前缀）====================
    input logic [6:0] lsu_rob_id1,
    input logic [6:0] lsu_rob_id2,
    input logic [63:0] lsu_imm1,
    input logic [63:0] lsu_imm2,
    input logic [5:0] lsu_rs1_number1,
    input logic [5:0] lsu_rs2_number1,
    input logic [5:0] lsu_rs1_number2,
    input logic [5:0] lsu_rs2_number2,
    input logic [5:0] lsu_rd_number1,
    input logic [5:0] lsu_rd_number2,
    input logic [3:0] lsu_control1,
    input logic [3:0] lsu_control2,
    input logic lsu_reg_write1,
    input logic lsu_reg_write2,
    input logic [1:0] lsu_instr_type1,
    input logic [1:0] lsu_instr_type2,
    input logic lsu_instr_valid1,
    input logic lsu_instr_valid2,
    
    // 寄存器有效信号
    input logic lsu_rs1_valid1,
    input logic lsu_rs1_valid2,
    input logic lsu_rs2_valid1,
    input logic lsu_rs2_valid2,
    
    // 转发总线（来自其他执行单元）
    input logic [6:0] bus_alu,
    input logic [6:0] bus_mul,
    input logic [6:0] bus_div,
    input logic [6:0] bus_bru,
    
    // 异常和恢复
    input logic bru_recovery,
    input logic [6:0] bru_rob_id,
    input logic [1:0]retire_en,     //ROB传过来的退休store数量
    
    // 来自其他执行单元写回阶段的结果（用于转发）
    input logic [63:0] alu_value_wb,
    input logic [63:0] bru_value_wb,
    input logic [63:0] mul_value_wb,
    input logic [63:0] div_value_wb,
    
    // 来自其他执行单元写回阶段的rd值（用于转发）
    input logic [5:0] alu_rd_wb,
    input logic [5:0] bru_rd_wb,
    input logic [5:0] mul_rd_wb,
    input logic [5:0] div_rd_wb,
    
    // 来自物理寄存器堆的值
    input logic [63:0] lsu_prf_rs1_value_lw,
    input logic [63:0] lsu_prf_rs1_value_sw,
    input logic [63:0] lsu_prf_rs2_value_sw,
    
    // 输出到物理寄存器堆的寄存器号
    output logic [5:0] lsu_rs1_number_prf,
    output logic [5:0] lsu_rs1_number_prf_sw,
    output logic [5:0] lsu_rs2_number_prf_sw,
    
    // ==================== WB接口输出（添加 _wb 后缀）====================
    output logic lsu_reg_write_wb,
    output logic [63:0] lsu_value_wb_end,
    output logic [5:0] lsu_rd_wb,
    output logic [6:0] load_rob_id,
    output logic complete_load_end,
    output logic complete_store_end,
    output logic [6:0] lsu_sw_rob_id,
    
    // 状态信号
    output logic lsu_iq4_full,

    // 输出给CACHE
    input logic [63:0] cache_data,
    input logic cache_valid,
    output logic cache_ready,
    input  logic cache_hit,

    output logic [63:0] retire_data_sb, 
    output logic [1:0] store_type_end,        
    output logic ld_en_end,
    output logic st_en_end,
    output logic [6:0]bus_lsu,
    output logic [63:0]D_VA,
    output logic [63:0]address_store_adr
);
    //IQ4所需要的信号和输出的信号
    logic [63:0] address_end;
    logic sb_full;
    logic fsm_free;
    logic [3:0]complete_grant_lw;
    logic [3:0]complete_grant_sw;
    logic [5:0] rs1_number_select;
    logic [63:0] imm_select;
    logic [5:0] dest_number_select;
    logic [6:0] rob_id_select;
    logic [3:0] lsu_control_select;
    logic reg_write_select;
    logic instr_valid_select;
    logic [3:0] grant_select;
    logic prf_occupied;
    logic [5:0]lsu_rd_wb_in;
    logic [63:0]lsu_value_wb_in;


    // SELECT_PRF_SW的输出信号
    logic [5:0] rs1_number_prf_sw;
    logic [63:0] imm_prf_sw;
    logic [5:0] dest_number_prf_sw;
    logic [6:0] rob_id_prf_sw;
    logic [3:0] lsu_control_prf_sw;
    logic reg_write_prf_sw;
    logic [3:0] grant_prf_sw;
    logic instr_valid_prf_sw;
    logic [3:0]grant_store_prf;
    
     // PRF_EX模块的输出信号
    logic [5:0] rs1_number_ex;
    logic [63:0] imm_ex;
    logic [5:0] dest_number_ex;
    logic [6:0] rob_id_ex;
    logic [3:0] lsu_control_ex;
    logic reg_write_ex;
    logic [3:0] grant_ex;
    logic instr_valid_ex;
    logic [63:0]rs1_value_ex;
    logic [63:0]rs2_value_ex;
    logic [3:0]grant_store_ex;

    //BYPASS模块缺失的端口
    logic [2:0]forward1,forward2;

    // AGU模块的输入信号
    logic complete_ex;
    logic [63:0] adr_value_ex;
    logic [63:0] rs2_value_store_ex;

    // EX_WB模块的输出信号
    logic [63:0] adr_value_wb;
    logic [63:0] rs2_value_store_wb;
    logic [3:0] lsu_control_wb;
    logic [6:0] rob_id_wb;
    logic complete_wb;
    logic instr_valid_wb;
    logic [3:0] grant_store_wb_last;
    logic [3:0] grant_store_wb;
    
    //storebuffer信息
    logic load_match;
    logic [63:0] load_match_data;
    logic retire_sb;
    logic [63:0] retire_data;     
    logic [63:0] retire_addr;
    logic [3:0] retire_lsu_control;

    // SELECT_PRF_LW的输出信号
    logic [5:0] rs1_number_prf_lw;
    logic [63:0] imm_prf_lw;
    logic [5:0] dest_number_prf_lw;
    logic [6:0] rob_id_prf_lw;
    logic [3:0] lsu_control_prf_lw;
    logic reg_write_prf_lw;
    logic [3:0] grant_prf_lw;
    logic instr_valid_prf_lw;
    logic [3:0] lsu_control_1_end;
    logic [63:0]address;
    logic instr_valid_end;
    logic cache_write_complete;
    logic [6:0]bus_lsu_int;
    logic complete1_load_end_int;
    
    assign  lsu_rd_wb_in=lsu_rd_wb;
    assign  lsu_value_wb_in=lsu_value_wb_end;
    


  // ==================== IQ4模块实例化 ====================
    iq4 u_iq4 (
        .clk(clk),
        .reset(reset),
        .rob_id1(lsu_rob_id1),
        .rob_id2(lsu_rob_id2),
        .imm1(lsu_imm1),
        .imm2(lsu_imm2),
        .rs1_number1(lsu_rs1_number1),
        .rs2_number1(lsu_rs2_number1),
        .rs1_number2(lsu_rs1_number2),
        .rs2_number2(lsu_rs2_number2),
        .rd_number1(lsu_rd_number1),
        .rd_number2(lsu_rd_number2),
        .lsu_control1(lsu_control1),
        .lsu_control2(lsu_control2),
        .reg_write1(lsu_reg_write1),
        .reg_write2(lsu_reg_write2),
        .instr_type1(lsu_instr_type1),
        .instr_type2(lsu_instr_type2),
        .instr_valid1(lsu_instr_valid1),
        .instr_valid2(lsu_instr_valid2),
        .bru_recovery(bru_recovery),
        .bru_rob_id(bru_rob_id),
        .bus_alu(bus_alu),
        .bus_mul(bus_mul),
        .bus_div(bus_div),
        .bus_bru(bus_bru),
        .bus_lsu(bus_lsu),
        .rs1_valid1(lsu_rs1_valid1),
        .rs1_valid2(lsu_rs1_valid2),
        .rs2_valid1(lsu_rs2_valid1),
        .rs2_valid2(lsu_rs2_valid2),
        .complete_sb_wb(complete_store_end),
        .complete_load_wb(complete_load_end),
        .sb_full(sb_full),
        .fsm_free(fsm_free),
        .complete_grant1(complete_grant_lw),
        .complete_grant2(complete_grant_sw),
        .rs1_number_select(rs1_number_select),
        .imm_select(imm_select),
        .dest_number_select(dest_number_select),
        .rob_id_select(rob_id_select),
        .lsu_control_select(lsu_control_select),
        .reg_write_select(reg_write_select),
        .iq4_full(lsu_iq4_full),
        .grant_select(grant_select),
        .instr_valid_select(instr_valid_select),
        .prf_occupied(prf_occupied)
    );
    // ==================== SELECT_PRF--SW模块实例化 ====================
    select_prf_sw sw (
        .clk(clk),
        .reset(reset),
        .rs1_number_select(rs1_number_select),
        .imm_select(imm_select),
        .dest_number_select(dest_number_select),
        .rob_id_select(rob_id_select),
        .lsu_control_select(lsu_control_select),
        .reg_write_select(reg_write_select),
        .instr_valid_select(instr_valid_select),
        .bru_recovery(bru_recovery),
        .grant_select(grant_select),
        .sb_full(sb_full),
        .rs1_number_prf(lsu_rs1_number_prf_sw),
        .imm_prf(imm_prf_sw),
        .dest_number_prf(lsu_rs2_number_prf_sw),
        .rob_id_prf(rob_id_prf_sw),
        .lsu_control_prf(lsu_control_prf_sw),
        .reg_write_prf(reg_write_prf_sw),
        .grant_prf(grant_prf_sw),
        .instr_valid_prf(instr_valid_prf_sw)
    );
 
    // ==================== 针对SW的Grant逻辑运算 ====================
    always_comb begin
        if(grant_prf_sw[3]) begin
            if(complete_load_end & complete_store_end) begin
                grant_store_prf = grant_prf_sw - 4'd2;  
            end
            else if(~complete_load_end & complete_store_end) begin
               grant_store_prf = grant_prf_sw - 4'd1;  
            end
            else if(complete_load_end & ~complete_store_end) begin
               grant_store_prf = grant_prf_sw - 4'd1;  
            end
            else begin
                grant_store_prf = grant_prf_sw;  
            end
        end
        else begin
            grant_store_prf = grant_prf_sw;  
        end
    end

    // ==================== PRF_EX模块实例化 ====================
    prf_ex u_prf_ex (
        .clk(clk),
        .reset(reset),
        .rs1_number_prf(lsu_rs1_number_prf_sw),
        .imm_prf(imm_prf_sw),
        .dest_number_prf(lsu_rs2_number_prf_sw),
        .rob_id_prf(rob_id_prf_sw),
        .lsu_control_prf(lsu_control_prf_sw),
        .reg_write_prf(reg_write_prf_sw),
        .instr_valid_prf(instr_valid_prf_sw),
        .bru_recovery(bru_recovery),
        .grant_prf(grant_store_prf),
        .sb_full(sb_full),
        .rs1_value_prf(lsu_prf_rs1_value_sw),
        .rs2_value_prf(lsu_prf_rs2_value_sw),
        .rs1_number_ex(rs1_number_ex),
        .imm_ex(imm_ex),
        .dest_number_ex(dest_number_ex),
        .rob_id_ex(rob_id_ex),
        .lsu_control_ex(lsu_control_ex),
        .reg_write_ex(reg_write_ex),
        .grant_ex(grant_ex),
        .instr_valid_ex(instr_valid_ex),
        .rs1_value_ex(rs1_value_ex),
        .rs2_value_ex(rs2_value_ex)
    );
     
    // ==================== 针对SW的Grant逻辑运算 ====================
    always_comb begin
        if(grant_ex[3]) begin
            if(complete_load_end & complete_store_end) begin
                grant_store_ex = grant_ex - 4'd2;  
            end
            else if(~complete_load_end & complete_store_end) begin
               grant_store_ex = grant_ex - 4'd1; 
            end
            else if(complete_load_end & ~complete_store_end) begin
               grant_store_ex = grant_ex - 4'd1; 
            end
            else begin
                grant_store_ex = grant_ex;  
            end
        end
        else begin
            grant_store_ex = grant_ex;  
        end
    end

    //==================== 实例化BYPASS模块--SW ==============
    bypass_lsu u_bypass (
        .prf_rs1                (rs1_number_ex),
        .prf_rs2                (dest_number_ex),
        .alu_rd                 (alu_rd_wb),
        .bru_rd                 (bru_rd_wb),
        .mul_rd                 (mul_rd_wb),
        .div_rd                 (div_rd_wb),
        .lsu_rd                 (lsu_rd_wb_in),
        .forward1               (forward1),
        .forward2               (forward2)
    );

     // ==================== AGU模块实例化 ====================
    sotre_agu u_agu (
        .imm(imm_ex),
        .instr_valid_ex(instr_valid_ex),
        .rs1_value_ex(rs1_value_ex),
        .rs2_value_ex(rs2_value_ex),
        .alu_value_wb(alu_value_wb),
        .bru_value_wb(bru_value_wb),
        .mul_value_wb(mul_value_wb),
        .div_value_wb(div_value_wb),
        .lsu_value_wb(lsu_value_wb_in),
        .forward1(forward1),
        .forward2(forward2),
        .complete_ex(complete_ex),
        .src2(rs2_value_store_ex),
        .adr_value_ex(adr_value_ex)
    );

    // ==================== EX/WB模块实例化 ====================
    ex_wb u_ex_wb (
        .clk(clk),
        .reset(reset),
        .adr_value_ex(adr_value_ex), 
        .rs2_value_ex(rs2_value_store_ex),
        .lsu_control_ex(lsu_control_ex),
        .rob_id_ex(rob_id_ex),
        .complete_ex(complete_ex),
        .instr_valid_ex(instr_valid_ex),
        .bru_recovery(bru_recovery),
        .sb_full(sb_full),
        .grant_ex(grant_store_ex),
        .adr_value_wb(adr_value_wb),
        .rs2_value_wb(rs2_value_store_wb),
        .lsu_control_wb(lsu_control_wb),
        .rob_id_wb(rob_id_wb),
        .complete_wb(complete_wb),
        .instr_valid_wb(instr_valid_wb),
        .grant_wb(grant_store_wb_last)
    );

     // ==================== 针对SW的Grant逻辑运算 ====================
    always_comb begin
        if(grant_store_wb_last[3]) begin
            if(complete_load_end & complete_store_end) begin
                grant_store_wb = grant_store_wb_last - 4'd2;  
            end
            else if(~complete_load_end & complete_store_end) begin
               grant_store_wb = grant_store_wb_last - 4'd1;  
            end
            else if(complete_load_end & ~complete_store_end) begin
               grant_store_wb = grant_store_wb_last - 4'd1;  
            end
            else begin
                grant_store_wb = grant_store_wb_last;  
            end
        end
        else begin
            grant_store_wb = grant_store_wb_last;  
        end
    end
    
    // ==================== StoreBuffer模块实例化 ====================
    store_buffer u_store_buffer (
        .clk(clk),
        .reset(reset),
        .bru_recovery(bru_recovery),
        .rob_id_wb(rob_id_wb),                  //store指令的rob_id
        .bru_rob_id(bru_rob_id),
        .rs2_value_wb(rs2_value_store_wb),      //要退休的内容
        .vA_wb(adr_value_wb),                   //要退休的地址
        .lsu_control_wb2(lsu_control_wb),       //store指令的信号
        .instr_valid_wb(instr_valid_wb),        //store的有效信号
        .grant_store(grant_store_wb),           //store写S_B的grant表项
        .complete_store(complete_store_end),    //写storebuffer完成的信息，传给ROB
        .grant_store_end(complete_grant_sw),    //store完成grant
        .store_rob_id(lsu_sw_rob_id),           //向ROB输出的ID
        .complete_load_end(complete_load_end),  //FSM传过来的load完成信息
        .grant_load(complete_grant_lw),         //FSM传过来的grant
        .lsu_control1(lsu_control_1_end),       //FSM传过来的load控制信号
        .load_virtual_addr(address_store_adr),            //FSM传过来的虚拟地址
        .load_valid(instr_valid_end),           //FSM传过来的指令有效信号
        .load_rob_id(load_rob_id),              //FSM传过来的ROB_ID
        .load_match(load_match),                //输出S_B是否匹配的信号
        .load_match_data(load_match_data),      //输出S_B的数据
        .cache_write_complete(cache_write_complete),//FSM传过来的写完cache的信号
        .fsm_free(fsm_free),                    //状态机是否空闲的信号
        .retire(retire_sb),                     //当前头指针store是否可以退休
        .full(sb_full),                         //SB_FULL
        .retire_data(retire_data),              //要退休的数据
        .retire_addr(retire_addr),              //要退休的地址
        .retire_lsu_control(retire_lsu_control),//要退休的信号
        .retire_en(retire_en)                   //ROB传过来的退休store数量
    );
 
    
 // ==================== SELECT_PRF--LW模块实例化 ====================
    select_prf u_select_prf_lw (
        .clk(clk),
        .reset(reset),
        .rs1_number_select(rs1_number_select),
        .imm_select(imm_select),
        .dest_number_select(dest_number_select),
        .rob_id_select(rob_id_select),
        .lsu_control_select(lsu_control_select),
        .reg_write_select(reg_write_select),
        .instr_valid_select(instr_valid_select),
        .bru_recovery(bru_recovery),
        .grant_select(grant_select),
        .sb_full(sb_full),
        .fsm_free(fsm_free),
        .rs1_number_prf(lsu_rs1_number_prf),
        .imm_prf(imm_prf_lw),
        .dest_number_prf(dest_number_prf_lw),
        .rob_id_prf(rob_id_prf_lw),
        .lsu_control_prf(lsu_control_prf_lw),
        .reg_write_prf(reg_write_prf_lw),
        .grant_prf(grant_prf_lw),
        .instr_valid_prf(instr_valid_prf_lw),
        .complete_load(complete_load_end),
        .complete_store(complete_store_end),
        .grant_load(complete_grant_lw),
        .grant_store(complete_grant_sw),
        .prf_occupied(prf_occupied)
    );


    // ==================== LOAD_UNIT模块实例化 ====================
    load_unit u_load_unit (
        .clk(clk),
        .reset(reset),
        .load_rob_id(rob_id_prf_lw),                //接受仲裁阶段的LW的信息
        .dest_number(dest_number_prf_lw),           //接受仲裁阶段的LW的信息
        .imm(imm_prf_lw),                           //接受仲裁阶段的LW的信息
        .reg_write(reg_write_prf_lw),               //接受仲裁阶段的LW的信息
        .lsu_control_1(lsu_control_prf_lw),         //接受仲裁阶段的LW的信息
        .instr_valid(instr_valid_prf_lw),           //接受仲裁阶段的LW的信息
        .grant_in(grant_prf_lw),                    //接受仲裁阶段的LW的信息
        .complete_store_end1(complete_store_end),   //S_B传过来的store完成信息   
        .grant_store(complete_grant_sw),            //storebuffer传过来的grant表项信息   

        .rs1_value(lsu_prf_rs1_value_lw),           //rs1_value
        .alu_value_wb(alu_value_wb),               
        .bru_value_wb(bru_value_wb),
        .mul_value_wb(mul_value_wb),
        .div_value_wb(div_value_wb),
        .lsu_value_wb_in(lsu_value_wb_in),
        .prf_rs1(lsu_rs1_number_prf),                //从仲裁送过来的rs1_number
        .alu_rd(alu_rd_wb),
        .bru_rd(bru_rd_wb),
        .mul_rd(mul_rd_wb),
        .div_rd(div_rd_wb),
        .lsu_rd(lsu_rd_wb_in),
        .reg_write_ex(reg_write_prf_lw),            //是从仲裁接受的寄存器写信号，和前面的重复了，但是保留，用于保留

        .sb_full(sb_full),                          //SB传过来的 
        .cache_write(retire_sb),                    //SB传过来的头指针是否可以退休
        .va(retire_addr),                           //SB传过来的虚拟地址是什么
        .rs2_value(retire_data),                    //要退休的数据
        .lsu_control_2(retire_lsu_control),         //要退休的信号
        .complete_store(cache_write_complete),  //FSM输出给SB退休完成的信号
        .bru_recovery(bru_recovery),
        .cache_valid(cache_valid),                      //SW/LOAD都是这个命中信号
        .cache_ready(cache_ready),
        .cache_hit(cache_hit),
        .fsm_free(fsm_free),                        //FSM输出外面空闲的信号
        .reg_write_end(lsu_reg_write_wb),           //load指令写信号给PRF
        .lsu_value_wb_out(lsu_value_wb_end),        //输出给PRF写的数据
        .rd_number_end(lsu_rd_wb),                  //输出给PRF，目的寄存器
         
        .rs2_value_end(retire_data_sb),             //输出给cache的数据
        .store_type_end(store_type_end),            //输出给cache的信号，sb|sh|sd|Sw
        .LD_EN_END(ld_en_end),                      //输出给cache的lw_enable
        .st_en_end(st_en_end),                      //输出给cache的SW_enable
        .sb_data(load_match_data),                  //SB输出的数据匹配的data
        .s_b_match(load_match),                  //SB输出的匹配信号
        .instr_valid_end(instr_valid_end),          //FSM输出给SB的指令有效信号
        .cache_data(cache_data),                    //在cache那边匹配上数据了给FSM_lw指令
        .complete_load_end(complete1_load_end_int),      //load处理完成的信号
        .grant_out(complete_grant_lw),              //load完成的grant表项
        .address_va(address_store_adr),                          //访问SB的地址，为了不差周期给了组合逻辑的值
        .load_rob_id_end(load_rob_id),              //load指令给SB的rob_id
        .lsu_control_1_end(lsu_control_1_end),      //传给store buffer的load指令的信号
        .bus_lsu(bus_lsu_int),
        .address_temp_end(D_VA)
    );
   
    always_comb  begin
        if(bru_recovery)   begin
            bus_lsu=7'd0;
            complete_load_end=1'd0;
        end
        else  begin
           bus_lsu=bus_lsu_int;
           complete_load_end=complete1_load_end_int;
        end
    end
endmodule


