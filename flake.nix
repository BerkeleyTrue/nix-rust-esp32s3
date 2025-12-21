{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixgl.url = "github:nix-community/nixGL";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
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
      in {
        formatter.default = pkgs.alejandra;
        devShells.default = pkgs.mkShell {
          name = "rust";

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
            just
          ];
          LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.stdenv.cc.cc pkgs.libz pkgs.libxml2];
          LIBCLANG_PATH = lib.makeLibraryPath [pkgs.libclang];

          shellHook = ''
            just --list
            # espup install --targets esp32s3 --export-file ./exports-esp.sh
            source ./exports-esp.sh
            export PATH=$PATH:$HOME/.cargo/bin
          '';
        };
      };
      flake = {};
    };
}
