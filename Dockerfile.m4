m4_changequote([[, ]])

##################################################
## "main" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/debian:sid-slim]], [[FROM docker.io/debian:sid-slim]]) AS main
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectorm/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		bash \
		bison \
		bzip2 \
		ca-certificates \
		cmake \
		curl \
		default-jre-headless \
		file \
		flex \
		gettext \
		git \
		gnupg \
		jq \
		libarchive-tools \
		libssl-dev \
		libtoml-tiny-perl \
		libtool \
		libtool-bin \
		locales \
		lsb-release \
		m4 \
		make \
		meson \
		mime-support \
		nano \
		ninja-build \
		parallel \
		patch \
		perl \
		pkgconf \
		python-dev-is-python3 \
		python-is-python3 \
		python3 \
		python3-dev \
		python3-pip \
		python3-venv \
		rsync \
		tzdata \
		unzip \
		wget \
		xz-utils \
		zip \
		zstd \
	&& rm -rf /var/lib/apt/lists/*

# Setup locale
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
RUN printf '%s\n' "${LANG:?} UTF-8" > /etc/locale.gen \
	&& localedef -c -i "${LANG%%.*}" -f UTF-8 "${LANG:?}" ||:

# Setup timezone
ENV TZ=UTC
RUN printf '%s\n' "${TZ:?}" > /etc/timezone \
	&& ln -snf "/usr/share/zoneinfo/${TZ:?}" /etc/localtime

# Initialize PATH
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Install Rust
ENV RUST_HOME=/opt/rust
ENV PATH=${RUST_HOME}/bin:${PATH}
RUN mkdir -p "${RUST_HOME:?}"
RUN case "$(uname -m)" in x86_64) ARCH=x86_64 ;; aarch64) ARCH=aarch64 ;; esac \
	&& mkdir /tmp/rust/ && cd /tmp/rust/ \
	&& curl -sSfL 'https://static.rust-lang.org/dist/channel-rust-stable.toml' -o ./manifest.toml \
	&& PKG_URL_PARSER='print(from_toml(do{local $/;<STDIN>})->{pkg}{$ARGV[0]}{target}{$ARGV[1]}{xz_url})' \
	&& curl -sSfL "$(perl -MPOSIX -MTOML::Tiny -e"${PKG_URL_PARSER:?}" rust     "${ARCH:?}"-unknown-linux-gnu < ./manifest.toml)" | bsdtar -x --no-same-owner \
	&& curl -sSfL "$(perl -MPOSIX -MTOML::Tiny -e"${PKG_URL_PARSER:?}" rust-std wasm32-wasi                   < ./manifest.toml)" | bsdtar -x --no-same-owner \
	&& curl -sSfL "$(perl -MPOSIX -MTOML::Tiny -e"${PKG_URL_PARSER:?}" rust-std wasm32-unknown-unknown        < ./manifest.toml)" | bsdtar -x --no-same-owner \
	&& curl -sSfL "$(perl -MPOSIX -MTOML::Tiny -e"${PKG_URL_PARSER:?}" rust-std wasm32-unknown-emscripten     < ./manifest.toml)" | bsdtar -x --no-same-owner \
	&& ./rust-*-"${ARCH:?}"-unknown-linux-gnu/install.sh --prefix="${RUST_HOME:?}" --components=rustc,rust-std-"${ARCH:?}"-unknown-linux-gnu,cargo,rustfmt-preview,clippy-preview \
	&& ./rust-std-*-wasm32-wasi/install.sh               --prefix="${RUST_HOME:?}" --components=rust-std-wasm32-wasi \
	&& ./rust-std-*-wasm32-unknown-unknown/install.sh    --prefix="${RUST_HOME:?}" --components=rust-std-wasm32-unknown-unknown \
	&& ./rust-std-*-wasm32-unknown-emscripten/install.sh --prefix="${RUST_HOME:?}" --components=rust-std-wasm32-unknown-emscripten \
	&& printf '%s\n' "${RUST_HOME:?}"/lib > /etc/ld.so.conf.d/rustlib.conf && ldconfig \
	&& curl -sSfL "https://static.rust-lang.org/rustup/dist/${ARCH:?}-unknown-linux-gnu/rustup-init" -o "${RUST_HOME:?}"/bin/rustup-init \
	&& chmod 0755 "${RUST_HOME:?}"/bin/rustup-init \
	&& rm -rf /tmp/rust/
RUN command -V rustc && rustc --version
RUN command -V cargo && cargo --version
RUN command -V rustup-init && rustup-init --version

# Install Zig
ENV ZIG_HOME=/opt/zig
ENV PATH=${ZIG_HOME}:${PATH}
RUN mkdir -p "${ZIG_HOME:?}"
RUN case "$(uname -m)" in x86_64) ARCH=x86_64 ;; aarch64) ARCH=aarch64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://ziglang.org/download/index.json') \
	&& PKG_URL_PARSER='to_entries | map(select(.key | test("^[0-9]+(\\.[0-9]+)*$"))) | sort_by(.value.date) | .[-1].value[$a + "-linux"].tarball' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --no-same-owner --strip-components=1 -C "${ZIG_HOME:?}"
RUN command -V zig && zig version

# Install Go
ENV GOROOT=/opt/go
ENV PATH=${GOROOT}/bin:${PATH}
ENV PATH=${GOROOT}/misc/wasm:${PATH}
RUN mkdir -p "${GOROOT:?}"
RUN case "$(uname -m)" in x86_64) ARCH=amd64 ;; aarch64) ARCH=arm64 ;; esac \
	&& VERSION=$(curl -sSfL 'https://go.dev/VERSION?m=text' | head -1) \
	&& PKG_URL="https://dl.google.com/go/${VERSION:?}.linux-${ARCH:?}.tar.gz" \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --no-same-owner --strip-components=1 -C "${GOROOT:?}"
RUN command -V go && go version

# Install TinyGo
ENV TINYGOROOT=/opt/tinygo
ENV PATH=${TINYGOROOT}/bin:${PATH}
RUN mkdir -p "${TINYGOROOT:?}"
RUN case "$(uname -m)" in x86_64) ARCH=amd64 ;; aarch64) ARCH=arm64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/tinygo-org/tinygo/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^tinygo[0-9]+(\\.[0-9]+)*\\.linux-" + $a + "\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --no-same-owner --strip-components=1 -C "${TINYGOROOT:?}" \
	&& rm -rf "${TINYGOROOT:?}"/bin/wasm-opt # Already included in Emscripten
RUN command -V tinygo && tinygo version

# Install Node.js
ENV NODE_HOME=/opt/node
ENV PATH=${NODE_HOME}/bin:${PATH}
RUN mkdir -p "${NODE_HOME:?}"
RUN case "$(uname -m)" in x86_64) ARCH=x64 ;; aarch64) ARCH=arm64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://nodejs.org/dist/index.json') \
	&& VERSION_PARSER='map(select(.lts)) | sort_by(.version | ltrimstr("v") | split(".") | map(tonumber)) | .[-1].version' \
	&& VERSION=$(printf '%s' "${RELEASE_JSON:?}" | jq -r "${VERSION_PARSER:?}") \
	&& PKG_URL="https://nodejs.org/dist/${VERSION:?}/node-${VERSION:?}-linux-${ARCH:?}.tar.xz" \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --no-same-owner --strip-components=1 -C "${NODE_HOME:?}"
RUN command -V node && node --version
RUN command -V npm && npm --version

# Install Emscripten
ENV EMSDK=/opt/emsdk
ENV WASM_OPT=${EMSDK}/upstream/bin/wasm-opt
ENV PATH=${EMSDK}:${PATH}
ENV PATH=${EMSDK}/upstream/emscripten:${PATH}
ENV PATH=${EMSDK}/upstream/bin:${PATH}
RUN mkdir -p "${EMSDK:?}"
RUN RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/emscripten-core/emsdk/tags') \
	&& PKG_URL_PARSER='sort_by(.name | split(".") | map(tonumber)) | .[-1].tarball_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --no-same-owner --strip-components=1 -C "${EMSDK:?}"
RUN cd "${EMSDK:?}" \
	&& emsdk install latest \
	&& emsdk activate latest \
	&& embuilder clear ALL \
	&& chown root:root -R "${EMSDK:?}" \
	&& rm -rf ~/.cache/ ~/.npm/
RUN command -V emcc && emcc --version
RUN command -V em++ && em++ --version
RUN command -V clang && clang --version
RUN "${WASM_OPT:?}" --version

# Install WASI SDK into Emscripten
ENV WASI_SDK_PATH=${EMSDK}/upstream
ENV WASI_SYSROOT=${WASI_SDK_PATH}/share/wasi-sysroot
RUN mkdir -p "${WASI_SDK_PATH:?}" "${WASI_SYSROOT:?}"
RUN RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/WebAssembly/wasi-sdk/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wasi-sdk-[0-9]+(\\.[0-9]+)*-linux\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --no-same-owner --strip-components=1 -C "${WASI_SDK_PATH:?}" \
		-s "#/lib/clang/[0-9]*/#/lib/clang/$(basename "$(clang --print-resource-dir)")/#" \
		'./wasi-sdk-*/lib/clang/[0-9]*/lib/wasi/' \
		'./wasi-sdk-*/share/'
