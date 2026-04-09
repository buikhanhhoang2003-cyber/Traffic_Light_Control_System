# Traffic Light Controller — Tutorial
## Part 5: Input Handling — DIP Switch, Debounce & Edge Detection

---

### 1. The Problem with Raw Switch Inputs

A DIP switch seems simple — it's either ON or OFF. But connecting it
directly to FPGA logic causes three distinct problems:

```
Problem 1: METASTABILITY
Problem 2: SWITCH BOUNCE
Problem 3: LEVEL vs EDGE
```

Each requires a different hardware solution. This is why `dip_controller.v`
has four stages rather than a simple wire.

---

### 2. Problem 1: Metastability

The FPGA's internal flip-flops are clocked at 50MHz.
The DIP switch changes state at a random, asynchronous time —
it has no relationship to the clock edge.

```
                 Clock edge
                     │
Switch changes ──────X────► Flip-flop samples HERE
                     │
                 Setup/Hold window
```

If the switch changes inside the flip-flop's **setup/hold window**
(typically ~1ns), the flip-flop output is unpredictable — it may
output 0, 1, or oscillate between both for nanoseconds to microseconds.
This is **metastability**.

**Fix: Two-stage synchronizer**

```verilog
reg [3:0] dip_sync0, dip_sync1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dip_sync0 <= 4'b0;
        dip_sync1 <= 4'b0;
    end else begin
        dip_sync0 <= dip_sw;    // Stage 1: may be metastable
        dip_sync1 <= dip_sync0; // Stage 2: almost certainly resolved
    end
end
```

**Why two stages?**

```
Stage 1 output: might be metastable for up to ~1ns
Stage 2 input:  samples Stage 1 output one full clock cycle later
                By then (20ns at 50MHz), metastability has resolved
                with probability > 99.9999%
```

The probability of metastability persisting through two stages is
astronomically low (< 10^-15 per flip-flop per second for typical FPGAs).

> **Rule:** Any asynchronous signal entering an FPGA clock domain MUST
> pass through a 2-stage synchronizer first.

---

### 3. Problem 2: Switch Bounce

Physical switches do not make clean transitions. When you flick a DIP switch,
the metal contacts physically bounce:

```
Ideal:   ___________╔══════════════════
                    │
Actual:  ___________╔╗╔╗╔═══╗╔╗╔══════
                    bouncing  (5–20ms)
```

Without debounce, the FPGA sees dozens of rapid transitions in ~20ms,
interpreting each as a separate switch toggle.

**Fix: Stability counter**

```verilog
localparam DEBOUNCE_MAX = 1_000_000;  // 20ms @ 50MHz

reg [3:0]  dip_stable;     // last accepted stable value
reg [3:0]  dip_candidate;  // value currently being timed
reg [19:0] deb_cnt;        // stability counter

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dip_stable    <= 4'b0;
        dip_candidate <= 4'b0;
        deb_cnt       <= 0;
    end else begin
        if (dip_sync1 != dip_candidate) begin
            // Input changed (or still bouncing) — restart timer
            dip_candidate <= dip_sync1;
            deb_cnt       <= 0;
        end else if (deb_cnt < DEBOUNCE_MAX) begin
            deb_cnt <= deb_cnt + 1;  // counting stability
        end else begin
            // Stable for 20ms — accept it
            dip_stable <= dip_candidate;
        end
    end
end
```

**Trace through a bouncing switch:**

```
Time:      0    1ms  3ms  5ms  8ms  15ms  25ms
Input:     0    1    0    1    1    1     1
Candidate: 0    1    0    1    1    1     1
Counter:   0    0    0    0  1..  ..max  max
Stable:    0    0    0    0    0    0     1  ← accepted after 20ms stable
```

The bounce at 1ms, 3ms, 5ms resets the counter each time.
Only at 8ms does the input stay stable long enough to be accepted.

---

### 4. Problem 3: Level vs Edge

After debouncing, `dip_stable` is a **level signal** — it holds its
value as long as the switch stays in that position.

If we feed this directly to the FSM as `start_jump`, the FSM would
continuously try to jump on every clock cycle while the switch is set:

```
dip_stable:  0000...1001...1001...1001...0000
start_jump:  ______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___  (stays HIGH!)

Result: FSM jumps, then immediately tries to jump again → chaos
```

**What we want:**

```
dip_stable:  0000...1001...1001...1001...0000
start_jump:  _______|‾|________________________  (single pulse!)

Result: FSM jumps exactly once
```

**Fix: Edge detector**

```verilog
reg [3:0] dip_prev;

// Register the previous stable value
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) dip_prev <= 4'b0;
    else        dip_prev <= dip_stable;
end

// Change detected when current ≠ previous
wire dip_changed = (dip_stable != dip_prev);
```

