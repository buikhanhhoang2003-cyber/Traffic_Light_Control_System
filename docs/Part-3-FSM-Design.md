# Traffic Light Controller — Tutorial
## Part 3: FSM Design

---

### 1. What Is a Finite State Machine?

An FSM is a system that:
- Exists in exactly **one state** at any time
- **Transitions** between states based on inputs and current state
- Produces **outputs** based on current state (Moore machine) or state + inputs (Mealy)

This project uses a **Moore FSM** — outputs depend only on the current state,
not on inputs. This is safer for traffic lights because outputs are predictable
and don't glitch when inputs change.

```
Moore FSM structure:
                    ┌─────────────────┐
    inputs ────────►│  Next-State     │
    current state ─►│  Logic (comb.)  ├──► next_state
                    └─────────────────┘
                             │
                    ┌────────▼────────┐
                    │  State Register │  (clocked)
                    │  (sequential)   ├──► current_state
                    └─────────────────┘
                             │
                    ┌────────▼────────┐
                    │  Output Logic   │
                    │  (combinational)├──► LED signals
                    └─────────────────┘
```

---

### 2. State Encoding

In SystemVerilog you can use `typedef enum`. In Verilog, use `localparam`:

```verilog
localparam [4:0]
    FAIL_SAFE  = 5'd0,   // safe default on reset
    A_STRAIGHT = 5'd1,   // S0
    A_S_YELLOW = 5'd2,   // S1
    ALLRED_1   = 5'd3,
    A_LEFT     = 5'd4,   // S2
    A_L_YELLOW = 5'd5,   // S3
    ALLRED_2   = 5'd6,
    B_STRAIGHT = 5'd7,   // S4
    B_S_YELLOW = 5'd8,   // S5
    ALLRED_3   = 5'd9,
    B_LEFT     = 5'd10,  // S6
    B_L_YELLOW = 5'd11,  // S7
    ALLRED_4   = 5'd12,
    IDLE_JUMP  = 5'd13,  // S8
    ALLRED_J   = 5'd14,
    BLINK_RED  = 5'd15;  // fault

reg [4:0] state;
```

**Why 5 bits?** We have 16 states (0–15), so 2^4 = 16 fits exactly in 4 bits.
We use 5 bits for safety margin — if synthesis adds a state, it won't overflow.

> **Rule:** Always use named constants for states. Never write `if (state == 5'd7)`.
> `if (state == B_STRAIGHT)` is readable; `5'd7` is a maintenance nightmare.

---

### 3. Separate Sequential and Combinational Logic

This is the **most important rule** in FSM design:

```
Rule: Always write FSMs with TWO always blocks:
  Block 1 — Sequential:   state register (always @posedge clk)
  Block 2 — Combinational: output logic  (always @*)
```

**Why?**

```verilog
// BAD: mixing sequential and combinational in one block
always @(posedge clk) begin
    case (state)
        A_STRAIGHT: begin
            a_str_green <= 1;   // registered output — 1 cycle delay!
            state <= A_S_YELLOW;
        end
    endcase
end

// GOOD: separate blocks
// Block 1: only handles state transitions
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= FAIL_SAFE;
    else if (tick_1hz) begin
        // transition logic only
    end
end

// Block 2: outputs are purely combinational (zero delay)
always @(*) begin
    case (state)
        A_STRAIGHT: begin
            a_str_green = 1; a_str_red = 0;
        end
    endcase
end
```

Registered outputs (`<=` in clocked block) add **1 clock cycle of latency**.
For a traffic light that is harmless, but for safety signals it can cause a
brief wrong-color glitch during state transitions.

---

### 4. Duration Lookup — Avoid Hardcoding

Each state has a different duration. Instead of scattering magic numbers
throughout the code, use a dedicated lookup:

```verilog
// Parameters define all timing in one place (easy to modify)
parameter A_STR_TIME  = 4;   // seconds
parameter ALLRED_TIME = 2;
...

// Duration lookup — pure combinational
reg [3:0] dur;
always @(*) begin
    case (state)
        A_STRAIGHT : dur = A_STR_TIME  [3:0];
        A_S_YELLOW : dur = A_SYEL_TIME [3:0];
        ALLRED_1   : dur = ALLRED_TIME  [3:0];
        ...
        default    : dur = 4'd1;
    endcase
end
```

Then the phase timer uses `dur` directly:
```verilog
if (sec_cnt + 1 >= dur) begin
    sec_cnt <= 0;
    // transition to next state
end
```

> **Benefit:** To change the green phase from 4s to 8s, you only change
> `A_STR_TIME = 8` in one place. Nothing else changes.

---

### 5. The Phase Timer

