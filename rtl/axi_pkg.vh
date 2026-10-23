// ============================================================================
// File: axi_pkg.vh
// Description: AMBA AXI4 / AXI4-Lite Protocol Definitions, Burst Encodings,
//              Response Codes, and System Constants.
// Standard: IEEE 1364-2001 (Verilog-2001 Header)
// ============================================================================

`ifndef AXI_PKG_VH
`define AXI_PKG_VH

// ----------------------------------------------------------------------------
// AXI4 Burst Type Encodings (AxBURST[1:0])
// ----------------------------------------------------------------------------
`define AXI_BURST_FIXED     2'b00   // Fixed address burst (FIFO style)
`define AXI_BURST_INCR      2'b01   // Incrementing address burst
`define AXI_BURST_WRAP      2'b10   // Wrapping address burst (cache line fills)
`define AXI_BURST_RESERVED  2'b11   // Reserved

// ----------------------------------------------------------------------------
// AXI4 Transfer Size Encodings (AxSIZE[2:0] = 2^AxSIZE bytes)
// ----------------------------------------------------------------------------
`define AXI_SIZE_1_BYTE     3'b000  // 1 byte  (8-bit transfer)
`define AXI_SIZE_2_BYTES    3'b001  // 2 bytes (16-bit transfer)
`define AXI_SIZE_4_BYTES    3'b010  // 4 bytes (32-bit transfer)
`define AXI_SIZE_8_BYTES    3'b011  // 8 bytes (64-bit transfer)
`define AXI_SIZE_16_BYTES   3'b100  // 16 bytes (128-bit transfer)
`define AXI_SIZE_32_BYTES   3'b101  // 32 bytes (256-bit transfer)
`define AXI_SIZE_64_BYTES   3'b110  // 64 bytes (512-bit transfer)
`define AXI_SIZE_128_BYTES  3'b111  // 128 bytes (1024-bit transfer)

// ----------------------------------------------------------------------------
// AXI4 Response Encodings (RRESP[1:0], BRESP[1:0])
// ----------------------------------------------------------------------------
`define AXI_RESP_OKAY       2'b00   // Normal access success
`define AXI_RESP_EXOKAY     2'b01   // Exclusive access OK
`define AXI_RESP_SLVERR     2'b10   // Slave error (target access failed)
`define AXI_RESP_DECERR     2'b11   // Decode error (unmapped address)

// ----------------------------------------------------------------------------
// AXI4 Protection Encodings (AxPROT[2:0])
// ----------------------------------------------------------------------------
`define AXI_PROT_UNPRIV_SEC_DATA    3'b000
`define AXI_PROT_PRIV_SEC_DATA      3'b001
`define AXI_PROT_UNPRIV_NONSEC_DATA 3'b010
`define AXI_PROT_PRIV_NONSEC_DATA   3'b011

// ----------------------------------------------------------------------------
// AXI4 Memory Region Address Map (1x2 Interconnect Crossbar)
// ----------------------------------------------------------------------------
`define AXI_ADDR_SLV0_BASE  32'h0000_0000   // BRAM High-Speed Memory Base
`define AXI_ADDR_SLV0_HIGH  32'h0000_FFFF   // BRAM Range: 64 KB
`define AXI_ADDR_SLV1_BASE  32'h4000_0000   // CSR Peripheral Registers Base
`define AXI_ADDR_SLV1_HIGH  32'h4000_0FFF   // CSR Range: 4 KB

// ----------------------------------------------------------------------------
// CSR Peripheral Register Offsets
// ----------------------------------------------------------------------------
`define REG_CTRL_OFFSET     32'h0000_0000   // Control: [0]=Start, [1]=Mode, [2]=IE
`define REG_STATUS_OFFSET   32'h0000_0004   // Status:  [0]=Busy, [1]=Done, [2]=Err
`define REG_SCRATCH0_OFFSET 32'h0000_0008   // Scratchpad Register 0
`define REG_SCRATCH1_OFFSET 32'h0000_000C   // Scratchpad Register 1
`define REG_TXN_CNT_OFFSET  32'h0000_0010   // Completed Transaction Counter
`define REG_LOOPBACK_OFFSET 32'h0000_0014   // Bitwise Inversion Loopback Reg

`endif // AXI_PKG_VH
