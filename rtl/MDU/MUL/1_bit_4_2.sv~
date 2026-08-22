module  base_unit_42(
     input logic a,
     input logic b,
     input logic c,
     input logic d,
     input logic cin,
     input logic shel_carry,
     input logic shel_cout,
     output logic sum,
     output logic carry,
     output logic cout
);  
   
    //定义信号的产生和sum+carry的输出
    assign sum=shel_carry^cin;
    assign carry=(shel_carry)?cin:d;
    assign cout=(shel_cout)?c:a;
endmodule
