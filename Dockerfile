##################################################
## "main" stage
##################################################

FROM docker.io/ubuntu:22.04 AS main

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
ARG EMSDK_TREEISH=main
ARG EMSDK_REMOTE=https://github.com/emscripten-core/emsdk.git
ENV EMSDK=${HOME}/.emsdk
ENV EM_CONFIG=${EMSDK}/.emscripten
ENV EM_PORTS=${HOME}/.emscripten_ports
ENV EM_CACHE=${HOME}/.emscripten_cache
RUN mkdir -p "${EMSDK:?}" "${EM_PORTS:?}" "${EM_CACHE:?}"
RUN cd "${EMSDK:?}" \
	&& git clone "${EMSDK_REMOTE:?}" ./ \
	&& git checkout "${EMSDK_TREEISH:?}" \
	&& git submodule update --init --recursive
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

# Install WASI SDK
ENV WASI_SDK_DIR=${HOME}/.wasi-sdk
ENV WASI_SYSROOT=${WASI_SDK_DIR}/share/wasi-sysroot
RUN mkdir -p "${WASI_SDK_DIR:?}" "${WASI_SYSROOT:?}"
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

# Install some tools for Rust
RUN cargo install wasm-pack wasm-snip cargo-wasi cargo-wasix \
	&& rm -rf "${CARGO_HOME:?}"/registry/
RUN command -V wasm-pack && wasm-pack --version
RUN command -V wasm-snip && wasm-snip --version
RUN cargo wasi --version
RUN cargo wasix --version

# Build some Emscripten system libraries
RUN embuilder.py build libjpeg libpng zlib

# Build sample C program
RUN mkdir "${HOME:?}"/test/ && cd "${HOME:?}"/test/ \
	# Create program
	&& MSGIN='Hello, World!' \
	&& printf '#include <stdio.h>\nint main(){puts("%s");}' "${MSGIN:?}" > ./hello.c \
	# Compile to WASM
	&& printf '%s\n' 'Compiling C to WASM...' \
	&& emcc ./hello.c -o ./hello.js \
	&& MSGOUT=$(node ./hello.js) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Compile to WASI
	&& printf '%s\n' 'Compiling C to WASI...' \
	&& clang ./hello.c --target=wasm32-wasi --sysroot="${WASI_SYSROOT:?}" -o ./hello.wasm \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& ([ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1) \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/

# Build sample Rust program
RUN mkdir "${HOME:?}"/test/ && cd "${HOME:?}"/test/ \
	# Create program
	&& MSGIN='Hello, World!' \
	&& printf 'fn main(){println!("%s");}' "${MSGIN:?}" > ./hello.rs \
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
	&& rm -rf "${HOME:?}"/test/

# Build sample Go program
RUN mkdir "${HOME:?}"/test/ && cd "${HOME:?}"/test/ \
	# Create program
	&& MSGIN='Hello, World!' \
	&& printf 'package main;import "fmt";func main(){fmt.Println("%s");}' "${MSGIN:?}" > ./hello.go \
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
	&& rm -rf "${HOME:?}"/test/

WORKDIR ${HOME}
CMD ["/bin/bash"]
