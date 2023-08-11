##################################################
## "main" stage
##################################################

FROM docker.io/debian:sid-slim AS main

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		bash \
		build-essential \
		ca-certificates \
		cmake \
		curl \
		file \
		git \
		gnupg \
		jq \
		libarchive-tools \
		libtool \
		libtool-bin \
		locales \
		lsb-release \
		meson \
		mime-support \
		nano \
		ninja-build \
		pkgconf \
		python-dev-is-python3 \
		python-is-python3 \
		python3 \
		python3-dev \
		python3-pip \
		python3-venv \
		tzdata \
		unzip \
		wget \
		zip \
	&& rm -rf /var/lib/apt/lists/*

# Create wasm user and group
ARG WASM_USER_UID=1000
ARG WASM_USER_GID=1000
RUN groupadd \
		--gid "${WASM_USER_GID:?}" \
		wasm
RUN useradd \
		--uid "${WASM_USER_UID:?}" \
		--gid "${WASM_USER_GID:?}" \
		--shell "$(command -v bash)" \
		--home-dir /home/wasm/ \
		--create-home \
		wasm

# Setup locale
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
RUN printf '%s\n' "${LANG:?} UTF-8" > /etc/locale.gen \
	&& localedef -c -i "${LANG%%.*}" -f UTF-8 "${LANG:?}" ||:

# Setup timezone
ENV TZ=UTC
RUN printf '%s\n' "${TZ:?}" > /etc/timezone \
	&& ln -snf "/usr/share/zoneinfo/${TZ:?}" /etc/localtime

# Drop root privileges
USER wasm:wasm
ENV USER=wasm
ENV HOME=/home/wasm
ENV XDG_CONFIG_HOME=${HOME}/.config
ENV XDG_CACHE_HOME=${HOME}/.cache
ENV XDG_DATA_HOME=${HOME}/.local/share
ENV XDG_STATE_HOME=${HOME}/.local/state

# Initialize PATH
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV PATH=${HOME}/.local/bin:${PATH}

# Install Rust
ENV RUSTUP_HOME=${HOME}/.rustup
ENV CARGO_HOME=${HOME}/.cargo
RUN mkdir -p "${RUSTUP_HOME:?}" "${CARGO_HOME:?}"
RUN URL='https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init' \
	&& curl -sSfL "${URL:?}" -o "${HOME:?}"/rustup-init \
	&& chmod 755 "${HOME:?}"/rustup-init \
	&& "${HOME:?}"/rustup-init -y --no-modify-path \
	&& rm -f "${HOME:?}"/rustup-init
ENV PATH=${CARGO_HOME}/bin:${PATH}
RUN command -V rustup && rustup --version
RUN command -V rustc && rustc --version
RUN command -V cargo && cargo --version
RUN rustup target add wasm32-wasi
RUN rustup target add wasm32-unknown-unknown
RUN rustup target add wasm32-unknown-emscripten

# Install Go
ENV GOROOT=${HOME}/.goroot
ENV GOPATH=${HOME}/.gopath
RUN mkdir -p "${GOROOT:?}" "${GOPATH:?}"/bin/ "${GOPATH:?}"/src/
RUN VERSION=$(curl -sSfL 'https://go.dev/VERSION?m=text' | head -1) \
	&& URL="https://dl.google.com/go/${VERSION:?}.linux-amd64.tar.gz" \
	&& curl -sSfL "${URL:?}" | bsdtar -x --strip-components=1 -C "${GOROOT:?}"
ENV PATH=${GOROOT}/bin:${PATH}
ENV PATH=${GOROOT}/misc/wasm:${PATH}
ENV PATH=${GOPATH}/bin:${PATH}
RUN command -V go && go version

# Install Zig
ENV ZIG_PATH=${HOME}/.zig
RUN mkdir -p "${ZIG_PATH:?}"
RUN URL=$(curl -sSfL 'https://ziglang.org/download/index.json' \
		| jq -r 'to_entries | map(select(.key | test("^[0-9]+(\\.[0-9]+)*$"))) | sort_by(.value.date) | .[-1].value["x86_64-linux"].tarball' \
	) \
	&& curl -sSfL "${URL:?}" | bsdtar -x --strip-components=1 -C "${ZIG_PATH:?}" \
	&& chmod 755 "${ZIG_PATH:?}"
ENV PATH=${ZIG_PATH}:${PATH}
RUN command -V zig && zig version

# Install Node.js
ENV FNM_DIR=${HOME}/.fnm
RUN mkdir -p "${FNM_DIR:?}"
RUN URL=$(curl -sSfL 'https://api.github.com/repos/Schniz/fnm/releases/latest' \
		| jq -r '.assets[] | select(.name | test("^fnm-linux\\.zip$")?) | .browser_download_url' \
	) \
	&& curl -sSfL "${URL:?}" | bsdtar -x -C "${FNM_DIR:?}" \
	&& chmod 755 "${FNM_DIR:?}"/fnm
ENV PATH=${FNM_DIR}:${PATH}
RUN command -V fnm && fnm --version
RUN fnm install --lts && fnm default lts-latest
ENV PATH=${FNM_DIR}/aliases/default/bin:${PATH}
RUN command -V node && node --version
RUN command -V npm && npm --version

# Install Emscripten
ENV EMSDK=${HOME}/.emsdk
ENV EM_CONFIG=${EMSDK}/.emscripten
ENV EM_PORTS=${HOME}/.emscripten_ports
ENV EM_CACHE=${HOME}/.emscripten_cache
RUN mkdir -p "${EMSDK:?}" "${EM_PORTS:?}" "${EM_CACHE:?}"
RUN URL=$(curl -sSfL 'https://api.github.com/repos/emscripten-core/emsdk/tags' \
		| jq -r 'sort_by(.name | split(".") | map(tonumber)) | .[-1].tarball_url' \
	) \
	&& curl -sSfL "${URL:?}" | bsdtar -x --strip-components=1 -C "${EMSDK:?}"
RUN cd "${EMSDK:?}" \
	&& ./emsdk install latest \
	&& ./emsdk activate latest \
	&& rm -rf "${HOME}"/.cache/ "${HOME}"/.npm/
ENV PATH=${EMSDK}:${PATH}
ENV PATH=${EMSDK}/upstream/emscripten:${PATH}
ENV PATH=${EMSDK}/upstream/bin:${PATH}
RUN command -V emcc && emcc --version
RUN command -V em++ && em++ --version
RUN command -V clang && clang --version

# Install WASI SDK into Emscripten
ENV WASI_SDK_PATH=${EMSDK}/upstream
ENV WASI_SYSROOT=${WASI_SDK_PATH}/share/wasi-sysroot
RUN mkdir -p "${WASI_SDK_PATH:?}" "${WASI_SYSROOT:?}"
RUN URL=$(curl -sSfL 'https://api.github.com/repos/WebAssembly/wasi-sdk/releases/latest' \
		| jq -r '.assets[] | select(.name | test("^wasi-sysroot-[0-9]+(\\.[0-9]+)*\\.tar\\.gz$")?) | .browser_download_url' \
	) \
	&& curl -sSfL "${URL:?}" | bsdtar -x --strip-components=1 -C "${WASI_SYSROOT:?}"
RUN URL=$(curl -sSfL 'https://api.github.com/repos/WebAssembly/wasi-sdk/releases/latest' \
		| jq -r '.assets[] | select(.name | test("^libclang_rt\\.builtins-wasm32-wasi-[0-9]+(\\.[0-9]+)*\\.tar\\.gz$")?) | .browser_download_url' \
	) \
	&& curl -sSfL "${URL:?}" | bsdtar -x -C "$(clang --print-resource-dir)"
RUN test -f "${WASI_SYSROOT:?}"/lib/wasm32-wasi/libc.a
RUN test -f "$(clang --print-resource-dir)"/lib/wasi/libclang_rt.builtins-wasm32.a

# Install Wasmtime
ENV WASMTIME_HOME=${HOME}/.wasmtime
RUN mkdir -p "${WASMTIME_HOME:?}"/bin/
RUN URL=$(curl -sSfL 'https://api.github.com/repos/bytecodealliance/wasmtime/releases/latest' \
		| jq -r '.assets[] | select(.name | test("^wasmtime-v[0-9]+(\\.[0-9]+)*-x86_64-linux\\.tar\\.xz$")?) | .browser_download_url' \
	) \
	&& curl -sSfL "${URL:?}" | bsdtar -x --strip-components=1 -C "${WASMTIME_HOME:?}" \
	&& mv "${WASMTIME_HOME:?}"/wasmtime "${WASMTIME_HOME:?}"/bin/
ENV PATH=${WASMTIME_HOME}/bin:${PATH}
RUN command -V wasmtime && wasmtime --version

# Install Wasmer
ENV WASMER_DIR=${HOME}/.wasmer
ENV WASMER_CACHE_DIR=${WASMER_DIR}/cache
RUN mkdir -p "${WASMER_DIR:?}" "${WASMER_CACHE_DIR:?}"
RUN URL=$(curl -sSfL 'https://api.github.com/repos/wasmerio/wasmer/releases/latest' \
		| jq -r '.assets[] | select(.name | test("^wasmer-linux-amd64\\.tar\\.gz$")?) | .browser_download_url' \
	) \
	&& curl -sSfL "${URL:?}" | bsdtar -x -C "${WASMER_DIR:?}"
ENV PATH=${WASMER_DIR}/bin:${PATH}
ENV PATH=${WASMER_DIR}/globals/wapm_packages/.bin:${PATH}
RUN command -V wasmer && wasmer --version

# Install "cargo wasi" and "cargo wasix"
RUN cargo install cargo-wasi cargo-wasix \
	&& rm -rf "${CARGO_HOME:?}"/registry/
RUN cargo wasi --version
RUN cargo wasix --version

# Install some extra tools
RUN cargo install wasm-pack wasm-snip \
	&& rm -rf "${CARGO_HOME:?}"/registry/
RUN command -V wasm-pack && wasm-pack --version
RUN command -V wasm-snip && wasm-snip --version

# Pre-build and cache some libraries
RUN embuilder.py build MINIMAL zlib bzip2
RUN embuilder.py build MINIMAL_PIC zlib bzip2 --pic

# Copy scripts
COPY --chown=wasm:wasm ./scripts/bin/ ${HOME}/.local/bin
RUN find "${HOME:?}"/.local/bin/ -type d -not -perm 0755 -exec chmod 0755 '{}' ';'
RUN find "${HOME:?}"/.local/bin/ -type f -not -perm 0755 -exec chmod 0755 '{}' ';'

# Build sample C program
RUN mkdir "${HOME:?}"/test/ \
	&& cd "${HOME:?}"/test/ \
	# Create program
	&& MSGIN='Hello, world!' \
	&& printf '%s\n' '#include <stdio.h>' 'int main(){puts("'"${MSGIN:?}"'");}' > ./hello.c \
	# Compile to native
	&& printf '%s\n' 'Compiling C to native...' \
	&& clang ./hello.c -o ./hello \
	&& MSGOUT=$(./hello) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Compile to WASM
	&& printf '%s\n' 'Compiling C to WASM...' \
	&& emcc ./hello.c -o ./hello.js \
	&& MSGOUT=$(node ./hello.js) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Compile to WASI
	&& printf '%s\n' 'Compiling C to WASI...' \
	&& wasicc ./hello.c -o ./hello.wasm \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/ \
	&& find "${XDG_CACHE_HOME:?}" "${WASMER_CACHE_DIR:?}" -mindepth 1 -delete

# Build sample Rust program
RUN mkdir "${HOME:?}"/test/ \
	&& cd "${HOME:?}"/test/ \
	# Create program
	&& MSGIN='Hello, world!' \
	&& printf '%s\n' 'fn main(){println!("'"${MSGIN:?}"'");}' > ./hello.rs \
	# Compile to native
	&& printf '%s\n' 'Compiling Rust to native...' \
	&& rustc ./hello.rs -o ./hello \
	&& MSGOUT=$(./hello) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Compile to WASM
	&& printf '%s\n' 'Compiling Rust to WASM...' \
	&& rustc ./hello.rs --target=wasm32-unknown-emscripten -o ./hello.js \
	&& MSGOUT=$(node ./hello.js) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Compile to WASI
	&& printf '%s\n' 'Compiling Rust to WASI...' \
	&& rustc ./hello.rs --target=wasm32-wasi -o ./hello.wasm \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/ \
	&& find "${XDG_CACHE_HOME:?}" "${WASMER_CACHE_DIR:?}" -mindepth 1 -delete

# Build sample Go program
RUN mkdir "${HOME:?}"/test/ \
	&& cd "${HOME:?}"/test/ \
	# Create program
	&& MSGIN='Hello, world!' \
	&& printf '%s\n' 'package main;import "fmt";func main(){fmt.Println("'"${MSGIN:?}"'");}' > ./hello.go \
	# Compile to native
	&& printf '%s\n' 'Compiling Go to native...' \
	&& go build -o ./hello ./hello.go \
	&& MSGOUT=$(./hello) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Compile to WASM
	&& printf '%s\n' 'Compiling Go to WASM...' \
	&& GOOS=js GOARCH=wasm go build -o ./hello.wasm ./hello.go \
	&& MSGOUT=$(node "${GOROOT:?}"/misc/wasm/wasm_exec_node.js ./hello.wasm) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Compile to WASI
	&& printf '%s\n' 'Compiling Go to WASI...' \
	&& GOOS=wasip1 GOARCH=wasm go build -o ./hello.wasm ./hello.go \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/ \
	&& find "${XDG_CACHE_HOME:?}" "${WASMER_CACHE_DIR:?}" -mindepth 1 -delete

# Build sample Zig program
RUN mkdir "${HOME:?}"/test/ \
	&& cd "${HOME:?}"/test/ \
	# Create program
	&& MSGIN='Hello, world!' \
	&& printf '%s\n' 'pub fn main() !void{try@import("std").io.getStdOut().writer().print("'"${MSGIN:?}"'\n",.{});}' > ./hello.zig \
	# Compile to native
	&& printf '%s\n' 'Compiling Zig to native...' \
	&& zig build-exe ./hello.zig \
	&& MSGOUT=$(./hello) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Compile to WASI
	&& printf '%s\n' 'Compiling Zig to WASI...' \
	&& zig build-exe -target wasm32-wasi ./hello.zig \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/ \
	&& find "${XDG_CACHE_HOME:?}" "${WASMER_CACHE_DIR:?}" -mindepth 1 -delete

WORKDIR ${HOME}
CMD ["/bin/bash"]
