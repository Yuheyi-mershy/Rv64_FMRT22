module compress_32_128_bit(
    input logic [127:0]pp1,
    input logic [127:0]pp2,
    input logic [127:0]pp3,
    output logic [127:0]sum,
    output logic [127:0]carry
);
    assign sum=pp1^pp2^pp3;
    assign carry=(pp1&pp2)|(pp3& (pp1^pp2));
endmodule


