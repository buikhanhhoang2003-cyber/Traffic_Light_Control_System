// =============================================================================
// config_regs.v
// Programmable timing configuration registers
// Uses shadow + active register pattern:
//   - Shadow registers accept writes any time
//   - Active registers latch shadow values only when halt=1 (all SMs idle)
//
// Register map (cfg_addr):
//   0x00 : yellow_ns    — yellow duration NS axis       (default 3s)
//   0x01 : yellow_ew    — yellow duration EW axis       (default 3s)
//   0x02 : left_max_ns  — max left turn green NS        (default 9s)
//   0x03 : left_max_ew  — max left turn green EW        (default 9s)
//   0x04 : stra_max_ns  — max straight green NS         (default 9s)
//   0x05 : stra_max_ew  — max straight green EW         (default 9s)
//   0x06 : stra_min     — min straight green all dirs   (default 2s)
//   0x07 : left_min     — min left turn green all dirs  (default 2s)
//   0x08 : ped_solid    — pedestrian solid green        (default 4s)
//   0x09 : ped_flash    — pedestrian flash green        (default 5s)
// =============================================================================
module config_regs (
    input  wire        clk,
    input  wire        rst_n,

    // Write interface
    input  wire [3:0]  cfg_addr,
    input  wire [7:0]  cfg_data,
    input  wire        cfg_we,      // write enable — 1-cycle pulse

    // Halt from SM0 — new config takes effect only when asserted
    input  wire        halt,

    // Active configuration outputs
    output reg  [7:0]  yellow_ns,
    output reg  [7:0]  yellow_ew,
    output reg  [7:0]  left_max_ns,
    output reg  [7:0]  left_max_ew,
    output reg  [7:0]  stra_max_ns,
    output reg  [7:0]  stra_max_ew,
    output reg  [7:0]  stra_min,
    output reg  [7:0]  left_min,
    output reg  [7:0]  ped_solid,
    output reg  [7:0]  ped_flash
);

    // ── Shadow registers — accept writes any time ─────────────────────────────
    reg [7:0] shadow [0:9];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shadow[0] <= 8'd3;   // yellow_ns
            shadow[1] <= 8'd3;   // yellow_ew
            shadow[2] <= 8'd9;   // left_max_ns
            shadow[3] <= 8'd9;   // left_max_ew
            shadow[4] <= 8'd9;   // stra_max_ns
            shadow[5] <= 8'd9;   // stra_max_ew
            shadow[6] <= 8'd2;   // stra_min
            shadow[7] <= 8'd2;   // left_min
            shadow[8] <= 8'd4;   // ped_solid
            shadow[9] <= 8'd5;   // ped_flash
        end else if (cfg_we && cfg_addr <= 4'd9) begin
            shadow[cfg_addr] <= cfg_data;
        end
    end

    // ── Active registers — latch shadow only when all SMs idle (halt=1) ───────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            yellow_ns   <= 8'd3;
            yellow_ew   <= 8'd3;
            left_max_ns <= 8'd9;
            left_max_ew <= 8'd9;
            stra_max_ns <= 8'd9;
            stra_max_ew <= 8'd9;
            stra_min    <= 8'd2;
            left_min    <= 8'd2;
            ped_solid   <= 8'd4;
            ped_flash   <= 8'd5;
        end else if (halt) begin
            yellow_ns   <= shadow[0];
            yellow_ew   <= shadow[1];
            left_max_ns <= shadow[2];
            left_max_ew <= shadow[3];
            stra_max_ns <= shadow[4];
            stra_max_ew <= shadow[5];
            stra_min    <= shadow[6];
            left_min    <= shadow[7];
            ped_solid   <= shadow[8];
            ped_flash   <= shadow[9];
        end
    end

endmodule