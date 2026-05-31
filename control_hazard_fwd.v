// ============================================================
// control_unit.v — Main Decoder for RV32I
// ============================================================
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        branch,
    output reg        jump,
    output reg [1:0]  alu_src,
    output reg [3:0]  alu_op
);
    localparam R_TYPE = 7'b0110011;
    localparam I_TYPE = 7'b0010011;
    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam JAL    = 7'b1101111;
    localparam JALR   = 7'b1100111;
    localparam LUI    = 7'b0110111;
    localparam AUIPC  = 7'b0010111;

    always @(*) begin
        reg_write = 0; mem_read  = 0;
        mem_write = 0; branch    = 0;
        jump      = 0; alu_src   = 2'b00;
        alu_op    = 4'b0000;

        case (opcode)
            R_TYPE: begin
                reg_write = 1; alu_src = 2'b00;
                case ({funct7[5], funct3})
                    4'b0_000: alu_op = 4'b0000; // ADD
                    4'b1_000: alu_op = 4'b0001; // SUB
                    4'b0_111: alu_op = 4'b0010; // AND
                    4'b0_110: alu_op = 4'b0011; // OR
                    4'b0_100: alu_op = 4'b0100; // XOR
                    4'b0_001: alu_op = 4'b0101; // SLL
                    4'b0_101: alu_op = 4'b0110; // SRL
                    4'b1_101: alu_op = 4'b0111; // SRA
                    4'b0_010: alu_op = 4'b1000; // SLT
                    4'b0_011: alu_op = 4'b1001; // SLTU
                    default:  alu_op = 4'b0000;
                endcase
            end
            I_TYPE: begin
                reg_write = 1; alu_src = 2'b01;
                case (funct3)
                    3'b000: alu_op = 4'b0000; // ADDI
                    3'b111: alu_op = 4'b0010; // ANDI
                    3'b110: alu_op = 4'b0011; // ORI
                    3'b100: alu_op = 4'b0100; // XORI
                    3'b001: alu_op = 4'b0101; // SLLI
                    3'b101: alu_op = funct7[5] ? 4'b0111 : 4'b0110; // SRAI/SRLI
                    3'b010: alu_op = 4'b1000; // SLTI
                    3'b011: alu_op = 4'b1001; // SLTIU
                    default: alu_op = 4'b0000;
                endcase
            end
            LOAD: begin
                reg_write = 1; mem_read = 1;
                alu_src = 2'b01; alu_op = 4'b0000;
            end
            STORE: begin
                mem_write = 1;
                alu_src = 2'b10; alu_op = 4'b0000;
            end
            BRANCH: begin
                branch = 1; alu_op = 4'b0001; // SUB for BEQ
                case (funct3)
                    3'b000: alu_op = 4'b0001; // BEQ  (zero if equal)
                    3'b001: alu_op = 4'b0001; // BNE
                    3'b100: alu_op = 4'b1000; // BLT
                    3'b101: alu_op = 4'b1000; // BGE
                    3'b110: alu_op = 4'b1001; // BLTU
                    3'b111: alu_op = 4'b1001; // BGEU
                    default: alu_op = 4'b0001;
                endcase
            end
            JAL:  begin jump = 1; reg_write = 1; end
            JALR: begin jump = 1; reg_write = 1; alu_src = 2'b01; end
            LUI:  begin reg_write = 1; alu_src = 2'b01; alu_op = 4'b1010; end
            AUIPC:begin reg_write = 1; alu_src = 2'b01; alu_op = 4'b0000; end
            default: begin end
        endcase
    end
endmodule


// ============================================================
// hazard_unit.v — Load-Use Hazard Detection (1-cycle stall)
// ============================================================
module hazard_unit (
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,
    input  wire [4:0] ex_rd,
    input  wire       ex_mem_read,
    output wire       stall
);
    // Stall if EX stage is a LOAD and destination matches ID source
    assign stall = ex_mem_read &&
                   ((ex_rd == id_rs1) || (ex_rd == id_rs2));
endmodule


// ============================================================
// forwarding_unit.v — Data Forwarding (MEM→EX, WB→EX)
// ============================================================
module forwarding_unit (
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,
    input  wire [4:0] mem_rd,
    input  wire       mem_reg_write,
    input  wire [4:0] wb_rd,
    input  wire       wb_reg_write,
    output reg  [1:0] fwd_a,   // 00=reg, 01=WB, 10=MEM
    output reg  [1:0] fwd_b
);
    always @(*) begin
        // Forward A
        if (mem_reg_write && mem_rd != 0 && mem_rd == ex_rs1)
            fwd_a = 2'b10; // Forward from MEM
        else if (wb_reg_write && wb_rd != 0 && wb_rd == ex_rs1)
            fwd_a = 2'b01; // Forward from WB
        else
            fwd_a = 2'b00; // No forwarding

        // Forward B
        if (mem_reg_write && mem_rd != 0 && mem_rd == ex_rs2)
            fwd_b = 2'b10;
        else if (wb_reg_write && wb_rd != 0 && wb_rd == ex_rs2)
            fwd_b = 2'b01;
        else
            fwd_b = 2'b00;
    end
endmodule
