// =============================================================================
// request_decoder.v
// Decodes 4-bit DIP switch into 12 logical request signals
// Maintains per-lane car counters (accumulate 1 car/2s while red, drain while green)
//
// DIP encoding:
//   0000 = no request
//   0001 = S left turn     0010 = S straight     0011 = S pedestrian (W side)
//   0100 = N left turn     0101 = N straight     0110 = N pedestrian (E side)
//   0111 = E left turn     1000 = E straight     1001 = E pedestrian (S side)
//   1010 = W left turn     1011 = W straight     1100 = W pedestrian (N side)
//
// Car counter rules (per document):
//   - Accumulates 1 car every 2 ticks while request active AND direction is red
//   - Drains 1 car every 2 ticks while green light is active
//   - Request level signal held HIGH while counter > 0
//   - Saturates at MAX_CARS to prevent overflow
// =============================================================================
module request_decoder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,

    // 4-bit DIP switch value (from dip_controller)
    input  wire [3:0]  dip_val,
    input  wire        dip_valid,   // pulse when new DIP value is available

    // Green light feedback — used to drain counters
    input  wire        s_left_green, s_stra_green, s_ped_green,
    input  wire        n_left_green, n_stra_green, n_ped_green,
    input  wire        e_left_green, e_stra_green, e_ped_green,
    input  wire        w_left_green, w_stra_green, w_ped_green,

    // Request level outputs (HIGH while cars waiting)
    output wire        s_left_req, s_stra_req, s_pedw_req,
    output wire        n_left_req, n_stra_req, n_pede_req,
    output wire        e_left_req, e_stra_req, e_peds_req,
    output wire        w_left_req, w_stra_req, w_pedn_req,

    // Per-lane car counts (for direction_sm green duration calculation)
    output wire [6:0]  s_left_cars, s_stra_cars,
    output wire [6:0]  n_left_cars, n_stra_cars,
    output wire [6:0]  e_left_cars, e_stra_cars,
    output wire [6:0]  w_left_cars, w_stra_cars,

    // Aggregate car counts for SM0 priority
    output wire [6:0]  car_count_ns,
    output wire [6:0]  car_count_ew
);

    localparam MAX_CARS = 7'd20;

    // ── Car counters ──────────────────────────────────────────────────────────
    reg [6:0] cnt_s_left, cnt_s_stra, cnt_s_ped;
    reg [6:0] cnt_n_left, cnt_n_stra, cnt_n_ped;
    reg [6:0] cnt_e_left, cnt_e_stra, cnt_e_ped;
    reg [6:0] cnt_w_left, cnt_w_stra, cnt_w_ped;

    // Sub-tick: fire every 2 seconds
    reg sub_tick;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        sub_tick <= 0;
        else if (tick_1hz) sub_tick <= ~sub_tick;
    end
    wire tick_2s = tick_1hz & sub_tick;

    // ── Active request flags — set by DIP, cleared when counter drains ────────
    reg req_s_left, req_s_stra, req_s_ped;
    reg req_n_left, req_n_stra, req_n_ped;
    reg req_e_left, req_e_stra, req_e_ped;
    reg req_w_left, req_w_stra, req_w_ped;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_s_left <= 0; req_s_stra <= 0; req_s_ped <= 0;
            req_n_left <= 0; req_n_stra <= 0; req_n_ped <= 0;
            req_e_left <= 0; req_e_stra <= 0; req_e_ped <= 0;
            req_w_left <= 0; req_w_stra <= 0; req_w_ped <= 0;
        end else begin
            // Set flag on new DIP selection
            if (dip_valid) begin
                case (dip_val)
                    4'd1:  req_s_left <= 1;
                    4'd2:  req_s_stra <= 1;
                    4'd3:  req_s_ped  <= 1;
                    4'd4:  req_n_left <= 1;
                    4'd5:  req_n_stra <= 1;
                    4'd6:  req_n_ped  <= 1;
                    4'd7:  req_e_left <= 1;
                    4'd8:  req_e_stra <= 1;
                    4'd9:  req_e_ped  <= 1;
                    4'd10: req_w_left <= 1;
                    4'd11: req_w_stra <= 1;
                    4'd12: req_w_ped  <= 1;
                    default: ;
                endcase
            end
            // Clear flag when counter fully drained
            if (cnt_s_left == 0) req_s_left <= 0;
            if (cnt_s_stra == 0) req_s_stra <= 0;
            if (cnt_s_ped  == 0) req_s_ped  <= 0;
            if (cnt_n_left == 0) req_n_left <= 0;
            if (cnt_n_stra == 0) req_n_stra <= 0;
            if (cnt_n_ped  == 0) req_n_ped  <= 0;
            if (cnt_e_left == 0) req_e_left <= 0;
            if (cnt_e_stra == 0) req_e_stra <= 0;
            if (cnt_e_ped  == 0) req_e_ped  <= 0;
            if (cnt_w_left == 0) req_w_left <= 0;
            if (cnt_w_stra == 0) req_w_stra <= 0;
            if (cnt_w_ped  == 0) req_w_ped  <= 0;
        end
    end

    // ── Counter update — accumulate when red+active, drain when green ─────────
    // Inline function: clamp value between 0 and MAX_CARS
    function [6:0] update_cnt;
        input [6:0] cnt;
        input       req_active;
        input       is_green;
        begin
            if (req_active && !is_green)
                update_cnt = (cnt < MAX_CARS) ? cnt + 1 : MAX_CARS;
            else if (is_green && cnt > 0)
                update_cnt = cnt - 1;
            else
                update_cnt = cnt;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_s_left <= 0; cnt_s_stra <= 0; cnt_s_ped <= 0;
            cnt_n_left <= 0; cnt_n_stra <= 0; cnt_n_ped <= 0;
            cnt_e_left <= 0; cnt_e_stra <= 0; cnt_e_ped <= 0;
            cnt_w_left <= 0; cnt_w_stra <= 0; cnt_w_ped <= 0;
        end else if (tick_2s) begin
            cnt_s_left <= update_cnt(cnt_s_left, req_s_left, s_left_green);
            cnt_s_stra <= update_cnt(cnt_s_stra, req_s_stra, s_stra_green);
            cnt_s_ped  <= update_cnt(cnt_s_ped,  req_s_ped,  s_ped_green);
            cnt_n_left <= update_cnt(cnt_n_left, req_n_left, n_left_green);
            cnt_n_stra <= update_cnt(cnt_n_stra, req_n_stra, n_stra_green);
            cnt_n_ped  <= update_cnt(cnt_n_ped,  req_n_ped,  n_ped_green);
            cnt_e_left <= update_cnt(cnt_e_left, req_e_left, e_left_green);
            cnt_e_stra <= update_cnt(cnt_e_stra, req_e_stra, e_stra_green);
            cnt_e_ped  <= update_cnt(cnt_e_ped,  req_e_ped,  e_ped_green);
            cnt_w_left <= update_cnt(cnt_w_left, req_w_left, w_left_green);
            cnt_w_stra <= update_cnt(cnt_w_stra, req_w_stra, w_stra_green);
            cnt_w_ped  <= update_cnt(cnt_w_ped,  req_w_ped,  w_ped_green);
        end
    end

    // ── Request outputs (level) ───────────────────────────────────────────────
    assign s_left_req = (cnt_s_left > 0);
    assign s_stra_req = (cnt_s_stra > 0);
    assign s_pedw_req = (cnt_s_ped  > 0);
    assign n_left_req = (cnt_n_left > 0);
    assign n_stra_req = (cnt_n_stra > 0);
    assign n_pede_req = (cnt_n_ped  > 0);
    assign e_left_req = (cnt_e_left > 0);
    assign e_stra_req = (cnt_e_stra > 0);
    assign e_peds_req = (cnt_e_ped  > 0);
    assign w_left_req = (cnt_w_left > 0);
    assign w_stra_req = (cnt_w_stra > 0);
    assign w_pedn_req = (cnt_w_ped  > 0);

    // ── Per-lane car count outputs ────────────────────────────────────────────
    assign s_left_cars = cnt_s_left;
    assign s_stra_cars = cnt_s_stra;
    assign n_left_cars = cnt_n_left;
    assign n_stra_cars = cnt_n_stra;
    assign e_left_cars = cnt_e_left;
    assign e_stra_cars = cnt_e_stra;
    assign w_left_cars = cnt_w_left;
    assign w_stra_cars = cnt_w_stra;

    // ── Aggregate counts for SM0 priority ─────────────────────────────────────
    assign car_count_ns = cnt_n_left + cnt_n_stra + cnt_n_ped +
                          cnt_s_left + cnt_s_stra + cnt_s_ped;
    assign car_count_ew = cnt_e_left + cnt_e_stra + cnt_e_ped +
                          cnt_w_left + cnt_w_stra + cnt_w_ped;

endmodule