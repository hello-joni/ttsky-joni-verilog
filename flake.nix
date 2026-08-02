{
  description = "Tiny Tapeout SKY 26c — Joni's Verilog project";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              iverilog
              gnumake
              python311
              python311Packages.cocotb
              python311Packages.pytest
            ];
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          test = pkgs.stdenv.mkDerivation {
            name = "ttsky-joni-verilog-test";
            src = self;

            nativeBuildInputs = with pkgs; [
              iverilog
              gnumake
              python311
              python311Packages.cocotb
              python311Packages.pytest
            ];

            buildPhase = ''
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
