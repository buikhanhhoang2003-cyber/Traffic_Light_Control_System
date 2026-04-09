# Traffic Light Controller — Tutorial
## Part 6: 7-Segment Display Driver

---

### 1. What Is a Multiplexed 7-Segment Display?

A 4-digit 7-segment display has:
- **8 segment pins** (a–g + decimal point) shared across ALL digits
- **4 digit-select pins** (one per digit) that enable one digit at a time

```
Segment pins (shared):
   ─ a ─
  |     |
  f     b
  |     |
   ─ g ─
  |     |
  e     c
  |     |
   ─ d ─  · dp

Digit select (individual):
  DIG0  DIG1  DIG2  DIG3
   N     S     E     W
```

**Key point:** You cannot drive all 4 digits simultaneously with different
values because the segment pins are shared. If DIG0 and DIG1 are both
enabled, they both show the same segments.

**Solution: Time-division multiplexing (TDM)**

Rapidly cycle through the digits, enabling one at a time:

```
Time:   ──T──┬──T──┬──T──┬──T──┬──T──┬──T──
DIG:         N     S     E     W     N     S
Segment:     3     0     7     2     3     0
             ↑     ↑     ↑     ↑
           showing different values fast enough
           that human eye sees all 4 simultaneously
```

---

### 2. Why 1kHz Refresh Rate?

Human **flicker fusion threshold** is ~50Hz — below this, we see flickering.
Each digit gets 1/4 of the total refresh time.

```
Minimum per-digit refresh = 4 × flicker_threshold = 4 × 50Hz = 200Hz

We use 1kHz (1000Hz) for comfortable viewing with margin:
  Each digit is ON for 1ms, OFF for 3ms → repeats 250 times/second
  Well above 50Hz threshold → no visible flicker
```

**Counter calculation:**
```
Refresh period  = 1/1000Hz = 1ms
Clock frequency = 50MHz
Cycles per ms   = 50,000,000 / 1000 = 50,000

MUX_MAX = 50,000 - 1 = 49,999

Register width: ceil(log2(50,000)) = 15.6 → use 32 bits (avoids truncation warning)
```

---

### 3. The Multiplexer Counter

```verilog
localparam MUX_MAX = 50_000 - 1;

reg [31:0] mux_cnt;   // 32-bit to avoid truncation warning
reg [1:0]  dig_sel;   // cycles 0→1→2→3→0→...

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mux_cnt <= 0;
        dig_sel <= 0;
    end else begin
        if (mux_cnt == MUX_MAX) begin
            mux_cnt <= 0;
            dig_sel <= dig_sel + 1;  // 2-bit: auto-wraps 3→0
        end else
            mux_cnt <= mux_cnt + 1;
    end
end
```

**Timing diagram:**

```
mux_cnt:  0────────49999|0────────49999|0────────49999|0──────...
dig_sel:  ─────── 0 ────|──────1──────|──────2──────|──3────...
DIG pin:  1110(N ON)    |1101(S ON)   |1011(E ON)   |0111(W)...
           ← 1ms →       ← 1ms →       ← 1ms →       ← 1ms →
```

---

### 4. Active-Low Digit Select

The display uses **PNP transistors** to switch digit power.
PNP transistors turn ON with a LOW base signal:

```
FPGA pin HIGH → transistor OFF → digit OFF
FPGA pin LOW  → transistor ON  → digit ON

Digit select encoding:
  DIG0 (North) active: SVNSEG_DIG = 4'b1110  (bit 0 = LOW)
  DIG1 (South) active: SVNSEG_DIG = 4'b1101  (bit 1 = LOW)
  DIG2 (East)  active: SVNSEG_DIG = 4'b1011  (bit 2 = LOW)
  DIG3 (West)  active: SVNSEG_DIG = 4'b0111  (bit 3 = LOW)
```

```verilog
always @(*) begin
    case (dig_sel)
        2'd0: begin SVNSEG_DIG = 4'b1110; cur_digit = time_N; end
        2'd1: begin SVNSEG_DIG = 4'b1101; cur_digit = time_S; end
        2'd2: begin SVNSEG_DIG = 4'b1011; cur_digit = time_E; end
        2'd3: begin SVNSEG_DIG = 4'b0111; cur_digit = time_W; end
        default: begin SVNSEG_DIG = 4'b1111; cur_digit = 4'd0; end
    endcase
end
```

---

### 5. 7-Segment Decoder

Each digit value (0–9) maps to an 8-bit pattern controlling which segments light up.
The display is **common anode** (active low):

```
Segment bit positions:
  SVNSEG_SEG = {dp, g, f, e, d, c, b, a}
                 7   6  5  4  3  2  1  0

Digit 0:  segments a,b,c,d,e,f ON  → g,dp OFF
  Binary: dp=1, g=1, f=0, e=0, d=0, c=0, b=0, a=0
        = 1100_0000 = 8'hC0

Digit 1:  segments b,c ON only
        = 1111_1001 = 8'hF9

Digit 8:  all segments ON
        = 1000_0000 = 8'h80
```

