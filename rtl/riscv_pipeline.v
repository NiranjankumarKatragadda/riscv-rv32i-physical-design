// ============================================================
// riscv_pipeline.v — 5-Stage Pipelined RV32I Core
// Stages: IF → ID → EX → MEM → WB
// ============================================================
module riscv_pipeline (
    input  wire        clk,
    input  wire        rst_n,
    // Instruction Memory
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,
    // Data Memory
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_we,
    input  wire [31:0] dmem_rdata
);

// ============================================================
// STAGE 1: IF — Instruction Fetch
// ============================================================
reg  [31:0] pc;
wire [31:0] pc_plus4 = pc + 32'd4;
wire [31:0] pc_branch;
wire        take_branch;

// PC update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)       pc <= 32'h0;
    else if (take_branch) pc <= pc_branch;
    else if (!stall)  pc <= pc_plus4;
end

assign imem_addr = pc;

// IF/ID Pipeline Register
reg [31:0] IF_ID_pc;
reg [31:0] IF_ID_instr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
        IF_ID_pc    <= 32'h0;
        IF_ID_instr <= 32'h0; // NOP
    end else if (!stall) begin
        IF_ID_pc    <= pc;
        IF_ID_instr <= imem_data;
    end
end

// ============================================================
// STAGE 2: ID — Instruction Decode + Register Read
// ============================================================
wire [6:0]  opcode  = IF_ID_instr[6:0];
wire [4:0]  rd_id   = IF_ID_instr[11:7];
wire [2:0]  funct3  = IF_ID_instr[14:12];
wire [4:0]  rs1     = IF_ID_instr[19:15];
wire [4:0]  rs2     = IF_ID_instr[24:20];
wire [6:0]  funct7  = IF_ID_instr[31:25];

