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
        web-flash = pkgs.rustPlatform.buildRustPackage rec {
          pname = "web-flash";
          version = "0.2.1";

          src = pkgs.fetchFromGitHub {
            owner = "esp-rs";
            repo = "esp-web-flash-server";
            rev = "v${version}";
            hash = "sha256-HUAFAU5oMFB2d59LiJrXYzDhpYDps9Kl1b2SN0x2CrY=";
          };

          cargoHash = "sha256-5WETh/B/btzxHAylWady1aORmZ9LRRJ41gZmzCe0iUw=";

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; [
            udev
            libusb1
          ];

          meta = with lib; {
            description = "Web server for flashing ESP devices";
            homepage = "https://github.com/esp-rs/esp-web-flash-server";
            license = licenses.mit;
            mainProgram = "web-flash";
          };
        };
      in {
        formatter.default = pkgs.alejandra;
        devShells.default = pkgs.mkShell {
          name = "rust";

          buildInputs =
            [
              web-flash
            ]
            ++ (with pkgs; [
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
            ]);
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
