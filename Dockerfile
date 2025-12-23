# Use the official Espressif IDF image as base
ARG IDF_VERSION=v5.2.3
FROM espressif/idf:${IDF_VERSION} AS build

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Arguments
ARG ESP_BOARD=esp32s3
ARG CARGO_HOME=/usr/local/cargo
ARG BUILD_TYPE=release

# Rust environment
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

# Install additional dependencies not in IDF image
RUN apt-get update \
    && apt-get install -y pkg-config libudev-dev unzip \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts

WORKDIR /app

# Install rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
    --default-toolchain none -y --profile minimal

# Install esp-rs tools
RUN ARCH=$($CARGO_HOME/bin/rustup show | grep "Default host" | sed -e 's/.* //') && \
    curl -L "https://github.com/esp-rs/espup/releases/latest/download/espup-${ARCH}" -o "${CARGO_HOME}/bin/espup" && \
    chmod u+x "${CARGO_HOME}/bin/espup" && \
    curl -L "https://github.com/esp-rs/espflash/releases/latest/download/cargo-espflash-${ARCH}.zip" -o "${CARGO_HOME}/bin/cargo-espflash.zip" && \
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

# Install Xtensa Rust toolchain with locked ESP-IDF version
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
# Source esp-rs first, then IDF (IDF last so its GCC takes precedence in PATH)
RUN --mount=type=cache,target=/usr/local/cargo/registry/ \
    . /app/export-esp.sh && \
    IDF_PATH_FORCE=1 . $IDF_PATH/export.sh && \
    cargo build --release && \
    cp /app/target/xtensa-esp32s3-espidf/release/test /app/test

FROM scratch
COPY --from=build /app/test /
ENTRYPOINT ["/test"]