```verilog
reg [3:0] sec_cnt;  // counts 0 to 15 seconds

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state   <= FAIL_SAFE;
        sec_cnt <= 4'd0;
    end
    else if (fault_lat) begin
        state   <= BLINK_RED;   // fault overrides everything
        sec_cnt <= 4'd0;
    end
    else if (tick_1hz) begin
        if (sec_cnt + 1 >= dur) begin
            sec_cnt <= 4'd0;    // phase complete
            case (state)        // advance to next state
                A_STRAIGHT : state <= A_S_YELLOW;
                A_S_YELLOW : state <= ALLRED_1;
                ALLRED_1   : state <= A_LEFT;
                ...
            endcase
        end else begin
            sec_cnt <= sec_cnt + 1;  // still counting
        end
    end
end
```

**Trace for A_STRAIGHT (dur = 4):**

| tick # | sec_cnt before | sec_cnt+1 >= 4? | action |
|--------|---------------|-----------------|--------|
| 1 | 0 | 1 >= 4? No | sec_cnt = 1 |
| 2 | 1 | 2 >= 4? No | sec_cnt = 2 |
| 3 | 2 | 3 >= 4? No | sec_cnt = 3 |
| 4 | 3 | 4 >= 4? **Yes** | sec_cnt = 0, state → A_S_YELLOW |

---

### 6. The Jump Mechanism (S8)

The jump is the trickiest part. Three conditions must all be true:

```verilog
wire in_green = (state == A_STRAIGHT) | (state == A_LEFT) |
                (state == B_STRAIGHT) | (state == B_LEFT);

wire [2:0] cur_green_idx =
    (state == A_STRAIGHT) ? 3'd0 :
    (state == A_LEFT)      ? 3'd2 :
    (state == B_STRAIGHT)  ? 3'd4 :
    (state == B_LEFT)      ? 3'd6 : 3'd7;

wire jump_needed = start_jump      // (1) button was pressed
                 & in_green        // (2) we are in a green state
                 & (jump_state != cur_green_idx);  // (3) target ≠ current
```

**Condition (3) is critical:** If North is already green and someone presses
the North button, we should NOT restart the phase. That would be disruptive
and confusing for drivers.

**Two jump trigger points:**

```verilog
// Point A: mid-phase (counter hasn't expired yet)
if (jump_needed && !(sec_cnt + 1 >= dur)) begin
    state       <= IDLE_JUMP;
    jump_target <= jump_state;  // latch the destination
    sec_cnt     <= 0;
end

// Point B: exactly at phase expiry (counter expired in same tick)
A_STRAIGHT: begin
    if (jump_needed) begin
        state <= IDLE_JUMP;
        jump_target <= jump_state;
    end else
        state <= A_S_YELLOW;  // normal flow
end
```

**After IDLE_JUMP yellow expires:**
```verilog
ALLRED_J: begin
    case (jump_target)
        3'd0: state <= A_STRAIGHT;
        3'd2: state <= A_LEFT;
        3'd4: state <= B_STRAIGHT;
        3'd6: state <= B_LEFT;
    endcase
end
```

---

### 7. Output Logic — Defaults First Pattern

Always set safe defaults BEFORE the case statement:

```verilog
always @(*) begin
    // STEP 1: Set all outputs to safe default (all red)
    a_str_green  = 0; a_str_yellow  = 0; a_str_red  = 1;
    a_left_green = 0; a_left_yellow = 0; a_left_red = 1;
    ...

    // STEP 2: Override only what changes in each state
    case (state)
        A_STRAIGHT: begin
            a_str_green = 1; a_str_red = 0;  // override red→green
            a_ped_walk  = 1;
            // everything else stays at default (red)
        end
        ...
    endcase
end
```

> **Why defaults first?** Without defaults, any signal not explicitly assigned
> in a case branch becomes a **latch** in synthesis — a common and subtle bug.
> Latches hold their previous value, which for a traffic light means a light
> might stay green when it should have gone red.

---

### 8. Fault Latch

```verilog
reg fault_lat;

// Sticky fault: once set, only reset clears it
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)            fault_lat <= 1'b0;
    else if (system_fault) fault_lat <= 1'b1;
    // no else — it HOLDS its value (intentional latch behavior)
end
```

This is one of the rare cases where **intentional latch behavior** in a
clocked register is correct. Once a conflict is detected, the system must
stay in fault mode — even if the conflict signal momentarily disappears.

---

### 9. Summary — FSM Design Rules

| Rule | Why |
|---|---|
| Use `localparam` for state names | Readable, maintainable |
| Two always blocks | Avoid latches, avoid output delay |
| Defaults before case | Prevent inferred latches |
| Duration lookup table | All timing in one place |
| Latch jump_target | Destination must survive until ALLRED_J |
| Fault latch is sticky | Safety: cannot self-recover from conflict |

---

### Exercise for Students

1. Add a new state `EMERGENCY` that makes all lights red immediately when
   an `emergency` input goes HIGH. It should return to normal after 5 seconds.
2. Draw the full state transition diagram for states S0–S8 + ALLRED states.
3. What would happen if you forgot `default: state <= FAIL_SAFE` in the
   case statement? What does synthesis do with unhandled states?