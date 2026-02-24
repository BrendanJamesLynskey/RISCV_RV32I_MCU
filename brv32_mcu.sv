// ============================================================================
// brv32_mcu.sv — BRV32 Microcontroller SoC Top-Level
// ============================================================================
// Integrates CPU core, instruction memory, data memory, and peripherals
// with a simple bus decoder.
//
// Memory Map:
//   0x0000_0000 – 0x0FFF_FFFF  Instruction Memory (4 KB)
//   0x1000_0000 – 0x1FFF_FFFF  Data Memory (4 KB)
//   0x2000_0000 – 0x2000_00FF  GPIO
//   0x2000_0100 – 0x2000_01FF  UART
//   0x2000_0200 – 0x2000_02FF  Timer
// ============================================================================
import riscv_pkg::*;

module brv32_mcu #(
  parameter IMEM_DEPTH = 1024,
  parameter DMEM_DEPTH = 1024,
  parameter INIT_FILE  = "firmware.hex"
)(
  input  logic        clk,
  input  logic        rst_n,

  // GPIO
  input  logic [31:0] gpio_in,
  output logic [31:0] gpio_out,

  // UART
  input  logic        uart_rx,
  output logic        uart_tx
);

  // ── CPU ↔ Memory Buses ────────────────────────────────────────────
  logic [31:0] imem_addr, imem_rdata;
  logic [31:0] dmem_addr;
  logic        dmem_rd_en, dmem_wr_en;
  mem_width_e  dmem_width;
  logic        dmem_sign_ext;
  logic [31:0] dmem_wdata, dmem_rdata;

  // ── Peripheral read data ──────────────────────────────────────────
  logic [31:0] dmem_mem_rdata;
  logic [31:0] gpio_rdata;
  logic [31:0] uart_rdata;
  logic [31:0] timer_rdata;

  // ── Interrupt lines ───────────────────────────────────────────────
  logic gpio_irq, uart_irq, timer_irq;

  // ── Bus decoder ───────────────────────────────────────────────────
  logic sel_dmem, sel_gpio, sel_uart, sel_timer;

  always_comb begin
    sel_dmem  = (dmem_addr[31:28] == 4'h1);
    sel_gpio  = (dmem_addr[31:8]  == 24'h2000_00);
    sel_uart  = (dmem_addr[31:8]  == 24'h2000_01);
    sel_timer = (dmem_addr[31:8]  == 24'h2000_02);
  end

  // ── Read MUX ──────────────────────────────────────────────────────
  always_comb begin
    if (sel_gpio)
      dmem_rdata = gpio_rdata;
    else if (sel_uart)
      dmem_rdata = uart_rdata;
    else if (sel_timer)
      dmem_rdata = timer_rdata;
    else
      dmem_rdata = dmem_mem_rdata;
  end

  // ── CPU Core ──────────────────────────────────────────────────────
  brv32_core u_core (
    .clk           (clk),
    .rst_n         (rst_n),
    .imem_addr     (imem_addr),
    .imem_rdata    (imem_rdata),
    .dmem_addr     (dmem_addr),
    .dmem_rd_en    (dmem_rd_en),
    .dmem_wr_en    (dmem_wr_en),
    .dmem_width    (dmem_width),
    .dmem_sign_ext (dmem_sign_ext),
    .dmem_wdata    (dmem_wdata),
    .dmem_rdata    (dmem_rdata),
    .ext_irq       (gpio_irq | uart_irq),
    .timer_irq     (timer_irq)
  );

  // ── Instruction Memory ────────────────────────────────────────────
  imem #(
    .DEPTH     (IMEM_DEPTH),
    .INIT_FILE (INIT_FILE)
  ) u_imem (
    .addr  (imem_addr),
    .rdata (imem_rdata)
  );

  // ── Data Memory ───────────────────────────────────────────────────
  dmem #(
    .DEPTH (DMEM_DEPTH)
  ) u_dmem (
    .clk      (clk),
    .rst_n    (rst_n),
    .addr     (dmem_addr),
    .rd_en    (dmem_rd_en & sel_dmem),
    .wr_en    (dmem_wr_en & sel_dmem),
    .width    (dmem_width),
    .sign_ext (dmem_sign_ext),
    .wdata    (dmem_wdata),
    .rdata    (dmem_mem_rdata)
  );

  // ── GPIO ──────────────────────────────────────────────────────────
  gpio u_gpio (
    .clk      (clk),
    .rst_n    (rst_n),
    .addr     (dmem_addr[7:0]),
    .wr_en    (dmem_wr_en & sel_gpio),
    .rd_en    (dmem_rd_en & sel_gpio),
    .wdata    (dmem_wdata),
    .rdata    (gpio_rdata),
    .gpio_in  (gpio_in),
    .gpio_out (gpio_out),
    .irq      (gpio_irq)
  );

  // ── UART ──────────────────────────────────────────────────────────
  uart u_uart (
    .clk      (clk),
    .rst_n    (rst_n),
    .addr     (dmem_addr[7:0]),
    .wr_en    (dmem_wr_en & sel_uart),
    .rd_en    (dmem_rd_en & sel_uart),
    .wdata    (dmem_wdata),
    .rdata    (uart_rdata),
    .uart_tx  (uart_tx),
    .uart_rx  (uart_rx),
    .irq      (uart_irq)
  );

  // ── Timer ─────────────────────────────────────────────────────────
  timer u_timer (
    .clk      (clk),
    .rst_n    (rst_n),
    .addr     (dmem_addr[7:0]),
    .wr_en    (dmem_wr_en & sel_timer),
    .rd_en    (dmem_rd_en & sel_timer),
    .wdata    (dmem_wdata),
    .rdata    (timer_rdata),
    .irq      (timer_irq)
  );

endmodule
