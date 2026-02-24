// ============================================================================
// csr.sv — Control and Status Register Unit (Machine-mode subset)
// ============================================================================
// Implements the minimum CSR set required for M-mode traps:
//   mstatus, mie, mtvec, mscratch, mepc, mcause, mtval, mip,
//   mcycle, minstret, mvendorid, marchid, mhartid
// ============================================================================
import riscv_pkg::*;

module csr (
  input  logic        clk,
  input  logic        rst_n,

  // CSR access
  input  logic        csr_en,
  input  logic [11:0] csr_addr,
  input  logic [2:0]  csr_op,     // funct3: CSRRW=001, CSRRS=010, CSRRC=011
  input  logic [31:0] csr_wdata,  // rs1 value or zimm
  output logic [31:0] csr_rdata,

  // Trap interface
  input  logic        trap_enter,
  input  logic [31:0] trap_cause,
  input  logic [31:0] trap_val,
  input  logic [31:0] trap_pc,    // PC of faulting instruction
  output logic [31:0] mtvec_out,
  output logic [31:0] mepc_out,

  // MRET
  input  logic        mret,

  // External interrupt lines
  input  logic        ext_irq,
  input  logic        timer_irq,

  // Cycle/instret increment
  input  logic        instr_retired,

  // Interrupt pending output
  output logic        irq_pending
);

  // ── CSR Registers ─────────────────────────────────────────────────
  logic [31:0] mstatus;   // Simplified: only MIE (bit 3) and MPIE (bit 7)
  logic [31:0] mie;       // Interrupt enables
  logic [31:0] mtvec;
  logic [31:0] mscratch;
  logic [31:0] mepc;
  logic [31:0] mcause;
  logic [31:0] mtval;
  logic [31:0] mip;       // Interrupt pending
  logic [63:0] mcycle;
  logic [63:0] minstret;

  assign mtvec_out = mtvec;
  assign mepc_out  = mepc;

  // ── Interrupt pending logic ───────────────────────────────────────
  always_comb begin
    mip = 32'b0;
    mip[11] = ext_irq;    // MEIP — Machine External Interrupt Pending
    mip[7]  = timer_irq;  // MTIP — Machine Timer Interrupt Pending
  end

  assign irq_pending = mstatus[3] & |(mip & mie); // MIE global enable

  // ── CSR Read ──────────────────────────────────────────────────────
  always_comb begin
    csr_rdata = 32'b0;
    case (csr_addr)
      CSR_MSTATUS:   csr_rdata = mstatus;
      CSR_MIE:       csr_rdata = mie;
      CSR_MTVEC:     csr_rdata = mtvec;
      CSR_MSCRATCH:  csr_rdata = mscratch;
      CSR_MEPC:      csr_rdata = mepc;
      CSR_MCAUSE:    csr_rdata = mcause;
      CSR_MTVAL:     csr_rdata = mtval;
      CSR_MIP:       csr_rdata = mip;
      CSR_MCYCLE:    csr_rdata = mcycle[31:0];
      CSR_MINSTRET:  csr_rdata = minstret[31:0];
      CSR_MVENDORID: csr_rdata = 32'h0;
      CSR_MARCHID:   csr_rdata = 32'h0;
      CSR_MHARTID:   csr_rdata = 32'h0;
      default:       csr_rdata = 32'b0;
    endcase
  end

  // ── CSR Write / Trap Logic ────────────────────────────────────────
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mstatus  <= 32'h0000_0000;
      mie      <= 32'b0;
      mtvec    <= 32'b0;
      mscratch <= 32'b0;
      mepc     <= 32'b0;
      mcause   <= 32'b0;
      mtval    <= 32'b0;
      mcycle   <= 64'b0;
      minstret <= 64'b0;
    end else begin
      // Free-running counters
      mcycle <= mcycle + 1'b1;
      if (instr_retired)
        minstret <= minstret + 1'b1;

      // Trap entry (highest priority)
      if (trap_enter) begin
        mepc    <= trap_pc;
        mcause  <= trap_cause;
        mtval   <= trap_val;
        // Save MIE to MPIE, clear MIE
        mstatus[7] <= mstatus[3]; // MPIE = MIE
        mstatus[3] <= 1'b0;       // MIE = 0
      end
      // MRET
      else if (mret) begin
        mstatus[3] <= mstatus[7]; // MIE = MPIE
        mstatus[7] <= 1'b1;       // MPIE = 1
      end
      // Normal CSR write
      else if (csr_en) begin
        logic [31:0] new_val;
        case (csr_op[1:0])
          2'b01: new_val = csr_wdata;                  // CSRRW
          2'b10: new_val = csr_rdata | csr_wdata;      // CSRRS
          2'b11: new_val = csr_rdata & ~csr_wdata;     // CSRRC
          default: new_val = csr_rdata;
        endcase

        case (csr_addr)
          CSR_MSTATUS:  mstatus  <= new_val & 32'h0000_0088; // Mask writable bits
          CSR_MIE:      mie      <= new_val;
          CSR_MTVEC:    mtvec    <= {new_val[31:2], 2'b00}; // Force aligned
          CSR_MSCRATCH: mscratch <= new_val;
          CSR_MEPC:     mepc     <= {new_val[31:2], 2'b00};
          CSR_MCAUSE:   mcause   <= new_val;
          CSR_MTVAL:    mtval    <= new_val;
          default: ;
        endcase
      end
    end
  end

endmodule