Full decode table:
```verilog
case (cur_digit)
    4'd0: SVNSEG_SEG = 8'b1100_0000;  // 0
    4'd1: SVNSEG_SEG = 8'b1111_1001;  // 1
    4'd2: SVNSEG_SEG = 8'b1010_0100;  // 2
    4'd3: SVNSEG_SEG = 8'b1011_0000;  // 3
    4'd4: SVNSEG_SEG = 8'b1001_1001;  // 4
    4'd5: SVNSEG_SEG = 8'b1001_0010;  // 5
    4'd6: SVNSEG_SEG = 8'b1000_0010;  // 6
    4'd7: SVNSEG_SEG = 8'b1111_1000;  // 7
    4'd8: SVNSEG_SEG = 8'b1000_0000;  // 8
    4'd9: SVNSEG_SEG = 8'b1001_0000;  // 9
    default: SVNSEG_SEG = 8'b1111_1111; // blank (all OFF)
endcase
```

---

### 6. What Each Digit Displays

Each digit shows the **remaining green seconds** for that direction.
When a direction is NOT green (it's red or yellow), it displays **0**.

```verilog
// In traffic_fsm.v:
wire [3:0] remaining = dur - sec_cnt;

always @(*) begin
    time_N = 4'd0; time_S = 4'd0;
    time_E = 4'd0; time_W = 4'd0;
    case (state)
        A_STRAIGHT,
        A_LEFT    : begin time_N = remaining; time_S = remaining; end
        B_STRAIGHT,
        B_LEFT    : begin time_E = remaining; time_W = remaining; end
        default   : begin end  // all zero
    endcase
end
```

**Example — during A_STRAIGHT (4s phase):**

```
sec_cnt=0: remaining=4 → N shows 4, S shows 4, E shows 0, W shows 0
sec_cnt=1: remaining=3 → N shows 3, S shows 3, E shows 0, W shows 0
sec_cnt=2: remaining=2 → N shows 2, S shows 2, E shows 0, W shows 0
sec_cnt=3: remaining=1 → N shows 1, S shows 1, E shows 0, W shows 0
→ transition → A_S_YELLOW: all digits show 0
```

---

### 7. The Shared Pin Problem — Inout Design

Pins PIN_133/135/136/137 serve double duty:
- **Output mode** (io_mode=1): drive 7-seg digit select
- **Input mode** (io_mode=0): read 4-bit DIP switch

```verilog
// In traffic_light_top.v:
wire [3:0] seg_dig_out;   // from seg_direction
wire [3:0] dip_btn;       // to dip_controller

// Tristate driver:
assign dig_dip[0] = io_mode ? seg_dig_out[0] : 1'bz;
assign dig_dip[1] = io_mode ? seg_dig_out[1] : 1'bz;
assign dig_dip[2] = io_mode ? seg_dig_out[2] : 1'bz;
assign dig_dip[3] = io_mode ? seg_dig_out[3] : 1'bz;

// Read value when in input mode:
assign dip_btn = io_mode ? 4'b0000 : dig_dip;
```

**`1'bz` = high impedance (tristate)**

When a pin is tristated, it is electrically disconnected from the FPGA output
driver. The PCB's pull-up/pull-down resistors and external DIP switch
then determine the pin voltage, which the FPGA reads as input.

```
io_mode=1 (output mode):
  FPGA drives dig_dip ──────────────► 7-seg display
  DIP switch is ignored (PCB mux disconnects it)

io_mode=0 (input mode):
  FPGA tristates ──── 1'bz
  DIP switch drives pin ──────────► FPGA reads dig_dip as dip_btn
```

---

### 8. Summary

| Concept | Key Point |
|---|---|
| Multiplexing | One digit at a time, fast enough to fool the eye |
| Refresh rate | 1kHz → each digit ON 1ms → well above 50Hz flicker threshold |
| Active-low | PNP transistors invert logic — LOW = ON |
| 7-seg decode | Each digit 0–9 is a hardcoded 8-bit constant |
| Countdown source | FSM outputs `remaining = dur - sec_cnt` per direction |
| Tristate inout | `1'bz` disconnects FPGA output — enables input reading |

---

### Exercise for Students

1. What refresh rate would you need if you had an 8-digit display instead of 4?
   Recalculate `MUX_MAX`.

2. The display shows 0 during yellow and all-red phases. A driver sees the
   countdown drop from 2 to 0 suddenly with no intermediate yellow count.
   How would you modify `seg_direction.v` to show the yellow countdown too?

3. Draw the segment pattern (which segments are ON/OFF) for the digit "5"
   on a 7-segment display. Verify it matches `8'b1001_0010`.