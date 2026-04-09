# Traffic Light Controller — Tutorial
## Part 4: Safety & Conflict Detection

---

### 1. Why Safety Logic Exists Separately

You might ask: if the FSM is designed correctly, why do we need a separate
conflict monitor? The FSM should never produce conflicting signals.

The answer is **defense in depth**:

```
Threat model:
  - FSM bug (design error)
  - Synthesis tool error
  - Bit-flip from radiation or noise (SEU in FPGA fabric)
  - Wiring mistake during integration
  - Any of the above causes wrong state → two conflicting greens
```

A traffic light failure is a **life-safety issue**. The conflict monitor
is a second, independent layer that watches the actual output wires —
not the FSM state. It doesn't trust the FSM. This is called a **watchdog**.

> **Design Principle:** For safety-critical systems, never rely on a single
> point of protection. The conflict monitor and the FSM are designed
> independently, so a bug in one cannot disable the other.

---

### 2. Identify All Conflict Pairs

Two signals conflict if they would allow vehicles/pedestrians from
**crossing paths** simultaneously.

Draw the intersection and trace every possible conflict:

```
         Axis A (N/S)
         Straight ↕
         Left ↙↗
              ╔═══╗
Axis B ←Left══╬   ╬══Left→ Axis B
  (E/W)       ║   ║        (E/W)
 Straight←════╬   ╬════→Straight
              ╚═══╝
         Left ↙↗
         Straight ↕
```

**Rule 1: A straight vs B straight**
```
A cars go N↔S, B cars go E↔W → head-on crossing → CONFLICT
assign conflict_str = a_str_green & b_str_green;
```

**Rule 2: A left vs B straight**
```
A turns left (→ East), B goes straight (← West) → oncoming → CONFLICT
assign conflict_a_left_b_str = a_left_green & b_str_green;
```

**Rule 3: B left vs A straight**
```
Mirror of Rule 2 → CONFLICT
assign conflict_b_left_a_str = b_left_green & a_str_green;
```

**Rule 4: Both left turns**
```
A turns left (→ East), B turns left (→ North) → crossing paths → CONFLICT
assign conflict_both_left = a_left_green & b_left_green;
```

**Rule 5: A straight vs B left**
```
Mirror of Rule 2/3, different direction combination → CONFLICT
assign conflict_a_str_b_left = a_str_green & b_left_green;
```

**Rule 6: Pedestrian vs opposing green**
```
Pedestrian crosses the road → any vehicle going THROUGH that crossing = CONFLICT
assign conflict_ped =
    (a_ped_walk & b_str_green)  |  // B cars drive through A pedestrian crossing
    (a_ped_walk & b_left_green) |  // B left turn drives through A ped crossing
    (b_ped_walk & a_str_green)  |  // A cars drive through B pedestrian crossing
    (b_ped_walk & a_left_green);   // A left turn drives through B ped crossing
```

---

### 3. The Complete Monitor

```verilog
module conflict_monitor (
    input  wire a_str_green, a_left_green, a_ped_walk,
    input  wire b_str_green, b_left_green, b_ped_walk,
    output wire system_fault
);
    wire c1 = a_str_green  & b_str_green;           // Rule 1
    wire c2 = a_left_green & b_str_green;            // Rule 2
    wire c3 = b_left_green & a_str_green;            // Rule 3
    wire c4 = a_left_green & b_left_green;           // Rule 4
    wire c5 = a_str_green  & b_left_green;           // Rule 5
    wire c6 = (a_ped_walk & b_str_green)  |          // Rule 6
              (a_ped_walk & b_left_green) |
              (b_ped_walk & a_str_green)  |
              (b_ped_walk & a_left_green);

    assign system_fault = c1 | c2 | c3 | c4 | c5 | c6;
endmodule
```

This is **pure combinational logic** — no clock, no state, no latches.
The output updates within nanoseconds of any input change.

---

### 4. What Is NOT a Conflict

Students often wonder: why isn't A_straight + A_left a conflict?

```
A_straight: N/S cars go straight (↕)
A_left:     N/S cars turn left  (↙↗)

Both are on Axis A — they are in the SAME direction group.
They never run simultaneously (FSM ensures this), but even if they did,
North-going straight and North-turning-left cars don't cross each other.
The left-turn car yields to oncoming straight traffic from the opposite end,
but that is managed by the protected left turn phase, not by this monitor.
```

