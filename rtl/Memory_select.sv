module Memory_select(
    input  logic clk,
    input  logic reset,
    input  logic IC_req,
    input  logic DC_req,
    input  logic IT_req,
    input  logic DT_req,
    input  logic IC_done,    // I-Cache完成信号
    input  logic DC_done,    // D-Cache完成信号
    input  logic IT_done,    // I-TLB完成信号
    input  logic DT_done,    // D-TLB完成信号
    input  logic recovery,
    input  logic bru_recovery,
    output logic IC_grant,
    output logic DC_grant,
    output logic IT_grant,
    output logic DT_grant
);

    // 状态定义
    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        GRANT_IT    = 3'b001,
        GRANT_DT    = 3'b010,
        GRANT_IC    = 3'b011,
        GRANT_DC    = 3'b100,
        WAIT_CYCLE  = 3'b101  // 新增等待状态
    } state_t;

    state_t current_state, next_state;
    state_t prev_state;  // 记录上一个周期的状态

    // 状态寄存器
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            prev_state <= IDLE;
	end else if(bru_recovery) begin
            current_state <= IDLE;
            prev_state <= IDLE;
	end else if(recovery && (current_state == GRANT_IC|current_state == GRANT_IT)) begin
            current_state <= IDLE;
            prev_state <= IDLE;
        end else begin
            current_state <= next_state;
            prev_state <= current_state;  // 保存上一个状态
        end
    end

    // 下一个状态逻辑
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                // 优先级：DT > DC > IT > IC
                if (DT_req) begin
                    next_state = GRANT_DT;
                end else if (DC_req) begin
                    next_state = GRANT_DC;
                end else if (IT_req) begin
                    next_state = GRANT_IT;
                end else if (IC_req) begin
                    next_state = GRANT_IC;
                end
            end
            
            GRANT_IT: begin
                if (IT_done) begin
                    // 完成后检查是否有其他请求
                    if (DT_req) begin
                        // 从IT切换到DT，需要等待一个周期
                        next_state = WAIT_CYCLE;
                    end else if (DC_req) begin
                        next_state = GRANT_DC; 
                    end else if (IC_req) begin
                        next_state = GRANT_IC;
                    end else if (IT_req) begin
                        // 继续IT请求
                        next_state = GRANT_IT;
                    end else begin
                        next_state = IDLE;
                    end
                end
                // 否则保持GRANT_IT状态
            end
            
            GRANT_DT: begin
                if (DT_done) begin
                    // 完成后检查是否有其他请求
                    if (DC_req) begin 
                        next_state = GRANT_DC;
                    end else if (IT_req) begin
                        next_state = WAIT_CYCLE;
                    end else if (IC_req) begin
                        next_state = GRANT_IC;
                    end else if (DT_req) begin
                        // 继续DT请求
                        next_state = GRANT_DT;
                    end else begin
                        next_state = IDLE;
                    end
                end
                // 否则保持GRANT_DT状态
            end
            
            GRANT_IC: begin
                if (IC_done) begin
                    // 完成后检查是否有其他请求
                    if (DT_req) begin
                        next_state = GRANT_DT;
                    end else if (DC_req) begin
                        next_state = GRANT_DC;
                    end else if (IT_req) begin
                        next_state = GRANT_IT;
                    end else if (IC_req) begin
                        // 继续IC请求
                        next_state = GRANT_IC;
                    end else begin
                        next_state = IDLE;
                    end
                end
                // 否则保持GRANT_IC状态
            end
            
            GRANT_DC: begin
                if (DC_done) begin
                    // 完成后检查是否有其他请求
                    if (DT_req) begin
                        next_state = GRANT_DT;
                    end else if (IT_req) begin
                        next_state = GRANT_IT;
                    end else if (IC_req) begin
                        next_state = GRANT_IC;
                    end else if (DC_req) begin
                        // 继续DC请求
                        next_state = GRANT_DC;
                    end else begin
                        next_state = IDLE;
                    end
                end
                // 否则保持GRANT_DC状态
            end
            
            WAIT_CYCLE: begin
                // 等待一个周期后，根据上一个状态决定下一个状态
                case (prev_state)
                    GRANT_IT: begin
                        if (DT_req) begin
                            next_state = GRANT_DT;
                        end else if (IC_req) begin
                            next_state = GRANT_IC;
                        end else if (DC_req) begin
                            next_state = GRANT_DC;
                        end else begin
                            next_state = IDLE;
                        end
                    end
                    GRANT_DT: begin
                        if (IT_req) begin
                            next_state = GRANT_IT;
                        end else if (IC_req) begin
                            next_state = GRANT_IC;
                        end else if (DC_req) begin
                            next_state = GRANT_DC;
                        end else begin
                            next_state = IDLE;
                        end
                    end
                    default: begin
                        // 不应该进入这个分支，但安全起见回到IDLE
                        next_state = IDLE;
                    end
                endcase
            end
        endcase
    end

    // 输出逻辑
    always_comb begin
        // 默认值
        IT_grant = 1'b0;
        DT_grant = 1'b0;
        IC_grant = 1'b0;
        DC_grant = 1'b0;
        
        case (current_state)
            GRANT_IT: begin
                IT_grant = 1'b1;
            end
            GRANT_DT: begin
                DT_grant = 1'b1;
            end
            GRANT_IC: begin
                IC_grant = 1'b1;
            end
            GRANT_DC: begin
                DC_grant = 1'b1;
            end
            WAIT_CYCLE: begin
                // 等待状态，所有grant为0
            end
            default: begin
                // IDLE状态，所有grant为0
            end
        endcase
    end

endmodule
