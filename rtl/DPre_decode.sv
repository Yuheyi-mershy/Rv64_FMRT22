module Pre_decode(
    input  logic[127:0] instrutions,
    output logic[11:0] PD
);
logic [31:0] instr1;
logic [31:0] instr2;
logic [31:0] instr3;
logic [31:0] instr4;
logic [11:9] PD_4;
logic [8:6]  PD_3;
logic [5:3]  PD_2;
logic [2:0]  PD_1;

Decode_logic DL1(
        .opcode     (instr1[6:0]),
        .rs1        (instr1[19:15]),
        .rd         (instr1[11:7]),
        .PD_information (PD_1)
        );
    Decode_logic DL2(
        .opcode     (instr2[6:0]),
        .rs1        (instr2[19:15]),
        .rd         (instr2[11:7]),
        .PD_information (PD_2)
        );    
    Decode_logic DL3(
        .opcode     (instr3[6:0]),
        .rs1        (instr3[19:15]),
        .rd         (instr3[11:7]),
        .PD_information (PD_3)
        );
    Decode_logic DL4(
        .opcode     (instr4[6:0]),
        .rs1        (instr4[19:15]),
        .rd         (instr4[11:7]),
        .PD_information (PD_4)
        );

always_comb begin 
    instr1 = instrutions[31:0];
    instr2 = instrutions[63:32];
    instr3 = instrutions[95:64];
    instr4 = instrutions[127:96];
   
    PD = {PD_4,PD_3,PD_2,PD_1};            
end

endmodule

module Decode_logic (
    input  logic[6:0] opcode,
    input  logic[4:0] rs1,
    input  logic[4:0] rd,
    output logic[2:0] PD_information
);
    always_comb begin 
        case (opcode)
            7'b1100011: PD_information = 3'b001;
            7'b1101111: if ((rd == 5'b00001)|(rd == 5'b00101)) 
                            PD_information = 3'b010;
                        else
                            PD_information = 3'b011;
            7'b1100111: if (((rd == 5'b00001)|(rd == 5'b00101))&((rs1 == 5'b00001)|(rs1 == 5'b00101)))
                            PD_information = 3'b010;
                        else if (((rd == 5'b00001)|(rd == 5'b00101))&((rs1 != 5'b00001)&(rs1 != 5'b00101)))
                            PD_information = 3'b010;
                        else if (((rd != 5'b00001)&(rd != 5'b00101))&((rs1 == 5'b00001)|(rs1 == 5'b00101)))
                            PD_information = 3'b100;
                        else
                            PD_information = 3'b011;
            7'b0010111: PD_information = 3'b101;
            default:    PD_information = 3'b000;
        endcase
    end
endmodule