The monitor only cares about **cross-axis** conflicts.

---

### 5. Fault Response: The Sticky Latch

When `system_fault` goes HIGH, the FSM must enter BLINK_RED and **stay there**:

```verilog
reg fault_lat;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)            fault_lat <= 1'b0;
    else if (system_fault) fault_lat <= 1'b1;
    // No else clause — value is held (sticky)
end
```

And in the FSM:
```verilog
else if (fault_lat) begin
    state   <= BLINK_RED;
    sec_cnt <= 4'd0;
end
```

**Why sticky?**

```
Timeline without sticky latch:
  t=0ms:  SEU causes wrong state → two greens → system_fault=1
  t=1ms:  SEU clears → system_fault=0 → FSM recovers to normal
  Result: Brief conflict, then normal operation — DANGEROUS, undetectable

Timeline with sticky latch:
  t=0ms:  system_fault=1 → fault_lat=1
  t=1ms:  system_fault=0 → fault_lat stays 1
  Result: System stays in BLINK_RED until operator physically resets
          → Requires human inspection before resuming → SAFE
```

---

### 6. All-Red Buffer — Safety Timing

Between every phase transition, there is an all-red period:

```
A_S_YELLOW (3s) → ALLRED_1 (2s) → A_LEFT
```

**What happens during ALLRED_1?**

The FSM output logic for all ALLRED states is simply the default:
```verilog
ALLRED_1, ALLRED_2, ALLRED_3, ALLRED_4, ALLRED_J: begin
    // No overrides — all signals stay at default (all red)
end
```

**Why 2 seconds?**

```
Scenario: Light turns yellow at T=0
  T=0s: Yellow starts
  T=3s: Yellow ends, all-red starts
  T=3s–T=5s: Vehicles that entered on late yellow clear the intersection
  T=5s: New green phase starts safely
```

The 2-second all-red buffer is standard in real traffic engineering.
It accounts for intersection size and vehicle speed.

---

### 7. Verify the Logic — Truth Table

Check every normal FSM state against the conflict rules:

| State | a_str | a_left | a_ped | b_str | b_left | b_ped | Any conflict? |
|-------|-------|--------|-------|-------|--------|-------|---------------|
| A_STRAIGHT | 1 | 0 | 1 | 0 | 0 | 0 | c1=0,c2=0,c3=0,c4=0,c5=0,c6=0 → **No** |
| A_LEFT | 0 | 1 | 0 | 0 | 0 | 0 | All zero → **No** |
| B_STRAIGHT | 0 | 0 | 0 | 1 | 0 | 1 | All zero → **No** |
| B_LEFT | 0 | 0 | 0 | 0 | 1 | 0 | All zero → **No** |
| ALLRED | 0 | 0 | 0 | 0 | 0 | 0 | All zero → **No** |

Every valid FSM state produces zero conflicts. The monitor only fires
if the FSM reaches an **invalid state** — which should never happen,
but now we are safe if it does.

---

### 8. Summary

| Concept | Key Point |
|---|---|
| Why a separate monitor | Defense in depth — don't trust the FSM alone |
| Purely combinational | Responds in nanoseconds, no clock latency |
| 6 conflict rules | All cross-axis green combinations + pedestrian |
| Sticky fault latch | One-way trip to BLINK_RED; requires human reset |
| All-red buffer | 2s clearance between phase transitions |
| Verify with truth table | Confirm no valid FSM state triggers a conflict |

---

### Exercise for Students

1. The system currently has no conflict between A_straight and A_left
   because the FSM never activates them together. What would you add to
   the conflict monitor if you wanted to make this an explicit hardware rule?

2. What is the minimum all-red buffer time for an intersection where the
   crossing distance is 20 meters and the speed limit is 50 km/h?
   (Hint: time = distance / speed)

3. Remove the sticky fault latch and replace it with a 5-second recovery:
   after 5 seconds in BLINK_RED, automatically return to FAIL_SAFE.
   Is this safer or less safe than the sticky approach? Justify your answer.