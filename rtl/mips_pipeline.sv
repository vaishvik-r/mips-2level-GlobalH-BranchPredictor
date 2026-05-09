// mips_pipeline.sv — Top-level 5-stage MIPS pipeline
// with Forwarding, Hazard Detection, and Two-Level Branch Predictor

module mips_pipeline (
    input logic clk,
    input logic rst
);

// ================================================================
// PIPELINE REGISTERS
// ================================================================

// IF/ID
logic [31:0] if_id_pc, if_id_instr;

// ID/EX
logic [31:0] id_ex_pc, id_ex_rd1, id_ex_rd2, id_ex_imm;
logic [4:0]  id_ex_rs, id_ex_rt, id_ex_rd;
logic [5:0]  id_ex_funct;
logic        id_ex_reg_dst, id_ex_alu_src, id_ex_mem_to_reg;
logic        id_ex_reg_write, id_ex_mem_read, id_ex_mem_write;
logic        id_ex_branch, id_ex_jump;
logic [1:0]  id_ex_alu_op;
logic        id_ex_bne; // distinguish beq vs bne

// EX/MEM
logic [31:0] ex_mem_pc_branch, ex_mem_alu_result, ex_mem_rd2;
logic [4:0]  ex_mem_rd;
logic        ex_mem_zero;
logic        ex_mem_reg_write, ex_mem_mem_to_reg;
logic        ex_mem_mem_read, ex_mem_mem_write;
logic        ex_mem_branch, ex_mem_bne;

// MEM/WB
logic [31:0] mem_wb_read_data, mem_wb_alu_result;
logic [4:0]  mem_wb_rd;
logic        mem_wb_reg_write, mem_wb_mem_to_reg;

// ================================================================
// WIRES
// ================================================================
logic [31:0] pc, pc_next, pc_plus4;
logic [31:0] instr;
logic [31:0] rd1, rd2, imm_ext;
logic [31:0] alu_a, alu_b, alu_result;
logic [3:0]  alu_ctrl;
logic        alu_zero;
logic [31:0] pc_branch, pc_jump;
logic        branch_taken, branch_mispred;
logic        prediction, update_en, actual_outcome;
logic        is_branch_if;

logic        stall;
logic        flush_id_ex;   // flush on branch taken
logic        flush_if_id;
logic        flush_ex_mem;  // flush EX/MEM on branch taken (3rd wrong instruction)

logic [1:0]  forward_a, forward_b;
logic [31:0] fwd_a, fwd_b;

logic        reg_dst_w, alu_src_w, mem_to_reg_w;
logic        reg_write_w, mem_read_w, mem_write_w, branch_w, jump_w;
logic [1:0]  alu_op_w;

logic [31:0] wb_data;
logic [31:0] mem_rd_data;

// ================================================================
// IF STAGE — Instruction Fetch
// ================================================================
instr_mem imem (.addr(pc), .instr(instr));

// Branch predictor sits here — predicts in IF using GHR
assign is_branch_if = (instr[31:26] == 6'b000100 || instr[31:26] == 6'b000101);

branch_predictor bp (
    .clk(clk), .rst(rst),
    .is_branch(is_branch_if),
    .prediction(prediction),
    .update_en(update_en),
    .actual_outcome(actual_outcome)
);

