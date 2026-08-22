

module pre_decode(

    input  logic        ic_dataout_val,
    input  logic [11:0] br_type_out,
    input  logic [63:0] pc,

    output logic [2:0]  num,
    output logic [63:0] br_pc,
    output logic [1:0]  br_logic,
    output logic        pc_read_btb,
    output logic [2:0] 	br_type,
    output logic        if_br,
    output logic 	    read_ras //输出作为BOB的一个输入信号写进去

);

    logic [3:0] fetch_num;
    logic [3:0] branch_pos; 
    logic       write_ras;
    

    always_comb begin
        // ================= 默认值（防 latch）=================
        num           = 3'd0;
        br_pc         = 64'd0;
        br_logic      = 2'd0;
        pc_read_btb   = 1'b0;
        write_ras     = 1'b0;
        read_ras      = 1'b0;

        fetch_num    = 4'b0000;
        branch_pos    = 4'b0000;
        if_br         = 1'b0;
        br_type       = 3'd0;

        // ================= 主逻辑 =================
        if (ic_dataout_val) begin

            // ---- branch_pos ----
            branch_pos[0] = (br_type_out[2:0]  != 3'b000);
            branch_pos[1] = (br_type_out[5:3]  != 3'b000);
            branch_pos[2] = (br_type_out[8:6]  != 3'b000);
            branch_pos[3] = (br_type_out[11:9] != 3'b000);

            // ---- fetch_num ----
            case (pc[3:2])
                2'b00: fetch_num = 4'b1111;
                2'b01: fetch_num = 4'b1110;
                2'b10: fetch_num = 4'b1100;
                2'b11: fetch_num = 4'b1000;
                default: fetch_num = 4'b1000;
            endcase

            // ---- 选择第一个分支 ----
            case (fetch_num)

                4'b1111: begin
                    if      (branch_pos[0]) begin num = 3'd1; if_br = 1'b1; end
                    else if (branch_pos[1]) begin num = 3'd2; if_br = 1'b1; end
                    else if (branch_pos[2]) begin num = 3'd3; if_br = 1'b1; end
                    else if (branch_pos[3]) begin num = 3'd4; if_br = 1'b1; end
                    else begin num = 3'd4; if_br = 1'b0; end
                end

                4'b1110: begin
                    if      (branch_pos[1]) begin num = 3'd1; if_br = 1'b1; end
                    else if (branch_pos[2]) begin num = 3'd2; if_br = 1'b1; end
                    else if (branch_pos[3]) begin num = 3'd3; if_br = 1'b1; end
                    else begin num = 3'd3; if_br = 1'b0; end
                end

                4'b1100: begin
                    if (branch_pos[2]) begin num = 3'd1; if_br = 1'b1; end
                    else begin num = 3'd2; if_br = branch_pos[3]; end
                end

                4'b1000: begin
                    num   = 3'd1;
                    if_br = branch_pos[3];
                end

                default: begin
                    num   = 3'd0;
                    if_br = 1'b0;
                end

            endcase

            // ---- br_pc ----
            if (if_br) begin
                br_pc = pc + (num - 1) * 64'd4;
            end

            // ---- br_logic ----
            if (if_br) begin
                case (fetch_num)
                    4'b1111: begin
                        if      (branch_pos[0]) br_logic = 2'b00;
                        else if (branch_pos[1]) br_logic = 2'b01;
                        else if (branch_pos[2]) br_logic = 2'b10;
                        else                    br_logic = 2'b11;
                    end

                    4'b1110: begin
                        if      (branch_pos[1]) br_logic = 2'b01;
                        else if (branch_pos[2]) br_logic = 2'b10;
                        else                    br_logic = 2'b11;
                    end

                    4'b1100: begin
                        if      (branch_pos[2]) br_logic = 2'b10;
                        else                    br_logic = 2'b11;
                    end

                    4'b1000: begin
                        br_logic = 2'b11;
                    end

                    default: br_logic = 2'b00;
                endcase

                // ---- br_type 选择 ----
                case (br_logic)
                    2'b00: br_type = br_type_out[2:0];
                    2'b01: br_type = br_type_out[5:3];
                    2'b10: br_type = br_type_out[8:6];
                    2'b11: br_type = br_type_out[11:9];
                    default: br_type = 3'b000;
                endcase

                // ---- 控制信号 ----
                case (br_type)
                    3'b001: begin
                        pc_read_btb = 1'b1;
                        write_ras   = 1'b0;
                        read_ras    = 1'b0;
                    end
                    3'b010: begin
                        pc_read_btb = 1'b1;
                        write_ras   = 1'b1;
                        read_ras    = 1'b0;
                    end
                    3'b011: begin
                        pc_read_btb = 1'b1;
                        write_ras   = 1'b0;
                        read_ras    = 1'b0;
                    end
                    3'b100: begin
                        pc_read_btb = 1'b0;
                        write_ras   = 1'b0;
                        read_ras    = 1'b1;
    
                    end
                    default: begin
                        pc_read_btb = 1'b0;
                        write_ras   = 1'b0;
                        read_ras    = 1'b0;
                    end
                endcase
            end else begin
                br_logic = 2'b00;
                pc_read_btb = 1'b0;
                write_ras   = 1'b0;
                read_ras    = 1'b0;
            end
        end
    end

endmodule

