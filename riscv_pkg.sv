// ============================================================================
// riscv_pkg.sv — Shared type and constant definitions for BRV32 MCU
// ============================================================================
package riscv_pkg;

  // ── Instruction Opcodes (bits [6:0]) ─────────────────────────────────
  typedef enum logic [6:0] {
    OP_LUI      = 7'b0110111,
    OP_AUIPC    = 7'b0010111,
    OP_JAL      = 7'b1101111,
    OP_JALR     = 7'b1100111,
    OP_BRANCH   = 7'b1100011,
    OP_LOAD     = 7'b0000011,
    OP_STORE    = 7'b0100011,
    OP_IMM      = 7'b0010011,
    OP_REG      = 7'b0110011,
    OP_FENCE    = 7'b0001111,
    OP_SYSTEM   = 7'b1110011
  } opcode_e;

  // ── ALU Operations ───────────────────────────────────────────────────
  typedef enum logic [3:0] {
    ALU_ADD   = 4'b0000,
    ALU_SUB   = 4'b1000,
    ALU_SLL   = 4'b0001,
    ALU_SLT   = 4'b0010,
    ALU_SLTU  = 4'b0011,
    ALU_XOR   = 4'b0100,
    ALU_SRL   = 4'b0101,
    ALU_SRA   = 4'b1101,
    ALU_OR    = 4'b0110,
    ALU_AND   = 4'b0111
  } alu_op_e;

  // ── Immediate Types ──────────────────────────────────────────────────
  typedef enum logic [2:0] {
    IMM_I = 3'd0,
    IMM_S = 3'd1,
    IMM_B = 3'd2,
    IMM_U = 3'd3,
    IMM_J = 3'd4
  } imm_type_e;

  // ── Memory Access Width ──────────────────────────────────────────────
  typedef enum logic [1:0] {
    MEM_BYTE = 2'b00,
    MEM_HALF = 2'b01,
    MEM_WORD = 2'b10
  } mem_width_e;

  // ── CSR Addresses ────────────────────────────────────────────────────
  localparam logic [11:0] CSR_MSTATUS  = 12'h300;
  localparam logic [11:0] CSR_MIE      = 12'h304;
  localparam logic [11:0] CSR_MTVEC    = 12'h305;
  localparam logic [11:0] CSR_MSCRATCH = 12'h340;
  localparam logic [11:0] CSR_MEPC     = 12'h341;
  localparam logic [11:0] CSR_MCAUSE   = 12'h342;
  localparam logic [11:0] CSR_MTVAL    = 12'h343;
  localparam logic [11:0] CSR_MIP      = 12'h344;
  localparam logic [11:0] CSR_MCYCLE   = 12'hB00;
  localparam logic [11:0] CSR_MINSTRET = 12'hB02;
  localparam logic [11:0] CSR_MVENDORID = 12'hF11;
  localparam logic [11:0] CSR_MARCHID   = 12'hF12;
  localparam logic [11:0] CSR_MHARTID   = 12'hF14;

  // ── Memory Map ───────────────────────────────────────────────────────
  localparam logic [31:0] IMEM_BASE   = 32'h0000_0000;
  localparam logic [31:0] DMEM_BASE   = 32'h1000_0000;
  localparam logic [31:0] PERIPH_BASE = 32'h2000_0000;
  localparam logic [31:0] GPIO_BASE   = 32'h2000_0000;
  localparam logic [31:0] UART_BASE   = 32'h2000_0100;
  localparam logic [31:0] TIMER_BASE  = 32'h2000_0200;

endpackage
