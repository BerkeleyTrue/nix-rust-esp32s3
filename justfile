default:
  just --list

[group('build')]
build:
  docker build --output=out -t test_esp-idf .

[group('build')]
debug:
  cargo build

[group('lsp')]
build-lsp:
  docker build -t rust-analyzer -f ./lsp/Dockerfile .

[group('lsp')]
run-lsp:
  docker run -i --rm -v "$(pwd):$(pwd)" rust-analyzer rust-analyzer "$@"

[group('flash')]
flash:
  web-flash --chip esp32s3 target/xtensa-esp32s3-none-elf/release/test

[group('flash')]
flash-debug:
  web-flash --chip esp32s3 target/xtensa-esp32s3-none-elf/debug/test
