default:
  just --list

[group('build')]
build:
  docker build --output=out -t test_esp-idf .
  notify-send "Build Complete" "ESP32 build finished"

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
  web-flash --chip esp32s3 out/test

[group('ui')]
preview:
  slint-viewer --auto-reload ui/appwindow.slint
