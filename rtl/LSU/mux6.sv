module mux6_lsu #(parameter  WIDTH=64)(
    input logic [63:0]a0,
    input logic [63:0]a1,
    input logic [63:0]a2,
    input logic [63:0]a3,
    input logic [63:0]a4,
    input logic [63:0]a5,
    input logic [2:0]forward,
    output logic [63:0]b
);
always_comb begin
   case(forward)
   3'b000: b=a0;
   3'b001: b=a1;
   3'b010: b=a2;
   3'b011: b=a3;
   3'b100: b=a4;
   3'b101: b=a5;
   default:b=64'd0;
   endcase
end
endmodule
