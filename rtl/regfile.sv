// ============================================================================
// regfile.sv — 32x32 Register File with x0 hardwired to zero
// ============================================================================
// Two read ports, one write port. Write-first forwarding for same-cycle
// read-after-write to the same register.
// ============================================================================

module regfile (
  input  logic        clk,
  input  logic        rst_n,

  // Read port A
  input  logic [4:0]  rs1_addr,
  output logic [31:0] rs1_data,

  // Read port B
  input  logic [4:0]  rs2_addr,
  output logic [31:0] rs2_data,

  // Write port
  input  logic        wr_en,
  input  logic [4:0]  rd_addr,
  input  logic [31:0] rd_data
);

  logic [31:0] regs [1:31]; // x1–x31; x0 is always zero

  // Read with write-forwarding
  always_comb begin
    if (rs1_addr == 5'd0)
      rs1_data = 32'd0;
    else if (wr_en && (rs1_addr == rd_addr))
      rs1_data = rd_data;
    else
      rs1_data = regs[rs1_addr];
  end

  always_comb begin
    if (rs2_addr == 5'd0)
      rs2_data = 32'd0;
    else if (wr_en && (rs2_addr == rd_addr))
      rs2_data = rd_data;
    else
      rs2_data = regs[rs2_addr];
  end

  // Synchronous write
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i < 32; i++)
        regs[i] <= 32'd0;
    end else if (wr_en && (rd_addr != 5'd0)) begin
      regs[rd_addr] <= rd_data;
    end
  end

endmodule
