# Traffic Light Controller — Tutorial
## Part 7: Top-Level Integration

---

### 1. What Is the Top-Level Module?

The top-level module (`traffic_light_top.v`) does **no logic itself**.
Its only jobs are:

1. **Instantiate** all subsystem modules
2. **Connect** wires between them
3. **Fan out** internal signals to physical output pins
4. **Handle** shared/special pins (inout, tristate)

Think of it as a wiring diagram expressed in Verilog.

```
External World                traffic_light_top                Subsystems
──────────────                ─────────────────                ──────────
clk ──────────────────────────────────────────────────────────► clk_div
rst_n ────────────────────────────────────────────────────────► all modules
dig_dip[3:0] ◄───────────────[tristate logic]────────────────► seg_direction
             ────────────────[tristate logic]────────────────► dip_controller
io_mode ──────────────────────────────────────────────────────► tristate ctrl
led_N_G ◄─────────────────────────────────────────────────────  traffic_fsm
...all other outputs                                             (fan-out)
```

---

### 2. Connection Principles

**Rule 1: Every subsystem output becomes a wire in top-level**

```verilog
// Declare internal wires for every inter-module connection
wire tick_1hz, tick_2hz;        // clk_div → fsm
wire system_fault;              // conflict_monitor → fsm, fault_led
wire [2:0] jump_state;          // dip_controller → fsm
wire       start_jump;          // dip_controller → fsm
wire [3:0] time_N, time_S;      // fsm → seg_direction
wire [3:0] time_E, time_W;      // fsm → seg_direction
wire [3:0] seg_dig_out;         // seg_direction → dig_dip (tristate)
wire [3:0] dip_btn;             // dig_dip (tristate) → dip_controller
```

**Rule 2: Module ports must match exactly**

```verilog
// The port name in the instantiation (.port_name) must match
// the module definition exactly. The wire name on the right
// can be anything.
traffic_fsm u_fsm (
    .clk         (clk),          // port=clk,     wire=clk
    .tick_1hz    (tick_1hz),     // port=tick_1hz, wire=tick_1hz
    .system_fault(system_fault), // port=system_fault, wire=system_fault
    ...
);
```

---

### 3. Signal Flow Diagram

```
                    ┌──────────────────────────────────────────────┐
          clk ─────►│ clk_div                                      │
        rst_n ─────►│          tick_1hz ──────────────────────────►│ traffic_fsm
                    │          tick_2hz ──────────────────────────►│
                    └──────────────────────────────────────────────┘

                    ┌──────────────────────────────────────────────┐
      dig_dip ─────►│ dip_controller                               │
       io_mode ────►│   (sync→debounce→edge→decode)                │
                    │          start_jump ────────────────────────►│ traffic_fsm
                    │          jump_state ────────────────────────►│
                    └──────────────────────────────────────────────┘

                    ┌──────────────────────────────────────────────┐
                    │ traffic_fsm                                   │
                    │          a_str_green ───────────────────────►│ conflict_monitor
                    │          a_left_green ──────────────────────►│
                    │          a_ped_walk ────────────────────────►│
                    │          b_str_green ───────────────────────►│
                    │          b_left_green ──────────────────────►│
                    │          b_ped_walk ────────────────────────►│
                    └──────────────────────────────────────────────┘

                    ┌──────────────────────────────────────────────┐
                    │ conflict_monitor                              │
                    │          system_fault ──────────────────────►│ traffic_fsm
                    │          system_fault ───────────────────────┼──► fault_led
                    └──────────────────────────────────────────────┘

                    ┌──────────────────────────────────────────────┐
                    │ traffic_fsm                                   │
                    │          time_N ────────────────────────────►│ seg_direction
                    │          time_S ────────────────────────────►│
                    │          time_E ────────────────────────────►│
                    │          time_W ────────────────────────────►│
                    └──────────────────────────────────────────────┘

                    ┌──────────────────────────────────────────────┐
                    │ seg_direction                                  │
                    │          seg_dig_out ───────────────────────►│ [tristate]──► dig_dip
                    │          SVNSEG_SEG ────────────────────────►│ SVNSEG_SEG (output pin)
                    └──────────────────────────────────────────────┘
```

---

### 4. The Tristate Inout Pattern

This is the most hardware-specific concept in the design.

```verilog
inout wire [3:0] dig_dip;

wire [3:0] seg_dig_out;  // output from seg_direction
wire [3:0] dip_btn;      // input to dip_controller

// Tristate driver: io_mode controls direction
assign dig_dip[0] = io_mode ? seg_dig_out[0] : 1'bz;
assign dig_dip[1] = io_mode ? seg_dig_out[1] : 1'bz;
assign dig_dip[2] = io_mode ? seg_dig_out[2] : 1'bz;
assign dig_dip[3] = io_mode ? seg_dig_out[3] : 1'bz;

// Read: suppress reading when driving output
assign dip_btn = io_mode ? 4'b0000 : dig_dip;
```

**Why `4'b0000` when io_mode=1?**

When the FPGA is driving the pins (output mode), reading `dig_dip` would
return the value the FPGA itself is driving — which would be interpreted
as a button press. We force `dip_btn = 0` (no request) when in output mode
to prevent false jump triggers.

**Physical layer:**

