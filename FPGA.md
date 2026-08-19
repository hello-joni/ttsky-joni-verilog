# FPGA Workflow

Build, flash, and test the design on the Tiny Tapeout FPGA breakout board.

All commands run inside the devShell, which direnv loads automatically on entering the repo
(`nix develop` works too). The `tt_fpga` command wraps tt-support-tools' `tt_fpga.py`.

## Build the bitstream

For the root project:

```
tt_fpga harden
```

The output is `build/<top_module>.bin`. The design comes from `info.yaml` in the project dir:
`top_module` and `source_files` (relative to `src/`).

To build one of the examples instead, point `--project-dir` at its folder:

```
tt_fpga --project-dir examples/tt_um_vga_example_gamepad harden
```

This writes `examples/tt_um_vga_example_gamepad/build/tt_um_vga_example_gamepad.bin`.

## Flash the board

For the root project:

```
tt_fpga configure --upload --port /dev/ttyACM0
```

This uploads `build/<top_module>.bin` to `/bitstreams/` on the board.

For one of the examples, pass the same `--project-dir` used to harden it:

```
tt_fpga --project-dir examples/tt_um_vga_example_gamepad configure --upload --port /dev/ttyACM0
```

## Enable the design

Connect to the REPL:

```
nix develop -c mpremote connect /dev/ttyACM0
```

Wait a few seconds after you plug in the board before you connect. If you connect before the boot
process finishes, the `tt` object is not available.

If `tt` is not defined, unplug the board and plug it in again. Wait for the boot to finish, then
connect again. If `tt` is still not defined, create the object manually:

```python
from ttboard.demoboard import DemoBoard
tt = DemoBoard.get()
```

Enable the design:

```python
tt.shuttle.<top_module>.enable()
```

For the gamepad example:

```python
tt.shuttle.tt_um_vga_example_gamepad.enable()
```

## Update the firmware

Firmware releases are published at https://github.com/TinyTapeout/tt-micropython-firmware/releases

1. Hold the BOOT button while you connect the board to USB. The board shows up as a mass-storage
   device.
2. Copy the RP2350 UF2 file from the latest release onto the drive.
3. The board flashes the firmware and restarts.

An update erases the board filesystem. This includes `config.ini` and all uploaded bitstreams. Run
the flash step again after the update.

Check the current firmware version from the REPL:

```python
tt.version
```
