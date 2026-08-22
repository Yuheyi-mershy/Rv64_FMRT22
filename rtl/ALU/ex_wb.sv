module exwb_alu(
    input logic clk,
    input logic reset,
    input logic [6:0] rob_id_ex,
    input logic complete_ex,
    input logic [5:0] rd_number_ex,
    input logic [63:0] value_ex,
    input logic bru_recovery,
    input logic [6:0] bru_rob_id,
    input logic reg_write_ex,
    output logic [6:0] rob_id_wb,
    output logic complete_wb,
    output logic [5:0] rd_number_wb,
    output logic [63:0] value_wb,
    output logic reg_write_wb
);
    // 定义产生冲突时候的信号
    logic flush, stall;
    
    brurecovery_alu bru_re(bru_recovery, bru_rob_id, rob_id_ex, flush, stall);
    
    // 正常执行
    always_ff @(posedge clk) begin
        if(reset | flush) begin
            rob_id_wb <= 7'd0;
            complete_wb <= 1'b0;
            rd_number_wb <= 6'b000000;
            value_wb <= 64'd0;
            reg_write_wb <= 1'b0;
        end
        else if(~stall) begin
            rob_id_wb <= rob_id_ex;
            complete_wb <= complete_ex;
            rd_number_wb <= rd_number_ex;
            value_wb <= value_ex;
            reg_write_wb <= reg_write_ex;
        end
    end
endmodule
