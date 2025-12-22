# this sets up the build process for the project using esp-rs
ARG VARIANT=bookworm-slim
FROM debian:${VARIANT} AS build
ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Arguments
ARG ESP_BOARD=esp32s3
ARG CARGO_HOME=/usr/local/cargo
ARG BUILD_TYPE=release

# Update envs
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

# Install dependencies
RUN apt-get update \
    && apt-get install -y pkg-config curl gcc clang libudev-dev unzip xz-utils \
    git wget flex bison gperf python3 python3-pip python3-venv cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0 \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts

WORKDIR /app

# Install rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
    --default-toolchain none -y --profile minimal

# Install extra crates
RUN ARCH=$($CARGO_HOME/bin/rustup show | grep "Default host" | sed -e 's/.* //') && \
    curl -L "https://github.com/esp-rs/espup/releases/latest/download/espup-${ARCH}" -o "${CARGO_HOME}/bin/espup" && \
    chmod u+x "${CARGO_HOME}/bin/espup" && \
    curl -L "https://github.com/esp-rs/espflash/releases/latest/download/cargo-espflash-${ARCH}.zip" -o "${CARGO_HOME}/bin/cargo-espflash.zip" && \
    ls -a "${CARGO_HOME}/bin" && \
    unzip "${CARGO_HOME}/bin/cargo-espflash.zip" -d "${CARGO_HOME}/bin/" && \
    rm "${CARGO_HOME}/bin/cargo-espflash.zip" && \
    chmod u+x "${CARGO_HOME}/bin/cargo-espflash" && \
    curl -L "https://github.com/esp-rs/espflash/releases/latest/download/espflash-${ARCH}.zip" -o "${CARGO_HOME}/bin/espflash.zip" && \
    unzip "${CARGO_HOME}/bin/espflash.zip" -d "${CARGO_HOME}/bin/" && \
    rm "${CARGO_HOME}/bin/espflash.zip" && \
    chmod u+x "${CARGO_HOME}/bin/espflash" && \
    curl -L "https://github.com/esp-rs/embuild/releases/latest/download/ldproxy-${ARCH}.zip" -o "${CARGO_HOME}/bin/ldproxy.zip" && \
    unzip "${CARGO_HOME}/bin/ldproxy.zip" -d "${CARGO_HOME}/bin/" && \
    rm "${CARGO_HOME}/bin/ldproxy.zip" && \
    chmod u+x "${CARGO_HOME}/bin/ldproxy"

# Install Xtensa Rust
RUN ${CARGO_HOME}/bin/espup install \
    --targets "${ESP_BOARD}" \
    --log-level debug \
    --export-file /app/export-esp.sh

# Set default toolchain
RUN rustup default esp

# Copy source files
COPY Cargo.toml Cargo.lock rust-toolchain.toml sdkconfig.defaults build.rs ./
COPY .cargo .cargo
COPY src src
COPY ui ui

# Build the application
# Cache only the cargo registry (safe), not target dir (causes ldproxy issues)
RUN --mount=type=cache,target=/usr/local/cargo/registry/ \
    bash -c "source /app/export-esp.sh && cargo build --release" && \
    # copy out of cached target dir or next step won't be able to find it
    cp /app/target/xtensa-esp32s3-espidf/release/test /app/test

FROM scratch
COPY --from=build /app/test /
ENTRYPOINT ["/test"]
