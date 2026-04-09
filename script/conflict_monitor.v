// =============================================================================
// conflict_monitor.v
// Purely combinational safety watchdog
// Monitors all 12 green output signals across 4 directions
// Asserts system_fault immediately if any conflicting pair is active
//
// Conflict rules:
//   1. Any NS vehicle green  vs any EW vehicle green
//   2. Any NS pedestrian     vs any EW vehicle green
//   3. Any EW pedestrian     vs any NS vehicle green
//   4. NS pedestrian         vs EW pedestrian (both crossing simultaneously)
// =============================================================================
module conflict_monitor (
    // North
    input  wire n_g_left, n_g_stra, n_g_ped,
    // South
    input  wire s_g_left, s_g_stra, s_g_ped,
    // East
    input  wire e_g_left, e_g_stra, e_g_ped,
    // West
    input  wire w_g_left, w_g_stra, w_g_ped,

    output wire system_fault
);

    wire ns_veh = n_g_left | n_g_stra | s_g_left | s_g_stra;
    wire ew_veh = e_g_left | e_g_stra | w_g_left | w_g_stra;
    wire ns_ped = n_g_ped  | s_g_ped;
    wire ew_ped = e_g_ped  | w_g_ped;

    wire c1 = ns_veh & ew_veh;   // NS vehicle vs EW vehicle
    wire c2 = ns_ped & ew_veh;   // NS pedestrian vs EW vehicle
    wire c3 = ew_ped & ns_veh;   // EW pedestrian vs NS vehicle
    wire c4 = ns_ped & ew_ped;   // both pedestrians crossing

    assign system_fault = c1 | c2 | c3 | c4;

endmodule