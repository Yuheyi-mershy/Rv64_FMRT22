module I_TLB(
    input logic clk,
    input logic reset,
    input logic [38:0] VA,
    input logic [127:0] IT_data_in,
    input logic IT_grant,
    input logic IT_datain_val,
    input logic IT_pause,
    input logic IT_req_in,  // 指令缓存请求信号，类似D_TLB的DC_req_in
    
    output logic [31:0] PA,
    output logic hit,
    output logic IT_datain_rdy,
    output logic IT_req,
    output logic [38:0] IT_miss_va
);
    
    // TLB存储
    logic [21:0] tag [31:0];
    logic [63:0] data [31:0];

    // 内部信号
    logic [4:0] index_in;
    logic [21:0] tag_in;
    logic select_high;
    logic [63:0] select_data;
    logic Write_en;
    logic write_complete;
    logic access_valid;

    logic [63:0] data_cache;
    logic [21:0] tag_cache;

    // 页表项字段
    logic [25:0] ppn2;
    logic [8:0]  ppn1;
    logic [8:0]  ppn0;
    logic [1:0]  rsw;
    logic        d;
    logic        a;
    logic        g;
    logic        u;
    logic        x;
    logic        w;
    logic        r;
    logic        v;

    // 有限状态机
    logic current_state;
    logic next_state;
    
    // 存放miss的地址信息
    logic [38:0] miss_va;
    logic [4:0] miss_index;

    always_comb begin
        // 虚拟地址分解
        index_in = VA[16:12];
        tag_in = VA[38:17];

        // 只有当IC_req_in有效时才处理访问
        if (reset) begin
            access_valid = 1'b0;
        end else begin
            access_valid = IT_req_in & ~IT_pause;
        end
        
        // 页表字段解析
        data_cache = data[index_in];
        tag_cache = tag[index_in];
        ppn2 = data_cache[53:28];
        ppn1 = data_cache[27:19];
        ppn0 = data_cache[18:10];
        rsw = data_cache[9:8];
        d = data_cache[7];
        a = data_cache[6];
        g = data_cache[5];
        u = data_cache[4];
        x = data_cache[3];
        w = data_cache[2];
        r = data_cache[1];
        v = data_cache[0];

        // 判断是否命中 - 需要考虑访问有效性和状态
        if(~access_valid) begin
            // 没有有效访问时，hit为0，PA输出0
            hit = 1'b0;
            PA = 32'b0;
        end
        else if (current_state == 1'b1) begin  // MISS状态
            // 在MISS状态下，强制hit=0，忽略当前输入的VA
            hit = 1'b0;
            PA = 32'b0;
        end
        else if (v & (tag_in == tag_cache)) begin  // IDLE状态且命中
            hit = 1'b1;
            PA = {ppn2[1:0], ppn1, ppn0, VA[11:0]};
        end 
        else begin  // IDLE状态且不命中
            hit = 1'b0;
            PA = 32'b0;
        end

        // 写回信号
        Write_en = (current_state == 1'b1) & IT_datain_val & IT_grant & (~IT_pause) & access_valid;

        // 选择写入数据（基于锁存的缺失地址）
        select_high = miss_va[3];
        select_data = select_high ? IT_data_in[127:64] : IT_data_in[63:0];

        // 输出数据就绪信号
        IT_datain_rdy = (current_state == 1'b1) & (~IT_pause) & access_valid;
        
        // 总线请求信号
        IT_req = (current_state == 1'b1) & (~IT_pause) & access_valid;
        
        // 输出缺失地址
        IT_miss_va = (current_state == 1'b1) ? miss_va : 39'b0;

        // 状态转换
        if(IT_pause) begin
            next_state = 1'b0;  // 暂停时强制返回IDLE
        end
        else if(~access_valid) begin
            // 没有有效访问时，保持当前状态
            next_state = current_state;
        end
        else if (current_state == 1'b1) begin  // MISS状态
            // 在MISS状态下，只根据写入完成标志来决定状态转换
            if (write_complete) begin
                next_state = 1'b0;  // 写入完成后返回IDLE
            end
            else begin
                next_state = 1'b1;  // 保持MISS状态
            end
        end
        else begin  // IDLE状态
            if (~hit & access_valid) begin  // 有效访问且不命中
                next_state = 1'b1;  // 进入MISS
            end
            else begin
                next_state = 1'b0;  // 保持IDLE
            end
        end
    end

    // TLB写入逻辑
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 32; i++) begin
                tag[i] <= 22'b0;
                data[i] <= 64'b0;
            end
        end
        else if (~IT_pause & access_valid) begin
            if (Write_en) begin
                // 使用锁存的缺失地址信息进行写入
                tag[miss_index] <= miss_va[38:17];
                data[miss_index] <= select_data;
            end
        end
    end
    
    // 写入完成检测（延迟一拍）
    always_ff @(posedge clk) begin
        if (reset) begin
            write_complete <= 1'b0;
        end else if (IT_pause) begin
            write_complete <= 1'b0;
        end else begin
            write_complete <= Write_en;
        end
    end

    // 状态机转移和地址锁存
    always_ff @(posedge clk) begin
        if (reset) begin
            current_state <= 1'b0;
            miss_va <= 39'b0;
            miss_index <= 5'b0;
        end
        else if (IT_pause) begin
            // 暂停时清除所有状态
            current_state <= 1'b0;
            miss_va <= 39'b0;
            miss_index <= 5'b0;
        end
        else if(access_valid) begin  
            current_state <= next_state;
            
            if (current_state == 1'b0 && next_state == 1'b1) begin
                miss_va <= VA;
                miss_index <= index_in;
            end
            else if (current_state == 1'b1 && next_state == 1'b0) begin
                miss_va <= 39'b0;
                miss_index <= 5'b0;
            end
        end
    end

endmodule