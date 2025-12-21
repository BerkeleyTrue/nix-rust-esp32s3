# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Experimental embedded Rust project using Slint UI framework on ESP32-S3 microcontroller with a 240x240 GC9A01 circular LCD display and CST816S touch controller. Currently builds successfully but has runtime issues.

## Commands (via just)

```bash
just              # List all available commands
just debug        # Local cargo build (debug)
just build        # Docker release build, outputs to out/
just flash        # Flash release binary via web-flash
just flash-debug  # Flash debug binary via web-flash
just build-lsp    # Build rust-analyzer Docker container
just run-lsp      # Run rust-analyzer in container
```

**Enter development environment:**
```bash
nix develop    # or direnv allow
```

## Architecture

### Platform Layer (src/esp32.rs)
Custom `EspPlatform` implementing `slint::platform::Platform`:
- Line-by-line software rendering to display driver
- SPI communication to GC9A01 display (2MHz)
- Timer-based animation support via FreeRTOS
- Hardware pins defined as constants (GPIO8-14 for LCD, GPIO6-7 for I2C)

### UI Layer (ui/appwindow.slint)
Slint UI compiled at build time via `build.rs`. The `slint_build::compile()` generates Rust code from `.slint` files.

### Build Toolchain
- Target: `xtensa-esp32s3-espidf`
- ESP-IDF version: v5.2.2
- Rust toolchain: "esp" channel (Xtensa-patched)
- Docker used for reliable builds since Nix cannot manage all ESP artifacts

### ESP Components (from Espressif registry)
- `esp_lcd_gc9a01` - Display driver
- `esp_lcd_touch_cst816s` - Touch controller
- C bindings generated from `src/bindings.h`

## Development Environment

**Nix shell provides:** cargo, clippy, rustfmt, espup, espflash, rust-analyzer, podman, ldproxy, just

**LSP:** rust-analyzer runs via Docker container (`just build-lsp` then `just run-lsp`). Neovim config in `.lnvim.fnl` auto-configures this.

## Key Configuration Files

- `.cargo/config.toml` - Target, linker (ldproxy), ESP-IDF version, MCU setting
- `sdkconfig.defaults` - ESP-IDF settings (8KB main stack, 16MB flash, 100Hz tick)
- `rust-toolchain.toml` - ESP-patched Rust channel
- `flake.nix` - Nix development environment

## Hardware Pin Mapping

```
LCD (SPI): SCLK=GPIO10, MOSI=GPIO11, CS=GPIO9, DC=GPIO8, RST=GPIO14
Touch (I2C): SDA=GPIO6, SCL=GPIO7
```
