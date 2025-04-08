# Project Plan: I2C Peripheral

## Project Summary

This project implements an I²C (Inter-Integrated Circuit) peripheral module in SystemVerilog. The goal is to create a synthesizable, testable design that supports both Standard Mode (100 kHz) and Fast Mode (400 kHz), with optional 7-bit or 10-bit addressing.

Two IP cores will be developed:

1. **Direct Register Access Core** – Exposes internal registers for direct read/write via logic.
2. **Wishbone-Compatible Core** – Implements a Wishbone B4 slave interface and provides an interrupt output when a write operation to the internal register file completes.

This project is designed to grow practical skills in IP design, simulation, bus interfacing, and hardware validation.

## Objectives

- Implement a I2C peripheral module in SystemVerliog
- Support both standard (100 kHz) and fast (400 kHz) mode
- Add 7-bit and 10-bit addressing support
- Create two IPs: one with raw register access, one with a Wishbone interface
- Develop testbench and simulate with Verilator
- Generate waveform output for verification
- Synthesize and deploy on Alchitry Pt V2 board using Alchitry Br V2 to breakout signals

## Tools and Technologies

| Tool              | Use                                    |
|------------------|-----------------------------------------|
| **SystemVerilog** | HDL for module and testbench design     |
| **Verilator**     | Simulation and testbench execution      |
| **GTKWave**       | Waveform viewing and debugging          |
| **Vivado 2024.2** | Synthesis and bitstream generation      |
| **Alchitry Pt V2**| Target FPGA board for testing           |
| **Alchitry Br V2**| Breakout FPGA pins for testing (optional) |
| **Raspberry Pi 4**| I²C master for hardware test interface (optional) |

## Key Features
- Configurable 7-bit or 10-bit peripheral address
- Supports Standard and Fast I2C modes
- Auto-incrementing internal register address on read/write
- Handles repeated start conditions
- Interrupt signal on successful register write (Wishbone core)

## Milestones

| Milestone                                | Status          | Date Completed |
|------------------------------------------|-----------------|----------------|
| Project repo created                     | ✅ Done        | Mar 29, 2025|
| Write initial I2C peripheral module        | ✅ Done |April 2, 2025|
| Create testbench and run simulation      | ✅ Done     |April 5, 2025|
| Add 10-bit addressing support            | ✅ Done     |April 5, 2025|
| Synthesize and test on Alcitry Pt V2     | ⏸️ On hold, waiting for board    ||
| Finalize README and documentation        | ⏳ Planned     ||

## Test Plan
- Simulate write/read from the same register with waveform validation
- Create Python script on Raspberry Pi too:
  - Write to all registers
  - Read back values and verify correctness
- Confirm ACK/NACK and repeated start handling in simulation

## Notes
- Follow I²C timing specs per [NXP UM10204](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
- Wishbone interface to follow [B4 Specification](https://cdn.opencores.org/downloads/wbspec_b4.pdf)

