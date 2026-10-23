// ============================================================================
// File: axi4_master.v
// Description: AMBA AXI4 Full Master Burst & Transaction Engine.
//              Supports independent full-duplex write and read channels,
//              burst lengths from 1 to 256 beats, burst types (FIXED, INCR,
//              WRAP), byte strobes, response checking, and status telemetry.
// Standard: IEEE 1364-2001 (Verilog-2001)
// ============================================================================

`timescale 1ns / 1ps
`include "axi_pkg.vh"

module axi4_master #(
    parameter integer C_M_AXI_ID_WIDTH      = 4,
    parameter integer C_M_AXI_ADDR_WIDTH    = 32,
    parameter integer C_M_AXI_DATA_WIDTH    = 32,
    parameter [C_M_AXI_ID_WIDTH-1:0] MASTER_ID = 4'h1
)(
    // Global Clock & Active-Low Reset
    input  wire                                 aclk,
    input  wire                                 aresetn,

    // -------------------------------------------------------------------------
    // User Control & Command Interface (Write)
    // -------------------------------------------------------------------------
    input  wire                                 cmd_wr_start,
    input  wire [C_M_AXI_ADDR_WIDTH-1:0]        cmd_wr_addr,
    input  wire [7:0]                           cmd_wr_len,
    input  wire [2:0]                           cmd_wr_size,
    input  wire [1:0]                           cmd_wr_burst,
    input  wire [C_M_AXI_DATA_WIDTH-1:0]        cmd_wr_seed,
    input  wire [(C_M_AXI_DATA_WIDTH/8)-1:0]    cmd_wr_strb,
    output reg                                  wr_busy,
    output reg                                  wr_done,
    output reg                                  wr_error,
    output reg  [1:0]                           wr_resp_code,

    // -------------------------------------------------------------------------
    // User Control & Command Interface (Read)
    // -------------------------------------------------------------------------
    input  wire                                 cmd_rd_start,
    input  wire [C_M_AXI_ADDR_WIDTH-1:0]        cmd_rd_addr,
    input  wire [7:0]                           cmd_rd_len,
    input  wire [2:0]                           cmd_rd_size,
    input  wire [1:0]                           cmd_rd_burst,
    output reg                                  rd_busy,
    output reg                                  rd_done,
    output reg                                  rd_error,
    output reg  [1:0]                           rd_resp_code,
    output reg  [C_M_AXI_DATA_WIDTH-1:0]        last_rd_data,
    output reg  [7:0]                           rd_beat_cnt_out,

    // -------------------------------------------------------------------------
    // AXI4 Write Address Channel (AW)
    // -------------------------------------------------------------------------
    output reg  [C_M_AXI_ID_WIDTH-1:0]          m_axi_awid,
    output reg  [C_M_AXI_ADDR_WIDTH-1:0]        m_axi_awaddr,
    output reg  [7:0]                           m_axi_awlen,
    output reg  [2:0]                           m_axi_awsize,
    output reg  [1:0]                           m_axi_awburst,
    output wire                                 m_axi_awlock,
    output wire [3:0]                           m_axi_awcache,
    output wire [2:0]                           m_axi_awprot,
    output wire [3:0]                           m_axi_awqos,
    output reg                                  m_axi_awvalid,
    input  wire                                 m_axi_awready,

    // -------------------------------------------------------------------------
    // AXI4 Write Data Channel (W)
    // -------------------------------------------------------------------------
    output reg  [C_M_AXI_DATA_WIDTH-1:0]        m_axi_wdata,
    output reg  [(C_M_AXI_DATA_WIDTH/8)-1:0]    m_axi_wstrb,
    output reg                                  m_axi_wlast,
    output reg                                  m_axi_wvalid,
    input  wire                                 m_axi_wready,

    // -------------------------------------------------------------------------
    // AXI4 Write Response Channel (B)
    // -------------------------------------------------------------------------
    input  wire [C_M_AXI_ID_WIDTH-1:0]          m_axi_bid,
    input  wire [1:0]                           m_axi_bresp,
    input  wire                                 m_axi_bvalid,
    output reg                                  m_axi_bready,

    // -------------------------------------------------------------------------
    // AXI4 Read Address Channel (AR)
    // -------------------------------------------------------------------------
    output reg  [C_M_AXI_ID_WIDTH-1:0]          m_axi_arid,
    output reg  [C_M_AXI_ADDR_WIDTH-1:0]        m_axi_araddr,
    output reg  [7:0]                           m_axi_arlen,
    output reg  [2:0]                           m_axi_arsize,
    output reg  [1:0]                           m_axi_arburst,
    output wire                                 m_axi_arlock,
    output wire [3:0]                           m_axi_arcache,
    output wire [2:0]                           m_axi_arprot,
    output wire [3:0]                           m_axi_arqos,
    output reg                                  m_axi_arvalid,
    input  wire                                 m_axi_arready,

    // -------------------------------------------------------------------------
    // AXI4 Read Data Channel (R)
    // -------------------------------------------------------------------------
    input  wire [C_M_AXI_ID_WIDTH-1:0]          m_axi_rid,
    input  wire [C_M_AXI_DATA_WIDTH-1:0]        m_axi_rdata,
    input  wire [1:0]                           m_axi_rresp,
    input  wire                                 m_axi_rlast,
    input  wire                                 m_axi_rvalid,
    output reg                                  m_axi_rready
);

    // Constant Sideband Signals
    assign m_axi_awlock  = 1'b0;
    assign m_axi_awcache = 4'b0011; // Normal, Non-cacheable, Modifiable
    assign m_axi_awprot  = `AXI_PROT_UNPRIV_SEC_DATA;
    assign m_axi_awqos   = 4'b0000;

    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = `AXI_PROT_UNPRIV_SEC_DATA;
    assign m_axi_arqos   = 4'b0000;

    // -------------------------------------------------------------------------
    // Write Transaction FSM
    // -------------------------------------------------------------------------
    localparam [2:0]
        MW_IDLE = 3'b000,
        MW_ADDR = 3'b001,
        MW_DATA = 3'b010,
        MW_RESP = 3'b011,
        MW_DONE = 3'b100;

    reg [2:0] mw_state;
    reg [7:0] wr_beat_cnt;
    reg [7:0] wr_len_reg;
    reg [C_M_AXI_DATA_WIDTH-1:0] wr_data_reg;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            mw_state      <= MW_IDLE;
            m_axi_awvalid <= 1'b0;
            m_axi_awid    <= MASTER_ID;
            m_axi_awaddr  <= {C_M_AXI_ADDR_WIDTH{1'b0}};
            m_axi_awlen   <= 8'd0;
            m_axi_awsize  <= `AXI_SIZE_4_BYTES;
            m_axi_awburst <= `AXI_BURST_INCR;
            m_axi_wvalid  <= 1'b0;
            m_axi_wdata   <= {C_M_AXI_DATA_WIDTH{1'b0}};
            m_axi_wstrb   <= {(C_M_AXI_DATA_WIDTH/8){1'b0}};
            m_axi_wlast   <= 1'b0;
            m_axi_bready  <= 1'b0;
            wr_busy       <= 1'b0;
            wr_done       <= 1'b0;
            wr_error      <= 1'b0;
            wr_resp_code  <= `AXI_RESP_OKAY;
            wr_beat_cnt   <= 8'd0;
            wr_len_reg    <= 8'd0;
            wr_data_reg   <= {C_M_AXI_DATA_WIDTH{1'b0}};
        end else begin
            wr_done <= 1'b0; // Default pulse
            case (mw_state)
                MW_IDLE: begin
                    wr_busy <= 1'b0;
                    if (cmd_wr_start) begin
                        wr_busy       <= 1'b1;
                        wr_error      <= 1'b0;
                        m_axi_awid    <= MASTER_ID;
                        m_axi_awaddr  <= cmd_wr_addr;
                        m_axi_awlen   <= cmd_wr_len;
                        m_axi_awsize  <= cmd_wr_size;
                        m_axi_awburst <= cmd_wr_burst;
                        m_axi_awvalid <= 1'b1;

                        wr_len_reg    <= cmd_wr_len;
                        wr_beat_cnt   <= 8'd0;
                        wr_data_reg   <= cmd_wr_seed;
                        m_axi_wstrb   <= cmd_wr_strb;

                        mw_state      <= MW_ADDR;
                    end
                end

                MW_ADDR: begin
                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        // Prepare first write beat
                        m_axi_wvalid  <= 1'b1;
                        m_axi_wdata   <= wr_data_reg;
                        m_axi_wlast   <= (wr_len_reg == 8'd0);
                        mw_state      <= MW_DATA;
                    end
                end

                MW_DATA: begin
                    if (m_axi_wvalid && m_axi_wready) begin
                        if (m_axi_wlast || (wr_beat_cnt == wr_len_reg)) begin
                            m_axi_wvalid <= 1'b0;
                            m_axi_wlast  <= 1'b0;
                            m_axi_bready <= 1'b1;
                            mw_state     <= MW_RESP;
                        end else begin
                            wr_beat_cnt  <= wr_beat_cnt + 1'b1;
                            wr_data_reg  <= wr_data_reg + 1'b1; // Increment pattern
                            m_axi_wdata  <= wr_data_reg + 1'b1;
                            m_axi_wvalid <= 1'b1;
                            m_axi_wlast  <= ((wr_beat_cnt + 1'b1) == wr_len_reg);
                        end
                    end
                end

                MW_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        wr_resp_code <= m_axi_bresp;
                        if (m_axi_bresp != `AXI_RESP_OKAY)
                            wr_error <= 1'b1;
                        mw_state <= MW_DONE;
                    end
                end

                MW_DONE: begin
                    wr_done  <= 1'b1;
                    wr_busy  <= 1'b0;
                    mw_state <= MW_IDLE;
                end

                default: mw_state <= MW_IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Read Transaction FSM
    // -------------------------------------------------------------------------
    localparam [2:0]
        MR_IDLE = 3'b000,
        MR_ADDR = 3'b001,
        MR_DATA = 3'b010,
        MR_DONE = 3'b011;

    reg [2:0] mr_state;
    reg [7:0] rd_len_reg;
    reg [7:0] rd_beat_cnt;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            mr_state        <= MR_IDLE;
            m_axi_arvalid   <= 1'b0;
            m_axi_arid      <= MASTER_ID;
            m_axi_araddr    <= {C_M_AXI_ADDR_WIDTH{1'b0}};
            m_axi_arlen     <= 8'd0;
            m_axi_arsize    <= `AXI_SIZE_4_BYTES;
            m_axi_arburst   <= `AXI_BURST_INCR;
            m_axi_rready    <= 1'b0;
            rd_busy         <= 1'b0;
            rd_done         <= 1'b0;
            rd_error        <= 1'b0;
            rd_resp_code    <= `AXI_RESP_OKAY;
            last_rd_data    <= {C_M_AXI_DATA_WIDTH{1'b0}};
            rd_beat_cnt     <= 8'd0;
            rd_beat_cnt_out <= 8'd0;
            rd_len_reg      <= 8'd0;
        end else begin
            rd_done <= 1'b0; // Default pulse
            case (mr_state)
                MR_IDLE: begin
                    rd_busy <= 1'b0;
                    if (cmd_rd_start) begin
                        rd_busy         <= 1'b1;
                        rd_error        <= 1'b0;
                        m_axi_arid      <= MASTER_ID;
                        m_axi_araddr    <= cmd_rd_addr;
                        m_axi_arlen     <= cmd_rd_len;
                        m_axi_arsize    <= cmd_rd_size;
                        m_axi_arburst   <= cmd_rd_burst;
                        m_axi_arvalid   <= 1'b1;
                        rd_len_reg      <= cmd_rd_len;
                        rd_beat_cnt     <= 8'd0;
                        rd_beat_cnt_out <= 8'd0;
                        mr_state        <= MR_ADDR;
                    end
                end

                MR_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1; // Ready to receive read beats
                        mr_state      <= MR_DATA;
                    end
                end

                MR_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        last_rd_data    <= m_axi_rdata;
                        rd_beat_cnt     <= rd_beat_cnt + 1'b1;
                        rd_beat_cnt_out <= rd_beat_cnt + 1'b1;

                        if (m_axi_rresp != `AXI_RESP_OKAY)
                            rd_error <= 1'b1;

                        if (m_axi_rlast || (rd_beat_cnt == rd_len_reg)) begin
                            m_axi_rready <= 1'b0;
                            rd_resp_code <= m_axi_rresp;
                            mr_state     <= MR_DONE;
                        end
                    end
                end

                MR_DONE: begin
                    rd_done  <= 1'b1;
                    rd_busy  <= 1'b0;
                    mr_state <= MR_IDLE;
                end

                default: mr_state <= MR_IDLE;
            endcase
        end
    end

endmodule