// PC computation
assign pc_plus4  = pc + 32'd4;
assign pc_branch = ex_mem_pc_branch; // resolved branch target
assign pc_jump   = {if_id_pc[31:28], if_id_instr[25:0], 2'b00}; // J-type

// Branch resolution in EX/MEM stage
assign branch_taken  = ex_mem_branch  && ex_mem_zero  ||
                       ex_mem_bne     && !ex_mem_zero;
assign branch_mispred = branch_taken != 1'b0; // simplified: flush on any branch resolve
// For predictor update
assign update_en     = ex_mem_branch || ex_mem_bne;
assign actual_outcome = branch_taken;

// Branch resolves in EX/MEM stage.
// We always predict not-taken (PC+4). If branch is taken, 2 wrong instructions
// have entered the pipeline (in IF/ID and ID/EX), so flush both.
// Also flush EX/MEM itself (clear control signals so no write-back occurs).
assign flush_if_id  = branch_taken;
assign flush_id_ex  = branch_taken;
assign flush_ex_mem = branch_taken;

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        pc <= 32'd0;
    else if (!stall) begin
        if (branch_taken)
            pc <= pc_branch;
        else if (id_ex_jump)
            pc <= pc_jump;
        else
            pc <= pc_plus4;
    end
end

// IF/ID pipeline register
always_ff @(posedge clk or posedge rst) begin
    if (rst || flush_if_id) begin
        if_id_pc    <= 32'd0;
        if_id_instr <= 32'd0; // NOP
    end else if (!stall) begin
        if_id_pc    <= pc_plus4;
        if_id_instr <= instr;
    end
end

// ================================================================
// ID STAGE — Instruction Decode & Register Read
// ================================================================
wire [5:0] opcode = if_id_instr[31:26];
wire [4:0] rs     = if_id_instr[25:21];
wire [4:0] rt     = if_id_instr[20:16];
wire [4:0] rd_id  = if_id_instr[15:11];
wire [5:0] funct  = if_id_instr[5:0];
wire [15:0] imm   = if_id_instr[15:0];

control ctrl (
    .opcode(opcode),
    .reg_dst(reg_dst_w), .alu_src(alu_src_w),
    .mem_to_reg(mem_to_reg_w), .reg_write(reg_write_w),
    .mem_read(mem_read_w), .mem_write(mem_write_w),
    .branch(branch_w), .jump(jump_w),
    .alu_op(alu_op_w)
);

regfile rf (
    .clk(clk),
    .we(mem_wb_reg_write),
    .rs(rs), .rt(rt), .rd(mem_wb_rd),
    .wd(wb_data),
    .rd1(rd1), .rd2(rd2)
);

assign imm_ext = {{16{imm[15]}}, imm}; // sign-extend

hazard_unit hu (
    .id_ex_rt(id_ex_rt),
    .id_ex_mem_read(id_ex_mem_read),
    .if_id_rs(rs), .if_id_rt(rt),
    .stall(stall)
);

// ID/EX pipeline register
always_ff @(posedge clk or posedge rst) begin
    if (rst || flush_id_ex) begin
        // Flush: insert NOP bubble (clear all control signals)
        id_ex_reg_dst   <= 0; id_ex_alu_src   <= 0;
        id_ex_mem_to_reg<= 0; id_ex_reg_write <= 0;
        id_ex_mem_read  <= 0; id_ex_mem_write <= 0;
        id_ex_branch    <= 0; id_ex_jump      <= 0;
        id_ex_alu_op    <= 0; id_ex_bne       <= 0;
        id_ex_pc        <= 0; id_ex_rd1       <= 0;
        id_ex_rd2       <= 0; id_ex_imm       <= 0;
        id_ex_rs        <= 0; id_ex_rt        <= 0;
        id_ex_rd        <= 0; id_ex_funct     <= 0;
    end else if (stall) begin
        // Stall: insert NOP bubble (control signals only, keep data)
        id_ex_reg_dst   <= 0; id_ex_alu_src   <= 0;
        id_ex_mem_to_reg<= 0; id_ex_reg_write <= 0;
        id_ex_mem_read  <= 0; id_ex_mem_write <= 0;
        id_ex_branch    <= 0; id_ex_jump      <= 0;
        id_ex_alu_op    <= 0; id_ex_bne       <= 0;
        id_ex_pc        <= 0; id_ex_rd1       <= 0;
        id_ex_rd2       <= 0; id_ex_imm       <= 0;
        id_ex_rs        <= 0; id_ex_rt        <= 0;
        id_ex_rd        <= 0; id_ex_funct     <= 0;
    end else begin
        id_ex_reg_dst    <= reg_dst_w;
        id_ex_alu_src    <= alu_src_w;
        id_ex_mem_to_reg <= mem_to_reg_w;
        id_ex_reg_write  <= reg_write_w;
        id_ex_mem_read   <= mem_read_w;
        id_ex_mem_write  <= mem_write_w;
        id_ex_branch     <= branch_w;
        id_ex_jump       <= jump_w;
        id_ex_alu_op     <= alu_op_w;
        id_ex_bne        <= (opcode == 6'b000101);
        id_ex_pc         <= if_id_pc;
        id_ex_rd1        <= rd1;
        id_ex_rd2        <= rd2;
        id_ex_imm        <= imm_ext;
        id_ex_rs         <= rs;
        id_ex_rt         <= rt;
        id_ex_rd         <= rd_id;
        id_ex_funct      <= funct;
    end
end

// ================================================================
// EX STAGE — Execute
// ================================================================
forwarding_unit fu (
    .ex_mem_rd(ex_mem_rd),       .ex_mem_reg_write(ex_mem_reg_write),
    .mem_wb_rd(mem_wb_rd),       .mem_wb_reg_write(mem_wb_reg_write),
    .id_ex_rs(id_ex_rs),         .id_ex_rt(id_ex_rt),
    .forward_a(forward_a),       .forward_b(forward_b)
);

// Forwarding muxes
always_comb begin
    case (forward_a)
        2'b00:   fwd_a = id_ex_rd1;
        2'b10:   fwd_a = ex_mem_alu_result;
        2'b01:   fwd_a = wb_data;
        default: fwd_a = id_ex_rd1;
    endcase
    case (forward_b)
        2'b00:   fwd_b = id_ex_rd2;
        2'b10:   fwd_b = ex_mem_alu_result;
        2'b01:   fwd_b = wb_data;
        default: fwd_b = id_ex_rd2;
    endcase
end

assign alu_a = fwd_a;
assign alu_b = id_ex_alu_src ? id_ex_imm : fwd_b;

alu_control ac (
    .alu_op(id_ex_alu_op),
    .funct(id_ex_funct),
    .alu_ctrl(alu_ctrl)
);

alu main_alu (
    .a(alu_a), .b(alu_b),
    .alu_ctrl(alu_ctrl),
    .result(alu_result),
    .zero(alu_zero)
);

wire [4:0] ex_rd = id_ex_reg_dst ? id_ex_rd : id_ex_rt;

// EX/MEM pipeline register
always_ff @(posedge clk or posedge rst) begin
    if (rst || flush_ex_mem) begin
        ex_mem_pc_branch  <= 0; ex_mem_alu_result <= 0;
        ex_mem_rd2        <= 0; ex_mem_rd         <= 0;
        ex_mem_zero       <= 0; ex_mem_reg_write  <= 0;
        ex_mem_mem_to_reg <= 0; ex_mem_mem_read   <= 0;
        ex_mem_mem_write  <= 0; ex_mem_branch     <= 0;
        ex_mem_bne        <= 0;
    end else begin
        ex_mem_pc_branch  <= id_ex_pc + (id_ex_imm << 2);
        ex_mem_alu_result <= alu_result;
        ex_mem_rd2        <= fwd_b;
        ex_mem_rd         <= ex_rd;
        ex_mem_zero       <= alu_zero;
        ex_mem_reg_write  <= id_ex_reg_write;
        ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        ex_mem_mem_read   <= id_ex_mem_read;
        ex_mem_mem_write  <= id_ex_mem_write;
        ex_mem_branch     <= id_ex_branch;
        ex_mem_bne        <= id_ex_bne;
    end
end

// ================================================================
// MEM STAGE — Memory Access
// ================================================================
data_mem dmem (
    .clk(clk),
    .mem_read(ex_mem_mem_read),
    .mem_write(ex_mem_mem_write),
    .addr(ex_mem_alu_result),
    .write_data(ex_mem_rd2),
    .read_data(mem_rd_data)
);

// MEM/WB pipeline register
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        mem_wb_read_data  <= 0; mem_wb_alu_result <= 0;
        mem_wb_rd         <= 0; mem_wb_reg_write  <= 0;
        mem_wb_mem_to_reg <= 0;
    end else begin
        mem_wb_read_data  <= mem_rd_data;
        mem_wb_alu_result <= ex_mem_alu_result;
        mem_wb_rd         <= ex_mem_rd;
        mem_wb_reg_write  <= ex_mem_reg_write;
        mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
    end
end

// ================================================================
// WB STAGE — Write Back
// ================================================================
assign wb_data = mem_wb_mem_to_reg ? mem_wb_read_data : mem_wb_alu_result;

endmodule
