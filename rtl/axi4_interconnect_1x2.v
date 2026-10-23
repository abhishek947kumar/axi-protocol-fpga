// ============================================================================
// File: axi4_interconnect_1x2.v
// Description: AMBA AXI4 1-Master to 2-Slave Crossbar Interconnect.
//              Routes memory accesses to Slave 0 (High-Speed BRAM),
//              peripheral accesses to Slave 1 (CSRs via Bridge),
//              and features an internal DECERR responder for unmapped ranges.
// Standard: IEEE 1364-2001 (Verilog-2001)
// ============================================================================

`timescale 1ns / 1ps
`include "axi_pkg.vh"

module axi4_interconnect_1x2 #(
    parameter integer C_AXI_ID_WIDTH   = 4,
    parameter integer C_AXI_ADDR_WIDTH = 32,
    parameter integer C_AXI_DATA_WIDTH = 32
)(
    input  wire                                 aclk,
    input  wire                                 aresetn,

    // -------------------------------------------------------------------------
    // Slave Interface (Connected to AXI4 Master)
    // -------------------------------------------------------------------------
    input  wire [C_AXI_ID_WIDTH-1:0]            s_axi_awid,
    input  wire [C_AXI_ADDR_WIDTH-1:0]          s_axi_awaddr,
    input  wire [7:0]                           s_axi_awlen,
    input  wire [2:0]                           s_axi_awsize,
    input  wire [1:0]                           s_axi_awburst,
    input  wire                                 s_axi_awlock,
    input  wire [3:0]                           s_axi_awcache,
    input  wire [2:0]                           s_axi_awprot,
    input  wire [3:0]                           s_axi_awqos,
    input  wire                                 s_axi_awvalid,
    output reg                                  s_axi_awready,

    input  wire [C_AXI_DATA_WIDTH-1:0]          s_axi_wdata,
    input  wire [(C_AXI_DATA_WIDTH/8)-1:0]      s_axi_wstrb,
    input  wire                                 s_axi_wlast,
    input  wire                                 s_axi_wvalid,
    output reg                                  s_axi_wready,

    output reg  [C_AXI_ID_WIDTH-1:0]            s_axi_bid,
    output reg  [1:0]                           s_axi_bresp,
    output reg                                  s_axi_bvalid,
    input  wire                                 s_axi_bready,

    input  wire [C_AXI_ID_WIDTH-1:0]            s_axi_arid,
    input  wire [C_AXI_ADDR_WIDTH-1:0]          s_axi_araddr,
    input  wire [7:0]                           s_axi_arlen,
    input  wire [2:0]                           s_axi_arsize,
    input  wire [1:0]                           s_axi_arburst,
    input  wire                                 s_axi_arlock,
    input  wire [3:0]                           s_axi_arcache,
    input  wire [2:0]                           s_axi_arprot,
    input  wire [3:0]                           s_axi_arqos,
    input  wire                                 s_axi_arvalid,
    output reg                                  s_axi_arready,

    output reg  [C_AXI_ID_WIDTH-1:0]            s_axi_rid,
    output reg  [C_AXI_DATA_WIDTH-1:0]          s_axi_rdata,
    output reg  [1:0]                           s_axi_rresp,
    output reg                                  s_axi_rlast,
    output reg                                  s_axi_rvalid,
    input  wire                                 s_axi_rready,

    // -------------------------------------------------------------------------
    // Master Interface 0 (Connected to Slave 0: BRAM Memory)
    // -------------------------------------------------------------------------
    output wire [C_AXI_ID_WIDTH-1:0]            m00_axi_awid,
    output wire [C_AXI_ADDR_WIDTH-1:0]          m00_axi_awaddr,
    output wire [7:0]                           m00_axi_awlen,
    output wire [2:0]                           m00_axi_awsize,
    output wire [1:0]                           m00_axi_awburst,
    output wire                                 m00_axi_awlock,
    output wire [3:0]                           m00_axi_awcache,
    output wire [2:0]                           m00_axi_awprot,
    output wire [3:0]                           m00_axi_awqos,
    output wire                                 m00_axi_awvalid,
    input  wire                                 m00_axi_awready,

    output wire [C_AXI_DATA_WIDTH-1:0]          m00_axi_wdata,
    output wire [(C_AXI_DATA_WIDTH/8)-1:0]      m00_axi_wstrb,
    output wire                                 m00_axi_wlast,
    output wire                                 m00_axi_wvalid,
    input  wire                                 m00_axi_wready,

    input  wire [C_AXI_ID_WIDTH-1:0]            m00_axi_bid,
    input  wire [1:0]                           m00_axi_bresp,
    input  wire                                 m00_axi_bvalid,
    output wire                                 m00_axi_bready,

    output wire [C_AXI_ID_WIDTH-1:0]            m00_axi_arid,
    output wire [C_AXI_ADDR_WIDTH-1:0]          m00_axi_araddr,
    output wire [7:0]                           m00_axi_arlen,
    output wire [2:0]                           m00_axi_arsize,
    output wire [1:0]                           m00_axi_arburst,
    output wire                                 m00_axi_arlock,
    output wire [3:0]                           m00_axi_arcache,
    output wire [2:0]                           m00_axi_arprot,
    output wire [3:0]                           m00_axi_arqos,
    output wire                                 m00_axi_arvalid,
    input  wire                                 m00_axi_arready,

    input  wire [C_AXI_ID_WIDTH-1:0]            m00_axi_rid,
    input  wire [C_AXI_DATA_WIDTH-1:0]          m00_axi_rdata,
    input  wire [1:0]                           m00_axi_rresp,
    input  wire                                 m00_axi_rlast,
    input  wire                                 m00_axi_rvalid,
    output wire                                 m00_axi_rready,

    // -------------------------------------------------------------------------
    // Master Interface 1 (Connected to Slave 1: CSR Peripheral Bridge)
    // -------------------------------------------------------------------------
    output wire [C_AXI_ID_WIDTH-1:0]            m01_axi_awid,
    output wire [C_AXI_ADDR_WIDTH-1:0]          m01_axi_awaddr,
    output wire [7:0]                           m01_axi_awlen,
    output wire [2:0]                           m01_axi_awsize,
    output wire [1:0]                           m01_axi_awburst,
    output wire                                 m01_axi_awlock,
    output wire [3:0]                           m01_axi_awcache,
    output wire [2:0]                           m01_axi_awprot,
    output wire [3:0]                           m01_axi_awqos,
    output wire                                 m01_axi_awvalid,
    input  wire                                 m01_axi_awready,

    output wire [C_AXI_DATA_WIDTH-1:0]          m01_axi_wdata,
    output wire [(C_AXI_DATA_WIDTH/8)-1:0]      m01_axi_wstrb,
    output wire                                 m01_axi_wlast,
    output wire                                 m01_axi_wvalid,
    input  wire                                 m01_axi_wready,

    input  wire [C_AXI_ID_WIDTH-1:0]            m01_axi_bid,
    input  wire [1:0]                           m01_axi_bresp,
    input  wire                                 m01_axi_bvalid,
    output wire                                 m01_axi_bready,

    output wire [C_AXI_ID_WIDTH-1:0]            m01_axi_arid,
    output wire [C_AXI_ADDR_WIDTH-1:0]          m01_axi_araddr,
    output wire [7:0]                           m01_axi_arlen,
    output wire [2:0]                           m01_axi_arsize,
    output wire [1:0]                           m01_axi_arburst,
    output wire                                 m01_axi_arlock,
    output wire [3:0]                           m01_axi_arcache,
    output wire [2:0]                           m01_axi_arprot,
    output wire [3:0]                           m01_axi_arqos,
    output wire                                 m01_axi_arvalid,
    input  wire                                 m01_axi_arready,

    input  wire [C_AXI_ID_WIDTH-1:0]            m01_axi_rid,
    input  wire [C_AXI_DATA_WIDTH-1:0]          m01_axi_rdata,
    input  wire [1:0]                           m01_axi_rresp,
    input  wire                                 m01_axi_rlast,
    input  wire                                 m01_axi_rvalid,
    output wire                                 m01_axi_rready
);

    // -------------------------------------------------------------------------
    // Address Decoding Definitions
    // -------------------------------------------------------------------------
    localparam ROUTE_SLV0   = 2'b00; // BRAM
    localparam ROUTE_SLV1   = 2'b01; // CSR Peripheral
    localparam ROUTE_DECERR = 2'b10; // Unmapped decode error

    function [1:0] decode_addr;
        input [C_AXI_ADDR_WIDTH-1:0] addr;
        begin
            if (addr >= `AXI_ADDR_SLV0_BASE && addr <= `AXI_ADDR_SLV0_HIGH)
                decode_addr = ROUTE_SLV0;
            else if (addr >= `AXI_ADDR_SLV1_BASE && addr <= `AXI_ADDR_SLV1_HIGH)
                decode_addr = ROUTE_SLV1;
            else
                decode_addr = ROUTE_DECERR;
        end
    endfunction

    // -------------------------------------------------------------------------
    // Write Channel Arbitration & Routing
    // -------------------------------------------------------------------------
    localparam [1:0]
        W_ROUTE_IDLE = 2'b00,
        W_ROUTE_DATA = 2'b01,
        W_ROUTE_RESP = 2'b10;

    reg [1:0] w_route_state;
    reg [1:0] wr_target_slave;
    reg [C_AXI_ID_WIDTH-1:0] wr_saved_id;

    // Internal DECERR Write Responder
    reg        decerr_awready;
    reg        decerr_wready;
    reg        decerr_bvalid;
    reg [C_AXI_ID_WIDTH-1:0] decerr_bid;

    wire is_aw_slv0 = (decode_addr(s_axi_awaddr) == ROUTE_SLV0);
    wire is_aw_slv1 = (decode_addr(s_axi_awaddr) == ROUTE_SLV1);
    wire is_aw_dec  = (decode_addr(s_axi_awaddr) == ROUTE_DECERR);

    assign m00_axi_awid    = s_axi_awid;
    assign m00_axi_awaddr  = s_axi_awaddr;
    assign m00_axi_awlen   = s_axi_awlen;
    assign m00_axi_awsize  = s_axi_awsize;
    assign m00_axi_awburst = s_axi_awburst;
    assign m00_axi_awlock  = s_axi_awlock;
    assign m00_axi_awcache = s_axi_awcache;
    assign m00_axi_awprot  = s_axi_awprot;
    assign m00_axi_awqos   = s_axi_awqos;
    assign m00_axi_awvalid = (w_route_state == W_ROUTE_IDLE) && s_axi_awvalid && is_aw_slv0;

    assign m01_axi_awid    = s_axi_awid;
    assign m01_axi_awaddr  = s_axi_awaddr;
    assign m01_axi_awlen   = s_axi_awlen;
    assign m01_axi_awsize  = s_axi_awsize;
    assign m01_axi_awburst = s_axi_awburst;
    assign m01_axi_awlock  = s_axi_awlock;
    assign m01_axi_awcache = s_axi_awcache;
    assign m01_axi_awprot  = s_axi_awprot;
    assign m01_axi_awqos   = s_axi_awqos;
    assign m01_axi_awvalid = (w_route_state == W_ROUTE_IDLE) && s_axi_awvalid && is_aw_slv1;

    // Write Data Forwarding
    assign m00_axi_wdata   = s_axi_wdata;
    assign m00_axi_wstrb   = s_axi_wstrb;
    assign m00_axi_wlast   = s_axi_wlast;
    assign m00_axi_wvalid  = (w_route_state == W_ROUTE_DATA) && (wr_target_slave == ROUTE_SLV0) && s_axi_wvalid;

    assign m01_axi_wdata   = s_axi_wdata;
    assign m01_axi_wstrb   = s_axi_wstrb;
    assign m01_axi_wlast   = s_axi_wlast;
    assign m01_axi_wvalid  = (w_route_state == W_ROUTE_DATA) && (wr_target_slave == ROUTE_SLV1) && s_axi_wvalid;

    // Write Response Forwarding
    assign m00_axi_bready  = (w_route_state == W_ROUTE_RESP) && (wr_target_slave == ROUTE_SLV0) && s_axi_bready;
    assign m01_axi_bready  = (w_route_state == W_ROUTE_RESP) && (wr_target_slave == ROUTE_SLV1) && s_axi_bready;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_route_state   <= W_ROUTE_IDLE;
            wr_target_slave <= ROUTE_SLV0;
            wr_saved_id     <= {C_AXI_ID_WIDTH{1'b0}};
            decerr_awready  <= 1'b0;
            decerr_wready   <= 1'b0;
            decerr_bvalid   <= 1'b0;
            decerr_bid      <= {C_AXI_ID_WIDTH{1'b0}};
        end else begin
            case (w_route_state)
                W_ROUTE_IDLE: begin
                    decerr_bvalid <= 1'b0;
                    if (s_axi_awvalid) begin
                        wr_saved_id <= s_axi_awid;
                        if (is_aw_slv0 && m00_axi_awready) begin
                            wr_target_slave <= ROUTE_SLV0;
                            w_route_state   <= W_ROUTE_DATA;
                        end else if (is_aw_slv1 && m01_axi_awready) begin
                            wr_target_slave <= ROUTE_SLV1;
                            w_route_state   <= W_ROUTE_DATA;
                        end else if (is_aw_dec) begin
                            wr_target_slave <= ROUTE_DECERR;
                            decerr_awready  <= 1'b1;
                            w_route_state   <= W_ROUTE_DATA;
                        end
                    end
                end

                W_ROUTE_DATA: begin
                    decerr_awready <= 1'b0;
                    if (wr_target_slave == ROUTE_DECERR) begin
                        decerr_wready <= 1'b1;
                        if (s_axi_wvalid && decerr_wready && s_axi_wlast) begin
                            decerr_wready <= 1'b0;
                            decerr_bvalid <= 1'b1;
                            decerr_bid    <= wr_saved_id;
                            w_route_state <= W_ROUTE_RESP;
                        end
                    end else if (wr_target_slave == ROUTE_SLV0) begin
                        if (s_axi_wvalid && m00_axi_wready && s_axi_wlast) begin
                            w_route_state <= W_ROUTE_RESP;
                        end
                    end else if (wr_target_slave == ROUTE_SLV1) begin
                        if (s_axi_wvalid && m01_axi_wready && s_axi_wlast) begin
                            w_route_state <= W_ROUTE_RESP;
                        end
                    end
                end

                W_ROUTE_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        decerr_bvalid <= 1'b0;
                        w_route_state <= W_ROUTE_IDLE;
                    end
                end

                default: w_route_state <= W_ROUTE_IDLE;
            endcase
        end
    end

    // Mux outputs to Master
    always @(*) begin
        case (w_route_state)
            W_ROUTE_IDLE: begin
                if (is_aw_slv0)
                    s_axi_awready = m00_axi_awready;
                else if (is_aw_slv1)
                    s_axi_awready = m01_axi_awready;
                else
                    s_axi_awready = 1'b1; // Ready to consume decode error address
            end
            default: s_axi_awready = 1'b0;
        endcase

        case (wr_target_slave)
            ROUTE_SLV0:   s_axi_wready = m00_axi_wready;
            ROUTE_SLV1:   s_axi_wready = m01_axi_wready;
            ROUTE_DECERR: s_axi_wready = decerr_wready;
            default:      s_axi_wready = 1'b0;
        endcase

        case (wr_target_slave)
            ROUTE_SLV0: begin
                s_axi_bid    = m00_axi_bid;
                s_axi_bresp  = m00_axi_bresp;
                s_axi_bvalid = m00_axi_bvalid;
            end
            ROUTE_SLV1: begin
                s_axi_bid    = m01_axi_bid;
                s_axi_bresp  = m01_axi_bresp;
                s_axi_bvalid = m01_axi_bvalid;
            end
            ROUTE_DECERR: begin
                s_axi_bid    = decerr_bid;
                s_axi_bresp  = `AXI_RESP_DECERR;
                s_axi_bvalid = decerr_bvalid;
            end
            default: begin
                s_axi_bid    = {C_AXI_ID_WIDTH{1'b0}};
                s_axi_bresp  = `AXI_RESP_DECERR;
                s_axi_bvalid = 1'b0;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Read Channel Arbitration & Routing
    // -------------------------------------------------------------------------
    localparam [1:0]
        R_ROUTE_IDLE = 2'b00,
        R_ROUTE_DATA = 2'b01;

    reg [1:0] r_route_state;
    reg [1:0] rd_target_slave;
    reg [C_AXI_ID_WIDTH-1:0] rd_saved_id;

    // Internal DECERR Read Responder
    reg        decerr_arready;
    reg        decerr_rvalid;
    reg        decerr_rlast;

    wire is_ar_slv0 = (decode_addr(s_axi_araddr) == ROUTE_SLV0);
    wire is_ar_slv1 = (decode_addr(s_axi_araddr) == ROUTE_SLV1);
    wire is_ar_dec  = (decode_addr(s_axi_araddr) == ROUTE_DECERR);

    assign m00_axi_arid    = s_axi_arid;
    assign m00_axi_araddr  = s_axi_araddr;
    assign m00_axi_arlen   = s_axi_arlen;
    assign m00_axi_arsize  = s_axi_arsize;
    assign m00_axi_arburst = s_axi_arburst;
    assign m00_axi_arlock  = s_axi_arlock;
    assign m00_axi_arcache = s_axi_arcache;
    assign m00_axi_arprot  = s_axi_arprot;
    assign m00_axi_arqos   = s_axi_arqos;
    assign m00_axi_arvalid = (r_route_state == R_ROUTE_IDLE) && s_axi_arvalid && is_ar_slv0;

    assign m01_axi_arid    = s_axi_arid;
    assign m01_axi_araddr  = s_axi_araddr;
    assign m01_axi_arlen   = s_axi_arlen;
    assign m01_axi_arsize  = s_axi_arsize;
    assign m01_axi_arburst = s_axi_arburst;
    assign m01_axi_arlock  = s_axi_arlock;
    assign m01_axi_arcache = s_axi_arcache;
    assign m01_axi_arprot  = s_axi_arprot;
    assign m01_axi_arqos   = s_axi_arqos;
    assign m01_axi_arvalid = (r_route_state == R_ROUTE_IDLE) && s_axi_arvalid && is_ar_slv1;

    // Read Data Ready Forwarding
    assign m00_axi_rready  = (r_route_state == R_ROUTE_DATA) && (rd_target_slave == ROUTE_SLV0) && s_axi_rready;
    assign m01_axi_rready  = (r_route_state == R_ROUTE_DATA) && (rd_target_slave == ROUTE_SLV1) && s_axi_rready;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_route_state   <= R_ROUTE_IDLE;
            rd_target_slave <= ROUTE_SLV0;
            rd_saved_id     <= {C_AXI_ID_WIDTH{1'b0}};
            decerr_arready  <= 1'b0;
            decerr_rvalid   <= 1'b0;
            decerr_rlast    <= 1'b0;
        end else begin
            case (r_route_state)
                R_ROUTE_IDLE: begin
                    decerr_rvalid <= 1'b0;
                    decerr_rlast  <= 1'b0;
                    if (s_axi_arvalid) begin
                        rd_saved_id <= s_axi_arid;
                        if (is_ar_slv0 && m00_axi_arready) begin
                            rd_target_slave <= ROUTE_SLV0;
                            r_route_state   <= R_ROUTE_DATA;
                        end else if (is_ar_slv1 && m01_axi_arready) begin
                            rd_target_slave <= ROUTE_SLV1;
                            r_route_state   <= R_ROUTE_DATA;
                        end else if (is_ar_dec) begin
                            rd_target_slave <= ROUTE_DECERR;
                            decerr_arready  <= 1'b1;
                            decerr_rvalid   <= 1'b1;
                            decerr_rlast    <= 1'b1;
                            r_route_state   <= R_ROUTE_DATA;
                        end
                    end
                end

                R_ROUTE_DATA: begin
                    decerr_arready <= 1'b0;
                    if (s_axi_rvalid && s_axi_rready && s_axi_rlast) begin
                        decerr_rvalid <= 1'b0;
                        decerr_rlast  <= 1'b0;
                        r_route_state <= R_ROUTE_IDLE;
                    end
                end

                default: r_route_state <= R_ROUTE_IDLE;
            endcase
        end
    end

    // Mux Read outputs to Master
    always @(*) begin
        case (r_route_state)
            R_ROUTE_IDLE: begin
                if (is_ar_slv0)
                    s_axi_arready = m00_axi_arready;
                else if (is_ar_slv1)
                    s_axi_arready = m01_axi_arready;
                else
                    s_axi_arready = 1'b1; // Ready to consume decode error address
            end
            default: s_axi_arready = 1'b0;
        endcase

        case (rd_target_slave)
            ROUTE_SLV0: begin
                s_axi_rid    = m00_axi_rid;
                s_axi_rdata  = m00_axi_rdata;
                s_axi_rresp  = m00_axi_rresp;
                s_axi_rlast  = m00_axi_rlast;
                s_axi_rvalid = m00_axi_rvalid;
            end
            ROUTE_SLV1: begin
                s_axi_rid    = m01_axi_rid;
                s_axi_rdata  = m01_axi_rdata;
                s_axi_rresp  = m01_axi_rresp;
                s_axi_rlast  = m01_axi_rlast;
                s_axi_rvalid = m01_axi_rvalid;
            end
            ROUTE_DECERR: begin
                s_axi_rid    = rd_saved_id;
                s_axi_rdata  = 32'hDEAD_DEAD;
                s_axi_rresp  = `AXI_RESP_DECERR;
                s_axi_rlast  = decerr_rlast;
                s_axi_rvalid = decerr_rvalid;
            end
            default: begin
                s_axi_rid    = {C_AXI_ID_WIDTH{1'b0}};
                s_axi_rdata  = 32'h0000_0000;
                s_axi_rresp  = `AXI_RESP_DECERR;
                s_axi_rlast  = 1'b0;
                s_axi_rvalid = 1'b0;
            end
        endcase
    end

endmodule
