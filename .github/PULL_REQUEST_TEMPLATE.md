## Description of Changes
Please include a summary of the change, motivation, and which issue is fixed.

## Protocol Verification Checklist
- [ ] Conforms to AMBA AXI4 (ARM IHI0022E) specification.
- [ ] SystemVerilog Assertions (`axi_protocol_checker.sv`) pass with 0 errors.
- [ ] Top-level verification test suite (`tb_axi_top.sv`) passes all test cases.
- [ ] Non-project synthesis runs without latch inference or timing violations.
- [ ] Code follows synchronous active-low reset conventions.

## Simulation / Synthesis Results
Attach simulation test log or Vivado terminal output confirming that all tests pass.
