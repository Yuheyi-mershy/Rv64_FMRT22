module top_tb;
    logic clk;
    logic reset;
    
    // 时钟周期定义
    parameter CLK_PERIOD = 10ns;
    
    // 实例化被测模块
    top dut (
        .clk(clk),
        .reset(reset)
    );
    
    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz时钟
    end
    
    // 用于记录是否已经检查过
    logic check_done = 0;
    logic signed [63:0] prev_data;
    logic signed [63:0] current_data;
    integer data_idx;
    integer error_count;
    integer mismatch_count;
    
    // ========== 添加存储数组来保存初始化的数据 ==========
    // 存储从地址8到32的所有128位数据
    logic [127:0] expected_mem_data [8:32];
    
    // ========== 用于排序的数据结构 ==========
    // 使用有符号数据类型
    logic signed [63:0] all_data [0:49];  // 25个地址 * 2 = 50个数据
    logic signed [63:0] sorted_data [0:49];  // 期望的排序结果
    logic signed [63:0] sort_self [0:49];      // 从Cache读取的实际排序结果
    integer data_count = 0;
    integer duplicate_count = 0;  // 记录重复数据的数量
    integer bru_complete_count = 0;
    integer bru_pre_count = 0;
    integer lsu_complete_count = 0;
    integer IC_access_count = 0;
    
    // ========== 比较函数：检查两个数组是否相等 ==========
    function bit compare_arrays();
        int i;
        bit is_match = 1;
        
        
        mismatch_count = 0;
        
        // 逐项比较
        for (i = 0; i < data_count; i++) begin
            if (sorted_data[i] !== sort_self[i]) begin
                $display("❌ 位置 %2d 不匹配: 期望 = %4d, 实际 = %4d", 
                         i, sorted_data[i], sort_self[i]);
                is_match = 0;
                mismatch_count++;
            end
        end
        
        // 显示比较结果
        if (is_match) begin
            $display("\n ========================================");
            $display(" 排序成功！所有数据完全匹配！");
            $display(" ========================================");
            $display(" 总共比较了 %0d 个数据，全部正确", data_count);
            $display(" ========================================\n");
        end else begin
            $display("\n ========================================");
            $display(" 排序失败！发现 %0d 个不匹配项", mismatch_count);
            $display(" ========================================");
            
            // 显示详细的不匹配信息
            $display("\n详细比较结果：");
            $display("位置  | 期望值 | 实际值 | 状态");
            $display("------|--------|--------|------");
            for (i = 0; i < data_count; i++) begin
                if (sorted_data[i] !== sort_self[i]) begin
                    $display("%4d  | %6d | %6d |  不匹配", 
                            i, sorted_data[i], sort_self[i]);
                end else begin
                    if (i < 10 || i > data_count-10) begin  // 只显示前10和后10个
                        $display("%4d  | %6d | %6d | ✓", 
                                i, sorted_data[i], sort_self[i]);
                    end else if (i == 10) begin
                        $display(" ...  |  ...   |  ...   | ...");
                    end
                end
            end
            $display("\n");
        end
        
        return is_match;
    endfunction


    
    task read_from_dcache();
        int i;
        int index;
        int way_selected;
        logic [20:0] target_tag;
        logic [6:0] target_index;
        logic [127:0] cache_data;
        int cache_miss_count = 0;
        int base_addr;
        int offset_in_128bit;
        int byte_offset;
        
        for (i = 0; i < 50; i++) begin
            // 计算实际的字节地址
            // 假设排序结果从地址 128 开始连续存储（字节地址）
            // 每个64位数据占用8字节
            base_addr = 128 + i * 8;  // 字节地址
            byte_offset = base_addr[3];  // 第3位决定在128位块中的偏移（0=低64位，1=高64位）
            
            // 计算128位对齐的块地址
            target_index = (base_addr >> 4) & 7'h7F;  // 7位index
            target_tag = base_addr >> 11;              // 21位tag
            
            cache_data = 128'b0;
            way_selected = -1;
            
            // 检查Way 0
            if (dut.memsys.d_cache_inst.valid_way0[target_index] && 
                dut.memsys.d_cache_inst.tag_way0[target_index] == target_tag) begin
                cache_data = dut.memsys.d_cache_inst.data_way0[target_index];
                way_selected = 0;
            end
            // 检查Way 1
            else if (dut.memsys.d_cache_inst.valid_way1[target_index] && 
                    dut.memsys.d_cache_inst.tag_way1[target_index] == target_tag) begin
                cache_data = dut.memsys.d_cache_inst.data_way1[target_index];
                way_selected = 1;
            end
            
            // 从128位数据中提取正确的64位数据
            if (way_selected != -1) begin
                if (byte_offset == 0) begin
                    sort_self[i] = $signed(cache_data[63:0]);
                end else begin
                    sort_self[i] = $signed(cache_data[127:64]);
                end
            end else begin
                $display("地址 %3d: ❌ D-Cache未命中", base_addr);
                sort_self[i] = -999;
                cache_miss_count++;
            end
        end
        
        // ========== 格式化输出从Cache读取的数据（每5个数据一次） ==========
        $display("\n========================================");
        $display("排序后结果（升序排列）：");
  
        // 按每5个数据输出
        for (i = 0; i < 50; i++) begin
            if (i % 5 == 0) begin
                // 每5个数据输出一组
                $write("\n[%2d-%2d]: ", i, (i+4 < 50) ? i+4 : 49);
            end
            
            // 高亮显示重复数据和负数
            if (i > 0 && sort_self[i] == sort_self[i-1]) begin
                $write("%4d  ", sort_self[i]);  // 重复数据用*标记
            end else if (sort_self[i] < 0) begin
                $write("%4d  ", sort_self[i]);  // 负数用#标记
            end else begin
                $write("%4d  ", sort_self[i]);
            end
            
           
            
        end
        
        
        
        
    endtask


    // ========== 直接在task中进行排序，不使用function ==========
    task automatic sort_expected_data();
        int i, j;
        logic signed [63:0] high_data, low_data;
        logic signed [63:0] temp;
        bit swapped;
          
        // 第一步：提取所有数据
        data_count = 0;
        duplicate_count = 0;
        
        for (i = 8; i <= 32; i++) begin
            // 提取高64位和低64位，并转换为有符号数
            high_data = $signed(expected_mem_data[i][63:0]);
            low_data = $signed(expected_mem_data[i][127:64]);
            
            // 存入数组
            all_data[data_count] = high_data;
            data_count++;
            all_data[data_count] = low_data;
            data_count++;
        end
        
        $display("\n总共提取了 %0d 个数据，具体如下", data_count);
        
        // 第二步：显示原始数据（按存储顺序）
        $display("\n原始数据（按存储顺序）：");
        for (i = 0; i < data_count; i++) begin
            if (i % 5 == 0) $write("\n[%2d-%2d]: ", i, i+4);
            if (all_data[i] < 0)
                $write("%4d  ", all_data[i]);
            else
                $write("%4d  ", all_data[i]);
        end
        $display("\n");
        
        // 第三步：复制到排序数组
        for (i = 0; i < data_count; i++) begin
            sorted_data[i] = all_data[i];
        end
        
        // 第四步：直接在task中进行冒泡排序    
        for (i = 0; i < data_count-1; i++) begin
            swapped = 0;
            for (j = 0; j < data_count-1-i; j++) begin
                // 有符号比较，升序排列
                if (sorted_data[j] > sorted_data[j+1]) begin
                    temp = sorted_data[j];
                    sorted_data[j] = sorted_data[j+1];
                    sorted_data[j+1] = temp;
                    swapped = 1;
                end
            end
            // 如果没有交换，说明已经有序
            if (!swapped) begin
                break;
            end
        end
        
    endtask
    
    // 测试过程
    initial begin
        bit test_passed;
        
        // 初始化信号
        reset = 1;
        
        // ========== 添加 FSDB 波形输出 ==========
        $display("========================================");
        $display("开始生成 FSDB 波形文件");
        $display("========================================");
        
        // 设置波形文件名
        $fsdbDumpfile("top_tb.fsdb");
        
        // 设置波形 dump 范围
        $fsdbDumpvars(0, top_tb);
        
        $display("FSDB 文件配置完成: top_tb.fsdb");
        $display("========================================");
        $display("开始测试: 初始化排序程序指令");
        $display("========================================");
        
        // 等待时钟稳定
        repeat(2) @(posedge clk);
        #1;
        
        // ========== 初始化Memory_System主存 ==========
        $display("[%0t] === 通过force初始化Memory_System主存 ===", $time);
        $display("注意：每个存储单元为128bits，可存放4条32位指令或2个64位数据");
        $display("      负数将使用补码表示，排序时将进行有符号比较");
        
        // 地址0: 存储第0-3条指令（字节地址0x00-0x0F）
        force dut.memsys.main_mem_inst.mem_array[0] = {
            32'h04535A63,   // 字节地址0x0C: bge x6, x5, END
            32'h00100313,   // 字节地址0x08: addi x6, x0, 1
            32'h03206293,   // 字节地址0x04: ori x5, x0, 20
            32'h08000213    // 字节地址0x00: addi x4, x0, 128
        };
        
        // 地址1: 存储第4-7条指令（字节地址0x10-0x1F）
        force dut.memsys.main_mem_inst.mem_array[1] = {
            32'hFFF30513,   // 字节地址0x1C: addi x10, x6, -1            
            32'h00043483,   // 字节地址0x18: ld x9, 0(x8)
            32'h00720433,   // 字节地址0x14: add x8, x4, x7           
            32'h00331393    // 字节地址0x10: slli x7, x6, 3
        };
        
        // 地址2: 存储第8-11条指令（字节地址0x20-0x2F）
        force dut.memsys.main_mem_inst.mem_array[2] = {
            32'h00063683,   // 字节地址0x2C: ld x13, 0(x12)            
            32'h00B20633,   // 字节地址0x28: add x12, x4, x11            
            32'h00351593,   // 字节地址0x24: slli x11, x10, 3
            32'h02054063    // 字节地址0x20: blt x10, x0, INSERT
        };
        
        // 地址3: 存储第12-15条指令（字节地址0x30-0x3F）
        force dut.memsys.main_mem_inst.mem_array[3] = {
            32'hfe5ff06f,   // 字节地址0x3C: jal x0, INNER            
            32'hfff50513,   // 字节地址0x38: addi x10, x10, -1            
            32'h00d63423,   // 字节地址0x34: sd x13, 8(x12)            
            32'h00d4d863    // 字节地址0x30: bge x9, x13, INSERT
        };
        
        // 地址4: 存储第16-19条指令（字节地址0x40-0x4F）
        force dut.memsys.main_mem_inst.mem_array[4] = {
            32'h00963423,   // 字节地址0x4C: sd x9, 8(x12)            
            32'h00b20633,   // 字节地址0x48: add x12, x4, x11
            32'h00351593,   // 字节地址0x44: slli x11, x10, 3            
            32'h00054a63    // 字节地址0x40: blt x10, x0, INSERT_START
        };
        
        // 地址5: 存储第20-23条指令（字节地址0x50-0x5F）
        force dut.memsys.main_mem_inst.mem_array[5] = {
            32'hfb1ff06f,   // 字节地址0x5C: jal x0, OUTER            
            32'h00130313,   // 字节地址0x58: addi x6, x6, 1            
            32'h00923023,   // 字节地址0x54: sd x9, 0(x4)            
            32'h0080006f    // 字节地址0x50: jal x0, NEXT
        };
        

        
        $display("[%0t] 初始化数据段：50个数据", $time);
        
        // ========== 初始化数据并存储到expected_mem_data数组 ==========
        // 地址8
        expected_mem_data[8] = {64'sd56, -64'sd11};
        force dut.memsys.main_mem_inst.mem_array[8] = expected_mem_data[8];
        
        // 地址9
        expected_mem_data[9] = {64'sd12, 64'sd74};  // -2
        force dut.memsys.main_mem_inst.mem_array[9] = expected_mem_data[9];
        
        // 地址10
        expected_mem_data[10] = {64'sd55, 64'sd85};
        force dut.memsys.main_mem_inst.mem_array[10] = expected_mem_data[10];
        
        // 地址11
        expected_mem_data[11] = {64'sd17, 64'sd99};
        force dut.memsys.main_mem_inst.mem_array[11] = expected_mem_data[11];
        
        // 地址12
        expected_mem_data[12] = {64'sd90, -64'sd33};
        force dut.memsys.main_mem_inst.mem_array[12] = expected_mem_data[12];
        
        // 地址13
        expected_mem_data[13] = {64'sd0, -64'sd10};
        force dut.memsys.main_mem_inst.mem_array[13] = expected_mem_data[13];
        
        // 地址14
        expected_mem_data[14] = {64'sd78, 64'sd95};
        force dut.memsys.main_mem_inst.mem_array[14] = expected_mem_data[14];
        
        // 地址15
        expected_mem_data[15] = {-64'sd99, 64'sd8};
        force dut.memsys.main_mem_inst.mem_array[15] = expected_mem_data[15];
        
        // 地址16
        expected_mem_data[16] = {64'sd29, -64'sd70};
        force dut.memsys.main_mem_inst.mem_array[16] = expected_mem_data[16];
        
        // 地址17
        expected_mem_data[17] = {64'sd15, -64'sd57};
        force dut.memsys.main_mem_inst.mem_array[17] = expected_mem_data[17];
        
        // 地址18
        expected_mem_data[18] = {64'sd15, 64'sd78};
        force dut.memsys.main_mem_inst.mem_array[18] = expected_mem_data[18];
        
        // 地址19
        expected_mem_data[19] = {64'sd87, 64'sd93};  
        force dut.memsys.main_mem_inst.mem_array[19] = expected_mem_data[19];
        
        // 地址20
        expected_mem_data[20] = {-64'sd45, 64'sd78};
        force dut.memsys.main_mem_inst.mem_array[20] = expected_mem_data[20];
        
        // 地址21
        expected_mem_data[21] = {-64'sd12, 64'sd44};
        force dut.memsys.main_mem_inst.mem_array[21] = expected_mem_data[21];
        
        // 地址22
        expected_mem_data[22] = {-64'sd75, -64'sd54};
        force dut.memsys.main_mem_inst.mem_array[22] = expected_mem_data[22];
        
        // 地址23
        expected_mem_data[23] = {64'sd42, 64'sd62};
        force dut.memsys.main_mem_inst.mem_array[23] = expected_mem_data[23];
        
        // 地址24
        expected_mem_data[24] = {64'sd73, -64'sd12};  // -2 (第三个重复)
        force dut.memsys.main_mem_inst.mem_array[24] = expected_mem_data[24];
        
        // 地址25
        expected_mem_data[25] = {64'sd7, 64'sd93};
        force dut.memsys.main_mem_inst.mem_array[25] = expected_mem_data[25];
        
        // 地址26
        expected_mem_data[26] = {64'sd74, -64'sd4};
        force dut.memsys.main_mem_inst.mem_array[26] = expected_mem_data[26];
        
        // 地址27
        expected_mem_data[27] = {64'sd80, 64'sd88};
        force dut.memsys.main_mem_inst.mem_array[27] = expected_mem_data[27];
        
        // 地址28
        expected_mem_data[28] = {64'sd21, -64'sd40};
        force dut.memsys.main_mem_inst.mem_array[28] = expected_mem_data[28];
        
        // 地址29
        expected_mem_data[29] = {64'sd76, 64'sd22};
        force dut.memsys.main_mem_inst.mem_array[29] = expected_mem_data[29];
        
        // 地址30
        expected_mem_data[30] = {64'sd54, -64'sd91};
        force dut.memsys.main_mem_inst.mem_array[30] = expected_mem_data[30];
        
        // 地址31
        expected_mem_data[31] = {64'sd90, -64'sd47};
        force dut.memsys.main_mem_inst.mem_array[31] = expected_mem_data[31];
        
        // 地址32
        expected_mem_data[32] = {64'sd33, -64'sd81};
        force dut.memsys.main_mem_inst.mem_array[32] = expected_mem_data[32];
        
        // ========== 调用排序任务生成期望结果 ==========
        sort_expected_data();
        
        // 初始化页表区域
        force dut.memsys.main_mem_inst.mem_array[4096] = 128'h00001001_00002001_00003001_00008001;
        force dut.memsys.main_mem_inst.mem_array[8192] = 128'h00010003_00020003_00030003_0000c003;
        force dut.memsys.main_mem_inst.mem_array[8320] = 128'h00010003_00020003_00030003_0000c003;
        force dut.memsys.main_mem_inst.mem_array[12288] = 128'h00001007_00002007_00003007_00000007;
        


        // 启动一个独立的监测进程
        fork
            begin
                // 监测 BRU complete_wb 信号
                forever begin
                    @(posedge clk);
                    if (dut.rv64im.u_top_ex.u_top_bru.complete_wb === 1'b1) begin
                        bru_complete_count++;
                        
                    end
                end
            end
        join_none

     fork
            begin
                // 监测 if_br 信号
                forever begin
                    @(posedge clk);
                    if (dut.rv64im.ifu.pre_decode_inst.if_br === 1'b1) begin
                        bru_pre_count++;
                        
                    end
                end
            end
        join_none
	// 启动一个独立的监测进程
        fork
            begin
                // 监测 BRU complete_wb 信号
                forever begin
                    @(posedge clk);
                    if (dut.memsys.d_cache_inst.hit === 1'b1) begin
                        lsu_complete_count++;
                    end
                end
            end
        join_none

	// 启动一个独立的监测进程
        fork
            begin
                
                forever begin
                    @(posedge clk);
                    if (dut.rv64im.ifu.u_instr_buffer.ic_valid === 1'b1) begin //dut.memsys.i_cache_inst.IC_dataout_val
                        IC_access_count++;
                    end
		   
                end
            end
        join_none



        // 释放复位
        repeat(3) @(posedge clk);
        #1;
        reset = 0;
        
        $display("\n========================================");
        $display("处理器开始执行排序程序...");
        $display("========================================\n");
        
        // 运行足够长时间以完成排序
        repeat(7577) @(posedge clk);








        $display(" BR计数: %0d", bru_complete_count);
	$display(" BR预测总次数: %0d", bru_pre_count);
 	$display(" LSU计数: %0d", lsu_complete_count);
 	$display(" I-Cached计数: %0d", IC_access_count);
	
        
        // ========== 从Cache读取实际排序结果 ==========
        read_from_dcache();
        
        // ========== 比较期望结果和实际结果 ==========
        test_passed = compare_arrays();
        

        
        #100;
        $finish;
    end
    
endmodule




