// =============================================================================
// sm0_coordinator.v
// Top-level axis coordinator FSM
//
// Responsibilities:
//   1. Enable NS or EW direction group based on car-count priority
//   2. Switch axis when opposite axis has more waiting cars
//   3. Never switch while pedestrian is crossing (ped_active blocks switch)
//   4. Assert chg_dir to tell active SMs to wrap up their straight phase
//   5. Assert halt when all SMs idle — config update window
//   6. Default to NS when car counts are equal (NS has priority)
//   7. If no traffic at all — keep NS active (higher priority by default)
// =============================================================================
module sm0_coordinator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,

    // Car count totals from request_decoder
    input  wire [6:0]  car_count_ns,
    input  wire [6:0]  car_count_ew,

    // Aggregated status from NS and EW direction SMs
    input  wire        ns_sm_idle,     // both N and S are idle
    input  wire        ew_sm_idle,     // both E and W are idle
    input  wire        ns_max_hit,     // NS straight hit max time
    input  wire        ew_max_hit,     // EW straight hit max time
    input  wire        ns_ped_active,  // pedestrian crossing on NS (block switch)
    input  wire        ew_ped_active,  // pedestrian crossing on EW (block switch)

    // Control outputs
    output reg         ns_enable,     // enable NS group
    output reg         ew_enable,     // enable EW group
    output reg         ns_chg_dir,    // 1-cycle pulse: ask NS SMs to finish up
    output reg         ew_chg_dir,    // 1-cycle pulse: ask EW SMs to finish up
    output reg         halt,          // halt all SMs for config window
    output reg         active_ns      // 1=NS active, 0=EW active (debug/display)
);

    // =========================================================================
    // STATE ENCODING
    // =========================================================================
    localparam [2:0]
        S_INIT      = 3'd0,  // power-on: choose first axis
        S_NS_ACTIVE = 3'd1,  // NS group running
        S_NS_SWITCH = 3'd2,  // waiting for NS to go idle before switching to EW
        S_EW_ACTIVE = 3'd3,  // EW group running
        S_EW_SWITCH = 3'd4,  // waiting for EW to go idle before switching to NS
        S_HALT      = 3'd5;  // all idle — one-cycle config window

    reg [2:0] state;

    // =========================================================================
    // SWITCH DECISION WIRES
    // =========================================================================
    // Switch NS→EW: EW has more cars, no NS ped crossing, NS can be interrupted
    wire should_to_ew = (car_count_ew > car_count_ns) &&
                        !ns_ped_active &&
                        (ns_sm_idle || ns_max_hit);

    // Switch EW→NS: NS has >= cars, no EW ped crossing, EW can be interrupted
    wire should_to_ns = (car_count_ns >= car_count_ew) &&
                        !ew_ped_active &&
                        (ew_sm_idle || ew_max_hit);

    wire all_idle = ns_sm_idle & ew_sm_idle;

    // =========================================================================
    // SM0 FSM
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_INIT;
            ns_enable  <= 0;
            ew_enable  <= 0;
            ns_chg_dir <= 0;
            ew_chg_dir <= 0;
            halt       <= 0;
            active_ns  <= 1;
        end else begin
            // Default: clear single-cycle pulse signals
            ns_chg_dir <= 0;
            ew_chg_dir <= 0;
            halt       <= 0;

            case (state)

                // ── Init: start NS by default ─────────────────────────────────
                S_INIT: begin
                    ns_enable <= 1;
                    ew_enable <= 0;
                    active_ns <= 1;
                    state     <= S_NS_ACTIVE;
                end

                // ── NS active ─────────────────────────────────────────────────
                S_NS_ACTIVE: begin
                    ns_enable <= 1;
                    ew_enable <= 0;
                    active_ns <= 1;
                    if (should_to_ew) begin
                        ns_chg_dir <= 1;   // ask NS SMs to finish straight phase
                        ns_enable  <= 0;
                        state      <= S_NS_SWITCH;
                    end
                end

                // ── Wait for NS to go idle ─────────────────────────────────────
                S_NS_SWITCH: begin
                    ns_enable <= 0;
                    ew_enable <= 0;
                    if (ns_sm_idle) begin
                        if (all_idle) begin
                            halt  <= 1;
                            state <= S_HALT;
                        end else begin
                            ew_enable <= 1;
                            active_ns <= 0;
                            state     <= S_EW_ACTIVE;
                        end
                    end
                end

                // ── EW active ─────────────────────────────────────────────────
                S_EW_ACTIVE: begin
                    ew_enable <= 1;
                    ns_enable <= 0;
                    active_ns <= 0;
                    if (should_to_ns) begin
                        ew_chg_dir <= 1;
                        ew_enable  <= 0;
                        state      <= S_EW_SWITCH;
                    end
                end

                // ── Wait for EW to go idle ─────────────────────────────────────
                S_EW_SWITCH: begin
                    ew_enable <= 0;
                    ns_enable <= 0;
                    if (ew_sm_idle) begin
                        if (all_idle) begin
                            halt  <= 1;
                            state <= S_HALT;
                        end else begin
                            ns_enable <= 1;
                            active_ns <= 1;
                            state     <= S_NS_ACTIVE;
                        end
                    end
                end

                // ── Halt: one-cycle config window, then resume ─────────────────
                S_HALT: begin
                    halt <= 1;
                    if (car_count_ns >= car_count_ew) begin
                        ns_enable <= 1;
                        active_ns <= 1;
                        state     <= S_NS_ACTIVE;
                    end else begin
                        ew_enable <= 1;
                        active_ns <= 0;
                        state     <= S_EW_ACTIVE;
                    end
                end

                default: state <= S_INIT;
            endcase
        end
    end

endmodule