Then in the decode stage:
```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        start_jump <= 1'b0;
    end else begin
        start_jump <= 1'b0;   // default LOW every cycle

        if (dip_changed && dip_stable != 4'b0000) begin
            start_jump <= 1'b1;  // HIGH for exactly ONE cycle
            // decode jump_state here
        end
    end
end
```

`start_jump` is HIGH for **exactly one clock cycle** (20ns at 50MHz),
which is exactly what the FSM expects.

---

### 5. The Complete 4-Stage Pipeline

```
Raw DIP switch
     │
     ▼
┌─────────────┐
│  Stage 1    │  2-flip-flop synchronizer
│  Sync       │  Fixes: metastability
└──────┬──────┘  Latency: 2 clock cycles (40ns)
       │
       ▼
┌─────────────┐
│  Stage 2    │  Stability counter (20ms)
│  Debounce   │  Fixes: switch bounce
└──────┬──────┘  Latency: 20ms
       │
       ▼
┌─────────────┐
│  Stage 3    │  Compare current vs previous stable value
│  Edge Det.  │  Fixes: level→pulse conversion
└──────┬──────┘  Latency: 1 clock cycle (20ns)
       │
       ▼
┌─────────────┐
│  Stage 4    │  4-bit → jump_state + start_jump
│  Decode     │  Converts encoded value to FSM signals
└──────┬──────┘  Latency: 1 clock cycle (20ns)
       │
       ▼
  To FSM (start_jump pulse + jump_state value)
```

Total latency from switch to FSM: ~20ms (dominated by debounce).
For a human pressing a button, this is completely imperceptible.

---

### 6. The Decode Table

```verilog
case (dip_stable)
    4'd0:  begin jump_state=3'd0; start_jump=0; end  // no request
    4'd1:  begin jump_state=3'd4; start_jump=1; end  // B-West  Ped → S4
    4'd2:  begin jump_state=3'd6; start_jump=1; end  // B-West  Left → S6
    4'd3:  begin jump_state=3'd4; start_jump=1; end  // B-West  Str → S4
    4'd4:  begin jump_state=3'd4; start_jump=1; end  // B-East  Ped → S4
    4'd5:  begin jump_state=3'd6; start_jump=1; end  // B-East  Left → S6
    4'd6:  begin jump_state=3'd4; start_jump=1; end  // B-East  Str → S4
    4'd7:  begin jump_state=3'd0; start_jump=1; end  // A-North Ped → S0
    4'd8:  begin jump_state=3'd2; start_jump=1; end  // A-North Left → S2
    4'd9:  begin jump_state=3'd0; start_jump=1; end  // A-North Str → S0
    4'd10: begin jump_state=3'd0; start_jump=1; end  // A-South Ped → S0
    4'd11: begin jump_state=3'd2; start_jump=1; end  // A-South Left → S2
    4'd12: begin jump_state=3'd0; start_jump=1; end  // A-South Str → S0
endcase
```

Notice that multiple button values map to the same `jump_state`:
- All "Straight" and "Pedestrian" buttons for Axis B → jump_state=4 (B_STRAIGHT)
- All "Left" buttons for Axis B → jump_state=6 (B_LEFT)
- All "Straight" and "Pedestrian" buttons for Axis A → jump_state=0 (A_STRAIGHT)
- All "Left" buttons for Axis A → jump_state=2 (A_LEFT)

This is intentional: whether you press "Straight", "Left" or "Pedestrian"
for a direction, the system gives that direction its *next appropriate green*
based on the FSM's normal sequence.

---

### 7. User Operating Procedure

```
Step 1: Ensure DIP switch is at 0000 (no request)
Step 2: Set DIP switch to desired value (e.g., 1001 = North Straight)
         └─► Edge detected → start_jump pulse fires → FSM receives request
Step 3: FSM finishes current yellow → all-red → jumps to North green
Step 4: Return DIP switch to 0000 to be ready for next request
```

> **Important:** If you set the switch to 1001, then change it to 1001
> again (same value), no new edge is detected — no new jump fires.
> You MUST return to 0000 between requests.

---

### 8. Summary

| Stage | Problem Solved | Technique | Latency |
|-------|---------------|-----------|---------|
| Synchronizer | Metastability | 2 FF chain | 40ns |
| Debounce | Switch bounce | Stability counter | ~20ms |
| Edge detect | Level → pulse | Compare prev/current | 20ns |
| Decode | Binary → FSM signals | Case statement | 20ns |

---

### Exercise for Students

1. Calculate the counter register width needed for a 50ms debounce
   time on a 50MHz clock. Is this better or worse than 20ms for traffic
   light control? What are the tradeoffs?

2. What happens if you skip the synchronizer but keep the debounce?
   Draw a scenario where metastability causes a problem even after debouncing.

3. Modify the edge detector to trigger on the **falling edge** instead
   (when switch returns to 0000). What would this change in system behavior?