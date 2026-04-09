# Traffic Light Controller — Tutorial
## Part 8: Simulation & Testbench

---

### 1. Why Simulate Before Uploading to Hardware?

Uploading to hardware and observing LEDs is a poor debugging method:

```
Problem 1: One full FSM cycle takes 4+3+2+4+3+2+4+3+2+4+3+2 = 36 seconds
           Watching 10 cycles = 6 minutes of waiting per test

Problem 2: You cannot see internal signals (state, sec_cnt, jump_target)
           on hardware — only the output LEDs

Problem 3: You cannot inject a system_fault easily on hardware

Problem 4: If something is wrong, you have no trace of what happened
```

Simulation solves all of these:
- Run 36 seconds of FSM operation in **milliseconds**
- See every internal wire at every clock cycle
- Inject any input at any time
- Replay and zoom into any moment

---

### 2. What Is a Testbench?

A testbench is a Verilog file that:
- **Instantiates** your design under test (DUT)
- **Generates** clock and input stimuli
- **Checks** outputs against expected values
- Is **never synthesized** — simulation only

```
Testbench (tb_traffic_light_top.v)
├── Clock generator (always block)
├── DUT instantiation (traffic_light_top)
├── Stimulus tasks (apply_reset, press_button, etc.)
└── Checker tasks (assert expected outputs)
```

---

### 3. The Critical Trick: Speed Up the Clock

Real timing: `CLK_FREQ = 50_000_000` → 1 tick every 1 real second  
Simulation timing: `CLK_FREQ = 10` → 1 tick every 10 clock cycles

```verilog
// In testbench, override the parameter:
traffic_light_top #(
    // We cannot pass CLK_FREQ directly to top-level,
    // but clk_div accepts it — see section 7 for full approach
) dut (...);
```

This is why `clk_div` is **parameterized**. In simulation, 1 FSM second
= 10 clock cycles instead of 50,000,000 — simulation runs 5,000,000× faster.

---

### 4. Complete Testbench

```verilog
// =============================================================================
// tb_traffic_light_top.v
// Testbench for the complete traffic light controller
// Uses fast clock (CLK_FREQ=10) so 1 FSM second = 10 clock cycles
// =============================================================================
`timescale 1ns/1ps

