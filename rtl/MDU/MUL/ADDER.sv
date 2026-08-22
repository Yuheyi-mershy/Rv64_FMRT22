module PPA_adder(
     input logic [127:0] product0,
     input logic [127:0] product1,
     output logic [127:0] Result
);
     logic [127:0] p;  // 传播进位信号有效否
     logic [127:0] g;  // 生成信号有效否
     logic [127:0] P_1;  // 传播节点
     logic [127:0] G_1;  // 生成节点
     logic [127:0] P_2;  // 传播节点
     logic [127:0] G_2;  // 生成节点
     logic [127:0] P_3;  // 传播节点
     logic [127:0] G_3;  // 生成节点
     logic [127:0] P_4;  // 传播节点
     logic [127:0] G_4;  // 生成节点
     logic [127:0] P_5;  // 传播节点
     logic [127:0] G_5;  // 生成节点
     logic [127:0] P_6;  // 传播节点
     logic [127:0] G_6;  // 生成节点
     logic [127:0] P_7;  // 传播节点
     logic [127:0] G_7;  // 生成节点
     logic [127:0] c;  // 进位
     
     //=====初始化准备工作，生成每一位的pi,gi;======//
     assign g = product0 & product1;  // 逐位生成g[i]
     assign p = product0 ^ product1;  // 逐位生成p[i]
 
always_comb begin
     //===一共要进行七次合并======================//
     //第一次合并，i>=1的都可以合并，生成了新节点。
     for(int i = 0; i < 128; i++) begin
        G_1[i] = (i == 0) ? g[0] : (g[i] | (p[i] & g[i-1]));
        P_1[i] = (i == 0) ? p[0] : (p[i] & p[i-1]);
     end
     
     //第二次合并，i>=2的都可以合并，生成一轮新节点//
     for(int i = 0; i < 128; i++) begin
        G_2[i] = (i < 2) ? G_1[i] : (G_1[i] | (P_1[i] & G_1[i-2]));
        P_2[i] = (i < 2) ? P_1[i] : (P_1[i] & P_1[i-2]);
     end
     
     //第三次合并，i>=4的都可以合并，生成一轮新节点//
     for(int i = 0; i < 128; i++) begin
        G_3[i] = (i < 4) ? G_2[i] : (G_2[i] | (P_2[i] & G_2[i-4]));
        P_3[i] = (i < 4) ? P_2[i] : (P_2[i] & P_2[i-4]);
     end
     
     //第四次合并，i>=8的都可以合并，生成一轮新节点//
     for(int i = 0; i < 128; i++) begin
        G_4[i] = (i < 8) ? G_3[i] : (G_3[i] | (P_3[i] & G_3[i-8]));
        P_4[i] = (i < 8) ? P_3[i] : (P_3[i] & P_3[i-8]);
     end
     
     //第五次合并，i>=16的都可以合并，生成一轮新节点//
     for(int i = 0; i < 128; i++) begin
        G_5[i] = (i < 16) ? G_4[i] : (G_4[i] | (P_4[i] & G_4[i-16]));
        P_5[i] = (i < 16) ? P_4[i] : (P_4[i] & P_4[i-16]);
     end
     
     //第六次合并，i>=32的都可以合并，生成一轮新节点//
     for(int i = 0; i < 128; i++) begin
        G_6[i] = (i < 32) ? G_5[i] : (G_5[i] | (P_5[i] & G_5[i-32]));
        P_6[i] = (i < 32) ? P_5[i] : (P_5[i] & P_5[i-32]);
     end
     
     //第七次合并，i>=64的都可以合并，生成一轮新节点//
     for(int i = 0; i < 128; i++) begin
        G_7[i] = (i < 64) ? G_6[i] : (G_6[i] | (P_6[i] & G_6[i-64]));
        P_7[i] = (i < 64) ? P_6[i] : (P_6[i] & P_6[i-64]);
     end
     
     //最后把每一位的进位都准备好
     for(int i = 0; i < 128; i++) begin
        c[i] = (i == 0) ? 1'b0 : G_7[i-1];
     end
     
     //产生了进位之后，开始最后的计算
     for(int i = 0; i < 128; i++) begin
        Result[i] = product0[i] ^ product1[i] ^ c[i];
     end
end

endmodule
