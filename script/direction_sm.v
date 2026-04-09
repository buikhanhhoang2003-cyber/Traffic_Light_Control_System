// =============================================================================
// direction_sm.v
// Single-direction traffic state machine: SM1 → SM2 → SM3
// Instantiated 4 times: North, South, East, West
//
// State sequence:
//   IDLE → SM1_LEFT_GREEN → SM1_LEFT_YELL →
//          SM2_PED_SOLID  → SM2_PED_FLASH  →
//          SM3_WAIT_OPP   →
//          SM3_STRA_GREEN → SM3_STRA_YELL  → IDLE
//
// Skip rules:
//   SM1: if no left turn request → skip to SM2, assert lt_done immediately
//   SM3: waits for opp_lt_done before going green
//
// Green duration = 2 * car_count seconds, clamped to [min, max]
// Phase countdown output (4-bit, clamped to 9) drives 7-segment display
// =============================================================================
module direction_sm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,
    input  wire        tick_05hz,    // 0.5Hz level — pedestrian flash gate

    // SM0 control
    input  wire        enable,       // HIGH when this axis is active
    input  wire        chg_dir,      // change-direction pulse from SM0
    input  wire        halt,         // freeze for config update

    // Requests for this direction
    input  wire        left_req,     // left turn vehicles waiting
    input  wire        stra_req,     // straight vehicles waiting
    input  wire        ped_req,      // pedestrian waiting

    // Car counts (from request_decoder)
    input  wire [6:0]  left_cars,
    input  wire [6:0]  stra_cars,

    // Opposite direction left-turn done (SM3 waits for this)
    input  wire        opp_lt_done,

    // Configuration (from config_regs)
    input  wire [7:0]  yellow_time,
    input  wire [7:0]  left_max,
    input  wire [7:0]  left_min,
    input  wire [7:0]  stra_max,
    input  wire [7:0]  stra_min,
    input  wire [7:0]  ped_solid,
    input  wire [7:0]  ped_flash,

    // Status outputs
    output reg         lt_done,       // left turn phase complete (level)
    output reg         sm_idle,       // this direction is idle
    output reg         max_hit,       // straight hit max time
    output reg         ped_active,    // pedestrian phase active (blocks chg_dir)

    // Phase countdown for 7-seg (0–9, 0 when idle)
    output reg  [3:0]  phase_remaining,

    // Traffic light outputs
    output reg         r_left, y_left, g_left,
    output reg         r_ped,         g_ped,
    output reg         r_stra, y_stra, g_stra
);

    // =========================================================================
    // STATE ENCODING
    // =========================================================================
    localparam [3:0]
        IDLE           = 4'd0,
        SM1_LEFT_GREEN = 4'd1,
        SM1_LEFT_YELL  = 4'd2,
        SM2_PED_SOLID  = 4'd3,
        SM2_PED_FLASH  = 4'd4,
        SM3_WAIT_OPP   = 4'd5,
        SM3_STRA_GREEN = 4'd6,
        SM3_STRA_YELL  = 4'd7;

    reg [3:0] state;

    // =========================================================================
    // PHASE TIMER
    // =========================================================================
    reg [7:0] phase_cnt;
    reg [7:0] dur;

    // Clamp helper: clamp val to [lo, hi]
    function [7:0] clamp;
        input [7:0] val, lo, hi;
        begin
            if      (val < lo) clamp = lo;
            else if (val > hi) clamp = hi;
            else               clamp = val;
        end
    endfunction

    // Green duration = 2s per car, clamped to configured min/max
    wire [7:0] left_dur = clamp(left_cars * 2, left_min, left_max);
    wire [7:0] stra_dur = clamp(stra_cars * 2, stra_min, stra_max);

    // =========================================================================
    // FSM — sequential logic
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            phase_cnt  <= 0;
            dur        <= 0;
            lt_done    <= 0;
            sm_idle    <= 1;
            max_hit    <= 0;
            ped_active <= 0;
        end
        else if (halt) begin
            // Freeze all SM activity during config update window
        end
        else if (tick_1hz) begin
            case (state)

                // ── IDLE: wait for SM0 to enable ─────────────────────────────
                IDLE: begin
                    sm_idle    <= 1;
                    lt_done    <= 0;
                    max_hit    <= 0;
                    ped_active <= 0;
                    if (enable) begin
                        sm_idle   <= 0;
                        phase_cnt <= 0;
                        if (left_req) begin
                            // Left turn vehicles waiting — start SM1
                            state <= SM1_LEFT_GREEN;
                            dur   <= left_dur;
                        end else begin
                            // No left turn — skip SM1, signal done immediately
                            lt_done    <= 1;
                            ped_active <= 1;
                            state      <= SM2_PED_SOLID;
                            dur        <= ped_solid;
                        end
                    end
                end

                // ── SM1: Left turn green ──────────────────────────────────────
                SM1_LEFT_GREEN: begin
                    if (phase_cnt + 1 >= dur) begin
                        phase_cnt <= 0;
                        state     <= SM1_LEFT_YELL;
                        dur       <= yellow_time;
                    end else
                        phase_cnt <= phase_cnt + 1;
                end

                // ── SM1: Left turn yellow ─────────────────────────────────────
                SM1_LEFT_YELL: begin
                    if (phase_cnt + 1 >= dur) begin
                        phase_cnt  <= 0;
                        lt_done    <= 1;    // notify opposite SM3 it can go
                        ped_active <= 1;
                        state      <= SM2_PED_SOLID;
                        dur        <= ped_solid;
                    end else
                        phase_cnt <= phase_cnt + 1;
                end

                // ── SM2: Pedestrian solid green ───────────────────────────────
                SM2_PED_SOLID: begin
                    if (phase_cnt + 1 >= dur) begin
                        phase_cnt <= 0;
                        state     <= SM2_PED_FLASH;
                        dur       <= ped_flash;
                    end else
                        phase_cnt <= phase_cnt + 1;
                end

                // ── SM2: Pedestrian flash green ───────────────────────────────
                // ped_active held HIGH — blocks SM0 from switching axis
                SM2_PED_FLASH: begin
                    if (phase_cnt + 1 >= dur) begin
                        phase_cnt  <= 0;
                        ped_active <= 0;
                        state      <= SM3_WAIT_OPP;
                    end else
                        phase_cnt <= phase_cnt + 1;
                end

                // ── SM3: Wait for opposite direction left turn to finish ───────
                SM3_WAIT_OPP: begin
                    if (opp_lt_done) begin
                        phase_cnt <= 0;
                        max_hit   <= 0;
                        state     <= SM3_STRA_GREEN;
                        dur       <= stra_dur;
                    end
                    // else: hold and wait (no counter increment)
                end

                // ── SM3: Straight green ───────────────────────────────────────
                SM3_STRA_GREEN: begin
                    if (phase_cnt + 1 >= stra_max) begin
                        // Hit maximum time — report to SM0 and hold green
                        max_hit   <= 1;
                        // Wait for chg_dir from SM0
                        if (chg_dir) begin
                            max_hit   <= 0;
                            phase_cnt <= 0;
                            state     <= SM3_STRA_YELL;
                            dur       <= yellow_time;
                        end
                    end else if (phase_cnt + 1 >= dur) begin
                        // Reached requested duration
                        if (chg_dir || !stra_req) begin
                            // Direction change requested or no more cars
                            phase_cnt <= 0;
                            state     <= SM3_STRA_YELL;
                            dur       <= yellow_time;
                        end
                        // else: hold green — cars still waiting
                    end else
                        phase_cnt <= phase_cnt + 1;
                end

                // ── SM3: Straight yellow ──────────────────────────────────────
                SM3_STRA_YELL: begin
                    if (phase_cnt + 1 >= dur) begin
                        phase_cnt <= 0;
                        lt_done   <= 0;
                        state     <= IDLE;
                        sm_idle   <= 1;
                    end else
                        phase_cnt <= phase_cnt + 1;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // =========================================================================
    // PHASE COUNTDOWN OUTPUT — clamped to 9 for single 7-seg digit
    // =========================================================================
    // Intermediate wire to avoid part-select on expression (not legal in Verilog)
    wire [7:0] remaining_raw = dur - phase_cnt;

    always @(*) begin
        case (state)
            SM1_LEFT_GREEN,
            SM1_LEFT_YELL,
            SM2_PED_SOLID,
            SM2_PED_FLASH,
            SM3_STRA_GREEN,
            SM3_STRA_YELL: begin
                // Clamp to 9 for single 7-seg digit
                if (remaining_raw > 8'd9)
                    phase_remaining = 4'd9;
                else
                    phase_remaining = remaining_raw[3:0];
            end
            default: phase_remaining = 4'd0;  // IDLE or WAIT — show dash
        endcase
    end

    // =========================================================================
    // OUTPUT LOGIC — combinational, defaults-first pattern
    // =========================================================================
    always @(*) begin
        // Default: all red
        r_left = 1; y_left = 0; g_left = 0;
        r_ped  = 1;             g_ped  = 0;
        r_stra = 1; y_stra = 0; g_stra = 0;

        case (state)
            SM1_LEFT_GREEN: begin
                r_left = 0; g_left = 1;
            end
            SM1_LEFT_YELL: begin
                r_left = 0; y_left = 1;
            end
            SM2_PED_SOLID: begin
                r_ped = 0; g_ped = 1;         // solid green
            end
            SM2_PED_FLASH: begin
                r_ped = tick_05hz;             // flash: gate with 0.5Hz toggle
                g_ped = ~tick_05hz;
            end
            SM3_STRA_GREEN: begin
                r_stra = 0; g_stra = 1;
            end
            SM3_STRA_YELL: begin
                r_stra = 0; y_stra = 1;
            end
            // IDLE, SM3_WAIT_OPP: default (all red) applies
            default: begin end
        endcase
    end

endmodule