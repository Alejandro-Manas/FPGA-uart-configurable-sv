# Configurable UART Core with Oversampling & Majority Voting

This project features a fully parameterized UART (Transmitter and Receiver) core developed in **SystemVerilog**. The architecture is optimized for noisy environments, implementing a receiver with compile-time configurable oversampling and a synchronous majority voting filtering sub-system that samples the center of the data bit to guarantee signal integrity.

## 🛠️ Architecture & RTL Design Specifications

The design is completely synchronous and modular, partitioned into four core blocks located in the `rtl/` directory:

* **Baud Rate Generator ([`baud_gen.sv`](./rtl/baud_gen.sv)):** Divides the global system clock (`clk_freq`) to generate precise oversampling ticks. All frequency divisors are calculated at compile time based on the chosen oversampling factor. It supports runtime dynamic baud rate selection (9600, 19200, 38400, 57600, 115200) via a 3-bit configuration bus.
* **Oversampled Reader ([`oversampled_reader.sv`](./rtl/oversampled_reader.sv)):** The core of the receiver's noise immunity. Upon activation, it opens a synchronous sampling window. Instead of relying on a single edge sample prone to glitches, it takes multiple readings strictly within the center of the bit duration and applies a majority voting algorithm to resolve the actual logic level ('0' or '1').
* **Transmitter Module ([`tx_module.sv`](./rtl/tx_module.sv)):** Implements the transmission Finite State Machine (FSM). It sequentially generates the *Start Bit*, 8 data bits (LSB first), computes and injects the parity bit on the fly, and appends the *Stop Bit*. It manages the `available_to_send` flag to stall upstream writes while the line is busy.
* **Receiver Module ([`rx_module.sv`](./rtl/rx_module.sv)):** Implements the receiver FSM. It integrates a double-flop synchronizer stage on the raw input line to prevent metastability. It orchestrates the oversampled reader to reconstruct incoming bytes, verifies parity integrity against the configured mode, and validates the *Stop Bit* framing before asserting `byte_ready`.

### Core Parameters & Configuration
* `clk_freq`: System clock frequency (default validated at 200 MHz).
* `oversampling_factor`: Clock ticks per bit, **configurable at compile time** (default 16x).
* `baud_rate`: Runtime dynamic selector (000: 9600, 001: 19200, 010: 38400, 011: 57600, 100: 115200).
* `parity_bit_mode` / `parity_bit`: Control bit configuration (00: NONE, 01: EVEN, 10: ODD).

---

## 📈 Verification & Simulation Reports

The integrity and robustness of every module have been thoroughly validated using automated testbenches driven by **synchronous assertions (`assert`)**. This ensures the hardware strictly adheres to the UART protocol under corner-case conditions.

### Testbenches & Simulation Logs

* **Transmitter Simulation ([`tx_sim.sv`](./sim/tx_sim.sv))** Validates FSM state transitions, bit-duration precision, and correct even/odd parity calculation. It asserts that new data writes are safely ignored when the transmitter is busy.  
  ▶️ *[View Simulation Report](./sim/reports/tx_sim_report.txt)*

* **Receiver Simulation ([`rx_sim.sv`](./sim/rx_sim.sv))** Evaluates standard frame reception across all supported baud rates. It injects deliberate parity and framing errors into the simulation stream to verify that the core drops the `byte_valid` flag accordingly.  
  ▶️ *[View Simulation Report](./sim/reports/rx_sim_report.txt)*

* **Oversampled Reader Simulation ([`oversampled_reader_sim.sv`](./sim/oversampled_reader_sim.sv))** Stresses the oversampling block's noise filter. High-frequency glitches and single-cycle line noise are simulated, proving the majority voting system successfully isolates rumbles and reconstructs clean data.  
  ▶️ *[View Simulation Report](./sim/reports/oversampled_reader_report.txt)*

* **Baud Generator Simulation ([`baud_gen_sim.sv`](./sim/baud_gen_sim.sv))** Measures exact clock cycles between generated ticks to guarantee negligible drift across all baud rates. It also verifies instantaneous response on the synchronous `clear` line.  
  ▶️ *[View Simulation Report](./sim/reports/baud_gen_report.txt)*

---

## 💻 Tools & Requirements
* **Language:** SystemVerilog (IEEE 1800-2012)
* **Recommended EDA Environment:** Xilinx Vivado / XSIM
