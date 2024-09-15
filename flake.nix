{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    nixgl.url = "github:nix-community/nixGL";
    flake-parts.url = "github:hercules-ci/flake-parts";
    boulder.url = "github:berkeleytrue/nix-boulder-banner";
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.boulder.flakeModule
      ];
      systems = ["x86_64-linux"];
      perSystem = {
        config,
        system,
        lib,
        ...
      }: let
        pkgs = import nixpkgs {
          inherit system;

          overlays = [
            inputs.nixgl.overlay
          ];
        };
        run = pkgs.writeShellScriptBin "run" ''
          cargo run
        '';

        build = pkgs.writeShellScriptBin "build" ''
          cargo build
        '';
      in {
        formatter.default = pkgs.alejandra;
        boulder.commands = [
          {
            exec = run;
            description = "cargo run";
          }
          {
            exec = build;
            description = "cargo build";
          }
        ];
        devShells.default = pkgs.mkShell {
          name = "rust";
          inputsFrom = [
            config.boulder.devShell
          ];

          buildInputs = with pkgs; [
            clippy
            cargo
            cargo-generate
            rustup
            rustfmt
            rust-analyzer
            espup
            espflash
            podman
            libclang.lib
            ldproxy
          ];
          LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.stdenv.cc.cc pkgs.libz pkgs.libxml2];
          LIBCLANG_PATH = lib.makeLibraryPath [pkgs.libclang];

          shellHook = ''
            # espup install --targets esp32s3 --export-file ./exports-esp.sh
            source ./exports-esp.sh
            export PATH=$PATH:$HOME/.cargo/bin
          '';
        };
      };
      flake = {};
    };
}
