// ============================================================================
// File: axi4_lite_slave_reg.v
// Description: AMBA AXI4-Lite Control & Status Register (CSR) Peripheral.
//              Provides memory-mapped control, status, scratchpad, counter,
//              and loopback registers with byte-enable write strobes.
// Standard: IEEE 1364-2001 (Verilog-2001)
// ============================================================================

`timescale 1ns / 1ps
`include "axi_pkg.vh"

module axi4_lite_slave_reg #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32
)(
    // Global Clock & Active-Low Reset
    input  wire                                 aclk,
    input  wire                                 aresetn,

    // Write Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]        s_axi_awaddr,
    input  wire [2:0]                           s_axi_awprot,
    input  wire                                 s_axi_awvalid,
    output reg                                  s_axi_awready,

    // Write Data Channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]        s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]    s_axi_wstrb,
    input  wire                                 s_axi_wvalid,
    output reg                                  s_axi_wready,

    // Write Response Channel
    output reg  [1:0]                           s_axi_bresp,
    output reg                                  s_axi_bvalid,
    input  wire                                 s_axi_bready,

    // Read Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]        s_axi_araddr,
    input  wire [2:0]                           s_axi_arprot,
    input  wire                                 s_axi_arvalid,
    output reg                                  s_axi_arready,

    // Read Data Channel
    output reg  [C_S_AXI_DATA_WIDTH-1:0]        s_axi_rdata,
    output reg  [1:0]                           s_axi_rresp,
    output reg                                  s_axi_rvalid,
    input  wire                                 s_axi_rready,

    // Peripheral Hardware I/O Ports
    output wire [31:0]                          o_ctrl_reg,
    input  wire [31:0]                          i_status_reg,
    output wire [31:0]                          o_scratch0,
    output wire [31:0]                          o_scratch1,
    output reg  [31:0]                          o_txn_cnt
);

    localparam ADDR_LSB = 2; // 32-bit aligned
    localparam OPT_MEM_ADDR_BITS = 3; // 6 registers (offsets 0x00 to 0x14)

    // -------------------------------------------------------------------------
    // Internal Registers
    // -------------------------------------------------------------------------
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_ctrl;      // 0x00
    wire [C_S_AXI_DATA_WIDTH-1:0] reg_status;   // 0x04 (read-only from hardware input)
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_scratch0;  // 0x08
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_scratch1;  // 0x0C
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_loopback;  // 0x14 (reads inverted)

    assign o_ctrl_reg   = reg_ctrl;
    assign reg_status   = i_status_reg;
    assign o_scratch0   = reg_scratch0;
    assign o_scratch1   = reg_scratch1;

    // -------------------------------------------------------------------------
    // Write Handling
    // -------------------------------------------------------------------------
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg                          aw_en;
    integer byte_index;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            aw_en         <= 1'b1;
            axi_awaddr    <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready <= 1'b1;
                aw_en         <= 1'b0;
                axi_awaddr    <= s_axi_awaddr;
            end else if (s_axi_bready && s_axi_bvalid) begin
                aw_en         <= 1'b1;
                s_axi_awready <= 1'b0;
            end else begin
                s_axi_awready <= 1'b0;
            end
        end
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_wready <= 1'b0;
        end else begin
            if (~s_axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en) begin
                s_axi_wready <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end
        end
    end

    wire slv_reg_wren = s_axi_wready && s_axi_wvalid && s_axi_awready && s_axi_awvalid;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            reg_ctrl      <= 32'h0000_0000;
            reg_scratch0  <= 32'h0000_0000;
            reg_scratch1  <= 32'h0000_0000;
            reg_loopback  <= 32'h0000_0000;
            o_txn_cnt     <= 32'h0000_0000;
        end else begin
            if (slv_reg_wren) begin
                o_txn_cnt <= o_txn_cnt + 1'b1;
                case (axi_awaddr[ADDR_LSB +: OPT_MEM_ADDR_BITS])
                    3'h0: begin // 0x00 Control
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                            if (s_axi_wstrb[byte_index])
                                reg_ctrl[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                    end
                    3'h1: begin // 0x04 Status (Read-only, writes ignored)
                    end
                    3'h2: begin // 0x08 Scratch0
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                            if (s_axi_wstrb[byte_index])
                                reg_scratch0[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                    end
                    3'h3: begin // 0x0C Scratch1
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                            if (s_axi_wstrb[byte_index])
                                reg_scratch1[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                    end
                    3'h4: begin // 0x10 Transaction Counter (can be cleared by writing 0)
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                            if (s_axi_wstrb[byte_index])
                                o_txn_cnt[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                    end
                    3'h5: begin // 0x14 Loopback
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                            if (s_axi_wstrb[byte_index])
                                reg_loopback[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

    // Write Response logic
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= `AXI_RESP_OKAY;
        end else begin
            if (s_axi_awready && s_axi_awvalid && ~s_axi_bvalid && s_axi_wready && s_axi_wvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= `AXI_RESP_OKAY;
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Read Handling
    // -------------------------------------------------------------------------
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            axi_araddr    <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                axi_araddr    <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end
        end
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= `AXI_RESP_OKAY;
            s_axi_rdata  <= {C_S_AXI_DATA_WIDTH{1'b0}};
        end else begin
            if (s_axi_arready && s_axi_arvalid && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= `AXI_RESP_OKAY;
                case (s_axi_araddr[ADDR_LSB +: OPT_MEM_ADDR_BITS])
                    3'h0: s_axi_rdata <= reg_ctrl;
                    3'h1: s_axi_rdata <= reg_status;
                    3'h2: s_axi_rdata <= reg_scratch0;
                    3'h3: s_axi_rdata <= reg_scratch1;
                    3'h4: s_axi_rdata <= o_txn_cnt;
                    3'h5: s_axi_rdata <= ~reg_loopback; // Loopback returns bitwise inverted value!
                    default: begin
                        s_axi_rdata <= 32'hDEAD_BEEF;
                        s_axi_rresp <= `AXI_RESP_SLVERR;
                    end
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
