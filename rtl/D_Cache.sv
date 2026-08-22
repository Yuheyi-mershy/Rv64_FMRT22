module D_Cache(
    input logic clk,
    input logic reset,
    input logic [31:0] DT_PA,    // D-TLB输出的物理地址
    input logic [127:0] DC_data_in,     // 主存写入D-Cache数据
    input logic DC_datain_val,   // 输入数据的有效信号
    input logic DC_dataout_rdy,  // 输出数据的就绪信号
    input logic DC_grant,        // 使用总线的授权信号
    input logic [63:0] St_data,  // Store指令的写操作数
    input logic [1:0] St_type,   // Store指令的写操作类型
    input logic Ld_en,           // Load指令访问信号
    input logic St_en,           // Store指令访问信号
    input logic DC_pause,        // 分支指令恢复是否完成
    input logic DT_hit,          // D-TLB命中信号
    
    output logic hit,            // D-Cache访问命中
    output logic [31:0] DC_addr, // {tag,Page_offset}物理地址
    output logic [127:0] Dirty_data, // D-Cache脏数据
    output logic DC_datain_rdy,  // 输入数据的就绪信号
    output logic DC_dataout_val, // 输出数据的有效信号
    output logic DC_req,         // 总线使用请求信号
    output logic dirty,          // 写回主存脏数据信号
    output logic [31:0] Dirty_addr, // {tag[旧],Page_offset}物理地址
    output logic [63:0] Data_ld  // Load指令取到的数据
);

    // ========== 存储单元定义 ==========
    // 两路组相联，每组2个路，共128组
    logic valid_way0 [127:0];
    logic valid_way1 [127:0];
    logic dirty_way0 [127:0];
    logic dirty_way1 [127:0];
    logic [20:0] tag_way0 [127:0];    // 21位Tag
    logic [20:0] tag_way1 [127:0];
    logic [127:0] data_way0 [127:0];  // 128位数据
    logic [127:0] data_way1 [127:0];
    logic lru [127:0];                // LRU位：0=way0最近使用，1=way1最近使用
    
    // ========== 地址解析 ==========
    logic [20:0] tag_in;
    logic [6:0] index_in;
    logic [3:0] offset_in;
    
    // ========== 内部信号 ==========
    logic cache_hit;               // Cache命中信号
    logic hit_way0, hit_way1;      // 各路命中信号
    logic valid0_cache, valid1_cache;  // 各路有效位
    logic dirty0_cache, dirty1_cache;  // 各路脏位
    logic [20:0] tag0_cache, tag1_cache; // 各路Tag
    logic [127:0] data0_cache, data1_cache; // 各路数据
    logic Write_enable;            // Cache写使能
    logic write_complete;          // 写入完成标志
    logic has_valid_request;       // 有效请求标志
    
    // 缺失状态机（简化版：只有IDLE和MISS两种状态）
    logic current_state;
    logic next_state;
    
    // 存放缺失的地址信息
    logic [31:0] miss_addr;
    logic [6:0] miss_index;
    logic miss_way;                // 0=way0, 1=way1
    
    // 临时变量用于寄存器更新逻辑
    logic replace_way_temp;
    logic selected_way_temp;
    logic [127:0] current_data;
    logic [127:0] modified_data;
    
    // 当前操作的Store信息（用于命中时）
    logic [31:0] current_store_addr;
    logic [63:0] current_store_data;
    logic [1:0] current_store_type;
    
    // 用于Store miss时保存的信息
    logic store_miss;
    logic [31:0] store_miss_addr;
    logic [63:0] store_miss_data;
    logic [1:0] store_miss_type;

    always_comb begin
        // 解析输入地址
        tag_in = DT_PA[31:11];    // 21位tag
        index_in = DT_PA[10:4];   // 7位index
        offset_in = DT_PA[3:0];   // 4位offset
        
        // 读取Cache中的数据
        valid0_cache = valid_way0[index_in];
        valid1_cache = valid_way1[index_in];
        dirty0_cache = dirty_way0[index_in];
        dirty1_cache = dirty_way1[index_in];
        tag0_cache = tag_way0[index_in];
        tag1_cache = tag_way1[index_in];
        data0_cache = data_way0[index_in];
        data1_cache = data_way1[index_in];
        
        // 是否有有效的Cache请求
        has_valid_request = (Ld_en | St_en) & DT_hit & ~DC_pause;
        
        // 命中判断
        hit_way0 = valid0_cache & (tag_in == tag0_cache);
        hit_way1 = valid1_cache & (tag_in == tag1_cache);
        cache_hit = (hit_way0 | hit_way1) & has_valid_request;
        
        // 写使能信号：在缺失状态且收到内存数据
        Write_enable = (current_state == 1'b1) & DC_datain_val & DC_grant & has_valid_request;
        
        // Load数据提取
        if (cache_hit) begin
            if (hit_way0) begin
                // 选择way0的数据
                if (offset_in[3] == 1'b0) begin
                    Data_ld = data0_cache[63:0];
                end else begin
                    Data_ld = data0_cache[127:64];
                end
            end else begin
                // 选择way1的数据
                if (offset_in[3] == 1'b0) begin
                    Data_ld = data1_cache[63:0];
                end else begin
                    Data_ld = data1_cache[127:64];
                end
            end
        end else begin
            Data_ld = 64'b0;
        end
        
        // LRU替换算法
        if (~valid0_cache) begin
            replace_way_temp = 1'b0;  // way0无效，替换way0
        end else if (~valid1_cache) begin
            replace_way_temp = 1'b1;  // way1无效，替换way1
        end else if (lru[index_in] == 1'b0) begin
            replace_way_temp = 1'b1;  // way0最近使用，替换way1
        end else begin
            replace_way_temp = 1'b0;  // way1最近使用，替换way0
        end
        
        // 输出逻辑
        if (DC_pause | ~DT_hit | ~(Ld_en | St_en)) begin
            // 暂停、TLB未命中或没有请求时：所有信号置为无效
            hit = 1'b0;
            DC_addr = 32'b0;
            Dirty_data = 128'b0;
            DC_datain_rdy = 1'b0;
            DC_dataout_val = 1'b0;
            DC_req = 1'b0;
            dirty = 1'b0;
            Dirty_addr = 32'b0;
        end else begin
            // 正常操作
            hit = cache_hit & (current_state == 1'b0);
            
            if (current_state == 1'b0) begin // IDLE状态
                DC_addr = 32'b0;
                Dirty_data = 128'b0;
                DC_datain_rdy = 1'b0;
                DC_dataout_val = cache_hit & DC_dataout_rdy;
                DC_req = 1'b0;
                dirty = 1'b0;
                Dirty_addr = 32'b0;
            end else begin // MISS状态
                DC_addr = miss_addr;
                DC_datain_rdy = 1'b1;
                DC_req = 1'b1;
                DC_dataout_val = 1'b0;
                
                // 判断是否需要写回脏数据
                if (miss_way == 1'b0 && dirty0_cache) begin
                    dirty = 1'b1;
                    Dirty_data = data0_cache;
                    Dirty_addr = {tag0_cache, miss_index, 4'b0};
                end else if (miss_way == 1'b1 && dirty1_cache) begin
                    dirty = 1'b1;
                    Dirty_data = data1_cache;
                    Dirty_addr = {tag1_cache, miss_index, 4'b0};
                end else begin
                    dirty = 1'b0;
                    Dirty_data = 128'b0;
                    Dirty_addr = 32'b0;
                end
            end
        end
        
        // 状态转换
        if (DC_pause | ~DT_hit | ~(Ld_en | St_en)) begin
            next_state = 1'b0;  // 保持在IDLE状态
        end else begin
            case (current_state)
                1'b0: begin // IDLE
                    if (has_valid_request && ~cache_hit) begin
                        next_state = 1'b1;  // 缺失，进入MISS状态
                    end else begin
                        next_state = 1'b0;  // 命中或没有请求，保持IDLE
                    end
                end
                1'b1: begin // MISS
                    if (write_complete) begin
                        next_state = 1'b0;  // 写入完成，返回IDLE
                    end else begin
                        next_state = 1'b1;  // 继续MISS状态
                    end
                end
                default: next_state = 1'b0;
            endcase
        end
        
        // 保存当前的Store信息（用于命中时）
        current_store_addr = DT_PA;
        current_store_data = St_data;
        current_store_type = St_type;
    end
    
    // 写入完成检测（延迟一拍）
    always_ff @(posedge clk) begin
        if (reset) begin
            write_complete <= 1'b0;
        end else if (DC_pause | ~DT_hit | ~(Ld_en | St_en)) begin
            write_complete <= 1'b0;
        end else begin
            write_complete <= Write_enable;
        end
    end
    
    // 状态机和寄存器更新
    always_ff @(posedge clk) begin
        if (reset) begin
            current_state <= 1'b0;
            miss_addr <= 32'b0;
            miss_index <= 7'b0;
            miss_way <= 1'b0;
            
            // 初始化Store miss信息
            store_miss <= 1'b0;
            store_miss_addr <= 32'b0;
            store_miss_data <= 64'b0;
            store_miss_type <= 2'b0;
            
            // 初始化Cache
            for (int i = 0; i < 128; i++) begin
                valid_way0[i] <= 1'b0;
                valid_way1[i] <= 1'b0;
                dirty_way0[i] <= 1'b0;
                dirty_way1[i] <= 1'b0;
                tag_way0[i] <= 21'b0;
                tag_way1[i] <= 21'b0;
                data_way0[i] <= 128'b0;
                data_way1[i] <= 128'b0;
                lru[i] <= 1'b0;
            end
        end else if (DC_pause | ~DT_hit | ~(Ld_en | St_en)) begin
            current_state <= 1'b0;
        end else begin
            current_state <= next_state;
            
            // 保存缺失地址信息
            if (current_state == 1'b0 && next_state == 1'b1) begin
                miss_addr <= DT_PA;
                miss_index <= index_in;
                
                // 使用组合逻辑的替换路结果
                miss_way <= replace_way_temp;
                
                // 如果是由Store引起的缺失，保存Store信息
                if (St_en) begin
                    store_miss <= 1'b1;
                    store_miss_addr <= DT_PA;
                    store_miss_data <= St_data;
                    store_miss_type <= St_type;
                end else begin
                    store_miss <= 1'b0;
                end
            end
            
            // Cache写入逻辑（缺失时从内存加载数据）
            if (Write_enable) begin
                if (miss_way == 1'b0) begin // 写入way0
                    valid_way0[miss_index] <= 1'b1;
                    // 如果有Store miss，标记脏位
                    dirty_way0[miss_index] <= store_miss;
                    tag_way0[miss_index] <= miss_addr[31:11];
                    
                    // 如果有Store miss，需要修改数据
                    if (store_miss) begin
                        // 应用Store修改
                        modified_data = DC_data_in;
                        case (store_miss_type)
                            2'b00: begin // SB
                                case (store_miss_addr[3:0])
                                    4'b0000: modified_data[7:0] = store_miss_data[7:0];
                                    4'b0001: modified_data[15:8] = store_miss_data[7:0];
                                    4'b0010: modified_data[23:16] = store_miss_data[7:0];
                                    4'b0011: modified_data[31:24] = store_miss_data[7:0];
                                    4'b0100: modified_data[39:32] = store_miss_data[7:0];
                                    4'b0101: modified_data[47:40] = store_miss_data[7:0];
                                    4'b0110: modified_data[55:48] = store_miss_data[7:0];
                                    4'b0111: modified_data[63:56] = store_miss_data[7:0];
                                    4'b1000: modified_data[71:64] = store_miss_data[7:0];
                                    4'b1001: modified_data[79:72] = store_miss_data[7:0];
                                    4'b1010: modified_data[87:80] = store_miss_data[7:0];
                                    4'b1011: modified_data[95:88] = store_miss_data[7:0];
                                    4'b1100: modified_data[103:96] = store_miss_data[7:0];
                                    4'b1101: modified_data[111:104] = store_miss_data[7:0];
                                    4'b1110: modified_data[119:112] = store_miss_data[7:0];
                                    4'b1111: modified_data[127:120] = store_miss_data[7:0];
                                endcase
                            end
                            2'b01: begin // SH
                                case (store_miss_addr[3:1])
                                    3'b000: modified_data[15:0] = store_miss_data[15:0];
                                    3'b001: modified_data[31:16] = store_miss_data[15:0];
                                    3'b010: modified_data[47:32] = store_miss_data[15:0];
                                    3'b011: modified_data[63:48] = store_miss_data[15:0];
                                    3'b100: modified_data[79:64] = store_miss_data[15:0];
                                    3'b101: modified_data[95:80] = store_miss_data[15:0];
                                    3'b110: modified_data[111:96] = store_miss_data[15:0];
                                    3'b111: modified_data[127:112] = store_miss_data[15:0];
                                endcase
                            end
                            2'b10: begin // SW
                                case (store_miss_addr[3:2])
                                    2'b00: modified_data[31:0] = store_miss_data[31:0];
                                    2'b01: modified_data[63:32] = store_miss_data[31:0];
                                    2'b10: modified_data[95:64] = store_miss_data[31:0];
                                    2'b11: modified_data[127:96] = store_miss_data[31:0];
                                endcase
                            end
                            2'b11: begin // SD
                                case (store_miss_addr[3])
                                    1'b0: modified_data[63:0] = store_miss_data[63:0];
                                    1'b1: modified_data[127:64] = store_miss_data[63:0];
                                endcase
                            end
                        endcase
                        data_way0[miss_index] <= modified_data;
                    end else begin
                        data_way0[miss_index] <= DC_data_in;
                    end
                    lru[miss_index] <= 1'b0; // way0变为最近使用
                    
                    // 清除Store miss标志
                    store_miss <= 1'b0;
                end else begin // 写入way1
                    valid_way1[miss_index] <= 1'b1;
                    dirty_way1[miss_index] <= store_miss;
                    tag_way1[miss_index] <= miss_addr[31:11];
                    
                    // 如果有Store miss，需要修改数据
                    if (store_miss) begin
                        // 应用Store修改
                        modified_data = DC_data_in;
                        case (store_miss_type)
                            2'b00: begin // SB
                                case (store_miss_addr[3:0])
                                    4'b0000: modified_data[7:0] = store_miss_data[7:0];
                                    4'b0001: modified_data[15:8] = store_miss_data[7:0];
                                    4'b0010: modified_data[23:16] = store_miss_data[7:0];
                                    4'b0011: modified_data[31:24] = store_miss_data[7:0];
                                    4'b0100: modified_data[39:32] = store_miss_data[7:0];
                                    4'b0101: modified_data[47:40] = store_miss_data[7:0];
                                    4'b0110: modified_data[55:48] = store_miss_data[7:0];
                                    4'b0111: modified_data[63:56] = store_miss_data[7:0];
                                    4'b1000: modified_data[71:64] = store_miss_data[7:0];
                                    4'b1001: modified_data[79:72] = store_miss_data[7:0];
                                    4'b1010: modified_data[87:80] = store_miss_data[7:0];
                                    4'b1011: modified_data[95:88] = store_miss_data[7:0];
                                    4'b1100: modified_data[103:96] = store_miss_data[7:0];
                                    4'b1101: modified_data[111:104] = store_miss_data[7:0];
                                    4'b1110: modified_data[119:112] = store_miss_data[7:0];
                                    4'b1111: modified_data[127:120] = store_miss_data[7:0];
                                endcase
                            end
                            2'b01: begin // SH
                                case (store_miss_addr[3:1])
                                    3'b000: modified_data[15:0] = store_miss_data[15:0];
                                    3'b001: modified_data[31:16] = store_miss_data[15:0];
                                    3'b010: modified_data[47:32] = store_miss_data[15:0];
                                    3'b011: modified_data[63:48] = store_miss_data[15:0];
                                    3'b100: modified_data[79:64] = store_miss_data[15:0];
                                    3'b101: modified_data[95:80] = store_miss_data[15:0];
                                    3'b110: modified_data[111:96] = store_miss_data[15:0];
                                    3'b111: modified_data[127:112] = store_miss_data[15:0];
                                endcase
                            end
                            2'b10: begin // SW
                                case (store_miss_addr[3:2])
                                    2'b00: modified_data[31:0] = store_miss_data[31:0];
                                    2'b01: modified_data[63:32] = store_miss_data[31:0];
                                    2'b10: modified_data[95:64] = store_miss_data[31:0];
                                    2'b11: modified_data[127:96] = store_miss_data[31:0];
                                endcase
                            end
                            2'b11: begin // SD
                                case (store_miss_addr[3])
                                    1'b0: modified_data[63:0] = store_miss_data[63:0];
                                    1'b1: modified_data[127:64] = store_miss_data[63:0];
                                endcase
                            end
                        endcase
                        data_way1[miss_index] <= modified_data;
                    end else begin
                        data_way1[miss_index] <= DC_data_in;
                    end
                    lru[miss_index] <= 1'b1; // way1变为最近使用
                    
                    // 清除Store miss标志
                    store_miss <= 1'b0;
                end
            end
            
            // Store命中时更新Cache和LRU
            if (St_en && cache_hit) begin
                selected_way_temp = hit_way1 ? 1'b1 : 1'b0;
                
                // 获取当前数据
                if (selected_way_temp == 1'b0) begin
                    current_data = data0_cache;
                end else begin
                    current_data = data1_cache;
                end
                
                // 复制数据并修改
                modified_data = current_data;
                
                case (current_store_type)
                    2'b00: begin // SB: 存储字节
                        case (current_store_addr[3:0])
                            4'b0000: modified_data[7:0] = current_store_data[7:0];
                            4'b0001: modified_data[15:8] = current_store_data[7:0];
                            4'b0010: modified_data[23:16] = current_store_data[7:0];
                            4'b0011: modified_data[31:24] = current_store_data[7:0];
                            4'b0100: modified_data[39:32] = current_store_data[7:0];
                            4'b0101: modified_data[47:40] = current_store_data[7:0];
                            4'b0110: modified_data[55:48] = current_store_data[7:0];
                            4'b0111: modified_data[63:56] = current_store_data[7:0];
                            4'b1000: modified_data[71:64] = current_store_data[7:0];
                            4'b1001: modified_data[79:72] = current_store_data[7:0];
                            4'b1010: modified_data[87:80] = current_store_data[7:0];
                            4'b1011: modified_data[95:88] = current_store_data[7:0];
                            4'b1100: modified_data[103:96] = current_store_data[7:0];
                            4'b1101: modified_data[111:104] = current_store_data[7:0];
                            4'b1110: modified_data[119:112] = current_store_data[7:0];
                            4'b1111: modified_data[127:120] = current_store_data[7:0];
                        endcase
                    end
                    2'b01: begin // SH: 存储半字
                        case (current_store_addr[3:1])
                            3'b000: modified_data[15:0] = current_store_data[15:0];
                            3'b001: modified_data[31:16] = current_store_data[15:0];
                            3'b010: modified_data[47:32] = current_store_data[15:0];
                            3'b011: modified_data[63:48] = current_store_data[15:0];
                            3'b100: modified_data[79:64] = current_store_data[15:0];
                            3'b101: modified_data[95:80] = current_store_data[15:0];
                            3'b110: modified_data[111:96] = current_store_data[15:0];
                            3'b111: modified_data[127:112] = current_store_data[15:0];
                        endcase
                    end
                    2'b10: begin // SW: 存储字
                        case (current_store_addr[3:2])
                            2'b00: modified_data[31:0] = current_store_data[31:0];
                            2'b01: modified_data[63:32] = current_store_data[31:0];
                            2'b10: modified_data[95:64] = current_store_data[31:0];
                            2'b11: modified_data[127:96] = current_store_data[31:0];
                        endcase
                    end
                    2'b11: begin // SD: 存储双字
                        case (current_store_addr[3])
                            1'b0: modified_data[63:0] = current_store_data[63:0];
                            1'b1: modified_data[127:64] = current_store_data[63:0];
                        endcase
                    end
                endcase
                
                // 写回修改后的数据
                if (selected_way_temp == 1'b0) begin
                    data_way0[index_in] <= modified_data;
                    dirty_way0[index_in] <= 1'b1;
                    lru[index_in] <= 1'b0; // way0变为最近使用
                end else begin
                    data_way1[index_in] <= modified_data;
                    dirty_way1[index_in] <= 1'b1;
                    lru[index_in] <= 1'b1; // way1变为最近使用
                end
            end
            
            // Load命中时更新LRU
            if (Ld_en && cache_hit) begin
                if (hit_way0) begin
                    lru[index_in] <= 1'b0; // way0变为最近使用
                end else begin
                    lru[index_in] <= 1'b1; // way1变为最近使用
                end
            end
        end
    end

endmodule
