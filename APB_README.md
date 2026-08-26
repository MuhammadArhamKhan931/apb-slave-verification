# APB Slave Design and Layered Verification Testbench

This repository contains the SystemVerilog RTL design of an APB (Advanced Peripheral Bus) Slave module with a 256x32 memory array, along with a complete layered UVM-style verification environment used to verify protocol compliance, data integrity, and error handling.

## Repository Structure

| File | Description |
|------|--------------|
| `apb_if.sv` | APB interface with modports for driver, monitor, and DUT |
| `apb_slave.sv` | APB Slave RTL design (DUT) |
| `transaction.sv` | Randomized transaction class |
| `generator.sv` | Directed and random test generator |
| `driver.sv` | Bus master driver |
| `monitor.sv` | Bus activity monitor and coverage trigger |
| `scoreboard.sv` | Shadow memory based data integrity checker |
| `coverage.sv` | Functional coverage collector |
| `environment.sv` | Verification environment integrating all components |
| `top_tb.sv` | Top-level testbench module |
| `wave.png` | Simulation waveform screenshot (placeholder) |
| `coverage_report.png` | Functional coverage report screenshot (placeholder) |

## Design Overview

### DUT: APB Slave

The APB Slave implements a memory-mapped peripheral with the following characteristics:

- **Memory:** 256 x 32-bit internal register/memory array
- **FSM:** Three-state Finite State Machine — `IDLE`, `SETUP`, `ACCESS` — implementing the standard APB protocol timing
- **Wait States:** Randomized wait-state generation to model realistic slave response latency and stress-test the master/driver handshaking
- **Error Response:** Reserved address `8'hFF` triggers a `PSLVERR` response, allowing verification of the APB error-handling path
- **Interface Signals:** `PCLK`, `PRESETn`, `PSEL`, `PENABLE`, `PWRITE`, `PADDR`, `PWDATA`, `PRDATA`, `PREADY`, `PSLVERR`

## Verification Architecture

The testbench follows a layered, transaction-based verification methodology. The top-level testbench instantiates the environment, which in turn connects the generator, driver, monitor, scoreboard, and coverage collector. The generator creates transactions and sends them to the driver, which drives them onto the APB interface toward the DUT. The monitor watches the same interface, reconstructs the transactions, and forwards them to the scoreboard for checking and to the coverage collector for sampling. The APB interface, with its driver/monitor/DUT modports, sits between the testbench components and the APB Slave DUT itself.

### Component Responsibilities

1. **APB Interface (`apb_if.sv`)**
   Defines all APB protocol signals with dedicated modports for the driver, monitor, and DUT, ensuring clean separation of signal directionality across the testbench.

2. **Transaction (`transaction.sv`)**
   A randomized transaction class that models a single APB bus operation, with:
   - Randomized address, constrained to valid and reserved ranges
   - 50/50 write/read operation distribution
   - Weighted data distributions to bias coverage toward interesting corner-case values

3. **Generator**
   A task-based stimulus generator that issues both directed test cases (targeting the reserved address and specific corner cases) and fully randomized transactions for broader coverage.

4. **Driver**
   Acts as the APB bus master, converting transaction objects into pin-level protocol activity — driving `PSEL`, `PENABLE`, `PWRITE`, `PADDR`, and `PWDATA` according to the APB timing diagram.

5. **Monitor**
   Passively samples bus activity on the interface, reconstructs observed transactions, and triggers functional coverage sampling without influencing the DUT.

6. **Scoreboard**
   Maintains a 256x32 shadow memory model that mirrors the expected DUT state. Every write updates the shadow memory, and every read is checked against it, with automated match/error tracking to flag data integrity violations.

7. **Functional Coverage**
   Collects coverage across:
   - Write vs. read operation distribution
   - Address range coverage (including the reserved error address)
   - Data value distribution
   - `PREADY`/wait-state behavior
   - Cross-coverage between operation type, address range, and ready state

8. **Environment & Top Test**
   The environment instantiates and connects the generator, driver, monitor, scoreboard, and coverage components. The top-level testbench module instantiates the DUT, environment, and interface, and starts the test.

## Key Protocol Features Verified

- Correct APB `IDLE → SETUP → ACCESS` state transitions
- Proper assertion/de-assertion timing of `PSEL`, `PENABLE`, and `PREADY`
- Randomized wait-state insertion during the `ACCESS` phase
- Correct `PSLVERR` assertion when accessing reserved address `8'hFF`
- Data integrity across back-to-back and randomized read/write sequences

## Functional Coverage Details

The coverage model tracks the following coverpoints and cross-coverage bins:

| Coverpoint | Description |
|------------|--------------|
| `write_read_cp` | Write vs. read operation split |
| `addr_range_cp` | Address bins spanning valid memory range and reserved address |
| `data_cp` | Data value distribution with weighted bins |
| `ready_cp` | `PREADY`/wait-state behavior (zero-wait vs. multi-cycle) |
| `cross_op_addr_ready` | Cross-coverage of operation type × address range × ready state |

Coverage reports are generated post-simulation and can be reviewed in the simulator's coverage viewer.

## Notes

This project demonstrates a complete layered verification methodology for an APB Slave peripheral, covering protocol timing, error handling, and data integrity through constrained-random stimulus, a self-checking scoreboard, and functional coverage closure.