```
         FPGA
         ┌─────┐
seg_dig ─┤ OE  │
         │     ├──── dig_dip[0] ──── PCB mux ──── 7-seg DIG0
io_mode ─┤ sel │                         └──────── DIP switch bit 0
         └─────┘
              ↑
         Tristate buffer
         (built into FPGA I/O cell)
```

---

### 5. Fan-Out Pattern

North and South share Axis A signals. East and West share Axis B signals.
This is expressed as simple `assign` statements:

```verilog
// Straight LEDs — North and South are identical (both Axis A)
assign led_N_G = a_str_green;
assign led_S_G = a_str_green;   // same wire, different physical pin
assign led_N_Y = a_str_yellow;
assign led_S_Y = a_str_yellow;
assign led_N_R = a_str_red;
assign led_S_R = a_str_red;

// East and West share Axis B
assign led_E_G = b_str_green;
assign led_W_G = b_str_green;
...
```

**In hardware:** This means one FPGA output register drives two physical pins.
The synthesis tool handles this automatically — no extra logic needed.

> **Note:** Driving two pins from one output is called **fan-out**.
> The FPGA's output driver can handle this easily for LED loads.
> For high-speed signals or large capacitive loads, fan-out must be
> carefully managed — but for 5–20mA LED drivers, it is trivial.

---

### 6. Parameterized Instantiation

The FSM phase durations are passed as parameters from the top level:

```verilog
traffic_fsm #(
    .A_STR_TIME   (4),    // North/South straight: 4 seconds
    .A_SYEL_TIME  (3),    // North/South yellow:   3 seconds
    .A_LFT_TIME   (4),    // North/South left:     4 seconds
    .A_LYEL_TIME  (3),
    .B_STR_TIME   (4),
    .B_SYEL_TIME  (3),
    .B_LFT_TIME   (4),
    .B_LYEL_TIME  (3),
    .ALLRED_TIME  (2),    // All-red buffer:       2 seconds
    .JUMP_YEL_TIME(3)     // Jump yellow:          3 seconds
) u_fsm (...);
```

**Why pass parameters from top level?**

Because `traffic_fsm` is a reusable module. You could instantiate two
FSMs with different timing (e.g., busy intersection vs quiet side road)
without changing the module source code:

```verilog
// Busy main road
traffic_fsm #(.A_STR_TIME(8), .B_STR_TIME(8)) u_fsm_main (...);

// Quiet side street
traffic_fsm #(.A_STR_TIME(3), .B_STR_TIME(3)) u_fsm_side (...);
```

---

### 7. QSF — Connecting RTL to Physical Pins

The `.qsf` file maps Verilog port names to physical FPGA pin numbers:

```tcl
# This tells Quartus: the port named "led_N_G" in traffic_light_top.v
# connects to physical pin 28 on the EP4CE6E22C8 package
set_location_assignment PIN_28 -to led_N_G
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to led_N_G
```

**IO Standard selection:**
- `3.3-V LVTTL` → output swings 0V to 3.3V → compatible with 3.3V LED drivers
- Must match the VCCIO voltage of the I/O bank the pin belongs to
- Mismatching causes the bank conflict error seen earlier

```
QSF assignment chain:
  Verilog port name
       ↓
  set_location_assignment PIN_XX
       ↓
  Physical FPGA pin
       ↓
  PCB trace
       ↓
  LED / switch / display
```

---

### 8. Complete Module Hierarchy

```
traffic_light_top   (top level — wiring only)
├── clk_div         (timing infrastructure)
├── dip_controller  (input pipeline)
│   └── (internal: sync → debounce → edge → decode)
├── conflict_monitor (safety watchdog)
├── traffic_fsm     (core state machine)
└── seg_direction   (display driver)
```

**Depth:** 2 levels (top → submodules).
All submodules are leaf nodes — none instantiate further submodules.
This keeps the hierarchy simple and easy to simulate individually.

---

### 9. Integration Checklist

Before running synthesis, verify:

- [ ] Every module port is connected (no unconnected ports)
- [ ] No port is driven by two sources simultaneously
- [ ] Input ports are not accidentally left floating
- [ ] Inout pins have proper tristate control
- [ ] All module names in instantiation match file names exactly
- [ ] QSF lists all `.v` files as source
- [ ] No duplicate pin assignments in QSF
- [ ] IO standards match board VCCIO per bank

---

### 10. Summary — Integration Rules

| Rule | Why |
|---|---|
| Top level does no logic | Separation of concerns; easy to swap submodules |
| Name internal wires clearly | Self-documenting, easier debugging |
| Match port names exactly | Synthesis errors are hard to trace |
| Parameters from top level | Reusability; one module, multiple configurations |
| Fan-out with assign | Zero logic cost for distributing signals |
| Tristate needs explicit control | Prevents reading your own output as input |
| QSF = hardware wiring diagram | Maps abstract ports to physical reality |

---

### Exercise for Students

1. Add a new submodule `emergency_handler.v` that takes an `emergency`
   input pin and outputs `force_allred`. Instantiate it in `traffic_light_top.v`
   and connect it to the FSM. What changes are needed in the FSM?

2. Draw the complete signal path from "user sets DIP switch to 1001"
   to "North green LED turns on", listing every module and wire traversed.

3. The QSF currently assigns PIN_100 to `io_mode`. Look up the EP4CE6E22C8
   datasheet and find which I/O bank PIN_100 belongs to. Is its VCCIO
   compatible with 3.3-V LVTTL? What would you do if it is not?