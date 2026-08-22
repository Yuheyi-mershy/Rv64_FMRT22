module top (input logic clk,reset);

    // 处理器接口 - 指令侧
    logic [38:0] I_VA;          // 指令虚拟地址
    logic IT_req_in;           // 指令缓存请求
    logic IC_dataout_rdy;      // 处理器准备好接收指令
    logic I_hit;              // 指令命中
    logic [127:0] I_data_out; // 指令数据输出
    logic [11:0] Br_type_out; // 分支类型输出
    logic IC_dataout_val;     // 用于IB
    
    // 处理器接口 - 数据侧
    logic [38:0] D_VA;          // 数据虚拟地址
    logic [63:0] St_data;       // Store指令的写操作数
    logic [1:0] St_type;        // Store指令的写操作类型
    logic Ld_en;               // Load指令访问信号
    logic St_en;               // Store指令访问信号（来自SB，受ROB控制）
    logic DC_dataout_rdy;      // 流水线输入
    logic D_hit;              // 数据命中
    logic [63:0] D_data_out;   // 数据输出
    logic DC_dataout_val;     // 流水线输出
    
    // 外部控制信号
    logic pause_signal;        // （暂停信号）
    logic BRU_recovery;
    logic [38:0] SD_VA;


    //instantiate processor and memories
    RV64IM rv64im(clk,reset,
                  I_VA,IT_req_in,IC_dataout_rdy,I_hit,I_data_out,Br_type_out,IC_dataout_val,
                  D_VA,St_data,St_type,Ld_en,St_en,DC_dataout_rdy,D_hit,D_data_out,DC_dataout_val,SD_VA,
                  pause_signal,BRU_recovery);


    Memory_System memsys(clk,reset,
                         I_VA,IT_req_in,IC_dataout_rdy,I_hit,I_data_out,Br_type_out,IC_dataout_val,
                         D_VA,St_data,St_type,Ld_en,St_en,DC_dataout_rdy,D_hit,D_data_out,DC_dataout_val, SD_VA,
                         pause_signal,BRU_recovery);


endmodule
