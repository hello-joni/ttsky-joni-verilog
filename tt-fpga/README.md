# tt-fpga

Python environment for the Tiny Tapeout FPGA flow, built with
[uv2nix](https://pyproject-nix.github.io/uv2nix/).

## How this folder was made

1. The `pyproject.toml` was copied from
   [tt-support-tools](https://github.com/TinyTapeout/tt-support-tools).
2. Python was pinned to 3.11 with `uv python pin 3.11`.
3. The lockfile was made with `uv lock` using a Nix-provided Python interpreter.

## What the files do

- `pyproject.toml`: lists the Python packages that tt-support-tools needs.
- `uv.lock`: pins the exact version and hash of every package.
- `.python-version`: tells `uv` to use Python 3.11.

## Rebuild on a new machine

No manual steps are needed. The flake reads `uv.lock` and builds the Python environment with uv2nix.
