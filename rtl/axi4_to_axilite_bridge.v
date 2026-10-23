// ============================================================================
// File: axi4_to_axilite_bridge.v
// Description: AMBA AXI4 Full to AXI4-Lite Protocol Converter / Bridge.
//              Translates high-performance full AXI4 transactions into
//              standard single-beat AXI4-Lite register access transactions,
//              preserving transaction IDs and response signaling.
// Standard: IEEE 1364-2001 (Verilog-2001)
// ============================================================================

`timescale 1ns / 1ps
`include "axi_pkg.vh"

module axi4_to_axilite_bridge #(
    parameter integer C_AXI_ID_WIDTH   = 4,
    parameter integer C_AXI_ADDR_WIDTH = 32,
    parameter integer C_AXI_DATA_WIDTH = 32
)(
    input  wire                                 aclk,
    input  wire                                 aresetn,

    // -------------------------------------------------------------------------
    // Upstream: Full AXI4 Slave Interface
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
    // Downstream: AXI4-Lite Master Interface
    // -------------------------------------------------------------------------
    output reg  [C_AXI_ADDR_WIDTH-1:0]          m_axil_awaddr,
    output reg  [2:0]                           m_axil_awprot,
    output reg                                  m_axil_awvalid,
    input  wire                                 m_axil_awready,

    output reg  [C_AXI_DATA_WIDTH-1:0]          m_axil_wdata,
    output reg  [(C_AXI_DATA_WIDTH/8)-1:0]      m_axil_wstrb,
    output reg                                  m_axil_wvalid,
    input  wire                                 m_axil_wready,

    input  wire [1:0]                           m_axil_bresp,
    input  wire                                 m_axil_bvalid,
    output reg                                  m_axil_bready,

    output reg  [C_AXI_ADDR_WIDTH-1:0]          m_axil_araddr,
    output reg  [2:0]                           m_axil_arprot,
    output reg                                  m_axil_arvalid,
    input  wire                                 m_axil_arready,

    input  wire [C_AXI_DATA_WIDTH-1:0]          m_axil_rdata,
    input  wire [1:0]                           m_axil_rresp,
    input  wire                                 m_axil_rvalid,
    output reg                                  m_axil_rready
);

    // -------------------------------------------------------------------------
    // Write Channel Conversion FSM
    // -------------------------------------------------------------------------
    localparam [2:0]
        W_IDLE    = 3'b000,
        W_ADDR    = 3'b001,
        W_DATA    = 3'b010,
        W_WAIT    = 3'b011,
        W_RESP    = 3'b100;

    reg [2:0] wr_state;
    reg [C_AXI_ID_WIDTH-1:0] wr_id_reg;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_state        <= W_IDLE;
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bid       <= {C_AXI_ID_WIDTH{1'b0}};
            s_axi_bresp     <= `AXI_RESP_OKAY;
            m_axil_awvalid  <= 1'b0;
            m_axil_awaddr   <= {C_AXI_ADDR_WIDTH{1'b0}};
            m_axil_awprot   <= 3'b000;
            m_axil_wvalid   <= 1'b0;
            m_axil_wdata    <= {C_AXI_DATA_WIDTH{1'b0}};
            m_axil_wstrb    <= {(C_AXI_DATA_WIDTH/8){1'b0}};
            m_axil_bready   <= 1'b0;
            wr_id_reg       <= {C_AXI_ID_WIDTH{1'b0}};
        end else begin
            case (wr_state)
                W_IDLE: begin
                    s_axi_bvalid  <= 1'b0;
                    s_axi_awready <= 1'b1;
                    s_axi_wready  <= 1'b0;
                    if (s_axi_awvalid && s_axi_awready) begin
                        s_axi_awready  <= 1'b0;
                        wr_id_reg      <= s_axi_awid;
                        m_axil_awaddr  <= s_axi_awaddr;
                        m_axil_awprot  <= s_axi_awprot;
                        m_axil_awvalid <= 1'b1;
                        s_axi_wready   <= 1'b1;
                        wr_state       <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (m_axil_awvalid && m_axil_awready) begin
                        m_axil_awvalid <= 1'b0;
                    end

                    if (s_axi_wvalid && s_axi_wready) begin
                        s_axi_wready   <= 1'b0;
                        m_axil_wdata   <= s_axi_wdata;
                        m_axil_wstrb   <= s_axi_wstrb;
                        m_axil_wvalid  <= 1'b1;
                        m_axil_bready  <= 1'b1;
                        wr_state       <= W_WAIT;
                    end
                end

                W_WAIT: begin
                    if (m_axil_awvalid && m_axil_awready) begin
                        m_axil_awvalid <= 1'b0;
                    end
                    if (m_axil_wvalid && m_axil_wready) begin
                        m_axil_wvalid <= 1'b0;
                    end

                    if (m_axil_bvalid && m_axil_bready) begin
                        m_axil_bready <= 1'b0;
                        s_axi_bvalid  <= 1'b1;
                        s_axi_bid     <= wr_id_reg;
                        s_axi_bresp   <= m_axil_bresp;
                        wr_state      <= W_RESP;
                    end
                end

                W_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state     <= W_IDLE;
                    end
                end

                default: wr_state <= W_IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Read Channel Conversion FSM
    // -------------------------------------------------------------------------
    localparam [1:0]
        R_IDLE  = 2'b00,
        R_WAIT  = 2'b01,
        R_DONE  = 2'b10;

    reg [1:0] rd_state;
    reg [C_AXI_ID_WIDTH-1:0] rd_id_reg;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_state        <= R_IDLE;
            s_axi_arready   <= 1'b0;
            s_axi_rvalid    <= 1'b0;
            s_axi_rlast     <= 1'b0;
            s_axi_rdata     <= {C_AXI_DATA_WIDTH{1'b0}};
            s_axi_rresp     <= `AXI_RESP_OKAY;
            s_axi_rid       <= {C_AXI_ID_WIDTH{1'b0}};
            m_axil_arvalid  <= 1'b0;
            m_axil_araddr   <= {C_AXI_ADDR_WIDTH{1'b0}};
            m_axil_arprot   <= 3'b000;
            m_axil_rready   <= 1'b0;
            rd_id_reg       <= {C_AXI_ID_WIDTH{1'b0}};
        end else begin
            case (rd_state)
                R_IDLE: begin
                    s_axi_rvalid  <= 1'b0;
                    s_axi_rlast   <= 1'b0;
                    s_axi_arready <= 1'b1;
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arready  <= 1'b0;
                        rd_id_reg      <= s_axi_arid;
                        m_axil_araddr  <= s_axi_araddr;
                        m_axil_arprot  <= s_axi_arprot;
                        m_axil_arvalid <= 1'b1;
                        m_axil_rready  <= 1'b1;
                        rd_state       <= R_WAIT;
                    end
                end

                R_WAIT: begin
                    if (m_axil_arvalid && m_axil_arready) begin
                        m_axil_arvalid <= 1'b0;
                    end

                    if (m_axil_rvalid && m_axil_rready) begin
                        m_axil_rready <= 1'b0;
                        s_axi_rdata   <= m_axil_rdata;
                        s_axi_rresp   <= m_axil_rresp;
                        s_axi_rid     <= rd_id_reg;
                        s_axi_rlast   <= 1'b1; // Single beat for Lite
                        s_axi_rvalid  <= 1'b1;
                        rd_state      <= R_DONE;
                    end
                end

                R_DONE: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        s_axi_rlast  <= 1'b0;
                        rd_state     <= R_IDLE;
                    end
                end

                default: rd_state <= R_IDLE;
            endcase
        end
    end

endmodule
