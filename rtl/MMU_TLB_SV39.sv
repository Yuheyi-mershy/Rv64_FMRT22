module MMU_ITLB_SV39 (
    input logic clk,
    input logic reset,
    input logic pause,                
    input logic tlb_miss,            
    input logic [38:0] miss_va,      
    input logic [127:0] pt_data,     // 页表数据（128位，一次读两个PTE）
    input logic pt_grant,            // 总线授予
    input logic pt_datain_val,       // 数据有效
    input logic DT_grant,
    input logic IT_grant,
    output logic [31:0] pt_addr     // 页表访问地址

);

    // ============== 内部信号声明 ==============
    // SATP寄存器
    logic [63:0] satp_reg;
    logic [19:0] root_ppn;  // 根页表PPN
    
    // 状态机
    logic state;  // 0=IDLE, 1=PAGE_WALK
    
    // 地址锁存
    logic [38:0] current_va;
    
    // 页表遍历状态
    logic [1:0] pt_level;  // 00=level2, 01=level1, 10=level0
    
    // PTE相关
    logic [63:0] selected_pte;
    logic leaf_pte;
    logic pte_valid;
    logic h1;
    logic h2;
    // ============== SATP逻辑 ==============
    // 固定为Sv39模式（MODE=8）
    // PPN字段使用[43:24]位（20位，适合32位物理地址）
    assign root_ppn = satp_reg[43:24];
    
    // SATP寄存器更新逻辑（只在初始化时写一次）
    always_ff @(posedge clk) begin
        if (reset) begin
            // 复位时：MODE=8(Sv39), PPN=0
            satp_reg <= {4'h8, 40'h00100, 20'b0}; // {MODE=8, ASID=0, PPN=0}
        end
    end

    always_ff @(posedge clk) begin
       h1 <= pt_datain_val;
       h2 <= h1;     
    end



    
    // ============== 组合逻辑 ==============

    
    // 页表遍历地址计算
    always_comb begin
        if (state && ~pause) begin  // 暂停时不输出有效地址
            case (pt_level)
                2'b00: pt_addr = {root_ppn, 12'b0} + {current_va[38:30], 3'b0};
                2'b01: pt_addr = {selected_pte[29:10], 12'b0} + {current_va[29:21], 3'b0};
                2'b10: pt_addr = {selected_pte[29:10], 12'b0} + {current_va[20:12], 3'b0};
                default: pt_addr = 32'b0;
            endcase
        end else begin
            pt_addr = 32'b0;
        end
    end
    
    // 当前选择的PTE（根据虚拟地址bit[3]选择高64位或低64位）
    assign selected_pte = 1'd0 ? pt_data[127:64] : pt_data[63:0];
    
    // PTE有效性和叶子判断
    assign pte_valid = selected_pte[0];
    assign leaf_pte = |selected_pte[3:1];  // R/W/X任意一个为1
    
    // ============== 时序逻辑 ==============
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= 0;
            pt_level <= 2'b00;
            current_va <= 39'b0;
        end else begin
            if (pause) begin
                // 暂停时立即恢复到空闲状态
                state <= 0;
                pt_level <= 2'b00;
                current_va <= 39'b0;
            end else begin
                // 正常状态转移
                case (state)
                    // IDLE状态
                    0: begin
                        if (tlb_miss && pt_grant) begin
                            // TLB缺失且总线空闲，进入页表遍历
                            state <= 1;
                            current_va <= miss_va;  // 从TLB获取缺失地址
                            pt_level <= 2'b00;      // 从Level 2开始
                        end
                    end
                    
                    // PAGE_WALK状态
                    1: begin
                        if (pt_datain_val& IT_grant) begin
                            if (pte_valid && leaf_pte) begin
                                // 找到有效的叶子PTE，返回IDLE
                                state <= 0;
                            end else if (pte_valid && !leaf_pte && pt_level < 2'b10) begin
                                // 有效的非叶子PTE，继续下一级
                                pt_level <= pt_level + 1;
                            end else begin
                                // 无效PTE或其他情况，返回IDLE
                                state <= 0;
                            end
                        end
                        
                        if (h2& DT_grant) begin
                            if (pte_valid && leaf_pte) begin
                                // 找到有效的叶子PTE，返回IDLE
                                state <= 0;
                            end else if (pte_valid && !leaf_pte && pt_level < 2'b10) begin
                                // 有效的非叶子PTE，继续下一级
                                pt_level <= pt_level + 1;
                            end else begin
                                // 无效PTE或其他情况，返回IDLE
                                state <= 0;
                            end
                        end
                        
                        // 如果总线授权丢失，也返回IDLE
                        if (!pt_grant) begin
                            state <= 0;
                        end
                    end
                endcase
            end
        end
    end
    
endmodule