module tb_traffic_light_top;

    // ── DUT ports ─────────────────────────────────────────────────────────────
    reg         clk;
    reg         rst_n;
    reg         io_mode;
    reg  [3:0]  dip_drive;      // drives dig_dip in input mode
    wire [3:0]  dig_dip;
    wire        led_N_G,  led_N_Y,  led_N_R;
    wire        led_S_G,  led_S_Y,  led_S_R;
    wire        led_E_G,  led_E_Y,  led_E_R;
    wire        led_W_G,  led_W_Y,  led_W_R;
    wire        led_NL_G, led_NL_Y, led_NL_R;
    wire        led_SL_G, led_SL_Y, led_SL_R;
    wire        led_EL_G, led_EL_Y, led_EL_R;
    wire        led_WL_G, led_WL_Y, led_WL_R;
    wire        ped_N, ped_S, ped_E, ped_W;
    wire [7:0]  SVNSEG_SEG;
    wire        system_fault_led;

    // ── Tristate drive ─────────────────────────────────────────────────────────
    // When io_mode=0 (input mode), testbench drives dig_dip
    assign dig_dip = (io_mode == 1'b0) ? dip_drive : 4'bzzzz;

    // ── DUT Instantiation ──────────────────────────────────────────────────────
    // Override CLK_FREQ deep in the hierarchy via defparam (simulation only)
    traffic_light_top dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .io_mode        (io_mode),
        .dig_dip        (dig_dip),
        .led_N_G        (led_N_G),  .led_N_Y (led_N_Y),  .led_N_R (led_N_R),
        .led_S_G        (led_S_G),  .led_S_Y (led_S_Y),  .led_S_R (led_S_R),
        .led_E_G        (led_E_G),  .led_E_Y (led_E_Y),  .led_E_R (led_E_R),
        .led_W_G        (led_W_G),  .led_W_Y (led_W_Y),  .led_W_R (led_W_R),
        .led_NL_G       (led_NL_G), .led_NL_Y(led_NL_Y), .led_NL_R(led_NL_R),
        .led_SL_G       (led_SL_G), .led_SL_Y(led_SL_Y), .led_SL_R(led_SL_R),
        .led_EL_G       (led_EL_G), .led_EL_Y(led_EL_Y), .led_EL_R(led_EL_R),
        .led_WL_G       (led_WL_G), .led_WL_Y(led_WL_Y), .led_WL_R(led_WL_R),
        .ped_N          (ped_N),    .ped_S   (ped_S),
        .ped_E          (ped_E),    .ped_W   (ped_W),
        .SVNSEG_SEG     (SVNSEG_SEG),
        .system_fault_led(system_fault_led)
    );

    // Override CLK_FREQ in clk_div to speed up simulation
    defparam dut.u_clk_div.CLK_FREQ = 10;
    // Override debounce to 3 cycles (instead of 1,000,000)
    defparam dut.u_dip.DEBOUNCE_MAX = 3;

    // ── Clock Generator ────────────────────────────────────────────────────────
    // 10ns period = 100MHz (faster than real, but scaled with CLK_FREQ=10)
    initial clk = 0;
    always #5 clk = ~clk;   // toggle every 5ns → 10ns period

    // ── Helper Tasks ──────────────────────────────────────────────────────────

    // Wait for N clock cycles
    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    // Wait for N FSM seconds (each = CLK_FREQ cycles)
    task wait_seconds;
        input integer n;
        begin
            wait_cycles(n * 10);  // 10 cycles per second (CLK_FREQ=10)
        end
    endtask

    // Apply reset
    task apply_reset;
        begin
            rst_n = 0;
            wait_cycles(5);
            rst_n = 1;
            $display("[%0t] Reset released", $time);
        end
    endtask

    // Simulate DIP switch press (input mode)
    task press_dip;
        input [3:0] val;
        begin
            io_mode  = 0;       // switch to input mode
            dip_drive = val;    // set DIP value
            $display("[%0t] DIP switch set to %04b (value=%0d)", $time, val, val);
            wait_cycles(20);    // hold long enough for debounce (3 cycles + margin)
            dip_drive = 4'b0000; // return to 0000
            wait_cycles(10);
            io_mode  = 1;       // return to output mode
        end
    endtask

    // Check a single LED signal
    task check_led;
        input       actual;
        input       expected;
        input [63:0] name;
        begin
            if (actual !== expected) begin
                $display("FAIL [%0t] %s = %b, expected %b", $time, name, actual, expected);
                $finish;
            end else
                $display("PASS [%0t] %s = %b", $time, name, actual);
        end
    endtask

    // ── Main Test Sequence ────────────────────────────────────────────────────
    initial begin
        // Initialise
        rst_n    = 0;
        io_mode  = 1;       // default: 7-seg output mode
        dip_drive = 4'b0000;

        // ── TEST 1: Reset behaviour ───────────────────────────────────────────
        $display("\n=== TEST 1: Reset ===");
        apply_reset;
        wait_cycles(2);
        // After reset, FSM should be in FAIL_SAFE (all red)
        check_led(led_N_R, 1, "led_N_R after reset");
        check_led(led_N_G, 0, "led_N_G after reset");
        check_led(led_E_R, 1, "led_E_R after reset");

        // ── TEST 2: Normal cycle — A_STRAIGHT ────────────────────────────────
        $display("\n=== TEST 2: A_STRAIGHT phase ===");
        // FAIL_SAFE lasts 1 second, then → A_STRAIGHT
        wait_seconds(2);
        check_led(led_N_G,  1, "led_N_G  in A_STRAIGHT");
        check_led(led_N_R,  0, "led_N_R  in A_STRAIGHT");
        check_led(led_NL_R, 1, "led_NL_R in A_STRAIGHT (left should be red)");
        check_led(ped_N,    1, "ped_N    in A_STRAIGHT");
        check_led(led_E_R,  1, "led_E_R  in A_STRAIGHT (B axis should be red)");
        check_led(ped_E,    0, "ped_E    in A_STRAIGHT (B ped should be off)");

        // ── TEST 3: Transition to A_S_YELLOW ─────────────────────────────────
        $display("\n=== TEST 3: A_S_YELLOW transition ===");
        // A_STRAIGHT lasts 4 seconds
        wait_seconds(4);
        check_led(led_N_Y,  1, "led_N_Y  in A_S_YELLOW");
        check_led(led_N_G,  0, "led_N_G  in A_S_YELLOW");
        check_led(led_N_R,  0, "led_N_R  in A_S_YELLOW");
        check_led(ped_N,    0, "ped_N    in A_S_YELLOW (ped off)");

        // ── TEST 4: ALL_RED buffer ────────────────────────────────────────────
        $display("\n=== TEST 4: ALL_RED_1 buffer ===");
        wait_seconds(3);    // yellow lasts 3 seconds
        check_led(led_N_R,  1, "led_N_R  in ALLRED_1");
        check_led(led_N_G,  0, "led_N_G  in ALLRED_1");
        check_led(led_N_Y,  0, "led_N_Y  in ALLRED_1");
        check_led(led_E_R,  1, "led_E_R  in ALLRED_1");

        // ── TEST 5: A_LEFT phase ──────────────────────────────────────────────
        $display("\n=== TEST 5: A_LEFT phase ===");
        wait_seconds(2);    // all-red lasts 2 seconds
        check_led(led_NL_G, 1, "led_NL_G in A_LEFT");
        check_led(led_NL_R, 0, "led_NL_R in A_LEFT");
        check_led(led_N_G,  0, "led_N_G  in A_LEFT (straight should be red)");
        check_led(led_N_R,  1, "led_N_R  in A_LEFT");
        check_led(ped_N,    0, "ped_N    in A_LEFT (no ped during left)");

        // ── TEST 6: Jump to B_STRAIGHT via DIP switch ─────────────────────────
        $display("\n=== TEST 6: DIP switch jump to B_STRAIGHT ===");
        // Currently in A_LEFT. Press DIP=0110 (B-East Straight → jump_state=4)
        wait_seconds(1);    // wait 1 second into A_LEFT
        press_dip(4'b0110); // request B_STRAIGHT

        // After yellow + all-red, should be in B_STRAIGHT
        // yellow = 3s, all-red = 2s = 5 seconds total
        wait_seconds(6);
        check_led(led_E_G,  1, "led_E_G  after jump to B_STRAIGHT");
        check_led(led_E_R,  0, "led_E_R  after jump to B_STRAIGHT");
        check_led(ped_E,    1, "ped_E    after jump to B_STRAIGHT");
        check_led(led_N_R,  1, "led_N_R  after jump (A should be red)");

        // ── TEST 7: No jump when already in target state ──────────────────────
        $display("\n=== TEST 7: No jump when target == current ===");
        // Still in B_STRAIGHT. Press DIP=0110 (also maps to B_STRAIGHT)
        press_dip(4'b0110);
        wait_seconds(2);
        // Should still be in B_STRAIGHT (not interrupted)
        check_led(led_E_G,  1, "led_E_G  still active (no jump taken)");

        // ── TEST 8: Fault detection ───────────────────────────────────────────
        $display("\n=== TEST 8: Fault state ===");
        // The conflict_monitor is purely combinational — we cannot inject
        // a real conflict without breaking the FSM. Instead, verify that
        // after a real conflict signal, system_fault_led goes HIGH.
        // In simulation, use force/release (ModelSim/Questa only):
        // force dut.u_monitor.a_str_green = 1;
        // force dut.u_monitor.b_str_green = 1;
        // wait_cycles(2);
        // check_led(system_fault_led, 1, "system_fault_led on conflict");
        // release dut.u_monitor.a_str_green;
        // release dut.u_monitor.b_str_green;
        $display("  (Fault injection requires force/release — use waveform viewer)");

        // ── ALL TESTS PASSED ──────────────────────────────────────────────────
        $display("\n=== ALL TESTS PASSED ===");
        $finish;
    end

    // ── Waveform Dump ─────────────────────────────────────────────────────────
    initial begin
        $dumpfile("tb_traffic_light_top.vcd");
        $dumpvars(0, tb_traffic_light_top);
    end

    // ── Timeout watchdog ──────────────────────────────────────────────────────
    initial begin
        #1_000_000;
        $display("TIMEOUT — simulation exceeded time limit");
        $finish;
    end

endmodule
```

---

### 5. Understanding `defparam`

```verilog
defparam dut.u_clk_div.CLK_FREQ = 10;
defparam dut.u_dip.DEBOUNCE_MAX = 3;
```

`defparam` overrides a module's parameter from **outside** the instantiation.
The path `dut.u_clk_div.CLK_FREQ` means:
- `dut` = top-level DUT instance
- `u_clk_div` = the clk_div instance inside it
- `CLK_FREQ` = the parameter to override

> **Important:** `defparam` is simulation-only. Never use it in synthesizable
> RTL. For synthesis, always use `#(.PARAM(value))` in the instantiation.

---

### 6. Running the Simulation

**Option A: ModelSim / Questa (recommended)**

```bash
# Compile all files
vlog clk_div.v conflict_monitor.v dip_controller.v \
     traffic_fsm.v seg_direction.v traffic_light_top.v \
     tb_traffic_light_top.v

# Run simulation
vsim -c tb_traffic_light_top -do "run -all; quit"

# Open waveform viewer
vsim tb_traffic_light_top
add wave -r /*
run -all
```

**Option B: Icarus Verilog (free, command line)**

```bash
# Compile
iverilog -o sim.out clk_div.v conflict_monitor.v dip_controller.v \
         traffic_fsm.v seg_direction.v traffic_light_top.v \
         tb_traffic_light_top.v

# Run
vvp sim.out

# View waveform (requires GTKWave)
gtkwave tb_traffic_light_top.vcd
```

**Option C: Quartus Built-in Simulator**

```
1. Assignments → Settings → EDA Tool Settings → Simulation
2. Set Tool Name: ModelSim-Altera
3. Add testbench file to project
4. Processing → Start Simulation
```

---

### 7. What to Look for in the Waveform

Open the `.vcd` file in GTKWave or ModelSim and add these signals:

```
Group: FSM internals
  dut.u_fsm.state        ← FSM state (show as decimal or symbolic)
  dut.u_fsm.sec_cnt      ← phase timer counter
  dut.u_fsm.dur          ← current phase duration
  dut.u_fsm.jump_target  ← latched jump destination

Group: Axis A outputs
  led_N_G, led_N_Y, led_N_R
  led_NL_G, led_NL_Y, led_NL_R
  ped_N

Group: Axis B outputs
  led_E_G, led_E_Y, led_E_R
  led_EL_G, led_EL_Y, led_EL_R
  ped_E

Group: Jump mechanism
  dut.u_dip.dip_stable
  dut.u_dip.dip_changed
  dut.u_fsm.start_jump
  dut.u_fsm.jump_state
  dut.u_fsm.in_green
  dut.u_fsm.jump_needed

Group: Safety
  dut.u_monitor.system_fault
  dut.u_fsm.fault_lat
  system_fault_led
```

**Normal cycle should look like:**

```
state:   FAIL_SAFE|A_STRAIGHT────────|A_S_YELLOW───|ALLRED_1|A_LEFT──────...
sec_cnt: 0        |0 1 2 3           |0 1 2        |0 1     |0 1 2 3
led_N_G: 0        |1 1 1 1           |0 0 0        |0 0     |0 0 0 0
led_N_Y: 0        |0 0 0 0           |1 1 1        |0 0     |0 0 0 0
led_N_R: 1        |0 0 0 0           |0 0 0        |1 1     |1 1 1 1
led_NL_R:1        |1 1 1 1           |1 1 1        |1 1     |0 0 0 0
led_NL_G:0        |0 0 0 0           |0 0 0        |0 0     |1 1 1 1
ped_N:   0        |1 1 1 1           |0 0 0        |0 0     |0 0 0 0
```

---

### 8. Common Simulation Issues

| Symptom | Likely Cause | Fix |
|---|---|---|
| All outputs stuck at X (unknown) | Reset not applied | Check `apply_reset` task runs first |
| FSM never advances | `defparam CLK_FREQ` not applied | Verify defparam path is correct |
| Jump never fires | Debounce too slow | Check `defparam DEBOUNCE_MAX = 3` |
| `dip_stable` never changes | Synchronizer adds 2-cycle delay | Add `wait_cycles(10)` after setting dip |
| Waveform all Z | Inout not driven correctly | Check testbench tristate assign |
| Timeout | CLK_FREQ not overridden | Simulation running at real speed |

---

### 9. Unit Testing Individual Modules

Before testing the full design, test each module in isolation:

```verilog
// tb_clk_div.v — verify tick_1hz fires every CLK_FREQ cycles
module tb_clk_div;
    reg clk, rst_n;
    wire tick_1hz, tick_2hz;

    clk_div #(.CLK_FREQ(10)) dut (
        .clk(clk), .rst_n(rst_n),
        .tick_1hz(tick_1hz), .tick_2hz(tick_2hz)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0; #20; rst_n = 1;
        // Expect tick_1hz HIGH at cycle 10, 20, 30...
        repeat(30) @(posedge clk);
        $finish;
    end
endmodule
```

**Test each module separately:**

| Module | What to verify |
|---|---|
| `clk_div` | tick_1hz fires every CLK_FREQ cycles exactly |
| `conflict_monitor` | All 6 conflict combinations trigger system_fault |
| `dip_controller` | Debounce filters glitches; edge detected exactly once |
| `traffic_fsm` | State sequence, timing, jump mechanism, fault latch |
| `seg_direction` | Correct digit rotates at 1kHz; correct segments per value |

---

### 10. Summary

| Concept | Key Point |
|---|---|
| Why simulate | Faster than hardware, full signal visibility, repeatable |
| Speed up trick | `defparam CLK_FREQ = 10` makes 1s = 10 cycles |
| Testbench structure | Clock gen + tasks + stimulus + checker |
| `defparam` | Simulation-only parameter override via hierarchy path |
| What to check | State sequence, transition timing, jump, fault |
| Unit test first | Test each module alone before full integration |

---

### Exercise for Students

1. Write `tb_conflict_monitor.v` that exhaustively tests all 64 combinations
   of the 6 input signals and verifies that `system_fault` is HIGH for exactly
   the conflicting combinations defined in the design.

2. The testbench uses `wait_seconds(6)` after pressing the DIP switch to
   wait for the jump to complete. Calculate exactly how many seconds it should
   take: yellow duration + all-red duration. Does `wait_seconds(6)` match?

3. Modify the testbench to print a **pass/fail summary** at the end showing
   how many tests passed and how many failed, instead of calling `$finish`
   on the first failure.