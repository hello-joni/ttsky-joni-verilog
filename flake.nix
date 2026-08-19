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

          # tt-support-tools with a local patch: tt_fpga.py references the
          # generated _tt_fpga_top.v wrapper relative to the CWD, so hardening
          # a non-root project from the repo root picks up a stale wrapper.
          # The patch makes the path absolute, matching the source files.
          tt-support-tools-patched = pkgs.applyPatches {
            name = "tt-support-tools-patched";
            src = tt-support-tools;
            patches = [ ./tt-fpga/tt_fpga-cwd-fix.patch ];
          };

          # Wrapper so tt_fpga.py can be invoked directly from the devShell.
          # tt_fpga.py imports sibling modules (project.py etc.), so the
          # tt-support-tools tree must be on PYTHONPATH.
          ttFpga = pkgs.writeShellScriptBin "tt_fpga" ''
            export PYTHONPATH=${tt-support-tools-patched}:''${PYTHONPATH:-}
            export LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.cairo ]}
            exec ${ttEnv}/bin/python ${tt-support-tools-patched}/tt_fpga.py "$@"
          '';
        in
        {
          # RTL simulation + lint + FPGA harden/flash shell
          default = pkgs.mkShell {
            packages = [
              ttFpga
              ttEnv
            ] ++ (with pkgs; [
              iverilog
              verilator
              gnumake
              python311
              python311Packages.cocotb
              python311Packages.pytest

              # FPGA bitstream synthesis and flashing
              yosys
              nextpnr
              icestorm
              git
              cairo
            ]);
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
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

          default = self.packages.${system}.test;
        }
      );
    };
}
