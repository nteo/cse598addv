## Contents

| Path | Description |
|------|-------------|
| `Makefile` | Compiles the RTL, then runs the ISS, RTL and comparison for each program |
| `tb_trace.sv` | Testbench that loads a program, runs the RTL, and writes the RTL trace |
| `MIPS-Simulator/` | The ISS (cloned from https://github.com/viggu3sd/MIPS-Simulator) |
| `programs/` | The 3 hand-written test programs (`prog1.asm`, `prog2.asm`, `prog3.asm`) |
| `traces/` | Generated files: machine code (`.bin`), ISS traces, RTL traces, sim logs |
| `compare.py` | Compares the ISS trace against the RTL trace (TODO) |

## ISS used

MIPS-Simulator by viggu3sd: a Python script that assembles a MIPS assembly file
to 32-bit binary, executes it, and prints each instruction with the register
state. It was chosen because it is the course-recommended ISS, supports the
instructions in this lab, needs no installation beyond Python 3, and prints a
trace that is easy to parse.

Changes made to the ISS (TODO: confirm which were applied):
- `lw`/`sw` effective address changed to `registers[rs] + immediate`. The
  original ignored the base register.
- Input and output file names are taken from the command line instead of
  being hard-coded to `input.txt` / `output.txt`.

## Requirements

- Python 3.6 or higher
- Synopsys VCS and Verdi (`VCS_HOME` and `VERDI_HOME` set)
- The RTL file list `project.f` (default location `../project.f`)

## Writing a program

Programs go in `programs/` as `.asm` files. The ISS has some limits:
- Use register names such as `$t0`-`$t3`, not `$1`, `$2`.
- Put each label on its own line, and do not use inline comments.
- Avoid `nop`, `move` and negative immediates.
- Use only `add`, `and`, `lw`, `sw`, `beq` and `addi`.
- End each program with the trickbox store, which writes `0xDED` to byte address
  `0x40`, for example:
  ```
  addi $t0, $zero, 3565
  sw $t0, 64($zero)
  ```
  The testbench ends the simulation when this value appears at that address.

## Running

Run these from this folder (on the Linux/VCS machine):

```
make compile      # compile the RTL and tb_trace.sv once
make              # compile, then run all 3 programs
make prog1        # run one program (after make compile)
```

For each program the Makefile runs these steps:

1. **ISS:** `python3 MIPS-Simulator/mips_simulator.py programs/progN.asm traces/progN.bin > traces/progN.iss.trace`
   writes the machine code (`.bin`) and the ISS trace.
2. **RTL:** `./simv +PROG=traces/progN.bin +TRACE=traces/progN.rtl.trace`
   runs the RTL on the same machine code and writes the RTL trace.
3. **Compare:** `python3 compare.py traces/progN.iss.trace traces/progN.rtl.trace`
   prints PASS or FAIL.

Other targets:

```
make verdi          # open Verdi
make waves_verdi    # open Verdi with waves from the last run (novas.fsdb)
make clean          # remove simulation files, keep traces/
make clean_all      # also remove traces/
```

If `project.f` is not at `../project.f`, run `make PROJ_F=<path>/project.f`.

## RTL trace format (`*.rtl.trace`)

One event per line, written by `tb_trace.sv`:

```
R <reg#> <data hex>        register file write (register 0 is never logged)
M <byte addr> <data hex>   data memory write (store)
```

Examples: `R 10 00000008`, `M 00000000 00000008`

Changes needed in the testbench/DUT: no DUT changes. The testbench reads the
register file write port (`dut.mips.dp.rf.we3`, `.wa3`, `.wd3`) and the top-level
`memwrite`, `dataadr` and `writedata` outputs on every clock edge.

## Comparing traces

Because the processor is pipelined, a store (MEM stage) and an older
instruction's register write (WB stage) can occur in a different relative order
than in the ISS. The two kinds of events are therefore compared as two separate
streams, each in program order:

- `R` events (register writes) against the register changes in the ISS trace
- `M` events (stores) against the ISS's memory writes

TODO: describe `compare.py` (how it parses the ISS trace, how it reports the
first mismatch).

## Partner contributions

TODO (required in the report; 20 points are deducted if it is missing).

## TODO list

- [ ] Write the 3 programs in `programs/`
- [ ] Confirm the ISS edits and the regfile signal names in `tb_trace.sv`
- [ ] Write the ISS trace converter and `compare.py`
- [ ] Run `make` and confirm all 3 programs pass
- [ ] Zip this folder with the Makefile and README