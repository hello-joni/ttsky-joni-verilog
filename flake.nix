{
  description = "Tiny Tapeout SKY 26c — Joni's Verilog project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tt-support-tools = {
      url = "github:TinyTapeout/tt-support-tools";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      tt-support-tools,
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # uv2nix Python environment for tt-support-tools
          workspace = uv2nix.lib.workspace.loadWorkspace {
            workspaceRoot = ./tt-fpga;
          };
          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          };
          pythonBase = pkgs.callPackage pyproject-nix.build.packages {
            python = pkgs.python311;
          };
          pythonSet = pythonBase.overrideScope (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.wheel
              overlay
            ]
          );
          ttEnv = pythonSet.mkVirtualEnv "tt-support-tools-env" workspace.deps.default;
        in
        {
          # RTL simulation + lint shell (unchanged from original)
          default = pkgs.mkShell {
            packages = with pkgs; [
              iverilog
              verilator
              gnumake
              python311
              python311Packages.cocotb
              python311Packages.pytest
            ];
          };

          # FPGA harden + flash shell
          fpga = pkgs.mkShell {
            packages = [
              ttEnv
              pkgs.yosys
              pkgs.nextpnr
              pkgs.icestorm
              pkgs.git
              pkgs.cairo
            ];

            # cairocffi loads libcairo via ctypes at import time.
            LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.cairo ];
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # uv2nix Python environment for tt-support-tools
          workspace = uv2nix.lib.workspace.loadWorkspace {
            workspaceRoot = ./tt-fpga;
          };
          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          };
          pythonBase = pkgs.callPackage pyproject-nix.build.packages {
            python = pkgs.python311;
          };
          pythonSet = pythonBase.overrideScope (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.wheel
              overlay
            ]
          );
          ttEnv = pythonSet.mkVirtualEnv "tt-support-tools-env" workspace.deps.default;

          # Toolchain for FPGA bitstream synthesis
          fpgaToolchain = [
            pkgs.yosys
            pkgs.nextpnr
            pkgs.icestorm
          ];

          ttFpgaScript = "${tt-support-tools}/tt_fpga.py";
        in
        {
          # RTL simulation + Verilator lint (unchanged from original)
          test = pkgs.stdenv.mkDerivation {
            name = "ttsky-joni-verilog-test";
            src = self;

            nativeBuildInputs = with pkgs; [
              iverilog
              verilator
              gnumake
              python311
              python311Packages.cocotb
              python311Packages.pytest
            ];

            buildPhase = ''
              verilator --lint-only --Wall --Wno-fatal \
                --Werror-LATCH --Werror-MULTIDRIVEN \
                --Wno-DECLFILENAME --Wno-EOFNEWLINE \
                --top-module tt_um_hello_joni \
                src/project.v

              cd test
              make clean
              make
            '';

            doCheck = true;
            checkPhase = ''
              ! grep failure results.xml
            '';

            installPhase = ''
              mkdir -p $out
              cp results.xml $out/
              cp tb.fst $out/
            '';
          };

          # FPGA bitstream synthesis: runs tt_fpga.py harden, outputs build/<top>.bin
          fpga-harden = pkgs.stdenv.mkDerivation {
            name = "ttsky-joni-verilog-fpga-harden";
            src = self;

            nativeBuildInputs = [
              ttEnv
              pkgs.git
            ] ++ fpgaToolchain;

            buildInputs = [
              pkgs.cairo
            ];

            # cairocffi loads libcairo via ctypes at import time.
            # gdstk may also need libraries from the Nix store.
            LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.cairo ];

            # tt_fpga.py writes _tt_fpga_top.v into the source dir and build/ next to it.
            # Both need to be writable.
            buildPhase = ''
              cp -r ${tt-support-tools} tt
              chmod -R u+w tt

              export PYTHONPATH=${tt-support-tools}:$PYTHONPATH
              python ${ttFpgaScript} --project-dir . harden
            '';

            installPhase = ''
              mkdir -p $out
              cp build/*.bin $out/
            '';
          };

          # FPGA flash: wrapper script that uploads a built bitstream to the demoboard.
          # The bitstream comes from fpga-harden's Nix store output.
          # Usage: nix run .#fpga-flash -- --port /dev/ttyACM0
          fpga-flash = pkgs.writeShellApplication {
            name = "tt-fpga-flash";
            runtimeInputs = [
              ttEnv
              pkgs.cairo
            ];
            text = ''
              export LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.cairo ]}

              # tt_fpga.py configure expects build/<top>.bin relative to CWD.
              # Copy the bitstream from the Nix store into a temp build/ dir.
              tmpdir=$(mktemp -d)
              trap 'rm -rf "$tmpdir"' EXIT
              mkdir -p "$tmpdir/build"
              cp ${self.packages.${system}.fpga-harden}/*.bin "$tmpdir/build/"

              cd "$tmpdir"
              exec python ${ttFpgaScript} \
                --project-dir ${self} \
                configure --upload "$@"
            '';
          };

          default = self.packages.${system}.test;
        }
      );
    };
}
