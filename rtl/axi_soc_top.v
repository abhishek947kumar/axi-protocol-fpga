// ============================================================================
// File: axi_soc_top.v
// Description: Top-Level AMBA AXI4 SoC Subsystem Integration.
//              Integrates AXI4 Master, 1x2 Crossbar Interconnect,
//              High-Speed AXI4 BRAM Memory Slave, AXI4-to-AXI-Lite Bridge,
//              and AXI4-Lite Control & Status Register Peripheral.
// Standard: IEEE 1364-2001 (Verilog-2001)
// ============================================================================

`timescale 1ns / 1ps
`include "axi_pkg.vh"

module axi_soc_top #(
    parameter integer C_AXI_ID_WIDTH      = 4,
    parameter integer C_AXI_ADDR_WIDTH    = 32,
    parameter integer C_AXI_DATA_WIDTH    = 32,
    parameter integer MEM_DEPTH_WORDS     = 512,
    parameter integer SLAVE_WAIT_CYCLES   = 0
)(
    input  wire                                 clk,
    input  wire                                 rst_n,

    // -------------------------------------------------------------------------
    // User / Testbench Command Interface
    // -------------------------------------------------------------------------
    input  wire                                 cmd_wr_start,
    input  wire [C_AXI_ADDR_WIDTH-1:0]          cmd_wr_addr,
    input  wire [7:0]                           cmd_wr_len,
    input  wire [2:0]                           cmd_wr_size,
    input  wire [1:0]                           cmd_wr_burst,
    input  wire [C_AXI_DATA_WIDTH-1:0]          cmd_wr_seed,
    input  wire [(C_AXI_DATA_WIDTH/8)-1:0]      cmd_wr_strb,
    output wire                                 wr_busy,
    output wire                                 wr_done,
    output wire                                 wr_error,
    output wire [1:0]                           wr_resp_code,

    input  wire                                 cmd_rd_start,
    input  wire [C_AXI_ADDR_WIDTH-1:0]          cmd_rd_addr,
    input  wire [7:0]                           cmd_rd_len,
    input  wire [2:0]                           cmd_rd_size,
    input  wire [1:0]                           cmd_rd_burst,
    output wire                                 rd_busy,
    output wire                                 rd_done,
    output wire                                 rd_error,
    output wire [1:0]                           rd_resp_code,
    output wire [C_AXI_DATA_WIDTH-1:0]          last_rd_data,
    output wire [7:0]                           rd_beat_cnt_out,

    // -------------------------------------------------------------------------
    // Hardware Diagnostics / Physical FPGA Board I/O
    // -------------------------------------------------------------------------
    output wire [3:0]                           status_leds,
    output wire [31:0]                          debug_csr_ctrl,
    output wire [31:0]                          debug_csr_scratch0,
    output wire [31:0]                          debug_csr_scratch1,
    output wire [31:0]                          debug_csr_txns
);

    // Heartbeat divider for FPGA LED visual indicator
    reg [24:0] heartbeat_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) heartbeat_cnt <= 25'd0;
        else heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end

    assign status_leds[0] = heartbeat_cnt[24]; // Heartbeat blinker
    assign status_leds[1] = wr_busy | rd_busy; // Activity indicator
    assign status_leds[2] = wr_done | rd_done; // Completion indicator
    assign status_leds[3] = wr_error | rd_error; // Error flag

    // -------------------------------------------------------------------------
    // Master to Interconnect Wires
    // -------------------------------------------------------------------------
    wire [C_AXI_ID_WIDTH-1:0]       m_awid;
    wire [C_AXI_ADDR_WIDTH-1:0]     m_awaddr;
    wire [7:0]                      m_awlen;
    wire [2:0]                      m_awsize;
    wire [1:0]                      m_awburst;
    wire                            m_awlock;
    wire [3:0]                      m_awcache;
    wire [2:0]                      m_awprot;
    wire [3:0]                      m_awqos;
    wire                            m_awvalid;
    wire                            m_awready;

    wire [C_AXI_DATA_WIDTH-1:0]     m_wdata;
    wire [(C_AXI_DATA_WIDTH/8)-1:0] m_wstrb;
    wire                            m_wlast;
    wire                            m_wvalid;
    wire                            m_wready;

    wire [C_AXI_ID_WIDTH-1:0]       m_bid;
    wire [1:0]                      m_bresp;
    wire                            m_bvalid;
    wire                            m_bready;

    wire [C_AXI_ID_WIDTH-1:0]       m_arid;
    wire [C_AXI_ADDR_WIDTH-1:0]     m_araddr;
    wire [7:0]                      m_arlen;
    wire [2:0]                      m_arsize;
    wire [1:0]                      m_arburst;
    wire                            m_arlock;
    wire [3:0]                      m_arcache;
    wire [2:0]                      m_arprot;
    wire [3:0]                      m_arqos;
    wire                            m_arvalid;
    wire                            m_arready;

    wire [C_AXI_ID_WIDTH-1:0]       m_rid;
    wire [C_AXI_DATA_WIDTH-1:0]     m_rdata;
    wire [1:0]                      m_rresp;
    wire                            m_rlast;
    wire                            m_rvalid;
    wire                            m_rready;

    // -------------------------------------------------------------------------
    // Interconnect to Slave 0 (BRAM) Wires
    // -------------------------------------------------------------------------
    wire [C_AXI_ID_WIDTH-1:0]       s0_awid;
    wire [C_AXI_ADDR_WIDTH-1:0]     s0_awaddr;
    wire [7:0]                      s0_awlen;
    wire [2:0]                      s0_awsize;
    wire [1:0]                      s0_awburst;
    wire                            s0_awlock;
    wire [3:0]                      s0_awcache;
    wire [2:0]                      s0_awprot;
    wire [3:0]                      s0_awqos;
    wire                            s0_awvalid;
    wire                            s0_awready;

    wire [C_AXI_DATA_WIDTH-1:0]     s0_wdata;
    wire [(C_AXI_DATA_WIDTH/8)-1:0] s0_wstrb;
    wire                            s0_wlast;
    wire                            s0_wvalid;
    wire                            s0_wready;

    wire [C_AXI_ID_WIDTH-1:0]       s0_bid;
    wire [1:0]                      s0_bresp;
    wire                            s0_bvalid;
    wire                            s0_bready;

    wire [C_AXI_ID_WIDTH-1:0]       s0_arid;
    wire [C_AXI_ADDR_WIDTH-1:0]     s0_araddr;
    wire [7:0]                      s0_arlen;
    wire [2:0]                      s0_arsize;
    wire [1:0]                      s0_arburst;
    wire                            s0_arlock;
    wire [3:0]                      s0_arcache;
    wire [2:0]                      s0_arprot;
    wire [3:0]                      s0_arqos;
    wire                            s0_arvalid;
    wire                            s0_arready;

    wire [C_AXI_ID_WIDTH-1:0]       s0_rid;
    wire [C_AXI_DATA_WIDTH-1:0]     s0_rdata;
    wire [1:0]                      s0_rresp;
    wire                            s0_rlast;
    wire                            s0_rvalid;
    wire                            s0_rready;

    // -------------------------------------------------------------------------
    // Interconnect to Slave 1 (Bridge) Wires
    // -------------------------------------------------------------------------
    wire [C_AXI_ID_WIDTH-1:0]       s1_awid;
    wire [C_AXI_ADDR_WIDTH-1:0]     s1_awaddr;
    wire [7:0]                      s1_awlen;
    wire [2:0]                      s1_awsize;
    wire [1:0]                      s1_awburst;
    wire                            s1_awlock;
    wire [3:0]                      s1_awcache;
    wire [2:0]                      s1_awprot;
    wire [3:0]                      s1_awqos;
    wire                            s1_awvalid;
    wire                            s1_awready;

    wire [C_AXI_DATA_WIDTH-1:0]     s1_wdata;
    wire [(C_AXI_DATA_WIDTH/8)-1:0] s1_wstrb;
    wire                            s1_wlast;
    wire                            s1_wvalid;
    wire                            s1_wready;

    wire [C_AXI_ID_WIDTH-1:0]       s1_bid;
    wire [1:0]                      s1_bresp;
    wire                            s1_bvalid;
    wire                            s1_bready;

    wire [C_AXI_ID_WIDTH-1:0]       s1_arid;
    wire [C_AXI_ADDR_WIDTH-1:0]     s1_araddr;
    wire [7:0]                      s1_arlen;
    wire [2:0]                      s1_arsize;
    wire [1:0]                      s1_arburst;
    wire                            s1_arlock;
    wire [3:0]                      s1_arcache;
    wire [2:0]                      s1_arprot;
    wire [3:0]                      s1_arqos;
    wire                            s1_arvalid;
    wire                            s1_arready;

    wire [C_AXI_ID_WIDTH-1:0]       s1_rid;
    wire [C_AXI_DATA_WIDTH-1:0]     s1_rdata;
    wire [1:0]                      s1_rresp;
    wire                            s1_rlast;
    wire                            s1_rvalid;
    wire                            s1_rready;

    // -------------------------------------------------------------------------
    // Bridge to AXI4-Lite Register Slave Wires
    // -------------------------------------------------------------------------
    wire [C_AXI_ADDR_WIDTH-1:0]     axil_awaddr;
    wire [2:0]                      axil_awprot;
    wire                            axil_awvalid;
    wire                            axil_awready;

    wire [C_AXI_DATA_WIDTH-1:0]     axil_wdata;
    wire [(C_AXI_DATA_WIDTH/8)-1:0] axil_wstrb;
    wire                            axil_wvalid;
    wire                            axil_wready;

    wire [1:0]                      axil_bresp;
    wire                            axil_bvalid;
    wire                            axil_bready;

    wire [C_AXI_ADDR_WIDTH-1:0]     axil_araddr;
    wire [2:0]                      axil_arprot;
    wire                            axil_arvalid;
    wire                            axil_arready;

    wire [C_AXI_DATA_WIDTH-1:0]     axil_rdata;
    wire [1:0]                      axil_rresp;
    wire                            axil_rvalid;
    wire                            axil_rready;

    // -------------------------------------------------------------------------
    // Instantiate AXI4 Master
    // -------------------------------------------------------------------------
    axi4_master #(
        .C_M_AXI_ID_WIDTH   (C_AXI_ID_WIDTH),
        .C_M_AXI_ADDR_WIDTH (C_AXI_ADDR_WIDTH),
        .C_M_AXI_DATA_WIDTH (C_AXI_DATA_WIDTH),
        .MASTER_ID          (4'h1)
    ) u_axi_master (
        .aclk               (clk),
        .aresetn            (rst_n),
        .cmd_wr_start       (cmd_wr_start),
        .cmd_wr_addr        (cmd_wr_addr),
        .cmd_wr_len         (cmd_wr_len),
        .cmd_wr_size        (cmd_wr_size),
        .cmd_wr_burst       (cmd_wr_burst),
        .cmd_wr_seed        (cmd_wr_seed),
        .cmd_wr_strb        (cmd_wr_strb),
        .wr_busy            (wr_busy),
        .wr_done            (wr_done),
        .wr_error           (wr_error),
        .wr_resp_code       (wr_resp_code),

        .cmd_rd_start       (cmd_rd_start),
        .cmd_rd_addr        (cmd_rd_addr),
        .cmd_rd_len         (cmd_rd_len),
        .cmd_rd_size        (cmd_rd_size),
        .cmd_rd_burst       (cmd_rd_burst),
        .rd_busy            (rd_busy),
        .rd_done            (rd_done),
        .rd_error           (rd_error),
        .rd_resp_code       (rd_resp_code),
        .last_rd_data       (last_rd_data),
        .rd_beat_cnt_out    (rd_beat_cnt_out),

        .m_axi_awid         (m_awid),
        .m_axi_awaddr       (m_awaddr),
        .m_axi_awlen        (m_awlen),
        .m_axi_awsize       (m_awsize),
        .m_axi_awburst      (m_awburst),
        .m_axi_awlock       (m_awlock),
        .m_axi_awcache      (m_awcache),
        .m_axi_awprot       (m_awprot),
        .m_axi_awqos        (m_awqos),
        .m_axi_awvalid      (m_awvalid),
        .m_axi_awready      (m_awready),

        .m_axi_wdata        (m_wdata),
        .m_axi_wstrb        (m_wstrb),
        .m_axi_wlast        (m_wlast),
        .m_axi_wvalid       (m_wvalid),
        .m_axi_wready       (m_wready),

        .m_axi_bid          (m_bid),
        .m_axi_bresp        (m_bresp),
        .m_axi_bvalid       (m_bvalid),
        .m_axi_bready       (m_bready),

        .m_axi_arid         (m_arid),
        .m_axi_araddr       (m_araddr),
        .m_axi_arlen        (m_arlen),
        .m_axi_arsize       (m_arsize),
        .m_axi_arburst      (m_arburst),
        .m_axi_arlock       (m_arlock),
        .m_axi_arcache      (m_arcache),
        .m_axi_arprot       (m_arprot),
        .m_axi_arqos        (m_arqos),
        .m_axi_arvalid      (m_arvalid),
        .m_axi_arready      (m_arready),

        .m_axi_rid          (m_rid),
        .m_axi_rdata        (m_rdata),
        .m_axi_rresp        (m_rresp),
        .m_axi_rlast        (m_rlast),
        .m_axi_rvalid       (m_rvalid),
        .m_axi_rready       (m_rready)
    );

    // -------------------------------------------------------------------------
    // Instantiate 1x2 AXI4 Interconnect Crossbar
    // -------------------------------------------------------------------------
    axi4_interconnect_1x2 #(
        .C_AXI_ID_WIDTH     (C_AXI_ID_WIDTH),
        .C_AXI_ADDR_WIDTH   (C_AXI_ADDR_WIDTH),
        .C_AXI_DATA_WIDTH   (C_AXI_DATA_WIDTH)
    ) u_interconnect (
        .aclk               (clk),
        .aresetn            (rst_n),

        // Slave Port (from Master)
        .s_axi_awid         (m_awid),
        .s_axi_awaddr       (m_awaddr),
        .s_axi_awlen        (m_awlen),
        .s_axi_awsize       (m_awsize),
        .s_axi_awburst      (m_awburst),
        .s_axi_awlock       (m_awlock),
        .s_axi_awcache      (m_awcache),
        .s_axi_awprot       (m_awprot),
        .s_axi_awqos        (m_awqos),
        .s_axi_awvalid      (m_awvalid),
        .s_axi_awready      (m_awready),

        .s_axi_wdata        (m_wdata),
        .s_axi_wstrb        (m_wstrb),
        .s_axi_wlast        (m_wlast),
        .s_axi_wvalid       (m_wvalid),
        .s_axi_wready       (m_wready),

        .s_axi_bid          (m_bid),
        .s_axi_bresp        (m_bresp),
        .s_axi_bvalid       (m_bvalid),
        .s_axi_bready       (m_bready),

        .s_axi_arid         (m_arid),
        .s_axi_araddr       (m_araddr),
        .s_axi_arlen        (m_arlen),
        .s_axi_arsize       (m_arsize),
        .s_axi_arburst      (m_arburst),
        .s_axi_arlock       (m_arlock),
        .s_axi_arcache      (m_arcache),
        .s_axi_arprot       (m_arprot),
        .s_axi_arqos        (m_arqos),
        .s_axi_arvalid      (m_arvalid),
        .s_axi_arready      (m_arready),

        .s_axi_rid          (m_rid),
        .s_axi_rdata        (m_rdata),
        .s_axi_rresp        (m_rresp),
        .s_axi_rlast        (m_rlast),
        .s_axi_rvalid       (m_rvalid),
        .s_axi_rready       (m_rready),

        // Master 0 (to Slave 0: BRAM)
        .m00_axi_awid       (s0_awid),
        .m00_axi_awaddr     (s0_awaddr),
        .m00_axi_awlen      (s0_awlen),
        .m00_axi_awsize     (s0_awsize),
        .m00_axi_awburst    (s0_awburst),
        .m00_axi_awlock     (s0_awlock),
        .m00_axi_awcache    (s0_awcache),
        .m00_axi_awprot     (s0_awprot),
        .m00_axi_awqos      (s0_awqos),
        .m00_axi_awvalid    (s0_awvalid),
        .m00_axi_awready    (s0_awready),

        .m00_axi_wdata      (s0_wdata),
        .m00_axi_wstrb      (s0_wstrb),
        .m00_axi_wlast      (s0_wlast),
        .m00_axi_wvalid     (s0_wvalid),
        .m00_axi_wready     (s0_wready),

        .m00_axi_bid        (s0_bid),
        .m00_axi_bresp      (s0_bresp),
        .m00_axi_bvalid     (s0_bvalid),
        .m00_axi_bready     (s0_bready),

        .m00_axi_arid       (s0_arid),
        .m00_axi_araddr     (s0_araddr),
        .m00_axi_arlen      (s0_arlen),
        .m00_axi_arsize     (s0_arsize),
        .m00_axi_arburst    (s0_arburst),
        .m00_axi_arlock     (s0_arlock),
        .m00_axi_arcache    (s0_arcache),
        .m00_axi_arprot     (s0_arprot),
        .m00_axi_arqos      (s0_arqos),
        .m00_axi_arvalid    (s0_arvalid),
        .m00_axi_arready    (s0_arready),

        .m00_axi_rid        (s0_rid),
        .m00_axi_rdata      (s0_rdata),
        .m00_axi_rresp      (s0_rresp),
        .m00_axi_rlast      (s0_rlast),
        .m00_axi_rvalid     (s0_rvalid),
        .m00_axi_rready     (s0_rready),

        // Master 1 (to Slave 1: Bridge)
        .m01_axi_awid       (s1_awid),
        .m01_axi_awaddr     (s1_awaddr),
        .m01_axi_awlen      (s1_awlen),
        .m01_axi_awsize     (s1_awsize),
        .m01_axi_awburst    (s1_awburst),
        .m01_axi_awlock     (s1_awlock),
        .m01_axi_awcache    (s1_awcache),
        .m01_axi_awprot     (s1_awprot),
        .m01_axi_awqos      (s1_awqos),
        .m01_axi_awvalid    (s1_awvalid),
        .m01_axi_awready    (s1_awready),

        .m01_axi_wdata      (s1_wdata),
        .m01_axi_wstrb      (s1_wstrb),
        .m01_axi_wlast      (s1_wlast),
        .m01_axi_wvalid     (s1_wvalid),
        .m01_axi_wready     (s1_wready),

        .m01_axi_bid        (s1_bid),
        .m01_axi_bresp      (s1_bresp),
        .m01_axi_bvalid     (s1_bvalid),
        .m01_axi_bready     (s1_bready),

        .m01_axi_arid       (s1_arid),
        .m01_axi_araddr     (s1_araddr),
        .m01_axi_arlen      (s1_arlen),
        .m01_axi_arsize     (s1_arsize),
        .m01_axi_arburst    (s1_arburst),
        .m01_axi_arlock     (s1_arlock),
        .m01_axi_arcache    (s1_arcache),
        .m01_axi_arprot     (s1_arprot),
        .m01_axi_arqos      (s1_arqos),
        .m01_axi_arvalid    (s1_arvalid),
        .m01_axi_arready    (s1_arready),

        .m01_axi_rid        (s1_rid),
        .m01_axi_rdata      (s1_rdata),
        .m01_axi_rresp      (s1_rresp),
        .m01_axi_rlast      (s1_rlast),
        .m01_axi_rvalid     (s1_rvalid),
        .m01_axi_rready     (s1_rready)
    );

    // -------------------------------------------------------------------------
    // Instantiate Slave 0: High-Speed AXI4 BRAM Memory
    // -------------------------------------------------------------------------
    axi4_slave_bram #(
        .C_S_AXI_ID_WIDTH   (C_AXI_ID_WIDTH),
        .C_S_AXI_DATA_WIDTH (C_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH (C_AXI_ADDR_WIDTH),
        .MEM_DEPTH_WORDS    (MEM_DEPTH_WORDS),
        .C_SLV_WAIT_CYCLES  (SLAVE_WAIT_CYCLES)
    ) u_bram_slave (
        .aclk               (clk),
        .aresetn            (rst_n),

        .s_axi_awid         (s0_awid),
        .s_axi_awaddr       (s0_awaddr),
        .s_axi_awlen        (s0_awlen),
        .s_axi_awsize       (s0_awsize),
        .s_axi_awburst      (s0_awburst),
        .s_axi_awlock       (s0_awlock),
        .s_axi_awcache      (s0_awcache),
        .s_axi_awprot       (s0_awprot),
        .s_axi_awqos        (s0_awqos),
        .s_axi_awvalid      (s0_awvalid),
        .s_axi_awready      (s0_awready),

        .s_axi_wdata        (s0_wdata),
        .s_axi_wstrb        (s0_wstrb),
        .s_axi_wlast        (s0_wlast),
        .s_axi_wvalid       (s0_wvalid),
        .s_axi_wready       (s0_wready),

        .s_axi_bid          (s0_bid),
        .s_axi_bresp        (s0_bresp),
        .s_axi_bvalid       (s0_bvalid),
        .s_axi_bready       (s0_bready),

        .s_axi_arid         (s0_arid),
        .s_axi_araddr       (s0_araddr),
        .s_axi_arlen        (s0_arlen),
        .s_axi_arsize       (s0_arsize),
        .s_axi_arburst      (s0_arburst),
        .s_axi_arlock       (s0_arlock),
        .s_axi_arcache      (s0_arcache),
        .s_axi_arprot       (s0_arprot),
        .s_axi_arqos        (s0_arqos),
        .s_axi_arvalid      (s0_arvalid),
        .s_axi_arready      (s0_arready),

        .s_axi_rid          (s0_rid),
        .s_axi_rdata        (s0_rdata),
        .s_axi_rresp        (s0_rresp),
        .s_axi_rlast        (s0_rlast),
        .s_axi_rvalid       (s0_rvalid),
        .s_axi_rready       (s0_rready)
    );

    // -------------------------------------------------------------------------
    // Instantiate AXI4 to AXI4-Lite Protocol Bridge
    // -------------------------------------------------------------------------
    axi4_to_axilite_bridge #(
        .C_AXI_ID_WIDTH     (C_AXI_ID_WIDTH),
        .C_AXI_ADDR_WIDTH   (C_AXI_ADDR_WIDTH),
        .C_AXI_DATA_WIDTH   (C_AXI_DATA_WIDTH)
    ) u_bridge (
        .aclk               (clk),
        .aresetn            (rst_n),

        .s_axi_awid         (s1_awid),
        .s_axi_awaddr       (s1_awaddr),
        .s_axi_awlen        (s1_awlen),
        .s_axi_awsize       (s1_awsize),
        .s_axi_awburst      (s1_awburst),
        .s_axi_awlock       (s1_awlock),
        .s_axi_awcache      (s1_awcache),
        .s_axi_awprot       (s1_awprot),
        .s_axi_awqos        (s1_awqos),
        .s_axi_awvalid      (s1_awvalid),
        .s_axi_awready      (s1_awready),

        .s_axi_wdata        (s1_wdata),
        .s_axi_wstrb        (s1_wstrb),
        .s_axi_wlast        (s1_wlast),
        .s_axi_wvalid       (s1_wvalid),
        .s_axi_wready       (s1_wready),

        .s_axi_bid          (s1_bid),
        .s_axi_bresp        (s1_bresp),
        .s_axi_bvalid       (s1_bvalid),
        .s_axi_bready       (s1_bready),

        .s_axi_arid         (s1_arid),
        .s_axi_araddr       (s1_araddr),
        .s_axi_arlen        (s1_arlen),
        .s_axi_arsize       (s1_arsize),
        .s_axi_arburst      (s1_arburst),
        .s_axi_arlock       (s1_arlock),
        .s_axi_arcache      (s1_arcache),
        .s_axi_arprot       (s1_arprot),
        .s_axi_arqos        (s1_arqos),
        .s_axi_arvalid      (s1_arvalid),
        .s_axi_arready      (s1_arready),

        .s_axi_rid          (s1_rid),
        .s_axi_rdata        (s1_rdata),
        .s_axi_rresp        (s1_rresp),
        .s_axi_rlast        (s1_rlast),
        .s_axi_rvalid       (s1_rvalid),
        .s_axi_rready       (s1_rready),

        // Downstream AXI-Lite
        .m_axil_awaddr      (axil_awaddr),
        .m_axil_awprot      (axil_awprot),
        .m_axil_awvalid     (axil_awvalid),
        .m_axil_awready     (axil_awready),

        .m_axil_wdata       (axil_wdata),
        .m_axil_wstrb       (axil_wstrb),
        .m_axil_wvalid      (axil_wvalid),
        .m_axil_wready      (axil_wready),

        .m_axil_bresp       (axil_bresp),
        .m_axil_bvalid      (axil_bvalid),
        .m_axil_bready      (axil_bready),

        .m_axil_araddr      (axil_araddr),
        .m_axil_arprot      (axil_arprot),
        .m_axil_arvalid     (axil_arvalid),
        .m_axil_arready     (axil_arready),

        .m_axil_rdata       (axil_rdata),
        .m_axil_rresp       (axil_rresp),
        .m_axil_rvalid      (axil_rvalid),
        .m_axil_rready      (axil_rready)
    );

    // -------------------------------------------------------------------------
    // Instantiate Slave 1: AXI4-Lite Control & Status Register Peripheral
    // -------------------------------------------------------------------------
    wire [31:0] hw_status_signals = {
        28'h0,
        rd_error,
        wr_error,
        rd_done | wr_done,
        rd_busy | wr_busy
    };

    axi4_lite_slave_reg #(
        .C_S_AXI_DATA_WIDTH (C_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH (C_AXI_ADDR_WIDTH)
    ) u_axil_reg_slave (
        .aclk               (clk),
        .aresetn            (rst_n),

        .s_axi_awaddr       (axil_awaddr),
        .s_axi_awprot       (axil_awprot),
        .s_axi_awvalid      (axil_awvalid),
        .s_axi_awready      (axil_awready),

        .s_axi_wdata        (axil_wdata),
        .s_axi_wstrb        (axil_wstrb),
        .s_axi_wvalid       (axil_wvalid),
        .s_axi_wready       (axil_wready),

        .s_axi_bresp        (axil_bresp),
        .s_axi_bvalid       (axil_bvalid),
        .s_axi_bready       (axil_bready),

        .s_axi_araddr       (axil_araddr),
        .s_axi_arprot       (axil_arprot),
        .s_axi_arvalid      (axil_arvalid),
        .s_axi_arready      (axil_arready),

        .s_axi_rdata        (axil_rdata),
        .s_axi_rresp        (axil_rresp),
        .s_axi_rvalid       (axil_rvalid),
        .s_axi_rready       (axil_rready),

        .o_ctrl_reg         (debug_csr_ctrl),
        .i_status_reg       (hw_status_signals),
        .o_scratch0         (debug_csr_scratch0),
        .o_scratch1         (debug_csr_scratch1),
        .o_txn_cnt          (debug_csr_txns)
    );

endmodule