// Immediate decode
wire [31:0] imm_i = {{20{IF_ID_instr[31]}}, IF_ID_instr[31:20]};
wire [31:0] imm_s = {{20{IF_ID_instr[31]}}, IF_ID_instr[31:25], IF_ID_instr[11:7]};
wire [31:0] imm_b = {{19{IF_ID_instr[31]}}, IF_ID_instr[31],
                     IF_ID_instr[7], IF_ID_instr[30:25], IF_ID_instr[11:8], 1'b0};
wire [31:0] imm_u = {IF_ID_instr[31:12], 12'b0};
wire [31:0] imm_j = {{11{IF_ID_instr[31]}}, IF_ID_instr[31],
                     IF_ID_instr[19:12], IF_ID_instr[20], IF_ID_instr[30:21], 1'b0};

// Register File (32 x 32-bit)
reg [31:0] regfile [0:31];
wire [31:0] rs1_data = (rs1 == 0) ? 32'b0 : regfile[rs1];
wire [31:0] rs2_data = (rs2 == 0) ? 32'b0 : regfile[rs2];

// Control signals from decode
wire        reg_write_id, mem_read_id, mem_write_id, branch_id, jump_id;
wire [1:0]  alu_src_id;
wire [3:0]  alu_op_id;
wire [31:0] imm_id;

control_unit u_ctrl (
    .opcode    (opcode),
    .funct3    (funct3),
    .funct7    (funct7),
    .reg_write (reg_write_id),
    .mem_read  (mem_read_id),
    .mem_write (mem_write_id),
    .branch    (branch_id),
    .jump      (jump_id),
    .alu_src   (alu_src_id),
    .alu_op    (alu_op_id)
);

assign imm_id = (opcode == 7'b0100011) ? imm_s :
                (opcode == 7'b1100011) ? imm_b :
                (opcode == 7'b0110111 || opcode == 7'b0010111) ? imm_u :
                (opcode == 7'b1101111) ? imm_j : imm_i;

// Hazard Detection
wire stall;
hazard_unit u_hazard (
    .id_rs1       (rs1),
    .id_rs2       (rs2),
    .ex_rd        (ID_EX_rd),
    .ex_mem_read  (ID_EX_mem_read),
    .stall        (stall)
);

// ID/EX Pipeline Register
reg [31:0] ID_EX_pc;
reg [31:0] ID_EX_rs1_data, ID_EX_rs2_data;
reg [31:0] ID_EX_imm;
reg [4:0]  ID_EX_rs1, ID_EX_rs2, ID_EX_rd;
reg [3:0]  ID_EX_alu_op;
reg [1:0]  ID_EX_alu_src;
reg        ID_EX_reg_write, ID_EX_mem_read;
reg        ID_EX_mem_write, ID_EX_branch, ID_EX_jump;
reg [2:0]  ID_EX_funct3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n || stall || flush) begin
        ID_EX_reg_write <= 0; ID_EX_mem_read  <= 0;
        ID_EX_mem_write <= 0; ID_EX_branch    <= 0;
        ID_EX_jump      <= 0; ID_EX_rd        <= 0;
    end else begin
        ID_EX_pc       <= IF_ID_pc;
        ID_EX_rs1_data <= rs1_data;
        ID_EX_rs2_data <= rs2_data;
        ID_EX_imm      <= imm_id;
        ID_EX_rs1      <= rs1;
        ID_EX_rs2      <= rs2;
        ID_EX_rd       <= rd_id;
        ID_EX_alu_op   <= alu_op_id;
        ID_EX_alu_src  <= alu_src_id;
        ID_EX_reg_write<= reg_write_id;
        ID_EX_mem_read <= mem_read_id;
        ID_EX_mem_write<= mem_write_id;
        ID_EX_branch   <= branch_id;
        ID_EX_jump     <= jump_id;
        ID_EX_funct3   <= funct3;
    end
end

// ============================================================
// STAGE 3: EX — Execute
// ============================================================

// Forwarding Unit
wire [1:0] fwd_a, fwd_b;
forwarding_unit u_fwd (
    .ex_rs1       (ID_EX_rs1),
    .ex_rs2       (ID_EX_rs2),
    .mem_rd       (EX_MEM_rd),
    .mem_reg_write(EX_MEM_reg_write),
    .wb_rd        (MEM_WB_rd),
    .wb_reg_write (MEM_WB_reg_write),
    .fwd_a        (fwd_a),
    .fwd_b        (fwd_b)
);

wire [31:0] wb_data; // from WB stage

// Forwarded operands
wire [31:0] alu_op_a = (fwd_a == 2'b10) ? EX_MEM_alu_result :
                       (fwd_a == 2'b01) ? wb_data : ID_EX_rs1_data;
wire [31:0] alu_op_b_pre = (fwd_b == 2'b10) ? EX_MEM_alu_result :
                           (fwd_b == 2'b01) ? wb_data : ID_EX_rs2_data;
wire [31:0] alu_op_b = (ID_EX_alu_src == 2'b01) ? ID_EX_imm :
                       (ID_EX_alu_src == 2'b10) ? ID_EX_imm : alu_op_b_pre;

wire [31:0] alu_result;
wire        alu_zero;

alu u_alu (
    .a      (alu_op_a),
    .b      (alu_op_b),
    .op     (ID_EX_alu_op),
    .result (alu_result),
    .zero   (alu_zero)
);

// Branch decision
assign take_branch = (ID_EX_branch && alu_zero) || ID_EX_jump;
assign pc_branch   = ID_EX_pc + ID_EX_imm;
wire   flush       = take_branch;

// EX/MEM Pipeline Register
reg [31:0] EX_MEM_alu_result;
reg [31:0] EX_MEM_rs2_data;
reg [4:0]  EX_MEM_rd;
reg        EX_MEM_reg_write, EX_MEM_mem_read;
reg        EX_MEM_mem_write;
reg [2:0]  EX_MEM_funct3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        EX_MEM_reg_write <= 0; EX_MEM_mem_read  <= 0;
        EX_MEM_mem_write <= 0; EX_MEM_rd        <= 0;
    end else begin
        EX_MEM_alu_result <= alu_result;
        EX_MEM_rs2_data   <= alu_op_b_pre;
        EX_MEM_rd         <= ID_EX_rd;
        EX_MEM_reg_write  <= ID_EX_reg_write;
        EX_MEM_mem_read   <= ID_EX_mem_read;
        EX_MEM_mem_write  <= ID_EX_mem_write;
        EX_MEM_funct3     <= ID_EX_funct3;
    end
end

// ============================================================
// STAGE 4: MEM — Memory Access
// ============================================================
assign dmem_addr  = EX_MEM_alu_result;
assign dmem_wdata = EX_MEM_rs2_data;
assign dmem_we    = EX_MEM_mem_write ? 4'b1111 : 4'b0000;

// MEM/WB Pipeline Register
reg [31:0] MEM_WB_rdata;
reg [31:0] MEM_WB_alu_result;
reg [4:0]  MEM_WB_rd;
reg        MEM_WB_reg_write, MEM_WB_mem_read;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        MEM_WB_reg_write <= 0; MEM_WB_mem_read <= 0;
        MEM_WB_rd        <= 0;
    end else begin
        MEM_WB_rdata      <= dmem_rdata;
        MEM_WB_alu_result <= EX_MEM_alu_result;
        MEM_WB_rd         <= EX_MEM_rd;
        MEM_WB_reg_write  <= EX_MEM_reg_write;
        MEM_WB_mem_read   <= EX_MEM_mem_read;
    end
end

// ============================================================
// STAGE 5: WB — Write Back
// ============================================================
assign wb_data = MEM_WB_mem_read ? MEM_WB_rdata : MEM_WB_alu_result;

always @(posedge clk) begin
    if (MEM_WB_reg_write && MEM_WB_rd != 5'b0)
        regfile[MEM_WB_rd] <= wb_data;
end

endmodule
