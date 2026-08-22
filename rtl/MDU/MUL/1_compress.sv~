module  first_compress(
    input logic [31:0][127:0]pp_in_1,
    output logic [7:0][127:0]pp_out_1
);
    logic [7:0][127:0]second_sum;
    logic [7:0][127:0]second_carry;//需要保证在使用的时候要左移；
    generate
        //=====第一级的压缩32-16====//
        for (genvar i = 0; i <8; i=i+1) begin 
        // 实例化128个4：2压缩器模块
            compress_42_128_bit stage1_comp(
              .pp1(pp_in_1[i*4]),
              .pp2(pp_in_1[i*4+1]),
              .pp3(pp_in_1[i*4+2]),
              .pp4(pp_in_1[i*4+3]),
              .sum(second_sum[i]),
              .carry(second_carry[i])
            );
        end
        //=========第二级压缩===========//
        for (genvar i = 0; i <4; i=i+1) begin 
        // 实例化128个4：2压缩器模块
            compress_42_128_bit stage2_comp (
              .pp1(second_sum[i*2]),
              .pp2(second_carry[i*2]<<1),
              .pp3(second_sum[i*2+1]),
              .pp4(second_carry[i*2+1]<<1),
              .sum(pp_out_1[i*2]),
              .carry(pp_out_1[i*2+1])
            );
        end
    endgenerate
endmodule
