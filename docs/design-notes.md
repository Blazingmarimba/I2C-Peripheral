# Design Notes

## FSM Overview

This design implements an I²C slave using a Finite State Machine (FSM) to handle protocol stages such as address detection, data read/write, and acknowledgment phases.

_→ Insert FSM diagram here (e.g., docs/images/fsm_diagram.png)_

---

## Reset Behavior
- FSM resets to `IDLE`
- Bit counter, register address, and watchdog timer reset to 0
- Data register resets to all '1'

## State Descriptions

| State Name       | Description                                                  | Entry Conditions                                          | Exit Conditions                              |
|------------------|--------------------------------------------------------------|-----------------------------------------------------------|-----------------------------------------------|
| `IDLE`           | Wait for start condition                                     | Reset or STOP condition detected. Watchdog timer expires                          | START condition detected                      |
| `I2C_ADDRESS`    | Receive slave address byte                                   | START or repeated START detected                          | Address byte received                         |
| `OTHER_PERIPHERAL` | Idle while controller interacts with another device         | Address does not match configured address                 | STOP or repeated start detected               |
| `ACK_ADDRESS`    | Send ACK for matched address                                 | Address byte matches configured address                   | SCL falling edge after ACK bit                |
| `REG_ADDRESS`    | Receive register address byte                                | Write bit detected after address match                    | Register byte received                        |
| `ACK_REG`        | Send ACK for register address                                | Register address received                                 | SCL falling edge after ACK bit                |
| `WRITE_HOLD`     | Wait for first SCL clock or stop/repeat                      | Entered after ACK_REG                                     | SCL rising edge or stop/repeated start       |
| `WRITE`          | Sample data from SDA and shift into data register                                     | SCL rising edge                                           | Byte received (8 bits shifted in)             |
| `ACK_WRITE`      | Send ACK after write byte received                           | Byte received                                              | SCL falling edge after ACK                    |
| `READ_PREP`      | Prepare data to send to controller                           | Read bit detected after address match                     | Data ready to drive SDA                 |
| `READ`           | Use register to drive SDA                                     | Data ready signal                                         | Byte sent, and ACK/NACK received               |
| `READ_DONE`      | Wait after NACK to detect repeated start or stop             | NACK received after data sent                             | Start or repeated start detected              |

---

## Transition Conditions

### `IDLE` → `I2C_ADDRESS`
- Detected START condition (SDA falling edge while SCL is high)

### `I2C_ADDRESS`
- After receiving 8 bits (address byte)
- If address matches → `ACK_ADDRESS`
- Else → `OTHER_PERIPHERAL`

### `ACK_ADDRESS` → `REG_ADDRESS` / `READ_PREP`
- If write bit detected → `REG_ADDRESS`
- If read bit detected → `READ_PREP`

### `REG_ADDRESS` → `ACK_REG` → `WRITE_HOLD` → `WRITE` → `ACK_WRITE`
- Sequential write phase
- Detect SCL rising edge to shift in data bits

### `READ_PREP` → `READ` → `READ_DONE`
- Sequential read phase
- Shift out data on SCL falling edge

---

## FSM Output Signals

| State           | `sda_out` | `reg_write` | `ack_out` | `data_out_valid` |
|-----------------|-----------|-------------|-----------|------------------|
| `IDLE`          | Z         | 0           | 0         | 0                |
| `ACK_ADDRESS`   | 0         | 0           | 1         | 0                |
| `ACK_REG`       | 0         | 0           | 1         | 0                |
| `WRITE`         | Z         | 0           | 0         | 0                |
| `ACK_WRITE`     | 0         | 1 (one-shot)| 1         | 0                |
| `READ`          | bit[n]    | 0           | 0         | 1 (during byte)  |
| `READ_DONE`     | Z         | 0           | 0         | 0                |
| `OTHER_PERIPHERAL` | Z      | 0           | 0         | 0                |

> Note: `sda_out` is high-impedance (Z) when not actively driven low.

---

## FSM Behavioral Summary

```markdown
- On power-up or STOP condition, FSM starts in IDLE.
- When START condition is detected, transitions to I2C_ADDRESS.
- If the address matches, FSM continues into ACK and either WRITE or READ path.
- WRITE path handles register addressing, data reception, and ACKs.
- READ path handles data output via shift register, ACK/NACK handling.
- FSM returns to IDLE on STOP or repeats the process on repeated START.
- Watchdog timer to prevent FSM lockup
- Watchdog timer inactive in IDLE state and resets on state transitions 
```

## Counters, Timers, and buffers

### Watchdog timer
A watchdog timer is used to prevent FSM lockup if an unexpected event occurs (e.g. I2C controller stops sending the clock signal). The watchdog timer is long enough to send 15 bits in standard mode (150 us). The watchdog counter is enabled on the rising edge of the system clock in all FSM states except `IDLE` and resets on any state transition.

### Bit counter
Counts the number of bits transmitted. Increments on the rising edge of SCL in the states `I2C_ADDRESS`, `READ`, `REG_ADDRESS`, and `WRITE`. Raises `byte_transmitted` signal when 8 bits have been transmitted. 

### Data register
Holds the data being transmitted on SDA. Performs left shifts. The data register has two modes

1. Read mode: The controller is reading from the peripheral. The MSB drives SDA. shifts on the falling edge of SCL and shifts in a '1'. Data is loaded parallel during `READ_PREP`. 
2. Write Mode: The controller is writing to the peripheral. SDA is sampled and shifted in on the rising edge of SCL. 

### Register Address
Holds the current register address that is being read from or written to. Loaded when exiting `REG_ADDRESS` state. Auto-increments when transition from `READ` to `READ_PREP` or from `WRTIE` to `SEND_ACK`.

---

## Test Coverage (Planned)

| Testbench File         | Covered FSM Path                                       |
|------------------------|--------------------------------------------------------|
| `tb_basic_write.sv`    | `IDLE → I2C_ADDRESS → ACK_ADDRESS → REG_ADDRESS → ACK_REG → WRITE → ACK_WRITE → IDLE` |
| `tb_basic_read.sv`     | `IDLE → I2C_ADDRESS → ACK_ADDRESS → READ_PREP → READ → READ_DONE` |
| `tb_repeat_start.sv`   | Tests repeated START during read                       |

---

## Notes

- This FSM handles basic I²C slave functionality with optional extensions.
- Clock stretching, arbitration, and PEC are **not** currently supported.
- SDA line is assumed to be bidirectional with external pull-up.