RUN [ -e "${WASI_SDK_PATH:?}"/share/cmake/Platform/ ] || mkdir "${WASI_SDK_PATH:?}"/share/cmake/Platform/
RUN [ -e "${WASI_SDK_PATH:?}"/share/cmake/Platform/WASI.cmake ] || printf '%s\n' 'set(WASI 1)' > "${WASI_SDK_PATH:?}"/share/cmake/Platform/WASI.cmake
RUN test -f "${WASI_SDK_PATH:?}"/share/cmake/wasi-sdk.cmake
RUN test -f "${WASI_SYSROOT:?}"/lib/wasm32-wasi/libc.a
RUN test -f "$(clang --print-resource-dir)"/lib/wasi/libclang_rt.builtins-wasm32.a

# Install WASIX sysroot into Emscripten
ENV WASIX_SYSROOT32=${EMSDK}/upstream/share/wasix-sysroot32
ENV WASIX_SYSROOT64=${EMSDK}/upstream/share/wasix-sysroot64
ENV WASIX_SYSROOT=${WASIX_SYSROOT32}
RUN mkdir -p "${WASIX_SYSROOT32:?}" "${WASIX_SYSROOT64:?}"
RUN RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/wasix-org/rust/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wasix-libc\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --no-same-owner --strip-components=1 -C "${WASIX_SYSROOT:?}"/../ \
		-s '#/wasix-libc/sysroot\(32\|64\)/#/wasix-sysroot\1/#' \
		'./wasix-libc/sysroot*/'
