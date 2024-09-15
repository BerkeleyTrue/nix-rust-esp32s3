ARG VARIANT=bookworm-slim
FROM debian:${VARIANT} AS build
ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Arguments
ARG CONTAINER_USER=root
ARG CONTAINER_GROUP=esp
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
    curl -L "https://github.com/esp-rs/embuild/releases/latest/download/ldproxy-${ARCH}.zip" -o "${CARGO_HOME}/bin/ldproxy.zip" && \
    unzip "${CARGO_HOME}/bin/ldproxy.zip" -d "${CARGO_HOME}/bin/" && \
    rm "${CARGO_HOME}/bin/ldproxy.zip" && \
    chmod u+x "${CARGO_HOME}/bin/ldproxy"


# Install Xtensa Rust
RUN ${CARGO_HOME}/bin/espup install\
    --targets "${ESP_BOARD}" \
    --log-level debug \
    --export-file /app/export-esp.sh

# set default to stable to install rust-analyzer
RUN rustup default stable

# install rust analyzer
RUN rustup component add rust-analyzer

# Set default toolchain
RUN rustup default esp

# link stable rust analyzer to esp 
RUN ln -sf /usr/local/rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rust-analyzer /usr/local/rustup/toolchains/esp/bin/rust-analyzer

# Activate ESP environment
RUN echo "source /app/export-esp.sh" >> .bashrc
