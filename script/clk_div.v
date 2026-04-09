// =============================================================================
// clk_div.v
// Generates tick pulses for all timing needs:
//   tick_1hz  : 1Hz  — general 1-second phase timer
//   tick_2hz  : 2Hz  — fault blink
//   tick_05hz : 0.5Hz level toggle — pedestrian flash gate (0.5s ON / 0.5s OFF)
// =============================================================================
module clk_div #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire clk,
    input  wire rst_n,
    output reg  tick_1hz,
    output reg  tick_2hz,
    output reg  tick_05hz   // level signal — toggles every 1s
);

    // ── 1Hz tick ──────────────────────────────────────────────────────────────
    reg [25:0] cnt_1hz;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_1hz  <= 0;
            tick_1hz <= 0;
        end else begin
            if (cnt_1hz == CLK_FREQ - 1) begin
                cnt_1hz  <= 0;
                tick_1hz <= 1;
            end else begin
                cnt_1hz  <= cnt_1hz + 1;
                tick_1hz <= 0;
            end
        end
    end

    // ── 2Hz tick ──────────────────────────────────────────────────────────────
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

    // ── 0.5Hz level toggle — pedestrian flash gate ────────────────────────────
    // Toggles every 1Hz tick → 0.5s ON, 0.5s OFF
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        tick_05hz <= 0;
        else if (tick_1hz) tick_05hz <= ~tick_05hz;
    end

endmodule