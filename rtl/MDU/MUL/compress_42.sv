module compress_42_128_bit(
    input logic [127:0] pp1,
    input logic [127:0] pp2,
    input logic [127:0] pp3,
    input logic [127:0] pp4,
    output logic [127:0] sum,
    output logic [127:0] carry
);
  
    logic [127:0] shel_cout;
    logic [127:0] shel_carry;
    logic [127:0] cout;
    
    assign shel_cout = pp1 ^ pp2;
    assign shel_carry = (pp1 ^ pp2) ^ (pp3 ^ pp4);
     
    generate
        // 单独处理第0位，避免 cout[-1]
        base_unit_42 compress_0_bit (
            .a(pp1[0]),
            .b(pp2[0]),
            .c(pp3[0]),
            .d(pp4[0]),
            .shel_carry(shel_carry[0]),
            .shel_cout(shel_cout[0]),
            .cin(1'b0),           // 第0位的进位输入为0
            .sum(sum[0]),
            .carry(carry[0]),
            .cout(cout[0])
        );
        
        // 处理第1到127位
        for (genvar i = 1; i < 128; i++) begin 
            base_unit_42 compress_1_bit (
                .a(pp1[i]),
                .b(pp2[i]),
                .c(pp3[i]),
                .d(pp4[i]),
                .shel_carry(shel_carry[i]),
                .shel_cout(shel_cout[i]),
                .cin(cout[i-1]),   // 现在 i>=1，cout[i-1] 有效
                .sum(sum[i]),
                .carry(carry[i]),
                .cout(cout[i])
            );  
        end
    endgenerate
endmodule
