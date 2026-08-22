module brurecovery_alu(
       input logic bru_recovery,
       input logic [6:0] bru_rob_id,
       input logic [6:0] rob_id,
       output logic flush,
       output logic stall
);

       logic is_newer;
       
       // 翻页比较：判断 rob_id 是否比 bru_rob_id 更新
       assign is_newer = (rob_id[6] == bru_rob_id[6]) ? 
                         (rob_id[5:0] > bru_rob_id[5:0]) : 
                         (rob_id[5:0] < bru_rob_id[5:0]);
       
       always_comb begin
          if (bru_recovery && is_newer) begin
              flush = 1'b1;
              stall = 1'b0;
          end
          else if (bru_recovery && ~is_newer) begin
              flush = 1'b0;
              stall = 1'b1;
          end
          else begin
              flush = 1'b0;
              stall = 1'b0;
          end
       end
       
endmodule
