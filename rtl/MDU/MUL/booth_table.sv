module booth_table(
   input logic [2:0] code,
   input logic [64:0] multiplicand,
   output logic [128:0] product_sign
);
    
    logic [64:0] not_multiplicand;
    
    // 连续赋值应该在 always_comb 外面
    assign not_multiplicand = ~multiplicand;
    
    always_comb begin
        case(code)  
            // 这个相当于把对应的值和符号输出了
            3'b000: product_sign = 129'd0;
            3'b001: product_sign = {{63{1'b0}}, multiplicand, 1'd0};
            3'b010: product_sign = {{63{1'b0}}, multiplicand, 1'd0};
            3'b011: product_sign = {{62{1'b0}}, multiplicand, 1'b0, 1'd0};
            3'b100: product_sign = {{62{1'b0}}, not_multiplicand, 1'b0, 1'd1};
            3'b101: product_sign = {{63{1'b0}}, not_multiplicand, 1'd1};
            3'b110: product_sign = {{63{1'b0}}, not_multiplicand, 1'd1};
            3'b111: product_sign = 129'd0; 
            default: product_sign = 129'd0;
        endcase
    end
    // product都是未处理过的，还没有移位
endmodule