RUN test -f "${WASIX_SYSROOT32:?}"/lib/wasm32-wasi/libc.a
RUN test -f "${WASIX_SYSROOT64:?}"/lib/wasm64-wasi/libc.a
RUN test -f "${WASIX_SYSROOT:?}"/lib/wasm32-wasi/libc.a

# Install Wasmtime
ENV WASMTIME_HOME=/opt/wasmtime
ENV PATH=${WASMTIME_HOME}/bin:${PATH}
RUN mkdir -p "${WASMTIME_HOME:?}"
RUN case "$(uname -m)" in x86_64) ARCH=x86_64 ;; aarch64) ARCH=aarch64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/bytecodealliance/wasmtime/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wasmtime-v[0-9]+(\\.[0-9]+)*-" + $a + "-linux\\.tar\\.xz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --no-same-owner --strip-components=1 -C "${WASMTIME_HOME:?}" \
	&& mkdir "${WASMTIME_HOME:?}"/bin/ && mv "${WASMTIME_HOME:?}"/wasmtime "${WASMTIME_HOME:?}"/bin/ \
	&& LIB_URL_PARSER='.assets[] | select(.name | test("^wasmtime-v[0-9]+(\\.[0-9]+)*-" + $a + "-linux-c-api\\.tar\\.xz$")?) | .browser_download_url' \
	&& LIB_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${LIB_URL_PARSER:?}") \
	&& curl -sSfL "${LIB_URL:?}" | bsdtar -x --no-same-owner --strip-components=1 -C "${WASMTIME_HOME:?}" \
	&& printf '%s\n' "${WASMTIME_HOME:?}"/lib > /etc/ld.so.conf.d/wasmtime.conf && ldconfig
RUN test -f "${WASMTIME_HOME:?}"/lib/libwasmtime.so
RUN command -V wasmtime && wasmtime --version

# Install Wasmer
ENV WASMER_DIR=/opt/wasmer
ENV PATH=${WASMER_DIR}/bin:${PATH}
RUN mkdir -p "${WASMER_DIR:?}"
RUN case "$(uname -m)" in x86_64) ARCH=amd64 ;; aarch64) ARCH=aarch64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/wasmerio/wasmer/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wasmer-linux-" + $a + "\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --no-same-owner -C "${WASMER_DIR:?}" \
	&& printf '%s\n' "${WASMER_DIR:?}"/lib > /etc/ld.so.conf.d/wasmer.conf && ldconfig
