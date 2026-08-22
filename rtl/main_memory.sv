module main_memory (
    input  logic                     clk,            // 时钟信号
    input  logic                     reset,          // 复位信号(高有效)
    
    // 写端口
    input  logic [127:0]             Mem_in,         // 写入主存的数据(128bit)
    input  logic [31:0]              Mem_addr_w,     // 写地址
    input  logic                     Mem_datain_val, // 写入数据有效
    input  logic                     Write_en,       // 写使能
    
    // 读端口  
    input  logic [31:0]              Mem_addr_r,     // 读地址
    input  logic                     Mem_dataout_rdy,// 读数据接收端就绪
    
    input  logic                     grant,          // 总线授权
    
    // 输出端口
    output logic [127:0]             Mem_out,        // 读出数据(128bit)
    output logic                     Mem_dataout_val,// 读数据有效
    output logic                     Mem_datain_rdy  // 写数据就绪
);

// 主存存储阵列 (128bit * 2^28) - 4GB容量
logic [127:0] mem_array [0:1048575];  // 2^28 = 268435456 (索引0~268435455)

// 地址对齐: 32位地址的[31:4]作为字地址（低4位为16字节偏移，无需处理）
logic [27:0] word_addr_w, word_addr_r;
assign word_addr_w = Mem_addr_w[31:4];  // 写地址
assign word_addr_r = Mem_addr_r[31:4];  // 读地址

// 内部寄存器
logic write_pending;      // 写操作挂起标志
logic [27:0] pending_addr; // 挂起的写地址
logic [127:0] pending_data; // 挂起的写数据

// 复位与握手逻辑
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        // 复位状态: 输出无效，输入就绪
        Mem_out         <= '0;
        Mem_dataout_val <= 1'b0;
        Mem_datain_rdy  <= 1'b1;
        write_pending   <= 1'b0;
        pending_addr    <= 28'b0;
        pending_data    <= 128'b0;
    end else begin
        if (grant) begin  // 仅总线授权时响应   
            // 读操作逻辑 - 优先处理
            if (Mem_dataout_rdy) begin
                // 如果有读请求
                if (write_pending & (word_addr_r == pending_addr)) begin
                    // 读地址与待写入地址相同，返回待写入数据（写前读）
                    Mem_out <= pending_data;
                    Mem_dataout_val <= 1'b1;
                end else begin
                    // 正常读取内存
                    Mem_out <= mem_array[word_addr_r];
                    Mem_dataout_val <= 1'b1;
                end
            end else begin
                Mem_dataout_val <= 1'b0;
            end
            
            // 写操作逻辑 - 使用握手协议
            Mem_datain_rdy <= 1'b1;  // 默认就绪
            
            if (Write_en && Mem_datain_val) begin
                // 写操作请求
                if (write_pending) begin
                    // 先将挂起的写操作写入内存
                    mem_array[pending_addr] <= pending_data;
                end
                
                // 保存新的写操作信息
                write_pending <= 1'b1;
                pending_addr  <= word_addr_w;
                pending_data  <= Mem_in;
            end else if (write_pending && (!Mem_dataout_rdy | word_addr_r != pending_addr)) begin
                // 如果没有活跃的读操作，或者读地址与写地址不同，执行写操作
                mem_array[pending_addr] <= pending_data;
                write_pending <= 1'b0;
            end
            
        end else begin
            // 无总线授权：输出无效，输入就绪
            Mem_dataout_val <= 1'b0;
            Mem_datain_rdy  <= 1'b1;
        end
    end
end

endmodule
