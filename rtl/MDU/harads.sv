module brurecovery_mul(
       input logic bru_recovery,
       input logic [6:0] bru_rob_id,
       input logic [6:0] rob_id,
       output logic flush,
       output logic stall
);
       
       always_comb begin
          if (bru_recovery == 1'b1) begin
              // 情况1：翻页信号相同（最高位相同）
              if (bru_rob_id[6] == rob_id[6]) begin
                  // 同一半区，直接比较低5位
                  if (rob_id[5:0] > bru_rob_id[5:0]) begin
                      // rob_id更大，说明更新，需要flush
                      flush = 1'b1;
                      stall = 1'b1;
                  end
                  else begin
                      // rob_id更小或相等，只需要stall
                      flush = 1'b0;
                      stall = 1'b1;
                  end
              end
              // 情况2：翻页信号不同（最高位不同）
              else begin
                  // 不同半区，翻页信号小的实际更大（更新）
                  if (rob_id[6] < bru_rob_id[6]) begin
                      // fu翻页信号小，说明更新，需要flush
                      flush = 1'b1;
                      stall = 1'b1;
                  end
                  else begin
                      // fu翻页信号大，说明更旧，只需要stall
                      flush = 1'b0;
                      stall = 1'b1;
                  end
              end
          end
          else begin
              // 没有分支恢复
              flush = 1'b0;
              stall = 1'b0;
          end
       end
       
endmodule
