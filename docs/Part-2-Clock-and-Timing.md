# Traffic Light Controller — Tutorial
## Part 2: Clock & Timing Design

---

### 1. The Problem: FPGA Clock vs Human Time

Your FPGA runs at **50,000,000 cycles per second (50 MHz)**.  
A traffic light phase lasts **4 seconds**.

These two worlds need to be connected. You cannot simply write:
```verilog
// WRONG — this makes no sense in hardware
wait(4_seconds);
next_state <= A_S_YELLOW;
```

Hardware has no concept of "wait." Everything is driven by the clock edge.  
The solution is a **counter** — count clock cycles until you reach the target, then act.

---

### 2. Core Concept: The Tick Pulse

Instead of giving the FSM a raw 50MHz clock, we generate a **tick** signal:
- A tick is a single clock cycle pulse (HIGH for exactly 1 cycle, then LOW)
- The FSM only advances when it sees a tick

```
clk:      __|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_...
tick_1hz: ___________________________________|‾|______________...
                      (50,000,000 cycles)
```

> **Key insight:** The FSM runs on the 50MHz clock but only *acts* on `tick_1hz`.
> This separates timing concerns from state logic cleanly.

---

### 3. How to Count: Down to 1Hz

**Target:** 1 pulse every 1 second  
**Clock:** 50,000,000 cycles per second  
**Required count:** 50,000,000 cycles

```
tick_1hz fires when: counter == 50_000_000 - 1
                                 ↑
                          why -1 ?
```

Because the counter starts at **0**, not 1.  
Counting 0 → 49,999,999 = exactly 50,000,000 steps = 1 second.

```verilog
// Counter size calculation:
// We need to count up to 49,999,999
// 2^25 = 33,554,432  ← too small
// 2^26 = 67,108,864  ← fits!
// Therefore: reg [25:0] cnt_1hz;

reg [25:0] cnt_1hz;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt_1hz  <= 0;
        tick_1hz <= 0;
    end else begin
        if (cnt_1hz == 50_000_000 - 1) begin
            cnt_1hz  <= 0;       // reset counter
            tick_1hz <= 1;       // fire the tick for ONE cycle
        end else begin
            cnt_1hz  <= cnt_1hz + 1;
            tick_1hz <= 0;       // tick is LOW all other cycles
        end
    end
end
```

**Trace through the behavior:**

| Cycle | cnt_1hz | tick_1hz |
|-------|---------|----------|
| 0 | 0 | 0 |
| 1 | 1 | 0 |
| ... | ... | 0 |
| 49,999,999 | 49,999,998 | 0 |
| 50,000,000 | 0 (reset!) | **1** ← tick fires |
| 50,000,001 | 1 | 0 |

---

### 4. How to Count: Down to 2Hz

**Target:** 2 pulses per second = 1 pulse every 0.5 seconds  
**Required count:** 50,000,000 / 2 = **25,000,000 cycles**

```verilog
// 2^24 = 16,777,216  ← too small
// 2^25 = 33,554,432  ← fits 25,000,000
// Therefore: reg [24:0] cnt_2hz;

reg [24:0] cnt_2hz;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt_2hz  <= 0;
        tick_2hz <= 0;
    end else begin
        if (cnt_2hz == (50_000_000/2) - 1) begin
            cnt_2hz  <= 0;
            tick_2hz <= 1;
        end else begin
            cnt_2hz  <= cnt_2hz + 1;
            tick_2hz <= 0;
        end
    end
end
```

> **Why 2Hz?** The fault state blinks all red lights at 2Hz.
> At 2Hz, each blink cycle is 500ms ON + 500ms OFF — clearly visible to drivers.
> Too fast (>5Hz) looks like flickering. Too slow (<1Hz) looks like a stuck light.

---

### 5. How the FSM Uses the Tick

The FSM has its own **phase counter** (`sec_cnt`) that counts *seconds*, not clock cycles.  
It only increments when `tick_1hz` fires:

```verilog
reg [3:0] sec_cnt;   // counts 0..15 seconds

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sec_cnt <= 0;
    end
    else if (tick_1hz) begin          // only act once per second
        if (sec_cnt + 1 >= dur) begin // dur = phase duration in seconds
            sec_cnt <= 0;             // phase complete, reset
            state   <= next_state;    // advance FSM
        end else begin
            sec_cnt <= sec_cnt + 1;   // still counting
        end
    end
end
```

**Two-level timing hierarchy:**

```
Level 1 — clk_div:
  50MHz clock → count 50,000,000 cycles → tick_1hz pulse

Level 2 — FSM timer:
  tick_1hz pulse → count N ticks → phase transition
  (N = phase duration in seconds, e.g. N=4 for green phase)
```

This is a classic **hierarchical counter** pattern in digital design.

---

### 6. How to Calculate Register Width

A common mistake is using the wrong register size. Here is the formula:

```
Required bits = ceil(log2(MAX_COUNT + 1))
```

