//I-Cache
module I_Cache(
    input logic clk,
    input logic reset,
    input logic [31:0] IT_PA,
    input logic [127:0] IC_data_in,
    input logic [11:0] Br_type_in,
    input logic IC_pause,
    input logic IC_datain_val,
    input logic IC_grant,
    input logic IT_hit,
    input logic IC_dataout_rdy,
    input logic IC_req_in, 
    
    output logic hit,
    output logic [31:0] IC_addr,
    output logic [11:0] Br_type_out,
    output logic [127:0] IC_data_out,
    output logic IC_datain_rdy,
    output logic IC_req,
    output logic IC_dataout_val
);
    //存储单元定义
    logic valid [255:0];
    logic [19:0] tag [255:0];              
    logic [11:0] br_type [255:0];         
    logic [127:0] data [255:0];

    //传入地址分割
    logic [19:0] tag_in;
    logic [7:0] index_in;
    logic [3:0] offset_in;

    //有限状态机
    logic current_state;
    logic next_state;

    //内部信号
    logic miss;
    logic valid_cache;
    logic [19:0] tag_cache;
    logic [11:0] br_type_cache;
    logic [127:0] data_cache;
    logic Write_en;
    logic write_complete;
    logic has_valid_request;
    logic cache_hit;  // 新增：实际的缓存命中信号

    //存放miss的地址信息
    logic [31:0] miss_addr;
    logic [7:0] miss_index;

    always_comb begin
        //解析输入地址
        tag_in = IT_PA[31:12];
        index_in = IT_PA[11:4];
        offset_in = IT_PA[3:0];

        //读取I-Cache中的数据
        valid_cache = valid[index_in];
        tag_cache = tag[index_in];
        br_type_cache = br_type[index_in];
        data_cache = data[index_in];
        
        // 是否有有效的Cache请求（有请求、TLB命中、未暂停）
        has_valid_request = IC_req_in & IT_hit & ~IC_pause;
        
        // 只在IDLE状态且有效请求时才判断命中
        if (has_valid_request && (current_state == 1'b0)) begin
            // 检查命中条件：valid位为1且tag匹配
            cache_hit = valid_cache & (tag_in == tag_cache);
            miss = ~cache_hit;  // 缺失 = 不命中
        end else begin
            cache_hit = 1'b0;
            miss = 1'b0;  // 不在IDLE状态或没有有效请求，不算miss
        end
        
        //写回信号：在MISS状态且收到有效数据时写入
        Write_en = (current_state == 1'b1) & IC_datain_val & IC_grant & has_valid_request;

        //输出逻辑
        if (IC_pause) begin
            // 暂停期间：放弃本次访问，所有信号置为无效
            hit = 1'b0;
            IC_addr = 32'b0;
            Br_type_out = 12'b0;
            IC_data_out = 128'b0;
            IC_datain_rdy = 1'b0;
            IC_req = 1'b0;
            IC_dataout_val = 1'b0;
        end else if (~IT_hit) begin
            // TLB未命中：没有有效的物理地址，所有信号置为无效
            hit = 1'b0;
            IC_addr = 32'b0;
            Br_type_out = 12'b0;
            IC_data_out = 128'b0;
            IC_datain_rdy = 1'b0;
            IC_req = 1'b0;
            IC_dataout_val = 1'b0;
        end else if (~IC_req_in) begin
            // 没有访问请求：所有信号置为无效
            hit = 1'b0;
            IC_addr = 32'b0;
            Br_type_out = 12'b0;
            IC_data_out = 128'b0;
            IC_datain_rdy = 1'b0;
            IC_req = 1'b0;
            IC_dataout_val = 1'b0;
        end else begin
            // 正常操作（有请求、TLB命中、未暂停）
            // 只在IDLE状态且命中时才报告命中
            hit = (current_state == 1'b0) & cache_hit & has_valid_request;
            
            // 总线请求：只在MISS状态时才请求总线
            IC_req = (current_state == 1'b1) & has_valid_request;
            
            // 总线地址：只在MISS状态时输出miss地址
            IC_addr = (current_state == 1'b1) ? miss_addr : 32'b0;
            
            // 数据输出：只在命中且IDLE状态时输出缓存数据
            IC_data_out = (hit) ? data_cache : 128'b0;
            Br_type_out = (hit) ? br_type_cache : 12'b0;
            
            // 数据接收就绪：在MISS状态时准备接收数据
            IC_datain_rdy = (current_state == 1'b1) & has_valid_request;
            
            // 数据输出有效：只在命中、IDLE状态且接收端就绪时有效
            IC_dataout_val = hit & IC_dataout_rdy;  
        end        

        //状态转换
        if(IC_pause | ~IT_hit | ~IC_req_in) begin
            next_state = 1'b0;  // 暂停、TLB未命中或没有请求时保持在IDLE
        end
        else begin
            case (current_state)
                1'b0: begin //IDLE
                        if (miss) begin // 有效请求且Cache缺失
                            next_state = 1'b1;
                        end
                        else begin
                            next_state = 1'b0;
                        end
                    end
                1'b1: begin //MISS
                        // 只有当写入真正完成后再跳回IDLE
                        if (write_complete) begin
                            next_state = 1'b0;
                        end
                        else begin
                            next_state = 1'b1;
                        end
                    end
                default: next_state = 1'b0;
            endcase
        end

    end

    
    // 写入完成检测（延迟一拍）
    always_ff @(posedge clk) begin
        if (reset) begin
            write_complete <= 1'b0;
        end else if (IC_pause | ~IT_hit | ~IC_req_in) begin
            write_complete <= 1'b0; 
        end else begin
            write_complete <= Write_en;
        end
    end
    
    //有限状态机
    always_ff @(posedge clk) begin
        if(reset) begin
            current_state <= 1'b0;
            miss_addr <= 32'b0;
            miss_index <= 8'b0;
        end 
        else if(IC_pause | ~IT_hit | ~IC_req_in) begin
            current_state <= 1'b0;
            miss_addr <= 32'b0;
            miss_index <= 8'b0;
        end
        else begin
            current_state <= next_state;
            if(current_state == 1'b0 & next_state == 1'b1)begin
                miss_addr <= IT_PA;
                miss_index <= index_in;
            end
        end
    end


    //I-Cache 数据写入逻辑
    always_ff @(posedge clk) begin
        if (reset) begin
            //I-Cache 初始化
            for (int i = 0;i < 256;i++) begin
                valid[i] <= 1'b0;
                tag[i] <= 20'b0;
                br_type[i] <= 12'b0;
                data[i] <= 128'b0;
            end
        end 
        else if (IC_req_in & IT_hit & ~IC_pause) begin  // 只有在有效请求时才允许写入
            if (Write_en) begin 
                valid[miss_index] <= 1'b1;
                tag[miss_index] <= miss_addr[31:12];
                br_type[miss_index] <= Br_type_in;
                data[miss_index] <= IC_data_in;
            end
        end
    end

endmodule
