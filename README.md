# RTL-Design-of-APB-Protocol

## System Overview
This system is an AMBA APB (Advanced Peripheral Bus) interconnect that manages communication between one Master and two Slaves. It uses a wrapper module to handle signal multiplexing, routing, and state transitions.

### **System Specifications**

*   **Protocol:** AMBA APB (Advanced Peripheral Bus), focusing on the **SETUP** and **ACCESS** phases for reliable data transfer.
    
*   **Architecture:** 1 Master to 2 Slave configuration, featuring a wrapper for signal routing.
    
*   **Handshaking:** Uses PREADY to handle variable-latency slaves (wait states) and PSLVERR for error detection.
    
*   **Data Integrity:** Supports byte-level write control via PSTRB (Write Strobes) and address decoding via SEL.
    
*   **State Management:** The master utilizes an FSM to transition from IDLE to SETUP (address phase) and then to ACCESS (data phase).

---



## Interface Signals

### 1. Control Interface (Testbench to Master)
| Signal | Dir | Description |
| :--- | :--- | :--- |
| `PCLK` | In | System clock. |
| `PRESETn` | In | Asynchronous active-low reset. |
| `EN` | In | Pulse: Triggers the transaction FSM. |
| `WRn` | In | 1: Write, 0: Read. |
| `SEL` | In | 0: Select Slave 1, 1: Select Slave 2. |
| `ADDR` | In | Target memory address. |
| `WDATA` | In | Write data payload. |
| `WSTRB` | In | Byte-enable mask for write operations. |
| `DATA_OUT` | Out | Data returned from a Read transaction. |

### 2. APB Bus Interface (Master to Slaves)
| Signal | Dir | Description |
| :--- | :--- | :--- |
| `PADDR` | Out | Current target address. |
| `PSELx` | Out | Slave select (PSEL1/PSEL2). |
| `PENABLE` | Out | High: Signals the ACCESS phase. |
| `PWRITE` | Out | Indicates Read or Write state. |
| `PWDATA` | Out | Data sent to the slave. |
| `PSTRB` | Out | Byte-enable mask. |
| `PREADY` | In | High: Slave ready; Low: Wait state. |
| `PRDATA` | In | Data returned from the slave. |
| `PSLVERR` | In | High: Error reported by the slave. |

---

## Master FSM Operation
* **IDLE:** Ready to receive `EN`. Signals are held at default values.
* **SETUP:** Address, Data, and Control signals are driven onto the bus. `PENABLE` is held low to allow signals to settle.
* **ACCESS:** `PENABLE` is asserted high to execute the transaction. The Master waits in this state until the selected slave asserts `PREADY`.
