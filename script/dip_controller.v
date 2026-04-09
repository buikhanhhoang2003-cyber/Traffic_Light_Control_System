// =============================================================================
// dip_controller.v
// Reads 4-bit DIP switch, debounces, detects changes, outputs stable value
//
// Pipeline: sync (2FF) → debounce (20ms) → edge detect → output
//
// Output:
//   dip_val   : stable 4-bit value (held until next change)
//   dip_valid : single-cycle pulse when a new stable value is detected
// =============================================================================
module dip_controller #(
    parameter DEBOUNCE_MAX = 1_000_000   // 20ms @ 50MHz (override in simulation)
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] dip_sw,    // raw DIP switch input

    output reg  [3:0] dip_val,   // stable decoded value
    output reg        dip_valid  // 1-cycle pulse on new value
);

    // ── Stage 1: 2-stage synchronizer (prevents metastability) ───────────────
    reg [3:0] sync0, sync1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync0 <= 4'b0;
            sync1 <= 4'b0;
        end else begin
            sync0 <= dip_sw;
            sync1 <= sync0;
        end
    end

    // ── Stage 2: Debounce — accept value after DEBOUNCE_MAX stable cycles ────
    reg [3:0]  dip_stable, dip_cand;
    reg [19:0] deb_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dip_stable <= 4'b0;
            dip_cand   <= 4'b0;
            deb_cnt    <= 0;
        end else begin
            if (sync1 != dip_cand) begin
                // Input changed — restart stability timer
                dip_cand <= sync1;
                deb_cnt  <= 0;
            end else if (deb_cnt < DEBOUNCE_MAX)
                deb_cnt <= deb_cnt + 1;
            else
                dip_stable <= dip_cand;  // stable long enough — accept
        end
    end

    // ── Stage 3: Edge detect — fire pulse only on change ─────────────────────
    reg [3:0] dip_prev;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dip_prev  <= 4'b0;
            dip_val   <= 4'b0;
            dip_valid <= 1'b0;
        end else begin
            dip_valid <= 1'b0;           // default: no pulse
            dip_prev  <= dip_stable;
            if (dip_stable != dip_prev) begin
                dip_val   <= dip_stable;
                dip_valid <= 1'b1;       // pulse for exactly one cycle
            end
        end
    end

endmodule