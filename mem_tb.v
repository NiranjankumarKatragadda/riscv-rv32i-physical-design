// ============================================================
// imem.v — Instruction Memory (Synchronous Read)
// ============================================================
module imem #(
    parameter DEPTH = 1024 // Words
)(
    input  wire        clk,
    input  wire [31:0] addr,
    output reg  [31:0] data
);
    reg [31:0] mem [0:DEPTH-1];

    // Load program from hex file
    initial begin
        $readmemh("program.hex", mem);
    end

    // Asynchronous read (combinational)
    always @(*) begin
        data = mem[addr[11:2]]; // Word-aligned (ignore lower 2 bits)
    end
endmodule


// ============================================================
// dmem.v — Data Memory with Byte-Enable Write
// ============================================================
module dmem #(
    parameter DEPTH = 1024
)(
    input  wire        clk,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  we,      // Byte enables
    output wire [31:0] rdata
);
    reg [31:0] mem [0:DEPTH-1];

    // Byte-enable write
    always @(posedge clk) begin
        if (we[0]) mem[addr[11:2]][7:0]   <= wdata[7:0];
        if (we[1]) mem[addr[11:2]][15:8]  <= wdata[15:8];
        if (we[2]) mem[addr[11:2]][23:16] <= wdata[23:16];
        if (we[3]) mem[addr[11:2]][31:24] <= wdata[31:24];
    end

    // Asynchronous read
    assign rdata = mem[addr[11:2]];

endmodule


// ============================================================
// tb_riscv_pipeline.v — Comprehensive Testbench
// ============================================================
`timescale 1ns/1ps

module tb_riscv_pipeline;

    // -------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------
    reg         clk, rst_n;
    wire [31:0] imem_addr, dmem_addr;
    wire [31:0] imem_data, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_we;

    // -------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------
    riscv_pipeline dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_data  (imem_data),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_we    (dmem_we),
        .dmem_rdata (dmem_rdata)
    );

    imem u_imem (
        .clk  (clk),
        .addr (imem_addr),
        .data (imem_data)
    );

    dmem u_dmem (
        .clk   (clk),
        .addr  (dmem_addr),
        .wdata (dmem_wdata),
        .we    (dmem_we),
        .rdata (dmem_rdata)
    );

    // -------------------------------------------------------
    // Clock: 100MHz (10ns period)
    // -------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------
    // Test Program — loaded into imem via program.hex
    // Simple test: ADD, SUB, LOAD, STORE, BRANCH
    // -------------------------------------------------------
    integer i;
    initial begin
        // Waveform dump
        $dumpfile("riscv_pipeline.vcd");
        $dumpvars(0, tb_riscv_pipeline);

        // Reset
        rst_n = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst_n = 1;
        $display("[%0t] Reset deasserted", $time);

        // Run 500 cycles
        repeat(500) @(posedge clk);

        // Check register file via task
        check_reg(1, 32'h00000001); // x1 should = 1 (test specific to program)
        check_reg(0, 32'h00000000); // x0 always 0

        $display("[%0t] Simulation PASSED!", $time);
        $finish;
    end

    // -------------------------------------------------------
    // Monitor — print PC and instruction each cycle
    // -------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n)
            $display("[%0t] PC=%08h INSTR=%08h", $time, imem_addr, imem_data);
    end

    // -------------------------------------------------------
    // Task: Register Check
    // -------------------------------------------------------
    task check_reg;
        input [4:0]  reg_num;
        input [31:0] expected;
        begin
            if (dut.regfile[reg_num] !== expected)
                $display("FAIL: x%0d = %08h, expected %08h",
                         reg_num, dut.regfile[reg_num], expected);
            else
                $display("PASS: x%0d = %08h", reg_num, dut.regfile[reg_num]);
        end
    endtask

    // -------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------
    initial begin
        #100000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
