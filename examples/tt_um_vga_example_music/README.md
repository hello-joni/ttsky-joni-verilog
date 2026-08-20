# Music example

Build and flash from the repo root:

```
tt_fpga --project-dir examples/tt_um_vga_example_music harden
tt_fpga --project-dir examples/tt_um_vga_example_music configure --upload --port /dev/ttyACM0
```

Then enable the design and set the clock in the REPL:

```python
tt.shuttle.tt_um_vga_example_music.enable()
tt.clock_project_PWM(25175000)
```

The clock must be set after every `enable()`, because the design expects 25.175 MHz, as declared in
`info.yaml` (`clock_hz: 25175000`).
