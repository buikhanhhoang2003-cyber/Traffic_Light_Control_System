# Traffic Light Controller — Tutorial
## Part 1: Requirements Analysis

---

### 1. What Are We Building?

A **4-way intersection traffic light controller** implemented on an FPGA (EP4CE6E22C8, Cyclone IV E).

The system controls traffic at a real intersection with:
- 4 directions: **North, South, East, West**
- Each direction has **3 signal heads**: Straight, Left Turn, Pedestrian
- Total: **12 signal heads × 3 colors (R/Y/G) = 36 LED outputs**

---

### 2. Identify the Axes

The first design insight is recognizing **symmetry**:

```
         North (A)
           ↑
West (B) ←   → East (B)
           ↓
         South (A)
```

- **Axis A = North + South** — they always show the same signal simultaneously
- **Axis B = East + West**  — they always show the same signal simultaneously

This reduces 4 independent directions to **2 axes**, cutting control logic in half.

> **Design Rule #1:** Identify symmetry early. North/South are physically opposite
> and never conflict with each other, so they share one signal.

---

### 3. Define the Signal Phases

For each axis, traffic must flow in a safe sequence. There are **2 phases per axis**:

| Phase | Description | Who moves |
|-------|-------------|-----------|
| Straight | Main flow + pedestrians cross | Cars going straight, pedestrians |
| Left Turn | Protected left turn | Cars turning left only |

This gives us **4 active phases** total, one per axis per phase type:

```
Phase 1: Axis A Straight  (+ pedestrian)
Phase 2: Axis A Left Turn
Phase 3: Axis B Straight  (+ pedestrian)
Phase 4: Axis B Left Turn
```

> **Design Rule #2:** Pedestrians only cross during the Straight phase of their axis.
> Left turn phases are vehicle-only because pedestrians would conflict with turning cars.

---

### 4. Define the Full State Sequence

Each phase needs a **yellow transition** before ending, plus an **all-red buffer** 
after yellow to let vehicles clear the intersection:

```
S0: A_STRAIGHT   → green on Axis A straight + pedestrian
S1: A_S_YELLOW   → yellow on Axis A straight (warning)
    ALL_RED_1    → all directions red (clearance buffer)
S2: A_LEFT       → green on Axis A left turn
S3: A_L_YELLOW   → yellow on Axis A left turn
    ALL_RED_2    → all directions red
S4: B_STRAIGHT   → green on Axis B straight + pedestrian
S5: B_S_YELLOW   → yellow on Axis B straight
    ALL_RED_3    → all directions red
S6: B_LEFT       → green on Axis B left turn
S7: B_L_YELLOW   → yellow on Axis B left turn
    ALL_RED_4    → all directions red
              ↳ loop back to S0
```

> **Design Rule #3:** Always insert an all-red buffer after yellow.
> This is a real-world safety requirement — vehicles caught in the yellow light
> need time to clear the junction before the crossing direction gets green.

---

### 5. Define Special States

Beyond the normal cycle, the system needs two more states:

#### S8 — Manual Override (IDLE_JUMP)
Simulates a **traffic police officer** manually directing traffic:
- Triggered by a 4-bit DIP switch (encodes 12 possible button requests)
- When triggered: current axis goes yellow → all-red → jump to requested green state
- Uses **first-come, first-served** — only one request active at a time

#### BLINK_RED — Fault State
When a conflict is detected (two conflicting green signals active simultaneously):
- All directions blink red at 2Hz
- System is **locked** until hardware reset
- This is a safety-critical requirement

---

### 6. Enumerate All Outputs

| Signal Group | Count | Notes |
|---|---|---|
| Straight LEDs (G/Y/R × 4 dirs) | 12 | N/S share Axis A, E/W share Axis B |
| Left Turn LEDs (G/Y/R × 4 dirs) | 12 | Same sharing as above |
| Pedestrian LEDs (4 dirs) | 4 | Active only during Straight phases |
| 7-Segment display | 4 digits × 8 seg | Shows countdown per direction |
| System fault LED | 1 | Active in BLINK_RED state |
| **Total outputs** | **33** | |

---

### 7. Enumerate All Inputs

| Signal | Type | Purpose |
|---|---|---|
| `clk` | Input | 50MHz system clock |
| `rst_n` | Input | Active-low async reset |
| `dig_dip[3:0]` | Inout | Shared: 7-seg digit select / DIP switch |
| `io_mode` | Input | Controls dig_dip direction (output=7seg, input=DIP) |

> **Key insight:** The 4 DIP switch pins are **shared** with the 7-segment digit select
> pins via a PCB mux. This is a hardware resource reuse technique.

---

### 8. Define the Timing Requirements

| Parameter | Value | Reason |
|---|---|---|
| System clock | 50 MHz | FPGA onboard oscillator |
| Phase timer resolution | 1 second | Human-visible traffic light timing |
| Fault blink rate | 2 Hz | Clearly visible warning |
| 7-seg refresh rate | ~1 kHz | Prevents visible flickering in multiplexed display |
| Debounce time | ~20 ms | Standard mechanical switch debounce |

---

### 9. Break Down into Subsystems

From the requirements above, we can identify **6 independent subsystems**:

```
┌─────────────────────────────────────────────────────┐
│                  traffic_light_top                   │
│                                                     │
│  ┌──────────┐  ┌───────────────┐  ┌──────────────┐ │
│  │  clk_div │  │dip_controller │  │   conflict   │ │
│  │          │  │               │  │   monitor    │ │
│  │ 1Hz tick │  │sync→debounce  │  │              │ │
│  │ 2Hz tick │  │→edge→decode   │  │ fault detect │ │
│  └────┬─────┘  └──────┬────────┘  └──────┬───────┘ │
│       │               │                  │         │
│       └───────────────▼──────────────────▼──────── │
│                  ┌──────────┐                       │
│                  │traffic   │                       │
│                  │  _fsm    │ ← core state machine  │
│                  └────┬─────┘                       │
│                       │ time_N/S/E/W                │
│                  ┌────▼──────────┐                  │
│                  │ seg_direction │ → 7-seg display  │
│                  └───────────────┘                  │
└─────────────────────────────────────────────────────┘
```

Each subsystem has a **single, clear responsibility**. This is the key to writing
maintainable, testable hardware design.

---

### 10. Summary — Requirements Checklist

Before writing a single line of RTL, verify you can answer all of these:

- [x] How many states does the FSM have? → **12 normal + 2 special = 14**
- [x] What are the timing parameters? → **1s resolution, 2Hz blink, 1kHz 7-seg**
- [x] What are all the outputs? → **33 signals**
- [x] What are all the inputs? → **clk, rst_n, dig_dip[3:0], io_mode**
- [x] What safety rules must be enforced? → **conflict detection, all-red buffers, fault latch**
- [x] How many hardware modules are needed? → **6 modules**
- [x] What shared resources exist? → **dig_dip inout pins**

---

### Next Part

**Part 2: Clock and Timing Design** — How to generate precise 1Hz and 2Hz
signals from a 50MHz clock, and why this matters for the FSM timer.