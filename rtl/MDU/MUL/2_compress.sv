module second_compress(
    input  logic [7:0][127:0] pp_in_2,
    input  logic [2:0][127:0] ex3_pp_in,
    input  logic [3:0]        mdu_control_ex2,
    input  logic              instr_valid_ex3,
    output logic [63:0]       result,
    output logic              complete_ex3
);

    logic [127:0]   pp_32_1;
    logic [127:0]   pp_32_2;
    logic [3:0][127:0] temp_pp;
    logic [1:0][127:0] temp_pp_pp;
    logic [1:0][127:0] product;
    logic             complete;
    logic [127:0]     result_temp;

    //======== 3:2 压缩 ==========//
    compress_32_128_bit compress_32(
        .pp1(ex3_pp_in[0]),
        .pp2(ex3_pp_in[1]),
        .pp3(ex3_pp_in[2]),
        .sum(pp_32_1),
        .carry(pp_32_2)
    );

    generate
        //======== 第三级压缩 =======//
        for (genvar i = 0; i < 2; i++) begin 
            compress_42_128_bit stage3_comp(
                .pp1(pp_in_2[i*4]),
                .pp2(pp_in_2[i*4+1] << 1),
                .pp3(pp_in_2[i*4+2]),
                .pp4(pp_in_2[i*4+3] << 1),
                .sum(temp_pp[i*2]),
                .carry(temp_pp[i*2+1])
            );
        end

        //======== 第四级压缩 ===========//
        compress_42_128_bit stage4_comp(
            .pp1(temp_pp[0]),
            .pp2(temp_pp[1] << 1),
            .pp3(temp_pp[2]),
            .pp4(temp_pp[3] << 1),
            .sum(temp_pp_pp[0]),
            .carry(temp_pp_pp[1])
        );

        //======== 第五级压缩 ============//
        compress_42_128_bit stage5_comp(
            .pp1(temp_pp_pp[0]),
            .pp2(temp_pp_pp[1] << 1),
            .pp3(pp_32_1),
            .pp4(pp_32_2 << 1),
            .sum(product[0]),
            .carry(product[1])
        );

        // 并行前缀加法器
        PPA_adder adder(
            .product0(product[0]),
            .product1(product[1] << 1),
            .Result(result_temp)
        );
    endgenerate

    // ====== 结果选择（修复版）======
    always_comb begin
        case(mdu_control_ex2)
            4'b0000: begin result = result_temp[63:0];   complete = 1'd1; end   // MUL
            4'b0001: begin result = result_temp[127:64]; complete = 1'd1; end   // MULH
            4'b0010: begin result = result_temp[127:64]; complete = 1'd1; end   // MULHSU
            4'b0011: begin result = result_temp[127:64]; complete = 1'd1; end   // MULHU
            4'b0100: begin result = result_temp[63:0];   complete = 1'd1; end   // MULW
            default: begin result = 64'd0;               complete = 1'd0; end
        endcase
    end

    // 输出完成信号
    assign complete_ex3 = instr_valid_ex3 & complete;

endmodule
