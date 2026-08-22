module store_buffer(
    input  logic        clk,
    input  logic        reset,
    
    //store指令写storebuffer
    input  logic        bru_recovery,
    input  logic [6:0]  rob_id_wb,
    input  logic [6:0]  bru_rob_id,
    input  logic [63:0] rs2_value_wb,
    input  logic [63:0] vA_wb,
    input  logic [3:0]  lsu_control_wb2,
    input  logic        instr_valid_wb,
    input  logic [3:0]  grant_store,
    
    //写storebuffer完成
    output logic        complete_store,
    output logic [3:0]  grant_store_end,
    output logic [6:0]  store_rob_id, 
    input  logic        complete_load_end,
    input  logic [3:0]  grant_load,

    //load指令读storebuffer
    input  logic [3:0]  lsu_control1,
    input  logic [63:0] load_virtual_addr,
    input  logic        load_valid,
    input  logic [6:0]  load_rob_id,
    output logic        load_match,
    output logic [63:0] load_match_data,

    //store指令影响仲裁退休写store buffer
    input  logic        cache_write_complete,
    input  logic        fsm_free,
    output logic        retire,
    output logic        full,
    output logic [63:0] retire_data,
    output logic [63:0] retire_addr,
    output logic [3:0]  retire_lsu_control,
    
    input  logic [1:0]  retire_en
);

    logic [6:0]  sb_rob_id [31:0];
    logic [63:0] sb_reg_value [31:0];
    logic [63:0] sb_virtual_addr [31:0];
    logic [3:0]  sb_lsu_control [31:0];
    
    logic [5:0] head_pointer, head_ptr_next;
    logic [5:0] tail_pointer, tail_ptr_next;
    logic [5:0] counter_reg, counter_comb;
    logic empty;
    
    logic write_enable;
    logic cache_retire_enable;
    logic [5:0] number;
    logic [5:0] counter_delta;
    logic       h3,h4,h7,h8;
    logic [6:0] h2;
    logic [5:0] h1, h5,h6;

    // ==================== 新增：grant 调整逻辑 ====================
    logic [3:0] grant_store_final;

    assign empty = (tail_pointer[4:0] == head_pointer[4:0]) && (tail_pointer[5] == head_pointer[5]);
    assign full  = (tail_pointer[4:0] == head_pointer[4:0]) && (tail_pointer[5] != head_pointer[5]);
    
    assign write_enable = (!full && instr_valid_wb && lsu_control_wb2[3]) ? 1'b1 : 1'b0;
    assign cache_retire_enable = (cache_write_complete && !empty) ? 1'b1 : 1'b0;

    always_comb begin
        case(retire_en) 
            2'b00: number = 6'd0;
            2'b01: number = 6'd1;
            2'b11: number = 6'd2;
            default: number = 6'd0;
        endcase
    end

    always_comb begin
        counter_delta = number - {5'd0, cache_retire_enable};
        counter_comb = counter_reg + counter_delta;
    end

always_comb begin
    head_ptr_next = head_pointer;
    tail_ptr_next = tail_pointer;

    if (cache_retire_enable) begin
        head_ptr_next = head_pointer + 6'd1;
    end

 if (bru_recovery) begin
    tail_ptr_next = tail_pointer;
    for(int i=0; i<32; i++) begin
        if(tail_ptr_next == head_ptr_next) break;
        
        h1 = tail_ptr_next - 6'd1;
        h1 = h1 & 6'b11111;
        
        h2 = sb_rob_id[h1[4:0]];
        h3 = h2[6];
        h4 = bru_rob_id[6];
        h5 = sb_rob_id[h1[4:0]][5:0];
        h6 = bru_rob_id[5:0];
        h7 = (h4 == h3);
        h8 = (h5 > h6);
        
        if((h7&h8)||((~h7)&(~h8))) begin
            tail_ptr_next = tail_ptr_next - 6'd1;
        end
        else begin
            break;
        end
    end
end
    else begin
        if(write_enable) begin
            tail_ptr_next = tail_pointer + 6'd1;
        end
    end
end

// ==================== ✅ 核心：grant_store_end 调整逻辑（你要的功能） ====================
always_comb begin
    // 默认：直接输出原始 grant
    grant_store_final = grant_store;

    // 只有在 load 完成、且 load grant 有效时，才做调整
    if (complete_load_end && grant_load[3]) begin
        if (grant_load[2:0] < grant_store[2:0]) begin
            // load 索引更小 → store grant 减 1
            grant_store_final = grant_store - 4'd1;
        end
        // load 索引更大 → 不做操作
    end
end

always_ff @(posedge clk) begin
    if (reset) begin
        head_pointer <= 6'd0;
        tail_pointer <= 6'd0;
        counter_reg <= 6'd0;
        complete_store <= 1'b0;
        grant_store_end <= 4'd0;
        store_rob_id<= 7'd0;
        
        for (int i = 0; i < 32; i = i + 1) begin
            sb_rob_id[i] <= 7'b0;
            sb_reg_value[i] <= 64'b0;
            sb_virtual_addr[i] <= 64'b0;
            sb_lsu_control[i] <= 4'b0;
        end
    end
    else begin
        head_pointer <= head_ptr_next;
        tail_pointer <= tail_ptr_next;
        counter_reg <= counter_comb;

        complete_store <= 1'b0;
        grant_store_end <= 5'd0;
        store_rob_id<= 7'd0;

        if (bru_recovery) begin
            for (int i = 0; i < 32; i++) begin
                if ((i[4:0] >= tail_ptr_next[4:0]) && (i[4:0] < tail_pointer[4:0])) begin
                    sb_rob_id[i] <= 7'd0;
                    sb_reg_value[i] <= 64'b0;
                    sb_virtual_addr[i] <= 64'b0;
                    sb_lsu_control[i] <= 4'b0;
                end
            end
        end
        else begin
            if (write_enable) begin
                sb_lsu_control[tail_pointer[4:0]] <= lsu_control_wb2;
                sb_virtual_addr[tail_pointer[4:0]] <= vA_wb;
                sb_reg_value[tail_pointer[4:0]] <= rs2_value_wb;
                sb_rob_id[tail_pointer[4:0]] <= rob_id_wb;
                complete_store <= 1'b1;
                store_rob_id <= rob_id_wb;
                grant_store_end <= grant_store_final;  // ✅ 使用调整后的 grant
            end
            
            if (cache_retire_enable) begin
                sb_rob_id[head_pointer[4:0]] <= 7'b0;
                sb_reg_value[head_pointer[4:0]] <= 64'b0;
                sb_virtual_addr[head_pointer[4:0]] <= 64'b0;
                sb_lsu_control[head_pointer[4:0]] <= 4'b0;
            end
        end
    end
end

always_comb begin
    load_match = 1'b0;
    load_match_data = 64'd0;
    retire = 1'b0;
    retire_data = 64'd0;
    retire_addr = 64'd0;
    retire_lsu_control = 4'd0;
    
    if (!bru_recovery) begin
        if (~lsu_control1[3] && !empty && load_valid) begin
            logic [5:0] idx;
            idx = tail_pointer - 6'd1;
            
            for (int count = 0; count < 32; count++) begin
                if (sb_virtual_addr[idx[4:0]] == load_virtual_addr) begin
                    if (((sb_rob_id[idx[4:0]][6] == load_rob_id[6] && sb_rob_id[idx[4:0]][5:0] <load_rob_id[5:0]) ||
                          (sb_rob_id[idx[4:0]][6] != load_rob_id[6] && sb_rob_id[idx[4:0]][5:0] > load_rob_id[5:0]))) 
                    begin
                        load_match = 1'b1;
                        load_match_data = sb_reg_value[idx[4:0]];
                        break;
                    end
                end
                
                if (idx == head_pointer) begin
                    break;
                end
                idx = idx - 6'd1;
            end
        end
        
        if (!empty && fsm_free && (counter_comb > 6'd0)) begin
            retire = 1'b1;
            retire_data = sb_reg_value[head_pointer[4:0]];
            retire_addr = sb_virtual_addr[head_pointer[4:0]];
            retire_lsu_control = sb_lsu_control[head_pointer[4:0]];
        end
    end
end

endmodule
