module instr_buffer #(
    parameter DEPTH = 32
)(
    input  wire         clk,
    input  wire         rst_n,

    input  wire [63:0]  pc,

    /* ICache */
    input  wire         ic_valid,
    input  wire [127:0] ic_line,
    input  wire [4:0]   ic_bob_id_0,
    input  wire [4:0]   ic_bob_id_1, 
    input  wire [4:0]   ic_bob_id_2,
    input  wire [4:0]   ic_bob_id_3,
    input  wire [2:0]   ic_num,

    output wire         ib_ready,

    /* IF/ID */
    output reg  [1:0]   ib_valid,
    input  wire         if_ready,
    output reg  [31:0]  if_instr0,
    output reg  [31:0]  if_instr1,
    output reg  [4:0]   if_bob_id0,
    output reg  [4:0]   if_bob_id1,

    /* flush */
    input  wire         bru_recover,
    input  wire         dec_recover,
    input  wire         recoverib_complete,

    /* debug */
    output reg  [5:0]   used_cnt_dbg,
    output reg  [5:0]   free_cnt_dbg,

    output reg ib_full,
    output reg ib_empty
);

/* ---------------- parameters ---------------- */
localparam PTR_W = $clog2(DEPTH);
localparam MASK  = DEPTH - 1;

/* ---------------- FIFO ---------------- */
reg [31:0] mem_instr [0:DEPTH-1];
reg [4:0]  mem_bid   [0:DEPTH-1];

reg [PTR_W-1:0] rd_ptr, wr_ptr;
reg [5:0] used;

always @(*) begin
    ib_empty = (used == 0);
    ib_full  = (used == DEPTH);
end


/* ---------------- control ---------------- */
wire flush = bru_recover | dec_recover;

reg ib_valid_state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ib_valid_state <= 1'b1;
    else if (flush)
        ib_valid_state <= 1'b0;
    else if (recoverib_complete)
        ib_valid_state <= 1'b1;
end

/* ---------------- offset ---------------- */
wire [1:0] offset = pc[3:2];

/* ---------------- line split ---------------- */
wire [31:0] line [0:3];
assign {line[3], line[2], line[1], line[0]} = ic_line;

/* ---------------- select ---------------- */
reg [31:0] sel_instr [0:3];
reg [4:0]  sel_bid   [0:3];

always @(*) begin
    case(offset)
        2'd0: begin
            sel_instr[0]=line[0]; sel_bid[0]=ic_bob_id_0;
            sel_instr[1]=line[1]; sel_bid[1]=ic_bob_id_1;
            sel_instr[2]=line[2]; sel_bid[2]=ic_bob_id_2;
            sel_instr[3]=line[3]; sel_bid[3]=ic_bob_id_3;
        end
        2'd1: begin
            sel_instr[0]=line[1]; sel_bid[0]=ic_bob_id_1;
            sel_instr[1]=line[2]; sel_bid[1]=ic_bob_id_2;
            sel_instr[2]=line[3]; sel_bid[2]=ic_bob_id_3;
            sel_instr[3]=0;       sel_bid[3]=0;
        end
        2'd2: begin
            sel_instr[0]=line[2]; sel_bid[0]=ic_bob_id_2;
            sel_instr[1]=line[3]; sel_bid[1]=ic_bob_id_3;
            sel_instr[2]=0; sel_instr[3]=0;
            sel_bid[2]=0;   sel_bid[3]=0;
        end
        default: begin
            sel_instr[0]=line[3]; sel_bid[0]=ic_bob_id_3;
            sel_instr[1]=0; sel_instr[2]=0; sel_instr[3]=0;
            sel_bid[1]=0;   sel_bid[2]=0;   sel_bid[3]=0;
        end
    endcase
end

/* ---------------- push ---------------- */
wire [2:0] max_fetch = 4 - offset;
wire [2:0] push_real = (ic_num < max_fetch) ? ic_num : max_fetch;

/* 关键：ready 只看 push_real，避免组合环 */
wire [2:0] push_req = ic_valid ? push_real : 0;

assign ib_ready = ib_valid_state && ((DEPTH - used) >= push_req);


/* push fire（不依赖 if_ready）*/
wire push_fire = ic_valid & ib_ready & !flush & ib_valid_state;

/* ---------------- bypass ---------------- */
wire bypass = ib_empty & push_fire & if_ready;

wire [1:0] bypass_send = (push_real >= 2) ? 2 :
                         (push_real == 1) ? 1 : 0;

/* ---------------- send ---------------- */
reg [1:0] send;

always @(*) begin
    send = 0;

    if (!flush && ib_valid_state && if_ready) begin
        if (bypass)
            send = bypass_send;
        else if (used >= 2)
            send = 2;
        else if (used == 1)
            send = 1;
    end
end

/* ---------------- pop ---------------- */
wire [1:0] pop = (if_ready && !flush) ? (bypass ? 0 : send) : 0;

/* ---------------- push into IB ---------------- */
wire [2:0] push_into_ib = bypass ? (push_real - send) : push_real;

/* ---------------- output ---------------- */
always @(*) begin
    ib_valid   = 0;
    if_instr0  = 0;
    if_instr1  = 0;
    if_bob_id0 = 0;
    if_bob_id1 = 0;

    if (!flush && ib_valid_state) begin
        ib_valid[0] = (send >= 1);
        ib_valid[1] = (send >= 2);

        if (bypass) begin
            if_instr0  = sel_instr[0];
            if_bob_id0 = sel_bid[0];

            if (send == 2) begin
                if_instr1  = sel_instr[1];
                if_bob_id1 = sel_bid[1];
            end
        end
        else begin
          if (send >= 1) begin
   	  if_instr0  = mem_instr[rd_ptr];
    	  if_bob_id0 = mem_bid[rd_ptr];
	end

	if (send >= 2) begin
  	 if_instr1  = mem_instr[(rd_ptr+1)&MASK];
   	 if_bob_id1 = mem_bid[(rd_ptr+1)&MASK];
end

        end
    end
end

/* ---------------- FIFO ---------------- */
integer i;

always @(posedge clk or negedge rst_n) begin
integer j;
	if (!rst_n) begin
   	 for (j = 0; j < DEPTH; j = j + 1) begin
      	  mem_instr[j] <= 0;
       	 mem_bid[j]   <= 0;
    end
end    
	if (!rst_n || flush) begin
        rd_ptr <= 0;
        wr_ptr <= 0;
        used   <= 0;
    end
	
    else begin
        /* write */
        if (push_fire) begin
            for(i=0;i<push_into_ib;i=i+1) begin
                if (bypass) begin
                    mem_instr[(wr_ptr+i)&MASK] <= sel_instr[i+send];
                    mem_bid  [(wr_ptr+i)&MASK] <= sel_bid[i+send];
                end
                else begin
                    mem_instr[(wr_ptr+i)&MASK] <= sel_instr[i];
                    mem_bid  [(wr_ptr+i)&MASK] <= sel_bid[i];
                end
            end
            wr_ptr <= (wr_ptr + push_into_ib) & MASK;
        end

        /* read */
        if (pop != 0)
            rd_ptr <= (rd_ptr + pop) & MASK;

        /* used update */
       if (used + push_into_ib - pop > DEPTH)
    used <= DEPTH;
else
    used <= used + push_into_ib - pop;

    end
end

/* ---------------- debug ---------------- */
always @(*) begin
    used_cnt_dbg = used;
    free_cnt_dbg = DEPTH - used;
end

endmodule

