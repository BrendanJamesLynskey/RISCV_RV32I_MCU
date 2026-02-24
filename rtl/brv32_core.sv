// ============================================================================
// brv32_core.sv — BRV32 RISC-V CPU Core (RV32I, single-cycle)
// ============================================================================
// A single-cycle, in-order RV32I core with M-mode trap support.
// Executes one instruction per clock cycle (CPI = 1).
// ============================================================================
import riscv_pkg::*;

module brv32_core (
  input  logic        clk,
  input  logic        rst_n,

  // Instruction memory interface
  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,

  // Data memory / bus interface
  output logic [31:0] dmem_addr,
  output logic        dmem_rd_en,
  output logic        dmem_wr_en,
  output mem_width_e  dmem_width,
  output logic        dmem_sign_ext,
  output logic [31:0] dmem_wdata,
  input  logic [31:0] dmem_rdata,

  // Interrupts
  input  logic        ext_irq,
  input  logic        timer_irq
);

  // ── Program Counter ───────────────────────────────────────────────
  logic [31:0] pc, pc_next;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      pc <= 32'h0000_0000;
    else
      pc <= pc_next;
  end

  assign imem_addr = pc;

  // ── Instruction Decode ────────────────────────────────────────────
  logic [31:0] instr;
  assign instr = imem_rdata;

  logic [4:0]  rs1_addr, rs2_addr, rd_addr;
  logic [31:0] imm;
  alu_op_e     alu_op;
  logic        alu_src;
  logic        reg_wr_en, mem_rd_en_dec, mem_wr_en_dec;
  mem_width_e  mem_width_dec;
  logic        mem_sign_ext_dec;
  logic        branch_dec, jal_dec, jalr_dec;
  logic [2:0]  funct3;
  logic        lui_dec, auipc_dec;
  logic        ecall_dec, ebreak_dec;
  logic        csr_en_dec;
  logic [11:0] csr_addr_dec;
  logic        illegal_instr;

  decoder u_decoder (
    .instr         (instr),
    .rs1_addr      (rs1_addr),
    .rs2_addr      (rs2_addr),
    .rd_addr       (rd_addr),
    .imm           (imm),
    .alu_op        (alu_op),
    .alu_src       (alu_src),
    .reg_wr_en     (reg_wr_en),
    .mem_rd_en     (mem_rd_en_dec),
    .mem_wr_en     (mem_wr_en_dec),
    .mem_width     (mem_width_dec),
    .mem_sign_ext  (mem_sign_ext_dec),
    .branch        (branch_dec),
    .jal           (jal_dec),
    .jalr          (jalr_dec),
    .funct3        (funct3),
    .lui           (lui_dec),
    .auipc         (auipc_dec),
    .ecall         (ecall_dec),
    .ebreak        (ebreak_dec),
    .csr_en        (csr_en_dec),
    .csr_addr      (csr_addr_dec),
    .illegal_instr (illegal_instr)
  );

  // ── Register File ─────────────────────────────────────────────────
  logic [31:0] rs1_data, rs2_data;
  logic [31:0] rd_data;
  logic        rd_wr_en;

  regfile u_regfile (
    .clk      (clk),
    .rst_n    (rst_n),
    .rs1_addr (rs1_addr),
    .rs1_data (rs1_data),
    .rs2_addr (rs2_addr),
    .rs2_data (rs2_data),
    .wr_en    (rd_wr_en),
    .rd_addr  (rd_addr),
    .rd_data  (rd_data)
  );

  // ── ALU ───────────────────────────────────────────────────────────
  logic [31:0] alu_a, alu_b, alu_result;
  logic        alu_zero;

  assign alu_a = rs1_data;
  assign alu_b = alu_src ? imm : rs2_data;

  alu u_alu (
    .a      (alu_a),
    .b      (alu_b),
    .op     (alu_op),
    .result (alu_result),
    .zero   (alu_zero)
  );

  // ── CSR Unit ──────────────────────────────────────────────────────
  logic [31:0] csr_rdata;
  logic [31:0] mtvec_out, mepc_out;
  logic        irq_pending;
  logic        trap_enter;
  logic [31:0] trap_cause, trap_val;
  logic        mret_sig;

  // CSR write data: for CSRRW/CSRRS/CSRRC use rs1_data;
  //                 for CSRRWI/CSRRSI/CSRRCI use zimm (rs1_addr zero-extended)
  logic [31:0] csr_wdata;
  assign csr_wdata = funct3[2] ? {27'b0, rs1_addr} : rs1_data;

  csr u_csr (
    .clk           (clk),
    .rst_n         (rst_n),
    .csr_en        (csr_en_dec & ~trap_enter),
    .csr_addr      (csr_addr_dec),
    .csr_op        (funct3),
    .csr_wdata     (csr_wdata),
    .csr_rdata     (csr_rdata),
    .trap_enter    (trap_enter),
    .trap_cause    (trap_cause),
    .trap_val      (trap_val),
    .trap_pc       (pc),
    .mtvec_out     (mtvec_out),
    .mepc_out      (mepc_out),
    .mret          (mret_sig),
    .ext_irq       (ext_irq),
    .timer_irq     (timer_irq),
    .instr_retired (1'b1),
    .irq_pending   (irq_pending)
  );

  // ── Branch Logic ──────────────────────────────────────────────────
  logic branch_taken;
  always_comb begin
    branch_taken = 1'b0;
    if (branch_dec) begin
      case (funct3)
        3'b000: branch_taken = alu_zero;           // BEQ
        3'b001: branch_taken = ~alu_zero;          // BNE
        3'b100: branch_taken = alu_result[0];      // BLT
        3'b101: branch_taken = ~alu_result[0];     // BGE
        3'b110: branch_taken = alu_result[0];      // BLTU
        3'b111: branch_taken = ~alu_result[0];     // BGEU
        default: branch_taken = 1'b0;
      endcase
    end
  end

  // ── MRET detection ────────────────────────────────────────────────
  assign mret_sig = (instr == 32'h3020_0073); // MRET encoding

  // ── Trap Logic ────────────────────────────────────────────────────
  always_comb begin
    trap_enter = 1'b0;
    trap_cause = 32'b0;
    trap_val   = 32'b0;

    if (illegal_instr) begin
      trap_enter = 1'b1;
      trap_cause = 32'd2; // Illegal instruction
      trap_val   = instr;
    end else if (ecall_dec) begin
      trap_enter = 1'b1;
      trap_cause = 32'd11; // Environment call from M-mode
    end else if (ebreak_dec) begin
      trap_enter = 1'b1;
      trap_cause = 32'd3; // Breakpoint
    end else if (irq_pending) begin
      trap_enter = 1'b1;
      trap_cause = {1'b1, 31'd11}; // Machine external interrupt
    end
  end

  // ── Data Memory Interface ─────────────────────────────────────────
  assign dmem_addr     = alu_result;
  assign dmem_rd_en    = mem_rd_en_dec & ~trap_enter;
  assign dmem_wr_en    = mem_wr_en_dec & ~trap_enter;
  assign dmem_width    = mem_width_dec;
  assign dmem_sign_ext = mem_sign_ext_dec;
  assign dmem_wdata    = rs2_data;

  // ── Writeback MUX ─────────────────────────────────────────────────
  always_comb begin
    if (lui_dec)
      rd_data = imm;
    else if (auipc_dec)
      rd_data = pc + imm;
    else if (jal_dec || jalr_dec)
      rd_data = pc + 32'd4;
    else if (mem_rd_en_dec)
      rd_data = dmem_rdata;
    else if (csr_en_dec)
      rd_data = csr_rdata;
    else
      rd_data = alu_result;
  end

  assign rd_wr_en = reg_wr_en & ~trap_enter;

  // ── Next PC Logic ─────────────────────────────────────────────────
  always_comb begin
    if (trap_enter)
      pc_next = mtvec_out;
    else if (mret_sig)
      pc_next = mepc_out;
    else if (jal_dec)
      pc_next = pc + imm;
    else if (jalr_dec)
      pc_next = {alu_result[31:1], 1'b0};
    else if (branch_taken)
      pc_next = pc + imm;
    else
      pc_next = pc + 32'd4;
  end

endmodule
