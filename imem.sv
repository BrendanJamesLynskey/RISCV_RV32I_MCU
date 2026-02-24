// ============================================================================
// imem.sv — Instruction Memory (ROM, 4 KB default)
// ============================================================================
// Byte-addressed, word-aligned reads only. Initialised from hex file.
// ============================================================================

module imem #(
  parameter DEPTH = 1024,                     // Number of 32-bit words
  parameter INIT_FILE = "firmware.hex"
)(
  input  logic [31:0] addr,
  output logic [31:0] rdata
);

  logic [31:0] mem [0:DEPTH-1];

  initial begin
    for (int i = 0; i < DEPTH; i++)
      mem[i] = 32'h0000_0013;                // NOP (ADDI x0, x0, 0)
    if (INIT_FILE != "")
      $readmemh(INIT_FILE, mem);
  end

  assign rdata = mem[addr[($clog2(DEPTH)+1):2]]; // Word-aligned index

endmodule
