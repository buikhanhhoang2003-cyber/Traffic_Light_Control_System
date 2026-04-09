// =============================================================================
// seg_state.v
// 4-digit multiplexed 7-segment display — one digit per direction
//
//   DIG0 (PIN_133) = North remaining seconds  (0–9)
//   DIG1 (PIN_135) = South remaining seconds  (0–9)
//   DIG2 (PIN_136) = East  remaining seconds  (0–9)
//   DIG3 (PIN_137) = West  remaining seconds  (0–9)
//
// Shows dash "–" (middle segment only) when direction is idle (value = 0)
// Refresh rate: ~1kHz (50MHz / 50000)
// Active-low digit select and segment drive (common anode display)
// =============================================================================
module seg_state (
    input  wire       clk,
    input  wire       rst_n,

    // Phase remaining per direction (0–9, from direction_sm)
    input  wire [3:0] time_N,
    input  wire [3:0] time_S,
    input  wire [3:0] time_E,
    input  wire [3:0] time_W,

    output reg  [3:0] SVNSEG_DIG,   // digit select (active low)
    output reg  [7:0] SVNSEG_SEG    // segment drive (active low)
);

    localparam MUX_MAX = 50_000 - 1;  // ~1kHz @ 50MHz

    // ── Mux refresh counter ───────────────────────────────────────────────────
    reg [31:0] mux_cnt;
    reg [1:0]  dig_sel;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mux_cnt <= 0;
            dig_sel <= 0;
        end else begin
            if (mux_cnt == MUX_MAX) begin
                mux_cnt <= 0;
                dig_sel <= dig_sel + 1;
            end else
                mux_cnt <= mux_cnt + 1;
        end
    end

    // ── Digit select and data mux ─────────────────────────────────────────────
    reg [3:0] cur_digit;
    reg       show_dash;

    always @(*) begin
        show_dash = 1'b0;
        cur_digit = 4'd0;
        case (dig_sel)
            2'd0: begin  // North
                SVNSEG_DIG = 4'b1110;
                if (time_N == 0) show_dash = 1'b1;
                else             cur_digit = time_N;
            end
            2'd1: begin  // South
                SVNSEG_DIG = 4'b1101;
                if (time_S == 0) show_dash = 1'b1;
                else             cur_digit = time_S;
            end
            2'd2: begin  // East
                SVNSEG_DIG = 4'b1011;
                if (time_E == 0) show_dash = 1'b1;
                else             cur_digit = time_E;
            end
            2'd3: begin  // West
                SVNSEG_DIG = 4'b0111;
                if (time_W == 0) show_dash = 1'b1;
                else             cur_digit = time_W;
            end
            default: begin
                SVNSEG_DIG = 4'b1111;
                show_dash  = 1'b1;
            end
        endcase
    end

    // ── 7-segment decoder (active low, common anode) ──────────────────────────
    always @(*) begin
        if (show_dash)
            SVNSEG_SEG = 8'b1011_1111;  // dash: only segment g (middle) ON
        else begin
            case (cur_digit)
                4'd0:    SVNSEG_SEG = 8'b1100_0000;
                4'd1:    SVNSEG_SEG = 8'b1111_1001;
                4'd2:    SVNSEG_SEG = 8'b1010_0100;
                4'd3:    SVNSEG_SEG = 8'b1011_0000;
                4'd4:    SVNSEG_SEG = 8'b1001_1001;
                4'd5:    SVNSEG_SEG = 8'b1001_0010;
                4'd6:    SVNSEG_SEG = 8'b1000_0010;
                4'd7:    SVNSEG_SEG = 8'b1111_1000;
                4'd8:    SVNSEG_SEG = 8'b1000_0000;
                4'd9:    SVNSEG_SEG = 8'b1001_0000;
                default: SVNSEG_SEG = 8'b1111_1111;  // blank
            endcase
        end
    end

endmodule