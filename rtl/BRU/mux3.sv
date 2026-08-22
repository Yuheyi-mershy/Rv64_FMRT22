module mux3_bru #(parameter WIDTH=64)(
    input logic [WIDTH-1:0] a,
    input logic [WIDTH-1:0] b,
    input logic [WIDTH-1:0] c,
    input logic [1:0] select,
    output logic [WIDTH-1:0] d
);
    // 修正：输出应该是 d，而不是给输入 c 赋值
    assign d = (select == 2'b00) ? a : 
               (select == 2'b01) ? b : 
               c;
endmodule