| Target frequency | Count needed | Exact bits needed | Register used |
|---|---|---|---|
| 1 Hz | 50,000,000 | 25.58 bits | `[25:0]` = 26 bits |
| 2 Hz | 25,000,000 | 24.58 bits | `[24:0]` = 25 bits |
| 1 kHz (7-seg) | 50,000 | 15.61 bits | `[31:0]` = 32 bits* |
| Phase timer | 0–15 seconds | 4 bits | `[3:0]` = 4 bits |

*The 7-seg counter uses 32 bits to avoid the truncation warning seen in compilation.

> **Common mistake:** Using `reg [15:0]` for a count of 50,000 (needs 16 bits = fits),
> but `localparam MUX_MAX = 50_000 - 1` is 32 bits by default in Verilog.
> Comparing a 16-bit reg to a 32-bit constant triggers a truncation warning.
> **Fix:** Use `reg [31:0]` or explicitly cast: `16'd(MUX_MAX)`.

---

### 7. The Parameterized Design

Instead of hardcoding `50_000_000`, the clock divider uses a parameter:

```verilog
module clk_div #(
    parameter CLK_FREQ = 50_000_000   // default: 50MHz
)(
    ...
);
```

**Why this matters for students:**

```verilog
// In simulation, use a fast clock to avoid waiting 1 real second:
clk_div #(.CLK_FREQ(10)) u_clk_div_sim (...);
// Now tick_1hz fires every 10 clock cycles — simulation runs 5,000,000x faster!

// On real hardware, use the actual clock:
clk_div #(.CLK_FREQ(50_000_000)) u_clk_div_hw (...);
```

This is called **parameterized design** and is essential for testability.

---

### 8. The Blink Toggle Pattern

The 2Hz tick is used differently from the 1Hz tick.  
Instead of counting seconds, it **toggles a register** to create a blink:

```verilog
reg blink;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)        blink <= 1'b0;
    else if (tick_2hz) blink <= ~blink;  // flip every 0.5 seconds
end
```

**Resulting waveform:**

```
tick_2hz: ___|‾|___________|‾|___________|‾|___________
blink:    ______|‾‾‾‾‾‾‾‾‾‾‾‾‾|___________|‾‾‾‾‾‾‾‾‾‾‾
          ← 0.5s →← 0.5s →← 0.5s →← 0.5s →
```

Then in the FSM output logic:
```verilog
BLINK_RED: begin
    a_str_red  = blink;   // ON for 0.5s, OFF for 0.5s
    a_left_red = blink;
    b_str_red  = blink;
    b_left_red = blink;
end
```

> **Design pattern:** Use a tick to *toggle* a register when you need a periodic
> signal. This is cleaner than running a separate counter inside the FSM.

---

### 9. Complete clk_div Module — Annotated

```verilog
module clk_div #(
    parameter CLK_FREQ = 50_000_000    // (1) parameterized for reuse
)(
    input  wire clk,
    input  wire rst_n,
    output reg  tick_1hz,
    output reg  tick_2hz
);
    // (2) Counter width: ceil(log2(50_000_000)) = 26 bits
    reg [25:0] cnt_1hz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_1hz  <= 0;
            tick_1hz <= 0;              // (3) reset tick to avoid stale pulse
        end else begin
            if (cnt_1hz == CLK_FREQ - 1) begin
                cnt_1hz  <= 0;          // (4) wrap counter
                tick_1hz <= 1;          // (5) single-cycle pulse
            end else begin
                cnt_1hz  <= cnt_1hz + 1;
                tick_1hz <= 0;          // (6) LOW all other cycles
            end
        end
    end

    // (7) Identical structure, half the count for 2Hz
    reg [24:0] cnt_2hz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_2hz  <= 0;
            tick_2hz <= 0;
        end else begin
            if (cnt_2hz == (CLK_FREQ/2) - 1) begin
                cnt_2hz  <= 0;
                tick_2hz <= 1;
            end else begin
                cnt_2hz  <= cnt_2hz + 1;
                tick_2hz <= 0;
            end
        end
    end

endmodule
```

---

### 10. Summary — Key Takeaways

| Concept | Rule |
|---|---|
| You cannot "wait" in hardware | Use a counter to measure time |
| Tick pulse | Single-cycle HIGH pulse — triggers actions without holding state |
| Counter width | `ceil(log2(N))` bits to count N cycles |
| Hierarchical counters | clk_div counts cycles; FSM timer counts ticks |
| Parameterization | Always parameterize clock frequency for simulation speed |
| Blink pattern | Toggle a register on each tick — never count inside FSM for this |

---

### Exercise for Students

1. Calculate the counter width needed for a **10Hz** tick from 50MHz.
2. Modify `clk_div.v` to also output a **`tick_500ms`** (same as tick_1hz but fires twice: at 0.25s and 0.75s of each second).
3. What happens if you forget to reset `tick_1hz <= 0` in the else branch? Draw the resulting waveform.

---

### Next Part

**Part 3: FSM Design** — How to translate the state table from the requirements
into actual Verilog: state encoding, duration lookup, transition logic, and
output logic — and why we separate them into two always blocks.