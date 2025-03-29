# I2C Peripheral

## Description
This project implements a SystemVerilog I2C slave peripheral that can operate in both Standard Mode (100 kHz) and Fast Mode (400 kHz). It supports 7-bit and 10-bit addressing, and includes two versions of the core:

- **Direct Access Core**: Exposes internal registers to the system for direct access.
- **Wishbone-Compatible Core**: Exposes a Wishbone B4 slave interface and an interrupt output when a write operation occurs.

Designed for both simulation and hardware deployment, this project builds practical skills in IP core design, communication protocols, and FPGA integration.

## **Features:**
- I2C Slave with support for:
  - 7-bit and 10-bit addresses
  - Standard (100 kHz) and Fast (400 kHz) modes
  - Repeated start detection
  - Auto-incrementing internal register addresses
- Two integration options:
  - Standalone with direct register access
  - Wishbone B4 slave interface with interrupt line
- Synthesizable for deployment on real hardware
- Testbench included for functional verification

## Tools & Platform

- **HDL**: SystemVerilog
- **Simulation**: Verilator + GTKWave
- **Synthesis**: Vivado 2024.2
- **Target FPGA**: Alchitry Pt V2 (Artix A7100T)
- **Testing Host**: Raspberry Pi 4 (optional, acts as I2C master)

## Project Structure
```
.
├── constraints/                        # FPGA constraint files (XDC)
├── docs/                               # Documentation and supporting materials
│   ├── images/                         # Block diagrams, waveforms, etc.
│   ├── project-plan.md                 # Project goals, milestones, test plan
│   └── resources.md                    # References and learning materials
├── rtl/                                # RTL design files (SystemVerilog)
│   ├── example/                        # Examples of top-level modules
│   │   ├── directAccess/               # Example using direct register access
│   │   │   └── directAccessTop.sv
│   │   └── wbTop/                      # Example using Wishbone interface
│   │       └── wbTop.sv
│   ├── debouncer.sv
│   └── i2c_peripheral.sv
├── scripts/                            # TCL scripts to build cores and examples
├── sim/                                # Testbenches, simulation files, VCD output
├── test/                               # Raspberry Pi test scripts (Python)
├── LICENSE                             # License
└── README.md                           # This file
```

## How to Use

### Simulation (via Verilator)
1. Navigate to the root directory
2. Run the testbench using:
```bash
make -C sim/
```
3. Open waveform:
```bash
gtkwave sim/waveform.vcd
```

### Synthesis and Deployment
1. Open Vivado
2. Run the provided script:
```tcl
source scripts/build_example.tcl
```
3. Program the Alchitry Pt V2 via USB

## Learnings & Takeaways

- Developed low-level understanding of the I2C protocol
- Designed and verified finite state machines (FSMs) for bus handling
- Practiced simulation and waveform debugging using GTKWave
- Integrated IP with Wishbone bus for system-on-chip interfacing

## References

- [I2C Protocol – Wikipedia](https://en.wikipedia.org/wiki/I%C2%B2C)
- [NXP I2C Specification](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
- [Wishbone B4 Spec](https://cdn.opencores.org/downloads/wbspec_b4.pdf)

See [`docs/resources.md`](docs/resources.md) for a complete list.

##  Author

**Michael Bjerregaard** – M.S. in Computer Engineering  
LinkedIn: [linkedin.com/in/michael-bjerregaard](https://www.linkedin.com/in/michael-bjerregaard/)

## 📄 License

This project is licensed under the terms of the [Solderpad Hardware License V2.1](LICENSE).