RUN test -f "${WASMER_DIR:?}"/lib/libwasmer.so
RUN command -V wasmer && wasmer --version

# Install WasmEdge
ENV WASMEDGE_DIR=/opt/wasmedge
ENV WASMEDGE_PLUGIN_PATH=${WASMEDGE_DIR}/lib
ENV PATH=${WASMEDGE_DIR}/bin:${PATH}
RUN mkdir -p "${WASMEDGE_DIR:?}"
RUN case "$(uname -m)" in x86_64) ARCH=x86_64 ;; aarch64) ARCH=aarch64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/WasmEdge/WasmEdge/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^WasmEdge-[0-9]+(\\.[0-9]+)*-manylinux2014_" + $a + "\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --no-same-owner --strip-components=1 -C "${WASMEDGE_DIR:?}" \
	&& mv "${WASMEDGE_DIR:?}"/lib64/ "${WASMEDGE_DIR:?}"/lib/ \
	&& PLUGIN_WASI_CRYPTO_URL_PARSER='.assets[] | select(.name | test("^WasmEdge-plugin-wasi_crypto-[0-9]+(\\.[0-9]+)*-manylinux2014_" + $a + "\\.tar\\.gz$")?) | .browser_download_url' \
	&& PLUGIN_WASI_CRYPTO_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PLUGIN_WASI_CRYPTO_URL_PARSER:?}") \
	&& curl -sSfL "${PLUGIN_WASI_CRYPTO_URL:?}" | bsdtar -x --no-same-owner -C "${WASMEDGE_PLUGIN_PATH:?}" \
	&& printf '%s\n' "${WASMEDGE_DIR:?}"/lib > /etc/ld.so.conf.d/wasmedge.conf && ldconfig
RUN test -f "${WASMEDGE_DIR:?}"/lib/libwasmedge.so
RUN test -f "${WASMEDGE_PLUGIN_PATH:?}"/libwasmedgePluginWasiCrypto.so
RUN command -V wasmedge && wasmedge --version

# Install some extra tools
RUN cargo install --root "${RUST_HOME:?}" \
		cargo-wasix \
		wasm-bindgen-cli \
		wasm-pack \
		wasm-snip \
		wasm-tools \
	&& rm -rf ~/.cargo/
RUN command -v cargo-wasix && cargo wasix --version
RUN command -V wasm-bindgen && wasm-bindgen --version
RUN command -V wasm-pack && wasm-pack --version
RUN command -V wasm-snip && wasm-snip --version
RUN command -V wasm-tools && wasm-tools --version

# Copy scripts
COPY --chown=wasm:wasm ./scripts/bin/ /usr/local/bin/
RUN find /usr/local/bin/ -type d -not -perm 0755 -exec chmod 0755 '{}' ';'
RUN find /usr/local/bin/ -type f -not -perm 0755 -exec chmod 0755 '{}' ';'

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

# Drop root privileges
USER wasm:wasm

# Set user environment
ENV USER=wasm
ENV HOME=/home/wasm
ENV XDG_CONFIG_HOME=${HOME}/.config
ENV XDG_CACHE_HOME=${HOME}/.cache
ENV XDG_DATA_HOME=${HOME}/.local/share
ENV XDG_STATE_HOME=${HOME}/.local/state
ENV XDG_RUNTIME_DIR=${HOME}/.local/run
ENV PATH=${HOME}/.local/bin:${PATH}

ENV CARGO_HOME=${XDG_DATA_HOME}/cargo
ENV RUSTUP_HOME=${XDG_DATA_HOME}/rustup
ENV RUSTUP_INIT_SKIP_PATH_CHECK=yes
ENV PATH=${CARGO_HOME}/bin:${PATH}

ENV GOPATH=${XDG_DATA_HOME}/go
ENV PATH=${GOPATH}/bin:${PATH}

ENV NPM_CONFIG_PREFIX=${XDG_DATA_HOME}/npm
ENV NPM_CONFIG_CACHE=${XDG_CACHE_HOME}/npm
ENV NPM_CONFIG_USERCONFIG=${XDG_CONFIG_HOME}/npm/npmrc
ENV NPM_CONFIG_INIT_MODULE=${XDG_CONFIG_HOME}/npm/config/npm-init.js
ENV PATH=${NPM_CONFIG_PREFIX}/bin:${PATH}

