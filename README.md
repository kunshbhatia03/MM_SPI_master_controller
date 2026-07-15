# Memory-Mapped SPI Master Controller
![Verilog](https://img.shields.io/badge/Language-Verilog-blue)
![Simulator](https://img.shields.io/badge/Simulator-Icarus_Verilog-orange)
![Waveform](https://img.shields.io/badge/Waveform-GTKWave-green)
![Protocol](https://img.shields.io/badge/Protocol-SPI-red)
![License](https://img.shields.io/badge/License-MIT-yellow)
![CI](https://github.com/shreekanthkapparagaon/verilog-spi-master-controller/actions/workflows/sim.yml/badge.svg)

A synthesizable SPI master peripheral in Verilog, built around a memory-mapped
register interface so it can be dropped behind any generic CPU/bus (APB, a
simple Wishbone-style bus, a custom FSM bus, etc.) with only the address
decode logic needing to change.

Supports all four standard SPI modes (CPOL/CPHA), TX/RX FIFO buffering, and
runtime-configurable clock division.

## Features

- All 4 SPI modes (CPOL = 0/1, CPHA = 0/1), selected at runtime via the
  control register — no re-synthesis needed to change mode.
- First-word-fall-through (FWFT) TX/RX FIFOs (`sync_fifo.v`), depth
  configurable via `DEPTH_LOG2` (default depth 16).
- Simple 4-register memory-mapped interface (`spi_reg_map.v`) for easy
  integration behind a CPU bus.
- Configurable clock divider (`CLKS_PER_HALF_BIT` parameter) for the SPI bit
  rate relative to the system clock.
- Single clock domain throughout (no gated/derived clock feeding any
  register) — no CDC hazards between the bus side and the SPI core.

## Architecture

![SPI top-level architecture](docs/architecture_diagram.svg)

- **`spi_reg_map.v`** — decodes the 4 registers, generates single-cycle
  `tx_wr_en` / `rx_rd_en` FIFO strobes, and holds `spi_en` / `cpol` / `cpha`.
- **`sync_fifo.v`** — generic FWFT synchronous FIFO; `rd_data` is driven
  combinationally from `mem[rd_ptr]`, so the entry at the head of the queue
  is visible before `rd_en` is even asserted (this avoids a whole class of
  "read one cycle late" bugs that plagued an earlier draft of this project).
- **`spi_master.v`** — the actual SPI shift-and-clock-generation core. A
  3-state FSM (`IDLE` → `SHIFT` → `DONE`) drives `sclk` directly off the
  system clock divided by `CLKS_PER_HALF_BIT`, and shifts/samples
  `mosi`/`miso` on the edge appropriate to the configured CPHA.

### FSM

![SPI master FSM](docs/fsm_diagram.svg)

`IDLE` waits for `spi_en` with a non-empty TX FIFO, then loads the shift
register and moves to `SHIFT`. `SHIFT` toggles `sclk` every
`CLKS_PER_HALF_BIT` cycles, alternating between a *sample* edge (capture
`miso`) and a *shift* edge (drive the next `mosi` bit) according to `cpha`,
for 8 bits. `DONE` writes the received byte into the RX FIFO and returns to
`IDLE` after exactly one cycle.

## Register Map

| Addr | Name | Access | Bits | Description |
|------|------|--------|------|-------------|
| `00` | CR (Control)  | R/W | `[2]` cpha, `[1]` cpol, `[0]` spi_en | Mode select + enable |
| `01` | SR (Status)   | R   | `[4]` spi_busy, `[3]` rx_full, `[2]` rx_empty, `[1]` tx_full, `[0]` tx_empty | Read-only status flags |
| `10` | TDR (TX Data) | W   | `[7:0]` | Write pushes a byte into the TX FIFO (ignored if full) |
| `11` | RDR (RX Data) | R   | `[7:0]` | Read pops a byte from the RX FIFO (returns `0x00` if empty) |

Typical sequence: write `CR` to set the mode and enable the core, write one
or more bytes to `TDR`, poll `SR` until `spi_busy` clears and `rx_empty`
deasserts, then read `RDR` once per received byte.

## Repo Layout

```
rtl/
  spi_top.v       — top-level integration (reg map + both FIFOs + core)
  spi_master.v    — SPI shift/clock-generation FSM
  spi_reg_map.v   — memory-mapped register interface
  sync_fifo.v     — generic FWFT synchronous FIFO
tb/
  tb_spi_top.v      — primary functional testbench (bus-driven, MOSI/MISO loopback)
  tb_mode_sweep.v   — sweeps all 4 CPOL/CPHA combinations
docs/
  architecture_diagram.svg — spi_top.v block diagram
  fsm_diagram.svg — spi_master.v FSM diagram
```

## Running the Simulation

Requires [Icarus Verilog](http://iverilog.icarus.com/) and, optionally,
[GTKWave](http://gtkwave.sourceforge.net/) for waveform viewing.

```bash
# Primary functional test (register writes/reads, 3-byte loopback transfer)
iverilog -g2012 -o sim_top rtl/spi_top.v rtl/spi_master.v rtl/spi_reg_map.v rtl/sync_fifo.v tb/tb_spi_top.v
vvp sim_top
gtkwave spi_fifo_regs.vcd

# All-4-modes sweep
iverilog -g2012 -o sim_sweep rtl/spi_top.v rtl/spi_master.v rtl/spi_reg_map.v rtl/sync_fifo.v tb/tb_mode_sweep.v
vvp sim_sweep
```

`tb_spi_top.v` ties `miso` to `mosi` (internal loopback), configures Mode 0,
writes three bytes (`0xA5`, `0x5A`, `0x7D`) into the TX FIFO, polls the
status register for completion, and reads all three back out of the RX
FIFO, checking each against the value transmitted.

### Verified Results

```
[DATA CHECK] Received Byte 1 (Expected A5): a5
[DATA CHECK] Received Byte 2 (Expected 5A): 5a
[DATA CHECK] Received Byte 3 (Expected 7D): 7d
[SUCCESS] All bytes processed and verified. RX FIFO is successfully cleared.
```

```
=== SPI mode sweep (post-fix sanity check) ===
  PASS: CPOL=0/CPHA=0 loopback byte 0xa5
  PASS: CPOL=0/CPHA=1 loopback byte 0x96
  PASS: CPOL=1/CPHA=0 loopback byte 0xc3
  PASS: CPOL=1/CPHA=1 loopback byte 0x3c
=== mode sweep complete: 4 passed, 0 failed ===
```

## Known Limitations

- `spi_master.v` is a single master, single chip-select design — no
  multi-slave chip-select decoding.
- `CLKS_PER_HALF_BIT` is a compile-time parameter, not runtime-configurable
  like CPOL/CPHA are; changing the SPI bit rate at runtime would need an
  extra register and a small RTL change to read it instead of the
  parameter.
- No interrupt output — status must be polled via `SR`.

