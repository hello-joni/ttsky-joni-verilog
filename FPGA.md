# FPGA Workflow

Build, flash, and test the design on the Tiny Tapeout FPGA breakout board.

## Build the bitstream

```
nix build .#fpga-harden
```

The output is `result/<top_module>.bin`.

## Flash the board

```
nix run .#fpga-flash -- --port /dev/ttyACM0
```

This command builds the bitstream if it is not built already. Then it uploads the bitstream to
`/bitstreams/` on the board.

## Enable the design

Connect to the REPL:

```
nix develop .#fpga -c mpremote connect /dev/ttyACM0
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
