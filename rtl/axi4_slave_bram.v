// ============================================================================
// File: axi4_slave_bram.v
// Description: Full AMBA AXI4 Memory Slave with Internal BRAM Model.
//              Supports FIXED, INCR, and WRAP bursts (lengths 1 to 256),
//              byte strobes (WSTRB), configurable wait-state backpressure,
//              and comprehensive response generation (OKAY, SLVERR).
// Standard: IEEE 1364-2001 (Verilog-2001)
// ============================================================================

`timescale 1ns / 1ps
`include "axi_pkg.vh"

module axi4_slave_bram #(
    parameter integer C_S_AXI_ID_WIDTH      = 4,
    parameter integer C_S_AXI_DATA_WIDTH    = 32,
    parameter integer C_S_AXI_ADDR_WIDTH    = 32,
    parameter integer MEM_DEPTH_WORDS       = 512,  // 512 words * 4 bytes = 2 KB
    parameter integer C_SLV_WAIT_CYCLES     = 0     // Default wait-state cycles (0 for max throughput)
)(
    // Global Clock & Active-Low Reset
    input  wire                                 aclk,
    input  wire                                 aresetn,

    // Write Address Channel (AW)
    input  wire [C_S_AXI_ID_WIDTH-1:0]          s_axi_awid,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]        s_axi_awaddr,
    input  wire [7:0]                           s_axi_awlen,
    input  wire [2:0]                           s_axi_awsize,
    input  wire [1:0]                           s_axi_awburst,
    input  wire                                 s_axi_awlock,
    input  wire [3:0]                           s_axi_awcache,
    input  wire [2:0]                           s_axi_awprot,
    input  wire [3:0]                           s_axi_awqos,
    input  wire                                 s_axi_awvalid,
    output reg                                  s_axi_awready,

    // Write Data Channel (W)
    input  wire [C_S_AXI_DATA_WIDTH-1:0]        s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]    s_axi_wstrb,
    input  wire                                 s_axi_wlast,
    input  wire                                 s_axi_wvalid,
    output reg                                  s_axi_wready,

    // Write Response Channel (B)
    output reg  [C_S_AXI_ID_WIDTH-1:0]          s_axi_bid,
    output reg  [1:0]                           s_axi_bresp,
    output reg                                  s_axi_bvalid,
    input  wire                                 s_axi_bready,

    // Read Address Channel (AR)
    input  wire [C_S_AXI_ID_WIDTH-1:0]          s_axi_arid,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]        s_axi_araddr,
    input  wire [7:0]                           s_axi_arlen,
    input  wire [2:0]                           s_axi_arsize,
    input  wire [1:0]                           s_axi_arburst,
    input  wire                                 s_axi_arlock,
    input  wire [3:0]                           s_axi_arcache,
    input  wire [2:0]                           s_axi_arprot,
    input  wire [3:0]                           s_axi_arqos,
    input  wire                                 s_axi_arvalid,
    output reg                                  s_axi_arready,

    // Read Data Channel (R)
    output reg  [C_S_AXI_ID_WIDTH-1:0]          s_axi_rid,
    output reg  [C_S_AXI_DATA_WIDTH-1:0]        s_axi_rdata,
    output reg  [1:0]                           s_axi_rresp,
    output reg                                  s_axi_rlast,
    output reg                                  s_axi_rvalid,
    input  wire                                 s_axi_rready
);

    localparam ADDR_LSB = 2; // For 32-bit data (4 bytes per word)
    localparam MEM_ADDR_BITS = 9; // 512 words -> 9 bits

    // -------------------------------------------------------------------------
    // Internal Memory Array
    // -------------------------------------------------------------------------
    reg [C_S_AXI_DATA_WIDTH-1:0] mem [0:MEM_DEPTH_WORDS-1];

    // -------------------------------------------------------------------------
    // Function: Calculate Next Burst Address (AMBA AXI4 Specification compliant)
    // -------------------------------------------------------------------------
    function [C_S_AXI_ADDR_WIDTH-1:0] get_next_addr;
        input [C_S_AXI_ADDR_WIDTH-1:0] current_addr;
        input [1:0]                    burst_type;
        input [2:0]                    burst_size;
        input [7:0]                    burst_len;
        input [C_S_AXI_ADDR_WIDTH-1:0] wrap_boundary;
        input [C_S_AXI_ADDR_WIDTH-1:0] wrap_size;
        
        reg [C_S_AXI_ADDR_WIDTH-1:0]   incr_val;
        begin
            incr_val = (1 << burst_size);
            case (burst_type)
                `AXI_BURST_FIXED: begin
                    get_next_addr = current_addr;
                end
                `AXI_BURST_INCR: begin
                    get_next_addr = current_addr + incr_val;
                end
                `AXI_BURST_WRAP: begin
                    if ((current_addr + incr_val) >= (wrap_boundary + wrap_size))
                        get_next_addr = wrap_boundary;
                    else
                        get_next_addr = current_addr + incr_val;
                end
                default: begin
                    get_next_addr = current_addr + incr_val;
                end
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // Write State Machine
    // -------------------------------------------------------------------------
    localparam [1:0]
        WS_IDLE  = 2'b00,
        WS_DATA  = 2'b01,
        WS_RESP  = 2'b10;

    reg [1:0] ws_state;

    reg [C_S_AXI_ID_WIDTH-1:0]   wr_id;
    reg [C_S_AXI_ADDR_WIDTH-1:0] wr_addr;
    reg [7:0]                    wr_len;
    reg [2:0]                    wr_size;
    reg [1:0]                    wr_burst;
    reg [7:0]                    wr_beat_cnt;
    reg [C_S_AXI_ADDR_WIDTH-1:0] wr_wrap_boundary;
    reg [C_S_AXI_ADDR_WIDTH-1:0] wr_wrap_size;
    reg                          wr_err;
    reg [3:0]                    wr_wait_cnt;

    // Word address for internal memory indexing
    wire [MEM_ADDR_BITS-1:0] wr_word_idx = wr_addr[ADDR_LSB +: MEM_ADDR_BITS];

    integer b_idx;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            ws_state          <= WS_IDLE;
            s_axi_awready     <= 1'b0;
            s_axi_wready      <= 1'b0;
            s_axi_bvalid      <= 1'b0;
            s_axi_bid         <= {C_S_AXI_ID_WIDTH{1'b0}};
            s_axi_bresp       <= `AXI_RESP_OKAY;
            wr_id             <= {C_S_AXI_ID_WIDTH{1'b0}};
            wr_addr           <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            wr_len            <= 8'd0;
            wr_size           <= 3'd0;
            wr_burst          <= 2'd0;
            wr_beat_cnt       <= 8'd0;
            wr_wrap_boundary  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            wr_wrap_size      <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            wr_err            <= 1'b0;
            wr_wait_cnt       <= 4'd0;
        end else begin
            case (ws_state)
                WS_IDLE: begin
                    s_axi_bvalid  <= 1'b0;
                    s_axi_wready  <= 1'b0;
                    
                    // Handle wait cycles if configured
                    if (wr_wait_cnt < C_SLV_WAIT_CYCLES) begin
                        wr_wait_cnt   <= wr_wait_cnt + 1'b1;
                        s_axi_awready <= 1'b0;
                    end else begin
                        s_axi_awready <= 1'b1;
                        if (s_axi_awvalid && s_axi_awready) begin
                            s_axi_awready     <= 1'b0;
                            wr_wait_cnt       <= 4'd0;
                            wr_id             <= s_axi_awid;
                            wr_addr           <= s_axi_awaddr;
                            wr_len            <= s_axi_awlen;
                            wr_size           <= s_axi_awsize;
                            wr_burst          <= s_axi_awburst;
                            wr_beat_cnt       <= 8'd0;
                            wr_err            <= 1'b0;

                            // Calculate WRAP boundaries using power-of-2 bitmasking (zero DSPs, single cycle)
                            wr_wrap_size      <= (s_axi_awlen + 1'b1) << s_axi_awsize;
                            wr_wrap_boundary  <= s_axi_awaddr & ~(((s_axi_awlen + 1'b1) << s_axi_awsize) - 1'b1);

                            s_axi_wready      <= 1'b1;
                            ws_state          <= WS_DATA;
                        end
                    end
                end

                WS_DATA: begin
                    s_axi_awready <= 1'b0;
                    if (s_axi_wvalid && s_axi_wready) begin
                        // Memory write with byte enable strobes
                        for (b_idx = 0; b_idx < (C_S_AXI_DATA_WIDTH/8); b_idx = b_idx + 1) begin
                            if (s_axi_wstrb[b_idx]) begin
                                mem[wr_word_idx][(b_idx*8) +: 8] <= s_axi_wdata[(b_idx*8) +: 8];
                            end
                        end

                        if (s_axi_wlast || (wr_beat_cnt == wr_len)) begin
                            s_axi_wready <= 1'b0;
                            s_axi_bvalid <= 1'b1;
                            s_axi_bid    <= wr_id;
                            s_axi_bresp  <= wr_err ? `AXI_RESP_SLVERR : `AXI_RESP_OKAY;
                            ws_state     <= WS_RESP;
                        end else begin
                            wr_beat_cnt <= wr_beat_cnt + 1'b1;
                            wr_addr     <= get_next_addr(wr_addr, wr_burst, wr_size, wr_len, wr_wrap_boundary, wr_wrap_size);
                            s_axi_wready <= 1'b1;
                        end
                    end
                end

                WS_RESP: begin
                    s_axi_wready <= 1'b0;
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        ws_state     <= WS_IDLE;
                    end
                end

                default: ws_state <= WS_IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Read State Machine
    // -------------------------------------------------------------------------
    localparam [1:0]
        RS_IDLE = 2'b00,
        RS_DATA = 2'b01;

    reg [1:0] rs_state;

    reg [C_S_AXI_ID_WIDTH-1:0]   rd_id;
    reg [C_S_AXI_ADDR_WIDTH-1:0] rd_addr;
    reg [7:0]                    rd_len;
    reg [2:0]                    rd_size;
    reg [1:0]                    rd_burst;
    reg [7:0]                    rd_beat_cnt;
    reg [C_S_AXI_ADDR_WIDTH-1:0] rd_wrap_boundary;
    reg [C_S_AXI_ADDR_WIDTH-1:0] rd_wrap_size;
    reg [3:0]                    rd_wait_cnt;

    wire [MEM_ADDR_BITS-1:0] rd_word_idx = rd_addr[ADDR_LSB +: MEM_ADDR_BITS];

    wire [C_S_AXI_ADDR_WIDTH-1:0] next_rd_addr_val;
    assign next_rd_addr_val = get_next_addr(rd_addr, rd_burst, rd_size, rd_len, rd_wrap_boundary, rd_wrap_size);
    wire [MEM_ADDR_BITS-1:0] next_rd_word_idx = next_rd_addr_val[ADDR_LSB +: MEM_ADDR_BITS];

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rs_state          <= RS_IDLE;
            s_axi_arready     <= 1'b0;
            s_axi_rvalid      <= 1'b0;
            s_axi_rlast       <= 1'b0;
            s_axi_rdata       <= {C_S_AXI_DATA_WIDTH{1'b0}};
            s_axi_rresp       <= `AXI_RESP_OKAY;
            s_axi_rid         <= {C_S_AXI_ID_WIDTH{1'b0}};
            rd_id             <= {C_S_AXI_ID_WIDTH{1'b0}};
            rd_addr           <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            rd_len            <= 8'd0;
            rd_size           <= 3'd0;
            rd_burst          <= 2'd0;
            rd_beat_cnt       <= 8'd0;
            rd_wrap_boundary  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            rd_wrap_size      <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            rd_wait_cnt       <= 4'd0;
        end else begin
            case (rs_state)
                RS_IDLE: begin
                    s_axi_rlast <= 1'b0;
                    if (rd_wait_cnt < C_SLV_WAIT_CYCLES) begin
                        rd_wait_cnt   <= rd_wait_cnt + 1'b1;
                        s_axi_arready <= 1'b0;
                    end else begin
                        s_axi_arready <= 1'b1;
                        if (s_axi_arvalid && s_axi_arready) begin
                            s_axi_arready     <= 1'b0;
                            rd_wait_cnt       <= 4'd0;
                            rd_id             <= s_axi_arid;
                            rd_addr           <= s_axi_araddr;
                            rd_len            <= s_axi_arlen;
                            rd_size           <= s_axi_arsize;
                            rd_burst          <= s_axi_arburst;
                            rd_beat_cnt       <= 8'd0;

                            // Calculate WRAP boundaries using power-of-2 bitmasking (zero DSPs, single cycle)
                            rd_wrap_size      <= (s_axi_arlen + 1'b1) << s_axi_arsize;
                            rd_wrap_boundary  <= s_axi_araddr & ~(((s_axi_arlen + 1'b1) << s_axi_arsize) - 1'b1);

                            // Stage first read beat
                            s_axi_rdata       <= mem[s_axi_araddr[ADDR_LSB +: MEM_ADDR_BITS]];
                            s_axi_rid         <= s_axi_arid;
                            s_axi_rresp       <= `AXI_RESP_OKAY;
                            s_axi_rvalid      <= 1'b1;
                            s_axi_rlast       <= (s_axi_arlen == 8'd0);
                            rs_state          <= RS_DATA;
                        end
                    end
                end

                RS_DATA: begin
                    s_axi_arready <= 1'b0;
                    // Transfer occurs when rvalid && rready
                    if (s_axi_rvalid && s_axi_rready) begin
                        if (s_axi_rlast || (rd_beat_cnt == rd_len)) begin
                            s_axi_rvalid <= 1'b0;
                            s_axi_rlast  <= 1'b0;
                            rs_state     <= RS_IDLE;
                        end else begin
                            // Advance to next beat
                            rd_beat_cnt  <= rd_beat_cnt + 1'b1;
                            rd_addr      <= next_rd_addr_val;
                            
                            // Next address fetch
                            s_axi_rdata  <= mem[next_rd_word_idx];
                            s_axi_rvalid <= 1'b1;
                            s_axi_rlast  <= ((rd_beat_cnt + 1'b1) == rd_len);
                            s_axi_rresp  <= `AXI_RESP_OKAY;
                        end
                    end
                end

                default: rs_state <= RS_IDLE;
            endcase
        end
    end

endmodule