ENV WASMER_CACHE_DIR=${XDG_CACHE_HOME}/wasmer

# Create user directories
RUN mkdir -p "${XDG_CONFIG_HOME:?}" "${XDG_CACHE_HOME:?}" "${XDG_DATA_HOME:?}" "${XDG_STATE_HOME:?}" "${XDG_RUNTIME_DIR:?}"

m4_ifdef([[SKIP_BUILD_EM_TARGETS]],, [[
# Precompile some targets to speed up further builds
RUN EM_CACHE="$(em-config CACHE)" \
	&& parallel --halt now,fail=1 --lb embuilder build '{=uq=}' \
		::: 'MINIMAL' 'MINIMAL_PIC --pic' \
		::: '' '--lto' '--lto=thin' \
	&& rm -rf ~/.parallel/ \
	&& find "${EM_CACHE:?}"/ports/ -maxdepth 1 -type f -delete \
	&& find "${EM_CACHE:?}"/ports-builds/ -mindepth 1 -delete
]])

m4_ifdef([[SKIP_BUILD_CODE_SAMPLES]],, [[
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
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Compile to WASM
	&& printf '%s\n' 'Compiling C to WASM...' \
	&& emcc ./hello.c -o ./hello.js -O2 --closure 1 \
	&& MSGOUT=$(node ./hello.js) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Compile to WASI
	&& printf '%s\n' 'Compiling C to WASI...' \
	&& wasicc ./hello.c -o ./hello.wasm \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmedge ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Compile to WASIX
	&& printf '%s\n' 'Compiling C to WASIX...' \
	&& WASI_SYSROOT="${WASIX_SYSROOT:?}" wasicc ./hello.c -o ./hello.wasm \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/ \
	&& find "${XDG_CACHE_HOME:?}" -mindepth 1 -delete
]])

m4_ifdef([[SKIP_BUILD_CODE_SAMPLES]],, [[
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
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Compile to WASM
	&& printf '%s\n' 'Compiling Rust to WASM...' \
	&& rustc ./hello.rs --target=wasm32-unknown-emscripten -o ./hello.js \
	&& MSGOUT=$(node ./hello.js) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Compile to WASI
	&& printf '%s\n' 'Compiling Rust to WASI...' \
	&& rustc ./hello.rs --target=wasm32-wasi -o ./hello.wasm \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmedge ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/ \
	&& find "${XDG_CACHE_HOME:?}" -mindepth 1 -delete
]])

m4_ifdef([[SKIP_BUILD_CODE_SAMPLES]],, [[
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
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Compile to WASI
	&& printf '%s\n' 'Compiling Zig to WASI...' \
	&& zig build-exe -target wasm32-wasi ./hello.zig \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmedge ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/ \
	&& find "${XDG_CACHE_HOME:?}" -mindepth 1 -delete
]])

m4_ifdef([[SKIP_BUILD_CODE_SAMPLES]],, [[
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
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& printf '%s\n' 'Compiling TinyGo to native...' \
	&& tinygo build -o ./hello ./hello.go \
	&& MSGOUT=$(./hello) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Compile to WASM
	&& printf '%s\n' 'Compiling Go to WASM...' \
	&& GOOS=js GOARCH=wasm go build -o ./hello.wasm ./hello.go \
	&& MSGOUT=$(go_js_wasm_exec ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& printf '%s\n' 'Compiling TinyGo to WASM...' \
	&& tinygo build -o ./hello.wasm -target wasm ./hello.go \
	&& MSGOUT=$(node "${TINYGOROOT:?}"/targets/wasm_exec.js ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Compile to WASI
	&& printf '%s\n' 'Compiling Go to WASI...' \
	&& GOOS=wasip1 GOARCH=wasm go build -o ./hello.wasm ./hello.go \
	&& MSGOUT=$(GOWASIRUNTIME=wasmtime go_wasip1_wasm_exec ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(GOWASIRUNTIME=wasmer go_wasip1_wasm_exec ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(GOWASIRUNTIME=wasmedge go_wasip1_wasm_exec ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& printf '%s\n' 'Compiling TinyGo to WASI...' \
	&& tinygo build -o ./hello.wasm -target wasi ./hello.go \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmedge ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/ \
	&& find "${XDG_CACHE_HOME:?}" -mindepth 1 -delete
]])

WORKDIR ${HOME}
CMD ["/bin/bash"]
