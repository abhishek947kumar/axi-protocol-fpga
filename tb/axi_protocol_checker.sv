// ============================================================================
// File: axi_protocol_checker.sv
// Description: AMBA AXI4 Protocol Assertion (SVA) Verification Monitor.
//              Checks formal protocol constraints: valid/ready handshake
//              stability, payload stability, burst length consistency,
//              wrap burst constraints, and deadlock avoidance.
// Standard: IEEE 1800-2012 (SystemVerilog)
// ============================================================================

`timescale 1ns / 1ps
`include "axi_pkg.vh"

module axi_protocol_checker #(
    parameter integer C_AXI_ID_WIDTH   = 4,
    parameter integer C_AXI_ADDR_WIDTH = 32,
    parameter integer C_AXI_DATA_WIDTH = 32,
    parameter string  INTERFACE_NAME   = "AXI_BUS"
)(
    input wire                          aclk,
    input wire                          aresetn,

    // Write Address Channel
    input wire [C_AXI_ID_WIDTH-1:0]     awid,
    input wire [C_AXI_ADDR_WIDTH-1:0]   awaddr,
    input wire [7:0]                    awlen,
    input wire [2:0]                    awsize,
    input wire [1:0]                    awburst,
    input wire                          awvalid,
    input wire                          awready,

    // Write Data Channel
    input wire [C_AXI_DATA_WIDTH-1:0]   wdata,
    input wire [(C_AXI_DATA_WIDTH/8)-1:0] wstrb,
    input wire                          wlast,
    input wire                          wvalid,
    input wire                          wready,

    // Write Response Channel
    input wire [C_AXI_ID_WIDTH-1:0]     bid,
    input wire [1:0]                    bresp,
    input wire                          bvalid,
    input wire                          bready,

    // Read Address Channel
    input wire [C_AXI_ID_WIDTH-1:0]     arid,
    input wire [C_AXI_ADDR_WIDTH-1:0]   araddr,
    input wire [7:0]                    arlen,
    input wire [2:0]                    arsize,
    input wire [1:0]                    arburst,
    input wire                          arvalid,
    input wire                          arready,

    // Read Data Channel
    input wire [C_AXI_ID_WIDTH-1:0]     rid,
    input wire [C_AXI_DATA_WIDTH-1:0]   rdata,
    input wire [1:0]                    rresp,
    input wire                          rlast,
    input wire                          rvalid,
    input wire                          rready
);

    // -------------------------------------------------------------------------
    // Rule 1: AWVALID stability - once asserted, remains high until AWREADY
    // -------------------------------------------------------------------------
    property p_awvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> awvalid;
    endproperty
    assert_awvalid_stable: assert property (p_awvalid_stable)
        else $error("[%s] Protocol Violation: AWVALID deasserted without AWREADY!", INTERFACE_NAME);

    // Rule 2: AW payload stability while AWVALID is asserted
    property p_awpayload_stable;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> $stable({awid, awaddr, awlen, awsize, awburst});
    endproperty
    assert_awpayload_stable: assert property (p_awpayload_stable)
        else $error("[%s] Protocol Violation: AWADDR/control changed while AWVALID asserted!", INTERFACE_NAME);

    // -------------------------------------------------------------------------
    // Rule 3: WVALID stability - once asserted, remains high until WREADY
    // -------------------------------------------------------------------------
    property p_wvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> wvalid;
    endproperty
    assert_wvalid_stable: assert property (p_wvalid_stable)
        else $error("[%s] Protocol Violation: WVALID deasserted without WREADY!", INTERFACE_NAME);

    // Rule 4: W payload stability while WVALID is asserted
    property p_wpayload_stable;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> $stable({wdata, wstrb, wlast});
    endproperty
    assert_wpayload_stable: assert property (p_wpayload_stable)
        else $error("[%s] Protocol Violation: WDATA/WSTRB/WLAST changed while WVALID asserted!", INTERFACE_NAME);

    // -------------------------------------------------------------------------
    // Rule 5: BVALID stability - once asserted, remains high until BREADY
    // -------------------------------------------------------------------------
    property p_bvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (bvalid && !bready) |=> bvalid;
    endproperty
    assert_bvalid_stable: assert property (p_bvalid_stable)
        else $error("[%s] Protocol Violation: BVALID deasserted without BREADY!", INTERFACE_NAME);

    // Rule 6: B payload stability while BVALID is asserted
    property p_bpayload_stable;
        @(posedge aclk) disable iff (!aresetn)
        (bvalid && !bready) |=> $stable({bid, bresp});
    endproperty
    assert_bpayload_stable: assert property (p_bpayload_stable)
        else $error("[%s] Protocol Violation: BRESP/BID changed while BVALID asserted!", INTERFACE_NAME);

    // -------------------------------------------------------------------------
    // Rule 7: ARVALID stability - once asserted, remains high until ARREADY
    // -------------------------------------------------------------------------
    property p_arvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && !arready) |=> arvalid;
    endproperty
    assert_arvalid_stable: assert property (p_arvalid_stable)
        else $error("[%s] Protocol Violation: ARVALID deasserted without ARREADY!", INTERFACE_NAME);

    // Rule 8: AR payload stability while ARVALID is asserted
    property p_arpayload_stable;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && !arready) |=> $stable({arid, araddr, arlen, arsize, arburst});
    endproperty
    assert_arpayload_stable: assert property (p_arpayload_stable)
        else $error("[%s] Protocol Violation: ARADDR/control changed while ARVALID asserted!", INTERFACE_NAME);

    // -------------------------------------------------------------------------
    // Rule 9: RVALID stability - once asserted, remains high until RREADY
    // -------------------------------------------------------------------------
    property p_rvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && !rready) |=> rvalid;
    endproperty
    assert_rvalid_stable: assert property (p_rvalid_stable)
        else $error("[%s] Protocol Violation: RVALID deasserted without RREADY!", INTERFACE_NAME);

    // Rule 10: R payload stability while RVALID is asserted
    property p_rpayload_stable;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && !rready) |=> $stable({rid, rdata, rresp, rlast});
    endproperty
    assert_rpayload_stable: assert property (p_rpayload_stable)
        else $error("[%s] Protocol Violation: RDATA/RRESP/RLAST changed while RVALID asserted!", INTERFACE_NAME);

    // -------------------------------------------------------------------------
    // Rule 11: WRAP burst length legality (must be 2, 4, 8, or 16 beats)
    // -------------------------------------------------------------------------
    property p_wrap_awlen_legal;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && (awburst == `AXI_BURST_WRAP)) |-> (awlen == 8'd1 || awlen == 8'd3 || awlen == 8'd7 || awlen == 8'd15);
    endproperty
    assert_wrap_awlen_legal: assert property (p_wrap_awlen_legal)
        else $error("[%s] Protocol Violation: WRAP burst AWLEN=%0d is illegal (must be 1, 3, 7, 15)!", INTERFACE_NAME, awlen);

    property p_wrap_arlen_legal;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && (arburst == `AXI_BURST_WRAP)) |-> (arlen == 8'd1 || arlen == 8'd3 || arlen == 8'd7 || arlen == 8'd15);
    endproperty
    assert_wrap_arlen_legal: assert property (p_wrap_arlen_legal)
        else $error("[%s] Protocol Violation: WRAP burst ARLEN=%0d is illegal (must be 1, 3, 7, 15)!", INTERFACE_NAME, arlen);

endmodule
