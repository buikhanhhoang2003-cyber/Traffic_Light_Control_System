// =============================================================================
// traffic_light_top.v
// Top-level module: 4-Way Traffic Light Controller
//
// Architecture:
//   clk_div        → tick signals
//   dip_controller → debounced DIP switch value
//   request_decoder→ 12 request signals + per-lane car counters
//   config_regs    → programmable timing (shadow/active, halt-gated)
//   sm0_coordinator→ axis priority switching (NS vs EW, car-count based)
//   direction_sm ×4→ SM1(Left)→SM2(Ped)→SM3(Straight) per direction
//   conflict_monitor→ safety watchdog
//   seg_state      → 4-digit 7-seg countdown display
//
// Outputs: 32 traffic light signals (8 per direction × 4 directions)
//   per direction: r_left, y_left, g_left, r_ped, g_ped, r_stra, y_stra, g_stra
//
// Shared pins (dig_dip):
//   io_mode=1 → FPGA drives pins as 7-seg digit select (output)
//   io_mode=0 → FPGA tristates and reads as DIP switch input
// =============================================================================
module traffic_light_top (
    input  wire        clk,
    input  wire        rst_n,

    // Shared inout: 7-seg digit select / DIP switch (via PCB mux)
    input  wire        io_mode,
    inout  wire [3:0]  dig_dip,

    // Config register write interface
    input  wire [3:0]  cfg_addr,
    input  wire [7:0]  cfg_data,
    input  wire        cfg_we,

    // 7-segment segment outputs (dedicated pins)
    output wire [7:0]  SVNSEG_SEG,

    // North outputs
    output wire        n_r_left, n_y_left, n_g_left,
    output wire        n_r_ped,  n_g_ped,
    output wire        n_r_stra, n_y_stra, n_g_stra,

    // South outputs
    output wire        s_r_left, s_y_left, s_g_left,
    output wire        s_r_ped,  s_g_ped,
    output wire        s_r_stra, s_y_stra, s_g_stra,

    // East outputs
    output wire        e_r_left, e_y_left, e_g_left,
    output wire        e_r_ped,  e_g_ped,
    output wire        e_r_stra, e_y_stra, e_g_stra,

    // West outputs
    output wire        w_r_left, w_y_left, w_g_left,
    output wire        w_r_ped,  w_g_ped,
    output wire        w_r_stra, w_y_stra, w_g_stra,

    // System fault indicator
    output wire        system_fault_led
);

    // =========================================================================
    // SHARED DIP / 7-SEG TRISTATE CONTROL
    // =========================================================================
    wire [3:0] seg_dig_out;   // digit select driven by seg_state
    wire [3:0] dip_btn;       // DIP value read when in input mode

    assign dig_dip[0] = io_mode ? seg_dig_out[0] : 1'bz;
    assign dig_dip[1] = io_mode ? seg_dig_out[1] : 1'bz;
    assign dig_dip[2] = io_mode ? seg_dig_out[2] : 1'bz;
    assign dig_dip[3] = io_mode ? seg_dig_out[3] : 1'bz;
    assign dip_btn    = io_mode ? 4'b0000 : dig_dip;

    // =========================================================================
    // INTERNAL WIRES
    // =========================================================================

    // Clock ticks
    wire tick_1hz, tick_2hz, tick_05hz;

    // DIP controller
    wire [3:0] dip_val;
    wire       dip_valid;

    // Config register outputs
    wire [7:0] yellow_ns, yellow_ew;
    wire [7:0] left_max_ns, left_max_ew;
    wire [7:0] stra_max_ns, stra_max_ew;
    wire [7:0] stra_min, left_min;
    wire [7:0] ped_solid, ped_flash;

    // Request signals
    wire s_left_req, s_stra_req, s_pedw_req;
    wire n_left_req, n_stra_req, n_pede_req;
    wire e_left_req, e_stra_req, e_peds_req;
    wire w_left_req, w_stra_req, w_pedn_req;

    // Per-lane car counts
    wire [6:0] s_left_cars, s_stra_cars;
    wire [6:0] n_left_cars, n_stra_cars;
    wire [6:0] e_left_cars, e_stra_cars;
    wire [6:0] w_left_cars, w_stra_cars;

    // Aggregate car counts for SM0
    wire [6:0] car_count_ns, car_count_ew;

    // SM0 control signals
    wire ns_enable, ew_enable;
    wire ns_chg_dir, ew_chg_dir;
    wire halt;

    // Direction SM status
    wire n_lt_done, n_sm_idle, n_max_hit, n_ped_active;
    wire s_lt_done, s_sm_idle, s_max_hit, s_ped_active;
    wire e_lt_done, e_sm_idle, e_max_hit, e_ped_active;
    wire w_lt_done, w_sm_idle, w_max_hit, w_ped_active;

    // Group aggregation for SM0
    wire ns_sm_idle    = n_sm_idle    & s_sm_idle;
    wire ew_sm_idle    = e_sm_idle    & w_sm_idle;
    wire ns_max_hit    = n_max_hit    | s_max_hit;
    wire ew_max_hit    = e_max_hit    | w_max_hit;
    wire ns_ped_active = n_ped_active | s_ped_active;
    wire ew_ped_active = e_ped_active | w_ped_active;

    // Phase countdowns for 7-seg
    wire [3:0] n_remaining, s_remaining;
    wire [3:0] e_remaining, w_remaining;

    // Safety
    wire system_fault;

    // =========================================================================
    // CLOCK DIVIDER
    // =========================================================================
    clk_div #(.CLK_FREQ(50_000_000)) u_clk_div (
        .clk      (clk),
        .rst_n    (rst_n),
        .tick_1hz (tick_1hz),
        .tick_2hz (tick_2hz),
        .tick_05hz(tick_05hz)
    );

    // =========================================================================
    // DIP CONTROLLER
    // =========================================================================
    dip_controller u_dip (
        .clk      (clk),
        .rst_n    (rst_n),
        .dip_sw   (dip_btn),
        .dip_val  (dip_val),
        .dip_valid(dip_valid)
    );

    // =========================================================================
    // CONFIG REGISTERS
    // =========================================================================
    config_regs u_cfg (
        .clk        (clk),        .rst_n      (rst_n),
        .cfg_addr   (cfg_addr),   .cfg_data   (cfg_data),  .cfg_we(cfg_we),
        .halt       (halt),
        .yellow_ns  (yellow_ns),  .yellow_ew  (yellow_ew),
        .left_max_ns(left_max_ns),.left_max_ew(left_max_ew),
        .stra_max_ns(stra_max_ns),.stra_max_ew(stra_max_ew),
        .stra_min   (stra_min),   .left_min   (left_min),
        .ped_solid  (ped_solid),  .ped_flash  (ped_flash)
    );

    // =========================================================================
    // REQUEST DECODER + CAR COUNTERS
    // =========================================================================
    request_decoder u_req (
        .clk         (clk),         .rst_n       (rst_n),
        .tick_1hz    (tick_1hz),    .dip_val     (dip_val),    .dip_valid(dip_valid),
        .s_left_green(s_g_left),    .s_stra_green(s_g_stra),   .s_ped_green(s_g_ped),
        .n_left_green(n_g_left),    .n_stra_green(n_g_stra),   .n_ped_green(n_g_ped),
        .e_left_green(e_g_left),    .e_stra_green(e_g_stra),   .e_ped_green(e_g_ped),
        .w_left_green(w_g_left),    .w_stra_green(w_g_stra),   .w_ped_green(w_g_ped),
        .s_left_req  (s_left_req),  .s_stra_req  (s_stra_req), .s_pedw_req(s_pedw_req),
        .n_left_req  (n_left_req),  .n_stra_req  (n_stra_req), .n_pede_req(n_pede_req),
        .e_left_req  (e_left_req),  .e_stra_req  (e_stra_req), .e_peds_req(e_peds_req),
        .w_left_req  (w_left_req),  .w_stra_req  (w_stra_req), .w_pedn_req(w_pedn_req),
        .s_left_cars (s_left_cars), .s_stra_cars (s_stra_cars),
        .n_left_cars (n_left_cars), .n_stra_cars (n_stra_cars),
        .e_left_cars (e_left_cars), .e_stra_cars (e_stra_cars),
        .w_left_cars (w_left_cars), .w_stra_cars (w_stra_cars),
        .car_count_ns(car_count_ns),.car_count_ew(car_count_ew)
    );

    // =========================================================================
    // SM0 COORDINATOR
    // =========================================================================
    sm0_coordinator u_sm0 (
        .clk          (clk),          .rst_n        (rst_n),
        .tick_1hz     (tick_1hz),
        .car_count_ns (car_count_ns), .car_count_ew (car_count_ew),
        .ns_sm_idle   (ns_sm_idle),   .ew_sm_idle   (ew_sm_idle),
        .ns_max_hit   (ns_max_hit),   .ew_max_hit   (ew_max_hit),
        .ns_ped_active(ns_ped_active),.ew_ped_active(ew_ped_active),
        .ns_enable    (ns_enable),    .ew_enable    (ew_enable),
        .ns_chg_dir   (ns_chg_dir),   .ew_chg_dir   (ew_chg_dir),
        .halt         (halt),
        .active_ns    ()
    );

    // =========================================================================
    // DIRECTION STATE MACHINES — NS GROUP
    // N and S run SM1→SM2→SM3 in parallel, each waiting for the other's lt_done
    // =========================================================================
    direction_sm u_north (
        .clk        (clk),         .rst_n      (rst_n),
        .tick_1hz   (tick_1hz),    .tick_05hz  (tick_05hz),
        .enable     (ns_enable),   .chg_dir    (ns_chg_dir), .halt(halt),
        .left_req   (n_left_req),  .stra_req   (n_stra_req), .ped_req(n_pede_req),
        .left_cars  (n_left_cars), .stra_cars  (n_stra_cars),
        .opp_lt_done(s_lt_done),
        .yellow_time(yellow_ns),   .left_max   (left_max_ns),.left_min(left_min),
        .stra_max   (stra_max_ns), .stra_min   (stra_min),
        .ped_solid  (ped_solid),   .ped_flash  (ped_flash),
        .lt_done    (n_lt_done),   .sm_idle    (n_sm_idle),
        .max_hit    (n_max_hit),   .ped_active (n_ped_active),
        .phase_remaining(n_remaining),
        .r_left(n_r_left), .y_left(n_y_left), .g_left(n_g_left),
        .r_ped (n_r_ped),                     .g_ped (n_g_ped),
        .r_stra(n_r_stra), .y_stra(n_y_stra), .g_stra(n_g_stra)
    );

    direction_sm u_south (
        .clk        (clk),         .rst_n      (rst_n),
        .tick_1hz   (tick_1hz),    .tick_05hz  (tick_05hz),
        .enable     (ns_enable),   .chg_dir    (ns_chg_dir), .halt(halt),
        .left_req   (s_left_req),  .stra_req   (s_stra_req), .ped_req(s_pedw_req),
        .left_cars  (s_left_cars), .stra_cars  (s_stra_cars),
        .opp_lt_done(n_lt_done),
        .yellow_time(yellow_ns),   .left_max   (left_max_ns),.left_min(left_min),
        .stra_max   (stra_max_ns), .stra_min   (stra_min),
        .ped_solid  (ped_solid),   .ped_flash  (ped_flash),
        .lt_done    (s_lt_done),   .sm_idle    (s_sm_idle),
        .max_hit    (s_max_hit),   .ped_active (s_ped_active),
        .phase_remaining(s_remaining),
        .r_left(s_r_left), .y_left(s_y_left), .g_left(s_g_left),
        .r_ped (s_r_ped),                     .g_ped (s_g_ped),
        .r_stra(s_r_stra), .y_stra(s_y_stra), .g_stra(s_g_stra)
    );

    // =========================================================================
    // DIRECTION STATE MACHINES — EW GROUP
    // =========================================================================
    direction_sm u_east (
        .clk        (clk),         .rst_n      (rst_n),
        .tick_1hz   (tick_1hz),    .tick_05hz  (tick_05hz),
        .enable     (ew_enable),   .chg_dir    (ew_chg_dir), .halt(halt),
        .left_req   (e_left_req),  .stra_req   (e_stra_req), .ped_req(e_peds_req),
        .left_cars  (e_left_cars), .stra_cars  (e_stra_cars),
        .opp_lt_done(w_lt_done),
        .yellow_time(yellow_ew),   .left_max   (left_max_ew),.left_min(left_min),
        .stra_max   (stra_max_ew), .stra_min   (stra_min),
        .ped_solid  (ped_solid),   .ped_flash  (ped_flash),
        .lt_done    (e_lt_done),   .sm_idle    (e_sm_idle),
        .max_hit    (e_max_hit),   .ped_active (e_ped_active),
        .phase_remaining(e_remaining),
        .r_left(e_r_left), .y_left(e_y_left), .g_left(e_g_left),
        .r_ped (e_r_ped),                     .g_ped (e_g_ped),
        .r_stra(e_r_stra), .y_stra(e_y_stra), .g_stra(e_g_stra)
    );

    direction_sm u_west (
        .clk        (clk),         .rst_n      (rst_n),
        .tick_1hz   (tick_1hz),    .tick_05hz  (tick_05hz),
        .enable     (ew_enable),   .chg_dir    (ew_chg_dir), .halt(halt),
        .left_req   (w_left_req),  .stra_req   (w_stra_req), .ped_req(w_pedn_req),
        .left_cars  (w_left_cars), .stra_cars  (w_stra_cars),
        .opp_lt_done(e_lt_done),
        .yellow_time(yellow_ew),   .left_max   (left_max_ew),.left_min(left_min),
        .stra_max   (stra_max_ew), .stra_min   (stra_min),
        .ped_solid  (ped_solid),   .ped_flash  (ped_flash),
        .lt_done    (w_lt_done),   .sm_idle    (w_sm_idle),
        .max_hit    (w_max_hit),   .ped_active (w_ped_active),
        .phase_remaining(w_remaining),
        .r_left(w_r_left), .y_left(w_y_left), .g_left(w_g_left),
        .r_ped (w_r_ped),                     .g_ped (w_g_ped),
        .r_stra(w_r_stra), .y_stra(w_y_stra), .g_stra(w_g_stra)
    );

    // =========================================================================
    // CONFLICT MONITOR
    // =========================================================================
    conflict_monitor u_monitor (
        .n_g_left(n_g_left), .n_g_stra(n_g_stra), .n_g_ped(n_g_ped),
        .s_g_left(s_g_left), .s_g_stra(s_g_stra), .s_g_ped(s_g_ped),
        .e_g_left(e_g_left), .e_g_stra(e_g_stra), .e_g_ped(e_g_ped),
        .w_g_left(w_g_left), .w_g_stra(w_g_stra), .w_g_ped(w_g_ped),
        .system_fault(system_fault)
    );

    assign system_fault_led = system_fault;

    // =========================================================================
    // 7-SEGMENT STATE DISPLAY
    // DIG0=N, DIG1=S, DIG2=E, DIG3=W — shows phase countdown, dash when idle
    // =========================================================================
    seg_state u_seg (
        .clk       (clk),
        .rst_n     (rst_n),
        .time_N    (n_remaining),
        .time_S    (s_remaining),
        .time_E    (e_remaining),
        .time_W    (w_remaining),
        .SVNSEG_DIG(seg_dig_out),
        .SVNSEG_SEG(SVNSEG_SEG)
    );

endmodule