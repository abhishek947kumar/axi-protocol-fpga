// ============================================================================
// File: tb_axi_top.sv
// Description: Comprehensive Self-Checking Verification Testbench for AMBA AXI4
//              SoC Subsystem. Covers single/burst transfers (INCR, FIXED, WRAP),
//              byte strobes (WSTRB), AXI4-Lite register access, concurrent
//              full-duplex operation, decode error handling, and SVA assertions.
// Standard: IEEE 1800-2012 (SystemVerilog)
// ============================================================================

`timescale 1ns / 1ps
`include "axi_pkg.vh"

module tb_axi_top;

    // -------------------------------------------------------------------------
    // Parameters & Clock/Reset Signals
    // -------------------------------------------------------------------------
    localparam C_AXI_ID_WIDTH   = 4;
    localparam C_AXI_ADDR_WIDTH = 32;
    localparam C_AXI_DATA_WIDTH = 32;
    localparam CLK_PERIOD       = 10; // 100 MHz clock

    reg  clk;
    reg  rst_n;

    // Command Interface Signals
    reg                             cmd_wr_start;
    reg  [C_AXI_ADDR_WIDTH-1:0]     cmd_wr_addr;
    reg  [7:0]                      cmd_wr_len;
    reg  [2:0]                      cmd_wr_size;
    reg  [1:0]                      cmd_wr_burst;
    reg  [C_AXI_DATA_WIDTH-1:0]     cmd_wr_seed;
    reg  [(C_AXI_DATA_WIDTH/8)-1:0] cmd_wr_strb;
    wire                            wr_busy;
    wire                            wr_done;
    wire                            wr_error;
    wire [1:0]                      wr_resp_code;

    reg                             cmd_rd_start;
    reg  [C_AXI_ADDR_WIDTH-1:0]     cmd_rd_addr;
    reg  [7:0]                      cmd_rd_len;
    reg  [2:0]                      cmd_rd_size;
    reg  [1:0]                      cmd_rd_burst;
    wire                            rd_busy;
    wire                            rd_done;
    wire                            rd_error;
    wire [1:0]                      rd_resp_code;
    wire [C_AXI_DATA_WIDTH-1:0]     last_rd_data;
    wire [7:0]                      rd_beat_cnt_out;

    wire [3:0]                      status_leds;
    wire [31:0]                     debug_csr_ctrl;
    wire [31:0]                     debug_csr_scratch0;
    wire [31:0]                     debug_csr_scratch1;
    wire [31:0]                     debug_csr_txns;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // Instantiate Device Under Test (DUT)
    // -------------------------------------------------------------------------
    axi_soc_top #(
        .C_AXI_ID_WIDTH     (C_AXI_ID_WIDTH),
        .C_AXI_ADDR_WIDTH   (C_AXI_ADDR_WIDTH),
        .C_AXI_DATA_WIDTH   (C_AXI_DATA_WIDTH),
        .MEM_DEPTH_WORDS    (512),
        .SLAVE_WAIT_CYCLES  (0)
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
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

        .status_leds        (status_leds),
        .debug_csr_ctrl     (debug_csr_ctrl),
        .debug_csr_scratch0 (debug_csr_scratch0),
        .debug_csr_scratch1 (debug_csr_scratch1),
        .debug_csr_txns     (debug_csr_txns)
    );

    // -------------------------------------------------------------------------
    // Instantiate SystemVerilog Assertions Protocol Checker
    // -------------------------------------------------------------------------
    axi_protocol_checker #(
        .C_AXI_ID_WIDTH     (C_AXI_ID_WIDTH),
        .C_AXI_ADDR_WIDTH   (C_AXI_ADDR_WIDTH),
        .C_AXI_DATA_WIDTH   (C_AXI_DATA_WIDTH),
        .INTERFACE_NAME     ("DUT_MASTER_AXI")
    ) u_sva_checker (
        .aclk               (clk),
        .aresetn            (rst_n),
        .awid               (dut.m_awid),
        .awaddr             (dut.m_awaddr),
        .awlen              (dut.m_awlen),
        .awsize             (dut.m_awsize),
        .awburst            (dut.m_awburst),
        .awvalid            (dut.m_awvalid),
        .awready            (dut.m_awready),

        .wdata              (dut.m_wdata),
        .wstrb              (dut.m_wstrb),
        .wlast              (dut.m_wlast),
        .wvalid             (dut.m_wvalid),
        .wready             (dut.m_wready),

        .bid                (dut.m_bid),
        .bresp              (dut.m_bresp),
        .bvalid             (dut.m_bvalid),
        .bready             (dut.m_bready),

        .arid               (dut.m_arid),
        .araddr             (dut.m_araddr),
        .arlen              (dut.m_arlen),
        .arsize             (dut.m_arsize),
        .arburst            (dut.m_arburst),
        .arvalid            (dut.m_arvalid),
        .arready            (dut.m_arready),

        .rid                (dut.m_rid),
        .rdata              (dut.m_rdata),
        .rresp              (dut.m_rresp),
        .rlast              (dut.m_rlast),
        .rvalid             (dut.m_rvalid),
        .rready             (dut.m_rready)
    );

    // -------------------------------------------------------------------------
    // Verification Tasks
    // -------------------------------------------------------------------------
    task automatic axi_write(
        input [31:0] addr,
        input [7:0]  len,
        input [2:0]  size,
        input [1:0]  burst,
        input [31:0] seed,
        input [3:0]  strb
    );
        begin
            @(posedge clk);
            cmd_wr_addr  <= addr;
            cmd_wr_len   <= len;
            cmd_wr_size  <= size;
            cmd_wr_burst <= burst;
            cmd_wr_seed  <= seed;
            cmd_wr_strb  <= strb;
            cmd_wr_start <= 1'b1;
            @(posedge clk);
            cmd_wr_start <= 1'b0;
            
            // Wait for write completion
            @(posedge clk);
            while (wr_busy) @(posedge clk);
            @(posedge clk);
        end
    endtask

    task automatic axi_read(
        input  [31:0] addr,
        input  [7:0]  len,
        input  [2:0]  size,
        input  [1:0]  burst,
        output [31:0] rdata,
        output [1:0]  resp
    );
        begin
            @(posedge clk);
            cmd_rd_addr  <= addr;
            cmd_rd_len   <= len;
            cmd_rd_size  <= size;
            cmd_rd_burst <= burst;
            cmd_rd_start <= 1'b1;
            @(posedge clk);
            cmd_rd_start <= 1'b0;

            // Wait for read completion
            @(posedge clk);
            while (rd_busy) @(posedge clk);
            rdata = last_rd_data;
            resp  = rd_resp_code;
            @(posedge clk);
        end
    endtask

    task automatic report_test(
        input string name,
        input bit    passed,
        input [31:0] expected,
        input [31:0] actual
    );
        begin
            test_count++;
            if (passed) begin
                pass_count++;
                $display("  [PASS] Test %02d: %s (Expected: 0x%08X, Actual: 0x%08X)", test_count, name, expected, actual);
            end else begin
                fail_count++;
                $display("  [FAIL] Test %02d: %s (Expected: 0x%08X, Actual: 0x%08X) <--- MISMATCH!", test_count, name, expected, actual);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Verification Flow
    // -------------------------------------------------------------------------
    reg [31:0] rd_data_val = 32'h0;
    reg [1:0]  rd_resp_val = 2'b00;
    integer i = 0;

    initial begin
        // Signal Initialization
        rd_data_val  = 32'h0;
        rd_resp_val  = 2'b00;
        i            = 0;
        cmd_wr_start = 1'b0;
        cmd_wr_addr  = 32'h0;
        cmd_wr_len   = 8'h0;
        cmd_wr_size  = 3'h2;
        cmd_wr_burst = 2'h1;
        cmd_wr_seed  = 32'h0;
        cmd_wr_strb  = 4'hF;

        cmd_rd_start = 1'b0;
        cmd_rd_addr  = 32'h0;
        cmd_rd_len   = 8'h0;
        cmd_rd_size  = 3'h2;
        cmd_rd_burst = 2'h1;

        // Dump VCD waveform for universal waveform viewing (GTKWave / VS Code WaveTrace)
        $dumpfile("sim_output/tb_axi_waveform.vcd");
        $dumpvars(0, tb_axi_top);

        rst_n = 1'b0;
        $display("\n================================================================================");
        $display("          AMBA AXI4 PROTOCOL SUBSYSTEM - SYSTEMVERILOG VERIFICATION");
        $display("================================================================================\n");

        // Reset sequence
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD * 5);
        $display("[INFO] System Reset Released. Initializing Test Sequence...\n");

        // ---------------------------------------------------------------------
        // TEST 1: Single-Beat 32-bit Memory Write and Read (INCR len=0)
        // ---------------------------------------------------------------------
        $display("--- [Phase 1: Basic Single-Beat Memory Access] ---");
        axi_write(32'h0000_0010, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, 32'hDEAD_BEEF, 4'hF);
        axi_read(32'h0000_0010, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("Single Beat Write/Read at 0x0000_0010", (rd_data_val == 32'hDEAD_BEEF && rd_resp_val == `AXI_RESP_OKAY), 32'hDEAD_BEEF, rd_data_val);

        // ---------------------------------------------------------------------
        // TEST 2: Multi-Beat INCR Burst (4 beats = 16 bytes)
        // ---------------------------------------------------------------------
        $display("\n--- [Phase 2: Multi-Beat Incrementing Bursts (INCR)] ---");
        axi_write(32'h0000_0020, 8'd3, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, 32'h1000_0000, 4'hF);
        // Verify written data by reading each beat
        for (i = 0; i < 4; i = i + 1) begin
            axi_read(32'h0000_0020 + (i*4), 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
            report_test($sformatf("INCR Burst Beat %0d at 0x%08X", i, 32'h0000_0020 + (i*4)), 
                        (rd_data_val == (32'h1000_0000 + i)), (32'h1000_0000 + i), rd_data_val);
        end

        // ---------------------------------------------------------------------
        // TEST 3: Long Multi-Beat INCR Burst (16 beats)
        // ---------------------------------------------------------------------
        axi_write(32'h0000_0100, 8'd15, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, 32'hA000_0000, 4'hF);
        // Check first and last beats of the 16-beat burst
        axi_read(32'h0000_0100, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("16-Beat INCR Burst First Beat at 0x0000_0100", (rd_data_val == 32'hA000_0000), 32'hA000_0000, rd_data_val);
        axi_read(32'h0000_013C, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("16-Beat INCR Burst Final Beat at 0x0000_013C", (rd_data_val == 32'hA000_000F), 32'hA000_000F, rd_data_val);

        // ---------------------------------------------------------------------
        // TEST 4: Fixed Address Burst (FIXED len=3, 4 beats to same address)
        // ---------------------------------------------------------------------
        $display("\n--- [Phase 3: Fixed Address Bursts (FIXED / FIFO Emulation)] ---");
        // All 4 beats write to 0x0000_0200; final value in memory will be seed + 3
        axi_write(32'h0000_0200, 8'd3, `AXI_SIZE_4_BYTES, `AXI_BURST_FIXED, 32'h5555_0001, 4'hF);
        axi_read(32'h0000_0200, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_FIXED, rd_data_val, rd_resp_val);
        report_test("FIXED Burst Overwrite at 0x0000_0200", (rd_data_val == 32'h5555_0004), 32'h5555_0004, rd_data_val);

        // ---------------------------------------------------------------------
        // TEST 5: Wrapping Address Burst (WRAP len=3, 4 beats = 16-byte wrap)
        // ---------------------------------------------------------------------
        $display("\n--- [Phase 4: Wrapping Bursts (WRAP / Cache Line Fill)] ---");
        // Start address 0x0000_0048 (Wrap boundary: 0x0000_0040, Wrap size: 16 bytes)
        // Beat 0: 0x0000_0048 -> data = 0xCAFE0000
        // Beat 1: 0x0000_004C -> data = 0xCAFE0001
        // Beat 2: 0x0000_0040 (WRAPPED) -> data = 0xCAFE0002
        // Beat 3: 0x0000_0044 -> data = 0xCAFE0003
        axi_write(32'h0000_0048, 8'd3, `AXI_SIZE_4_BYTES, `AXI_BURST_WRAP, 32'hCAFE_0000, 4'hF);
        axi_read(32'h0000_0048, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("WRAP Burst Beat 0 at 0x0000_0048", (rd_data_val == 32'hCAFE_0000), 32'hCAFE_0000, rd_data_val);
        axi_read(32'h0000_004C, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("WRAP Burst Beat 1 at 0x0000_004C", (rd_data_val == 32'hCAFE_0001), 32'hCAFE_0001, rd_data_val);
        axi_read(32'h0000_0040, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("WRAP Burst Beat 2 (Wrapped) at 0x0000_0040", (rd_data_val == 32'hCAFE_0002), 32'hCAFE_0002, rd_data_val);
        axi_read(32'h0000_0044, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("WRAP Burst Beat 3 at 0x0000_0044", (rd_data_val == 32'hCAFE_0003), 32'hCAFE_0003, rd_data_val);

        // ---------------------------------------------------------------------
        // TEST 6: Byte Strobe Masking (WSTRB)
        // ---------------------------------------------------------------------
        $display("\n--- [Phase 5: Byte Enable Write Strobes (WSTRB)] ---");
        // Clear word at 0x0000_0300
        axi_write(32'h0000_0300, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, 32'h0000_0000, 4'b1111);
        // Write byte 0 (0xAA) with strb=4'b0001
        axi_write(32'h0000_0300, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, 32'h1122_33AA, 4'b0001);
        // Write byte 2 (0xCC) with strb=4'b0100
        axi_write(32'h0000_0300, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, 32'h77CC_8899, 4'b0100);
        axi_read(32'h0000_0300, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("Byte Strobe Selective Masking (0x00CC00AA)", (rd_data_val == 32'h00CC_00AA), 32'h00CC_00AA, rd_data_val);

        // ---------------------------------------------------------------------
        // TEST 7: AXI4-Lite Register Interface via Protocol Converter Bridge
        // ---------------------------------------------------------------------
        $display("\n--- [Phase 6: AXI4-Lite CSR Peripheral Access via Bridge] ---");
        // Write to Scratchpad 0 (0x4000_0008)
        axi_write(32'h4000_0008, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, 32'h1234_5678, 4'hF);
        axi_read(32'h4000_0008, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("AXI4-Lite Scratchpad 0 Register Read/Write", (rd_data_val == 32'h1234_5678), 32'h1234_5678, rd_data_val);

        // Write to Loopback Register (0x4000_0014) -> reads ~value
        axi_write(32'h4000_0014, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, 32'h0000_FFFF, 4'hF);
        axi_read(32'h4000_0014, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("AXI4-Lite Loopback Inversion Register", (rd_data_val == 32'hFFFF_0000), 32'hFFFF_0000, rd_data_val);

        // Write to Control Register (0x4000_0000)
        axi_write(32'h4000_0000, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, 32'h0000_0007, 4'hF);
        axi_read(32'h4000_0000, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("AXI4-Lite Control Register Configuration", (rd_data_val == 32'h0000_0007), 32'h0000_0007, rd_data_val);

        // ---------------------------------------------------------------------
        // TEST 8: Crossbar Address Decode Error Handling (DECERR)
        // ---------------------------------------------------------------------
        $display("\n--- [Phase 7: Address Decode Error Handling (DECERR)] ---");
        // Access unmapped address 0x8000_0000 (outside 0x0000_0000-0x0000_FFFF and 0x4000_0000-0x4000_0FFF)
        axi_write(32'h8000_0000, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, 32'hBAAD_F00D, 4'hF);
        report_test("Interconnect Write DECERR Response Code", (wr_resp_code == `AXI_RESP_DECERR && wr_error == 1'b1), 
                    `AXI_RESP_DECERR, wr_resp_code);

        axi_read(32'h8000_0000, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("Interconnect Read DECERR Response Code", (rd_resp_val == `AXI_RESP_DECERR && rd_error == 1'b1), 
                    `AXI_RESP_DECERR, rd_resp_val);

        // ---------------------------------------------------------------------
        // TEST 9: Concurrent Full-Duplex Write and Read Operation
        // ---------------------------------------------------------------------
        $display("\n--- [Phase 8: Concurrent Full-Duplex Read & Write Channels] ---");
        @(posedge clk);
        cmd_wr_addr  <= 32'h0000_0500;
        cmd_wr_len   <= 8'd3;
        cmd_wr_size  <= `AXI_SIZE_4_BYTES;
        cmd_wr_burst <= `AXI_BURST_INCR;
        cmd_wr_seed  <= 32'hF00D_0000;
        cmd_wr_strb  <= 4'hF;
        cmd_wr_start <= 1'b1;

        cmd_rd_addr  <= 32'h0000_0020;
        cmd_rd_len   <= 8'd3;
        cmd_rd_size  <= `AXI_SIZE_4_BYTES;
        cmd_rd_burst <= `AXI_BURST_INCR;
        cmd_rd_start <= 1'b1;

        @(posedge clk);
        cmd_wr_start <= 1'b0;
        cmd_rd_start <= 1'b0;

        @(posedge clk);
        while (wr_busy || rd_busy) @(posedge clk);
        @(posedge clk);

        report_test("Simultaneous Full-Duplex Write Completion", (!wr_error && wr_resp_code == `AXI_RESP_OKAY), 32'd0, wr_error);
        report_test("Simultaneous Full-Duplex Read Completion", (!rd_error && rd_resp_code == `AXI_RESP_OKAY), 32'd0, rd_error);

        // Read back written concurrent data to ensure data integrity
        axi_read(32'h0000_0500, 8'd0, `AXI_SIZE_4_BYTES, `AXI_BURST_INCR, rd_data_val, rd_resp_val);
        report_test("Concurrent Write Data Integrity Check", (rd_data_val == 32'hF00D_0000), 32'hF00D_0000, rd_data_val);

        // ---------------------------------------------------------------------
        // Final Summary Report
        // ---------------------------------------------------------------------
        #(CLK_PERIOD * 10);
        $display("\n================================================================================");
        $display("                         VERIFICATION SUMMARY REPORT");
        $display("================================================================================");
        $display("  Total Test Cases Executed : %0d", test_count);
        $display("  Total Test Cases Passed   : %0d", pass_count);
        $display("  Total Test Cases Failed   : %0d", fail_count);
        if (fail_count == 0) begin
            $display("\n  >>> STATUS: ALL TESTS PASSED SUCCESSFULLY! AMBA AXI4 COMPLIANT! <<<");
        end else begin
            $display("\n  >>> STATUS: VERIFICATION FAILED WITH %0d ERRORS! <<<", fail_count);
        end
        $display("================================================================================\n");

        $finish;
    end

endmodule
