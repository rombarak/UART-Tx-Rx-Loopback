# UART Transmitter & Receiver with Loopback (Verilog HDL)
<a id="sec-author"></a>
**Author:** Rom Barak  
**Institution:** Bar-Ilan University
**Focus:** Nanoelectronics and Communication Systems

This project implements a complete **UART communication system** in **Verilog HDL**, designed and verified through a **fully functional loopback setup**.  
It includes the **Baud Rate Generator**, **Transmitter (TX)**, **Receiver (RX)**, **Top-Level Integration**, and a **self-checking Testbench** that validates transmission accuracy and synchronization in simulation.  

The design was built from the ground up - focusing on **precise timing**, **half-bit sampling alignment**, and **shared tick synchronization** - achieving bit-perfect loopback communication with zero mismatches.

---

## Table of Contents
- [Author](#sec-author)
- [Introduction](#sec-intro)
- [System Overview](#sec-overview)
- [Timing and Synchronization](#sec-timing)
- [Baud Rate Configuration](#sec-baud)
- [Frame Format](#sec-frame)
- [Modules Description](#sec-modules)
  - [Baud Generator (`baud_gen.v`)](#sec-baud-gen)
  - [UART Transmitter (`uart_tx.v`)](#sec-uart-tx)
  - [UART Receiver (`uart_rx.v`)](#sec-uart-rx)
  - [Top-Level Loopback Integration (`uart_top.v`)](#sec-top)
  - [Verification Testbench (`uart_tb.v`)](#sec-tb)
- [Simulation and Waveforms](#sec-waves)
- [Results](#sec-results)
- [Design Insights](#sec-insights)
- [Baud Rate Adjustment Guide](#sec-baud-guide)
- [Future Improvements](#sec-future)
- [License](#sec-license)

---
<a id="sec-intro"></a>
## Introduction
This project demonstrates a reliable **UART (Universal Asynchronous Receiver/Transmitter)** design that achieves error-free serial communication under simulation.  
The system follows the **8N1** standard format — 8 data bits, no parity, 1 stop bit — and is clocked by a **50 MHz** system clock with a **9600 baud** transmission rate.  

Unlike many UART examples, this design does not rely on oversampling.  
Instead, it achieves accurate reception through **deterministic half-bit alignment**, verified by timing analysis and waveform inspection.

The design and all test scenarios were implemented and simulated using **Cadence Xcelium** and **GTKWave**.

---
<a id="sec-overview"></a>
## System Overview
The UART system contains three main hardware modules:
1. **Baud Rate Generator (`baud_gen.v`)** – Divides the 50 MHz clock to generate the baud-rate tick.
2. **Transmitter (`uart_tx.v`)** – Serializes data into start, data, and stop bits.
3. **Receiver (`uart_rx.v`)** – Deserializes incoming bits, aligns timing, and reconstructs data bytes.

These modules are connected inside the **`uart_top.v`** integration file, where the TX output is **looped back** to the RX input, allowing complete internal verification without physical UART lines.

Both TX and RX use the **same baud tick** signal from the generator, ensuring perfect synchronization at the bit level.

---
<a id="sec-timing"></a>
## Timing and Synchronization
The system operates at:
- **System Clock:** 50 MHz  
- **Baud Rate:** 9600 bps  
- **Tick Period:** 1 / 9600 s ≈ 104.17 µs  
- **Clock Cycles per Tick:** 50,000,000 / 9600 ≈ 5208  

The `baud_gen` creates a **1-cycle-wide pulse** (`tick`) every 5208 system cycles.  
This tick acts as the universal timing reference for both the transmitter and receiver.

When the RX detects the **falling edge** of the start bit, it enters a “half-bit delay” phase - effectively aligning sampling to the **middle** of each subsequent bit period.  
This precise half-tick offset ensures that RX samples at the most stable voltage level of the bit.

Although both TX and RX receive ticks at the same time, their internal FSM phases cause a natural half-tick difference between transmission edges and sampling points — producing correct mid-bit alignment.

---
<a id="sec-baud"></a>
## Baud Rate Configuration
The default setup is **50 MHz system clock** and **9600 baud rate** - this configuration provides highly stable and accurate timing (≈0.006% baud error).  
If you wish to change the baud rate, update the following parameters in **`baud_gen.v`**:

```verilog
parameter CLK_FREQ  = 50_000_000;  // System clock frequency [Hz]
parameter BAUD_RATE = 9600;        // Target baud rate [bps]
```

After changing `BAUD_RATE`, the `DIVISOR` constant will automatically adjust:
```
localparam integer DIVISOR = CLK_FREQ / BAUD_RATE;
```
> **Important:**  
> - The same clock frequency and baud rate must be used across all modules.  
> - If you change the baud rate, you **must also modify timing-related delays in the testbench (`uart_tb.v`)** —  
>   specifically, the wait durations between transmitted bytes (`#2000`, `wait(rx_done)`, etc.), so that they correspond to the new bit period.  
> - For best simulation stability, it is recommended to keep the default configuration: **50 MHz / 9600 bps**.

This is the frequency ratio that the entire project was verified and tuned with.

---
<a id="sec-frame"></a>
## Frame Format
Each transmitted UART frame contains **10 bits total**:
| Segment | Bits | Description |
|----------|------|-------------|
| Idle | 1 | Line held high (`1`) |
| Start Bit | 1 | Logic low (`0`) to begin frame |
| Data Bits | 8 | Sent LSB first |
| Stop Bit | 1 | Logic high (`1`) to end frame |

**Frame Example:**  
`Idle (1)` → `Start (0)` → `b0 b1 b2 b3 b4 b5 b6 b7` → `Stop (1)`  

This follows the 8N1 UART convention.

---
<a id="sec-modules"></a>
## Module Descriptions
<a id="sec-baud-gen"></a>
### **1. Baud Generator – `baud_gen.v`**
Generates the baud-rate timing pulse shared by both TX and RX.  
The divider computes:
```
DIVISOR = CLK_FREQ / BAUD_RATE
```
When the internal counter reaches `DIVISOR - 1`, a one-clock-cycle `tick` pulse is asserted and the counter resets.

**Purpose:** Ensures both transmitter and receiver progress through each bit period in exact lockstep.

---
<a id="sec-uart-tx"></a>
### **2. UART Transmitter – `uart_tx.v`**
Implements the transmit-side FSM with four states:
- **IDLE:** Line is high; waits for `tx_start` trigger.  
- **START:** Drives line low for one tick.  
- **DATA:** Sends each bit of `tx_data` (LSB first) every tick.  
- **STOP:** Drives line high, signaling frame completion.  

When `tx_start` is asserted, the module latches the byte into a shift register and sets `tx_busy` high until all bits are transmitted.

This FSM guarantees consistent bit timing and correct framing.

---
<a id="sec-uart-rx"></a>
### **3. UART Receiver – `uart_rx.v`**
The receiver mirrors the TX FSM with four states:
- **IDLE:** Monitors line for a falling edge (start bit).  
- **START:** Waits half a bit-time before confirming valid start.  
- **DATA:** Samples 8 data bits at each tick midpoint and shifts them into a register.  
- **STOP:** Confirms the stop bit (line high), asserts `rx_done`, and outputs the byte.  

This design achieves accurate mid-bit sampling without oversampling, purely based on timing alignment from the shared tick.

---
<a id="sec-top"></a>
### **4. Top-Level Integration – `uart_top.v`**
Connects all modules into a complete UART system.  
The TX line is internally looped to the RX input, allowing closed-loop validation.  
This configuration verifies all timing, synchronization, and FSM behavior within one simulation environment.

---
<a id="sec-tb"></a>
### **5. Verification Testbench – `uart_tb.v`**
A self-checking testbench that automates:
- Clock generation (50 MHz)
- Reset sequencing  
- Transmission of multiple bytes  
- Waiting for `rx_done` pulses  
- Comparing transmitted vs received bytes  

**Test sequence:**  
`A5`, `3C`, `FF`, `00`, `55`  

Each transaction is logged using `$display`, verifying byte-for-byte integrity.  
A VCD waveform (`uart_loopback.vcd`) is generated for visual inspection.

---
<a id="sec-waves"></a>
## Simulation and Waveforms
The design was simulated using **Cadence Xcelium** and **GTKWave**.  
Waveforms show:
- The shared `tick` signal aligning TX and RX  
- The RX’s half-bit delay for mid-bit sampling  
- The FSM transitions (`IDLE → START → DATA → STOP`)  
- Perfect data reconstruction with no mismatches  

---
<a id="sec-results"></a>
## Results
- 100% match between transmitted and received bytes  
- TX and RX perfectly synchronized under shared tick control  
- Verified stable half-bit sampling with no timing drift  
- Baud rate error < 0.01% (9600.6 bps effective)  
- Clean stop-bit recognition and proper idle-state recovery  

This confirms full functional correctness and timing reliability.

---
<a id="sec-insights"></a>
## Design Insights
- **Single shared tick** ensures deterministic synchronization between TX and RX.  
- **Half-bit delay** in RX guarantees sampling at the bit center without oversampling.  
- **FSM-based control** provides cycle-accurate sequencing and easy debugging.  
- **Edge-triggered start detection** prevents false frame detection due to noise.  

The combination of shared timing, FSM separation, and internal loopback produces a robust and verifiable UART implementation.

---
<a id="sec-future"></a>
## Future Improvements

The current UART system operates accurately in a full loopback configuration, but several engineering enhancements could extend its functionality and robustness for real-world applications:

- **Parity Bit (Even/Odd)**  
  Adds a basic error detection mechanism by appending an extra control bit after the data bits. Useful for detecting transmission errors over long or noisy lines.

- **Two Stop Bits**  
  Introduces an additional idle period between frames, improving synchronization and tolerance to clock mismatch between transmitter and receiver.

- **Runtime Baud Rate Selection**  
  Allows dynamic adjustment of the baud rate by replacing the `parameter BAUD_RATE` with a writable control register.  
  When changing the baud rate, make sure to also update timing-related parameters in `baud_gen.v` and the `repeat` delays in `uart_tb.v`.

- **×16 Oversampling for Noise Immunity**  
  Samples each bit 16 times per baud period and uses a majority-vote mechanism to determine the received value, enhancing stability and noise resistance in real environments.

- **FPGA I/O Integration (External UART Interface)**  
  Connecting the TX/RX signals to physical FPGA pins enables real serial communication with PCs, microcontrollers, or other devices, facilitating hardware-level verification.
---
<a id="sec-license"></a>
## License
Released under the **MIT License**.  
Free for academic, research, and educational use.
