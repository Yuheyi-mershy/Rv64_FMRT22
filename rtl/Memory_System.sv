module Memory_System(
    input logic clk,
    input logic reset,
    
    // 处理器接口 - 指令侧
    input logic [38:0] I_VA,          // 指令虚拟地址
    input logic IT_req_in,           // 指令缓存请求
    input logic IC_dataout_rdy,      // 处理器准备好接收指令
    output logic I_hit,              // 指令命中
    output logic [127:0] I_data_out, // 指令数据输出
    output logic [11:0] Br_type_out, // 分支类型输出
    output logic IC_dataout_val,     // 用于IB
    
    // 处理器接口 - 数据侧
    input logic [38:0] D_VA,          // 数据虚拟地址
    input logic [63:0] St_data,       // Store指令的写操作数
    input logic [1:0] St_type,        // Store指令的写操作类型
    input logic Ld_en,               // Load指令访问信号
    input logic St_en,               // Store指令访问信号（来自SB，受ROB控制）
    input logic DC_dataout_rdy,      // 流水线输入
    output logic D_hit,              // 数据命中
    output logic [63:0] D_data_out,   // 数据输出
    output logic DC_dataout_val,     // 流水线输出
    input logic[38:0] SD_VA,
    
    // 外部控制信号
    input logic pause_signal,         // （暂停信号）
    input logic BRU_recovery
);

    // ========== 内部连线声明 ==========
    // I-TLB相关
    logic [31:0] IT_PA;
    logic IT_hit;
    logic IT_req;
    logic IT_grant;
    logic [38:0] IT_miss_va;
    logic IT_datain_rdy;                    
    logic IT_access_done;             
    
    // I-Cache相关
    logic IC_hit;
    logic [31:0] IC_addr;
    logic [127:0] IC_data_out_local;
    logic IC_req;
    logic IC_grant;
    logic IC_datain_rdy;
    logic IC_done;                    
    
    // D-TLB相关
    logic [31:0] DT_PA;
    logic DT_hit;
    logic DT_req;
    logic DT_grant;
    logic [38:0] DT_miss_va;
    logic DT_datain_rdy;                 
    logic DT_access_done;             
    
    // D-Cache相关
    logic DC_hit;
    logic [31:0] DC_addr;
    logic [127:0] DC_dirty_data;
    logic DC_req;
    logic DC_grant;
    logic DC_datain_rdy;
    logic DC_dirty;
    logic [31:0] DC_dirty_addr;
    logic DC_done;                    
    
    // 存储器选择器相关
    logic mem_IC_grant, mem_DC_grant, mem_IT_grant, mem_DT_grant;
    
    // 主存相关
    logic [127:0] mem_out;
    logic mem_data_valid;
    logic [31:0] mem_read_addr;      
    logic [31:0] mem_write_addr;     
    logic mem_write_en;
    logic [127:0] mem_write_data;
    logic mem_datain_rdy;
    
    logic IT_grant_delayed;                                //2
    logic DT_grant_delayed;
    // 页表遍历单元相关
    logic [31:0] PT_addr;
    logic PT_grant;
    
    // 预解码相关
    logic [11:0] br_type_decoded;
    
    // TLB访问控制相关
    logic [1:0] IT_access_counter;    
    logic [1:0] DT_access_counter;    
    logic IT_access_active;           
    logic DT_access_active;           

    logic [1:0] IT_access_counter_delayed;  // 延迟一个周期的IT_access_counter
    logic [1:0] DT_access_counter_delayed;  // 延迟一个周期的DT_access_counter

    logic [38:0] VA;
    // ========== 模块实例化 ==========
    
    // 1. I-TLB实例
    I_TLB i_tlb_inst(
        .clk(clk),
        .reset(reset),
        .VA(I_VA),
        .IT_data_in(mem_out),
        .IT_grant(mem_IT_grant),
        .IT_datain_val(IT_access_done),  
        .IT_pause(pause_signal),
        .IT_req_in(IT_req_in),
        
        .PA(IT_PA),
        .hit(IT_hit),
        .IT_datain_rdy(IT_datain_rdy),                    
        .IT_req(IT_req),
        .IT_miss_va(IT_miss_va)
    );




    always_comb begin
        if(Ld_en) 
	    VA = D_VA;
	 else
	    VA = SD_VA;
    end    





    // 2. D-TLB实例（Load和Store共享）
    D_TLB d_tlb_inst(
        .clk(clk),
        .reset(reset),
        .VA(VA),
        .DT_data_in(mem_out),
        .DT_grant(mem_DT_grant),
        .DT_datain_val(DT_access_done),  
        .DT_pause(BRU_recovery),
        .DC_req_in(Ld_en | St_en),
        
        .PA(DT_PA),
        .hit(DT_hit),
        .DT_datain_rdy(DT_datain_rdy),                   
        .DT_req(DT_req),
        .DT_miss_va(DT_miss_va)
    );
    


    // 3. I-Cache实例
    I_Cache i_cache_inst(
        .clk(clk),
        .reset(reset),
        .IT_PA(IT_PA),
        .IC_data_in(mem_out),
        .Br_type_in(br_type_decoded),
        .IC_pause(pause_signal),
        .IC_datain_val(mem_data_valid),
        .IC_grant(mem_IC_grant),
        .IT_hit(IT_hit),
        .IC_dataout_rdy(IC_dataout_rdy),                  
        .IC_req_in(IT_req_in),
        
        .hit(IC_hit),
        .IC_addr(IC_addr),
        .Br_type_out(Br_type_out),
        .IC_data_out(IC_data_out_local),
        .IC_datain_rdy(IC_datain_rdy),                
        .IC_req(IC_req),
        .IC_dataout_val(IC_dataout_val)                 
    );
    



    // 4. D-Cache实例
    D_Cache d_cache_inst(
        .clk(clk),
        .reset(reset),
        .DT_PA(DT_PA),
        .DC_data_in(mem_out),
        .DC_datain_val(mem_data_valid),
        .DC_dataout_rdy(1'b1),          // 流水线输入
        .DC_grant(mem_DC_grant),
        .St_data(St_data),
        .St_type(St_type),
        .Ld_en(Ld_en),
        .St_en(St_en),
        .DC_pause(BRU_recovery),
        .DT_hit(DT_hit),
        
        .hit(DC_hit),
        .DC_addr(DC_addr),
        .Dirty_data(DC_dirty_data),
        .DC_datain_rdy(DC_datain_rdy),            
        .DC_dataout_val(DC_dataout_val),          // 流水线输出
        .DC_req(DC_req),
        .dirty(DC_dirty),
        .Dirty_addr(DC_dirty_addr),
        .Data_ld(D_data_out)
    );
    
    // 5. 主存实例
    main_memory main_mem_inst(
        .clk(clk),
        .reset(reset),
        .Mem_in(mem_write_data),
        .Mem_addr_w(mem_write_addr),     
        .Mem_addr_r(mem_read_addr),      
        .Mem_datain_val(mem_write_en),   
        .Write_en(mem_write_en),
        .Mem_dataout_rdy((IT_datain_rdy | IC_datain_rdy | DT_datain_rdy | DC_datain_rdy)),
        .grant((mem_IC_grant | mem_IT_grant | mem_DC_grant | mem_DT_grant)),
        
        .Mem_out(mem_out),
        .Mem_dataout_val(mem_data_valid),
        .Mem_datain_rdy(mem_datain_rdy)
    );
    
    // 6. 存储器选择器实例
    Memory_select mem_select_inst(
        .clk(clk),                    
        .reset(reset),                
        .IC_req(IC_req),
        .DC_req(DC_req),
        .IT_req(IT_req),
        .DT_req(DT_req),
        .IC_done(IC_hit),            
        .DC_done(DC_hit),            
        .IT_done(IT_hit),            
        .DT_done(DT_hit),
	.recovery(pause_signal),
	.bru_recovery(BRU_recovery),            
        .IC_grant(mem_IC_grant),
        .DC_grant(mem_DC_grant),
        .IT_grant(mem_IT_grant),
        .DT_grant(mem_DT_grant)
    );
    
    // 7. 页表遍历单元实例
    MMU_ITLB_SV39 mmu_tlb_inst(
        .clk(clk),
        .reset(reset),
        .pause(BRU_recovery),
        .tlb_miss(IT_req | DT_req),
        .miss_va(IT_req ? IT_miss_va : DT_miss_va),
        .pt_data(mem_out),
        .pt_grant(PT_grant),
        .pt_datain_val(((IT_grant_delayed & mem_IT_grant) | (DT_grant_delayed & mem_DT_grant))),
        .DT_grant(mem_DT_grant),
	.IT_grant(mem_IT_grant),
        .pt_addr(PT_addr)
    );
    
    // 8. 预解码器实例
    Pre_decode pre_decode_inst(
        .instrutions(mem_out),
        .PD(br_type_decoded)
    );
    
    // ========== TLB访问控制逻辑 ==========
    
    
    
    always_ff @(posedge clk) begin
        if (reset) begin
            IT_access_counter <= 2'b00;
            IT_access_active <= 1'b0;
            IT_grant_delayed <= 1'b0;
        end else begin
            // 延迟grant信号以匹配mem_data_valid
            IT_grant_delayed <= mem_data_valid;
            
            if (mem_IT_grant && IT_req && !IT_access_active) begin
                // 开始页表遍历
                IT_access_active <= 1'b1;
                IT_access_counter <= 2'b00;
            end
            
            // 当收到有效数据时增加计数器
            if (IT_access_active & IT_grant_delayed) begin
                IT_access_counter <= IT_access_counter + 1;
            end
            
            // 完成条件：完成3次访问后（计数器从0到2）
            if (IT_access_active && (IT_access_counter == 2'b10)) begin
                IT_access_active <= 1'b0;
            end
        end
    end
    
    // D-TLB三级页表访问控制
    
    
    always_ff @(posedge clk) begin
        if (reset) begin
            DT_access_counter <= 2'b00;
            DT_access_active <= 1'b0;
            DT_grant_delayed <= 1'b0;
        end else begin
            // 延迟grant信号以匹配mem_data_valid
            DT_grant_delayed <= mem_data_valid;
            
            if (mem_DT_grant && DT_req && !DT_access_active) begin
                // 开始页表遍历
                DT_access_active <= 1'b1;
                DT_access_counter <= 2'b00;
            end
            
            // 当收到有效数据时增加计数器
            if (DT_access_active && DT_grant_delayed) begin
                DT_access_counter <= DT_access_counter + 1;
            end
            
            // 完成条件：完成3次访问后
            if (DT_access_active && (DT_access_counter == 2'b10)) begin
                DT_access_active <= 1'b0;
            end
        end
    end
    
    // ========== 完成信号生成逻辑 ==========
    
     always_ff @(posedge clk) begin
        if (reset) begin
            IT_access_counter_delayed <= 2'b00;
            DT_access_counter_delayed <= 2'b00;
        end else begin
            // 延迟一个周期的计数器值
            IT_access_counter_delayed <= IT_access_counter;
            DT_access_counter_delayed <= DT_access_counter;
        end
    end
    
    // ========== 完成信号生成逻辑 ==========
    
    // I-TLB完成：使用延迟一个周期的计数器值
    assign IT_access_done = (IT_access_counter_delayed == 2'b10) & mem_data_valid;  
    
    // D-TLB完成：使用延迟一个周期的计数器值
    assign DT_access_done = (DT_access_counter_delayed == 2'b10) & mem_data_valid;  

    // I-Cache完成：当获得grant且数据有效时完成一次访问
    assign IC_done = mem_IC_grant & mem_data_valid;
    
    // D-Cache完成：分为两种情况
    assign DC_done = mem_DC_grant & mem_data_valid;
    
    // ========== 主存访问控制逻辑 ==========
    always_comb begin
        // 初始化地址
        mem_read_addr = 32'b0;
        mem_write_addr = 32'b0;
        mem_write_en = 1'b0;
        mem_write_data = 128'b0;
        
        // 读地址逻辑：哪个模块获得了grant，就用哪个模块的地址
        if (mem_IT_grant && IT_req) begin
            // I-TLB页表遍历获得授权
            mem_read_addr = PT_addr;
        end else if (mem_DT_grant && DT_req) begin
            // D-TLB页表遍历获得授权
            mem_read_addr = PT_addr;
        end else if (mem_IC_grant && IC_req) begin
            // I-Cache缺失获得授权
            mem_read_addr = IC_addr;
        end else if (mem_DC_grant && DC_req) begin
            // D-Cache获得授权
            mem_read_addr = DC_addr;
        end
        
        // 写地址逻辑：只有D-Cache脏块写回时才需要写
        if (DC_dirty && mem_DC_grant && DC_req) begin
            // D-Cache脏块写回
            mem_write_addr = DC_dirty_addr;
            mem_write_en = 1'b1;
            mem_write_data = DC_dirty_data;      
        end
    end
    
    // ========== 内部连接 ==========
    
    // 处理器接口连接
    assign I_hit = IC_hit;
    assign I_data_out = IC_data_out_local;
    assign D_hit = DC_hit;
    
    // 页表遍历授权信号：当TLB获得授权时，页表遍历单元也获得授权
    assign PT_grant = (mem_IT_grant && IT_req) || (mem_DT_grant && DT_req);

endmodule
