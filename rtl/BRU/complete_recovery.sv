module resolve_bru(
   input logic complete_fentch,
   input logic complete_rob,
   output logic resolve_complete
);
   assign resolve_complete=(complete_fentch&complete_rob)?1'b1:1'b0;
endmodule
