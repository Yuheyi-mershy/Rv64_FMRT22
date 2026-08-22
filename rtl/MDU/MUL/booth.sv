module booth(
    input logic [63:0] A,
    input logic [63:0] B,
    input logic [3:0] mdu_control_ex1,
    output logic [34:0][127:0] product
);
    
    // 信号声明
    logic [64:0] multiplicand;      // 被乘数
    logic [66:0] multiplier;        // 乘数
    logic [31:0] A_temp, B_temp;
    logic [32:0][2:0] booth_code;   // 存放乘数产生的组合
    logic [32:0][128:0] product_temp; // 存放未移位前的部分积
    logic [32:0][127:0] sign_correct; // 用于符号修正
    logic [127:0] temp_sum;
    logic [127:0] product_33;
    logic [127:0] shift_number;
    
    // 组合逻辑
    assign A_temp = A[31:0];
    assign B_temp = B[31:0];
    assign shift_number = 128'hfffffffffffffffe0000000000000000;
    
    // 取被乘数
    always_comb begin
        case(mdu_control_ex1) 
            4'b0000: multiplicand = {A[63], A};      // MUL  
            4'b0001: multiplicand = {A[63], A};      // MULH
            4'b0010: multiplicand = {1'b0, A};       // MULHSU
            4'b0011: multiplicand = {1'b0, A};       // MULHU
            4'b0100: multiplicand = {{33{A_temp[31]}}, A_temp}; // MULW
            default: multiplicand = 65'd0;
        endcase
    end
    
    // 取乘数
    always_comb begin
        case(mdu_control_ex1) 
            4'b0000: multiplier = {{2{B[63]}}, B, 1'b0}; // MUL  
            4'b0001: multiplier = {{2{B[63]}}, B, 1'b0}; // MULH
            4'b0010: multiplier = {2'b00, B, 1'b0};      // MULHSU
            4'b0011: multiplier = {2'b00, B, 1'b0};      // MULHU
            4'b0100: multiplier = {{34{B_temp[31]}}, B_temp, 1'b0}; // MULW
            default: multiplier = 67'd0;
        endcase
    end
    
    // 计算booth编码（使用generate）
    generate
        for (genvar i = 0; i < 33; i = i + 1) begin
            assign booth_code[i] = {multiplier[2*i+2], multiplier[2*i+1], multiplier[2*i]};
        end
    endgenerate
    
    // 计算部分积（使用generate实例化）
    generate
        for (genvar i = 0; i < 33; i = i + 1) begin
            booth_table generate_part(
                .code(booth_code[i]),
                .multiplicand(multiplicand),
                .product_sign(product_temp[i])
            );
        end
    endgenerate
    
    // 计算最终结果
    always_comb begin
        temp_sum = 128'd0;
        product_33 = 128'd0;
        
        for (int i = 0; i < 33; i = i + 1) begin
            product[i] = (product_temp[i][128:1] << (2 * i));
            product_33[2*i] = product_temp[i][0];
            sign_correct[i] = (product_temp[i][0] == 1'b0) ? 128'd0 : (shift_number << (2 * i));
            temp_sum = temp_sum + sign_correct[i];
        end
        
        product[33] = product_33;
        product[34] = temp_sum;
    end
    
endmodule
