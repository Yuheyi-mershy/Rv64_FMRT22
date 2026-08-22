module mux2_alu #(parameter  WIDTH=64)(
    input logic [63:0]a,
    input logic [63:0]b,
    input logic select,
    output logic [63:0]c
);

  assign c=select ?a:b;
  
endmodule
