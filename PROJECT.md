# Project Guide

Tiny Tapeout SKY 26c submission. One tile, SkyWater 130nm PDK, Verilog-2005.

## Repository layout

- `src/`: the HDL design. `project.v` contains the top module (`tt_um_hello_joni`).
- `test/`: cocotb test harness. `test.py` drives the simulation, `tb.v` instantiates the DUT,
  `Makefile` orchestrates the build. Run `make -B` from this directory.
- `docs/`: datasheet source. `info.md` becomes the project page on the Tiny Tapeout site.
- `.github/workflows/`: CI definitions. `test.yaml` runs RTL simulation, `gds.yaml` runs the full
  hardening flow, `docs.yaml` builds the datasheet.
- `.devcontainer/`: VS Code dev container with LibreLane and tt-support-tools for local hardening.
- `.vscode/`: editor settings and recommended extensions.

## Notable files

- `info.yaml`: project metadata consumed by the Tiny Tapeout tooling. Defines the top module name,
  source file list, pinout labels, and tile count. CI validates this on every push.
- `flake.nix`: Nix flake providing a devShell (iverilog, cocotb, pytest) and a `test` package
  runnable via `nix build`.
- `.envrc`: direnv integration, loads the flake automatically on entering the directory.

## Local development

Enter the devShell with `nix develop` or rely on direnv. Run tests from `test/` with `make -B`.
Alternatively, `nix build` runs the full test suite and produces a `result/` symlink with the test
artifacts.

## Reference

- [Tiny Tapeout HDL guide (submission overview, templates, testing)](https://tinytapeout.com/hdl/)
- [Tiny Tapeout important notes (hard constraints on HDL submissions)](https://tinytapeout.com/hdl/important/)
- [Local hardening guide (running LibreLane outside CI)](https://tinytapeout.com/guides/local-hardening/)
- [SKY 26c shuttle page (deadline, foundry, PDK)](https://tinytapeout.com/chips/ttsky26c/)
- [Shuttle status dashboard (live submission deadline)](https://app.tinytapeout.com/shuttles/)
- [cocotb documentation (Python testbench framework)](https://docs.cocotb.org/)
- [LibreLane (ASIC implementation flow used by CI)](https://github.com/librelane/librelane)
