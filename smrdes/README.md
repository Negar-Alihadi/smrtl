# Sequential Machines SERDES (smrdes)

Just tilt your head, and you should see SERDES.

## Architecture

- source-synchronous forwarded clock
- DDR sampling
- LANES=11, W=8, 88-bit output

## Files
- `rtl/` - Verilog sources, synth-friendly vendor neutral
- `sim/` - sim-only models (jitter/delayline, analogish)
- `tb/` -  unit + small integration TBs for smrdes blocks
  - `tb_unit_*` (bitslip/delay/buf alone)
  - `tb_link_*` (small end-to-end: tx→channel→rx with training + PRBS)