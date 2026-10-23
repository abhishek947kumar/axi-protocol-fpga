# Contributing Guidelines

Thank you for your interest in contributing to the **AMBA AXI4 Protocol Implementation on FPGA** project!

## How to Contribute
1. **Fork the repository** on GitHub.
2. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Coding Standards**:
   - Write clean, synthesizable Verilog-2001 for RTL modules.
   - Use SystemVerilog (IEEE 1800) for testbenches and SVA assertion monitors.
   - Strictly follow synchronous reset (`aresetn` active-low) design methodology.
   - Avoid combinational loops and inferred latches (verify `utilization.rpt` has 0 latches).
4. **Verification**:
   - Run the simulation test suite before submitting:
     ```powershell
     .\scripts\run_sim.bat
     ```
   - Ensure all 21 test cases pass with 0 errors and zero SVA violations.
5. **Submit a Pull Request**:
   - Provide a clear PR description detailing your changes, motivation, and attaching simulation logs.
