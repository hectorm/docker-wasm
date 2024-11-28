m4_changequote([[, ]])

##################################################
## "base" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/debian:sid-slim]], [[FROM docker.io/debian:sid-slim]]) AS base

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		autopoint \
		bash \
		bison \
		build-essential \
		bzip2 \
		ca-certificates \
		ccache \
		cmake \
		curl \
		default-jre-headless \
		file \
		flex \
		gettext \
		git \
		gnupg \
		intltool \
		jq \
		libarchive-tools \
		libltdl-dev \
		libssl-dev \
		libtoml-tiny-perl \
		libtool \
		libtool-bin \
		locales \
		lsb-release \
		m4 \
		make \
		media-types \
		meson \
		mold \
		nano \
		ninja-build \
		openssh-client \
		parallel \
		patch \
		patchelf \
		perl \
		pkgconf \
		python-dev-is-python3 \
		python-is-python3 \
		python3 \
		python3-dev \
		python3-packaging \
		python3-pip \
		python3-venv \
		ragel \
		rsync \
		sudo \
		tzdata \
		unzip \
		wget \
		xz-utils \
		zip \
		zstd \
	&& rm -rf /var/lib/apt/lists/*

# Set Bash as the default shell
SHELL ["/bin/bash", "-euc"]

# Setup locale and timezone
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TZ=UTC
RUN printf '%s\n' "${LANG:?} UTF-8" > /etc/locale.gen \
	&& localedef -c -i "${LANG%%.*}" -f UTF-8 "${LANG:?}" ||: \
	&& printf '%s\n' "${TZ:?}" > /etc/timezone \
	&& ln -snf "/usr/share/zoneinfo/${TZ:?}" /etc/localtime

# Allow members of group root to execute any command
RUN printf '%s\n' '%root ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/nopasswd

# Define system environment
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV XDG_CONFIG_DIRS=/etc/xdg
ENV XDG_DATA_DIRS=/usr/local/share:/usr/share

# Define prefix environment
ARG PREFIX=/opt
ENV PATH=${PREFIX}/bin:${PATH}
ENV XDG_CONFIG_DIRS=${PREFIX}/etc/xdg:${XDG_CONFIG_DIRS}
ENV XDG_DATA_DIRS=${PREFIX}/share:${XDG_DATA_DIRS}

# Define Rust environment
ENV RUST_HOME=${PREFIX}/rust
ENV PATH=${RUST_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${RUST_HOME}/lib:${LD_LIBRARY_PATH}

# Define Zig environment
ENV ZIG_HOME=${PREFIX}/zig
ENV PATH=${ZIG_HOME}:${PATH}

# Define Go environment
ENV GOROOT=${PREFIX}/go
ENV PATH=${GOROOT}/bin:${PATH}
ENV PATH=${GOROOT}/misc/wasm:${PATH}

# Define TinyGo environment
ENV TINYGOROOT=${PREFIX}/tinygo
ENV PATH=${TINYGOROOT}/bin:${PATH}

# Define Node.js environment
ENV NODE_HOME=${PREFIX}/node
ENV PATH=${NODE_HOME}/bin:${PATH}

# Define Emscripten environment
ENV EMSDK=${PREFIX}/emsdk
ENV WASM_OPT=${EMSDK}/upstream/bin/wasm-opt
ENV PATH=${EMSDK}:${PATH}
ENV PATH=${EMSDK}/upstream/emscripten:${PATH}
ENV PATH=${EMSDK}/upstream/emscripten/node_modules/.bin:${PATH}
ENV PATH=${EMSDK}/upstream/bin:${PATH}

# Define WASI environment
ENV WASI_SDK_PATH=${EMSDK}/upstream
ENV WASI_SYSROOT=${WASI_SDK_PATH}/share/wasi-sysroot

# Define Wasmtime environment
ENV WASMTIME_HOME=${PREFIX}/wasmtime
ENV PATH=${WASMTIME_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${WASMTIME_HOME}/lib:${LD_LIBRARY_PATH}

# Define Wasmer environment
ENV WASMER_DIR=${PREFIX}/wasmer
ENV PATH=${WASMER_DIR}/bin:${PATH}
ENV LD_LIBRARY_PATH=${WASMER_DIR}/lib:${LD_LIBRARY_PATH}

# Define WasmEdge environment
ENV WASMEDGE_DIR=${PREFIX}/wasmedge
ENV WASMEDGE_PLUGIN_PATH=${WASMEDGE_DIR}/lib
ENV PATH=${WASMEDGE_DIR}/bin:${PATH}
ENV LD_LIBRARY_PATH=${WASMEDGE_DIR}/lib:${LD_LIBRARY_PATH}

# Define Wazero environment
ENV WAZERO_DIR=${PREFIX}/wazero
ENV PATH=${WAZERO_DIR}/bin:${PATH}

# Define WABT environment
ENV WABT_DIR=${PREFIX}/wabt
ENV PATH=${WABT_DIR}/bin:${PATH}

# Define wasm-tools environment
ENV WASM_TOOLS_DIR=${PREFIX}/wasm-tools
ENV PATH=${WASM_TOOLS_DIR}/bin:${PATH}

# Define wasm-bindgen environment
ENV WASM_BINDGEN_DIR=${PREFIX}/wasm-bindgen
ENV PATH=${WASM_BINDGEN_DIR}/bin:${PATH}

# Define wasm-pack environment
ENV WASM_PACK_DIR=${PREFIX}/wasm-pack
ENV PATH=${WASM_PACK_DIR}/bin:${PATH}

# Define wasm user environment
ENV HOME=/home/wasm
ENV XDG_CONFIG_HOME=${HOME}/.config
ENV XDG_CACHE_HOME=${HOME}/.cache
ENV XDG_DATA_HOME=${HOME}/.local/share
ENV XDG_STATE_HOME=${HOME}/.local/state
ENV XDG_RUNTIME_DIR=${HOME}/.local/run
ENV PATH=${HOME}/.local/bin:${PATH}

# Define Rust environment for wasm user
ENV CARGO_HOME=${XDG_DATA_HOME}/cargo
ENV RUSTUP_HOME=${XDG_DATA_HOME}/rustup
ENV RUSTUP_INIT_SKIP_PATH_CHECK=yes
ENV PATH=${CARGO_HOME}/bin:${PATH}

# Define Go environment for wasm user
ENV GOPATH=${XDG_DATA_HOME}/go
ENV PATH=${GOPATH}/bin:${PATH}

# Define Node.js environment for wasm user
ENV NPM_CONFIG_PREFIX=${XDG_DATA_HOME}/npm
ENV NPM_CONFIG_CACHE=${XDG_CACHE_HOME}/npm
ENV NPM_CONFIG_USERCONFIG=${XDG_CONFIG_HOME}/npm/npmrc
ENV NPM_CONFIG_INIT_MODULE=${XDG_CONFIG_HOME}/npm/config/npm-init.js
ENV PATH=${NPM_CONFIG_PREFIX}/bin:${PATH}

# Define Emscripten environment for wasm user
ENV EM_CACHE=${XDG_CACHE_HOME}/emscripten
ENV EM_PORTS=${EM_CACHE}/ports

# Define Wasmer environment for wasm user
ENV WASMER_CACHE_DIR=${XDG_CACHE_HOME}/wasmer

# Create wasm user
RUN useradd --uid 1000 --user-group --create-home --home-dir "${HOME:?}" --shell /bin/bash wasm \
	&& mkdir -p "${XDG_CONFIG_HOME:?}" "${XDG_CACHE_HOME:?}" "${XDG_DATA_HOME:?}" "${XDG_STATE_HOME:?}" "${XDG_RUNTIME_DIR:?}" \
	&& chown -R wasm:wasm "${HOME:?}"

##################################################
## "build" stage
##################################################

FROM base AS build

# Create install prefix
RUN mkdir -p "${PREFIX:?}" && chown -R wasm:wasm "${PREFIX:?}"

# Drop root privileges
USER wasm:wasm

# Install Rust
RUN mkdir -p "${RUST_HOME:?}" \
	&& case "$(uname -m)" in x86_64) ARCH=x86_64 ;; aarch64) ARCH=aarch64 ;; esac \
	&& mkdir /tmp/rust/ && cd /tmp/rust/ \
	&& curl -sSfL 'https://static.rust-lang.org/dist/channel-rust-nightly.toml' -o ./manifest.toml \
	&& PKG_URL_PARSER='print(from_toml(do{local $/;<STDIN>})->{pkg}{$ARGV[0]}{target}{$ARGV[1]}{xz_url})' \
	&& curl -sSfL "$(perl -MPOSIX -MTOML::Tiny -e"${PKG_URL_PARSER:?}" rust     "${ARCH:?}"-unknown-linux-gnu < ./manifest.toml)" | bsdtar -x \
	&& curl -sSfL "$(perl -MPOSIX -MTOML::Tiny -e"${PKG_URL_PARSER:?}" rust-std wasm32-wasip1                 < ./manifest.toml)" | bsdtar -x \
	&& curl -sSfL "$(perl -MPOSIX -MTOML::Tiny -e"${PKG_URL_PARSER:?}" rust-std wasm32-wasip2                 < ./manifest.toml)" | bsdtar -x \
	&& curl -sSfL "$(perl -MPOSIX -MTOML::Tiny -e"${PKG_URL_PARSER:?}" rust-std wasm32-unknown-unknown        < ./manifest.toml)" | bsdtar -x \
	&& curl -sSfL "$(perl -MPOSIX -MTOML::Tiny -e"${PKG_URL_PARSER:?}" rust-std wasm32-unknown-emscripten     < ./manifest.toml)" | bsdtar -x \
	&& ./rust-*-"${ARCH:?}"-unknown-linux-gnu/install.sh --prefix="${RUST_HOME:?}" --components=rustc,rust-std-"${ARCH:?}"-unknown-linux-gnu,cargo,rustfmt-preview,clippy-preview \
	&& ./rust-std-*-wasm32-wasip1/install.sh             --prefix="${RUST_HOME:?}" --components=rust-std-wasm32-wasip1 \
	&& ./rust-std-*-wasm32-wasip2/install.sh             --prefix="${RUST_HOME:?}" --components=rust-std-wasm32-wasip2 \
	&& ./rust-std-*-wasm32-unknown-unknown/install.sh    --prefix="${RUST_HOME:?}" --components=rust-std-wasm32-unknown-unknown \
	&& ./rust-std-*-wasm32-unknown-emscripten/install.sh --prefix="${RUST_HOME:?}" --components=rust-std-wasm32-unknown-emscripten \
	&& curl -sSfL "https://static.rust-lang.org/rustup/dist/${ARCH:?}-unknown-linux-gnu/rustup-init" -o "${RUST_HOME:?}"/bin/rustup-init \
	&& chmod 0755 "${RUST_HOME:?}"/bin/rustup-init \
	&& rm -rf /tmp/rust/
RUN command -V rustc && rustc --version
RUN command -V cargo && cargo --version
RUN command -V rustup-init && rustup-init --version

# Install Zig
RUN mkdir -p "${ZIG_HOME:?}" \
	&& case "$(uname -m)" in x86_64) ARCH=x86_64 ;; aarch64) ARCH=aarch64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://ziglang.org/download/index.json') \
	&& PKG_URL_PARSER='to_entries | map(select(.key | test("^[0-9]+(\\.[0-9]+)*$"))) | sort_by(.value.date) | .[-1].value[$a + "-linux"].tarball' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C "${ZIG_HOME:?}"
RUN command -V zig && zig version

# Install Go
RUN mkdir -p "${GOROOT:?}" \
	&& case "$(uname -m)" in x86_64) ARCH=amd64 ;; aarch64) ARCH=arm64 ;; esac \
	&& VERSION=$(curl -sSfL 'https://go.dev/VERSION?m=text' | head -1) \
	&& PKG_URL="https://dl.google.com/go/${VERSION:?}.linux-${ARCH:?}.tar.gz" \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C "${GOROOT:?}"
RUN command -V go && go version

# Install TinyGo
RUN mkdir -p "${TINYGOROOT:?}" \
	&& case "$(uname -m)" in x86_64) ARCH=amd64 ;; aarch64) ARCH=arm64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/tinygo-org/tinygo/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^tinygo[0-9]+(\\.[0-9]+)*\\.linux-" + $a + "\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C "${TINYGOROOT:?}" \
	&& rm -f "${TINYGOROOT:?}"/bin/wasm-opt # Already included in Emscripten
RUN command -V tinygo && tinygo version

# Install Node.js
RUN mkdir -p "${NODE_HOME:?}" \
	&& case "$(uname -m)" in x86_64) ARCH=x64 ;; aarch64) ARCH=arm64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://nodejs.org/dist/index.json') \
	&& VERSION_PARSER='map(select(.lts)) | sort_by(.version | ltrimstr("v") | split(".") | map(tonumber)) | .[-1].version' \
	&& VERSION=$(printf '%s' "${RELEASE_JSON:?}" | jq -r "${VERSION_PARSER:?}") \
	&& PKG_URL="https://nodejs.org/dist/${VERSION:?}/node-${VERSION:?}-linux-${ARCH:?}.tar.xz" \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C "${NODE_HOME:?}"
RUN command -V node && node --version
RUN command -V npm && npm --version

# Install Emscripten
RUN mkdir -p "${EMSDK:?}" \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/emscripten-core/emsdk/tags') \
	&& PKG_URL_PARSER='sort_by(.name | split(".") | map(tonumber)) | .[-1].tarball_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C "${EMSDK:?}" \
	&& emsdk install latest \
	&& emsdk activate latest \
	&& ln -sr "${EMSDK:?}"/upstream/bin/{lld,ld.lld} \
	&& embuilder clear ALL \
	&& rm -rf "${EMSDK:?}"/upstream/emscripten/cache/
RUN command -V emcc && emcc --version
RUN command -V em++ && em++ --version
RUN command -V clang && clang --version
RUN "${WASM_OPT:?}" --version

# Install WASI SDK into Emscripten
RUN mkdir -p "${WASI_SDK_PATH:?}" "${WASI_SYSROOT:?}" \
	&& case "$(uname -m)" in x86_64) ARCH=x86_64 ;; aarch64) ARCH=arm64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/WebAssembly/wasi-sdk/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wasi-sdk-[0-9]+(\\.[0-9]+)*-" + $a + "-linux\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C "${WASI_SDK_PATH:?}" \
		-s "#/lib/clang/[0-9]*/#/lib/clang/$(basename "$(clang --print-resource-dir)")/#" \
		'./wasi-sdk-*/bin/wasm*-ld' \
		'./wasi-sdk-*/bin/wasm*-wasi*' \
		'./wasi-sdk-*/lib/clang/[0-9]*/lib/' \
		'./wasi-sdk-*/share/' \
	&& ln -s "${WASI_SDK_PATH:?}" "${PREFIX:?}"/wasi-sdk
RUN test -f "${WASI_SDK_PATH:?}"/share/cmake/wasi-sdk.cmake
RUN test -f "${WASI_SDK_PATH:?}"/share/cmake/wasi-sdk-p2.cmake
RUN test -f "${WASI_SYSROOT:?}"/lib/wasm32-wasip1/libc.a
RUN test -f "${WASI_SYSROOT:?}"/lib/wasm32-wasip2/libc.a
RUN test -f "$(clang --print-resource-dir)"/lib/wasip1/libclang_rt.builtins-wasm32.a
RUN test -f "$(clang --print-resource-dir)"/lib/wasip2/libclang_rt.builtins-wasm32.a

# Install Wasmtime
RUN mkdir -p "${WASMTIME_HOME:?}" \
	&& case "$(uname -m)" in x86_64) ARCH=x86_64 ;; aarch64) ARCH=aarch64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/bytecodealliance/wasmtime/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wasmtime-v[0-9]+(\\.[0-9]+)*-" + $a + "-linux\\.tar\\.xz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C "${WASMTIME_HOME:?}" \
	&& mkdir "${WASMTIME_HOME:?}"/bin/ && mv "${WASMTIME_HOME:?}"/wasmtime "${WASMTIME_HOME:?}"/wasmtime-min "${WASMTIME_HOME:?}"/bin/ \
	&& LIB_URL_PARSER='.assets[] | select(.name | test("^wasmtime-v[0-9]+(\\.[0-9]+)*-" + $a + "-linux-c-api\\.tar\\.xz$")?) | .browser_download_url' \
	&& LIB_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${LIB_URL_PARSER:?}") \
	&& curl -sSfL "${LIB_URL:?}" | bsdtar -x --strip-components=1 -C "${WASMTIME_HOME:?}"
RUN test -f "${WASMTIME_HOME:?}"/lib/libwasmtime.so
RUN command -V wasmtime && wasmtime --version

# Install Wasmer
RUN mkdir -p "${WASMER_DIR:?}" \
	&& case "$(uname -m)" in x86_64) ARCH=amd64 ;; aarch64) ARCH=aarch64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/wasmerio/wasmer/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wasmer-linux-" + $a + "\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x -C "${WASMER_DIR:?}"
RUN test -f "${WASMER_DIR:?}"/lib/libwasmer.so
RUN command -V wasmer && wasmer --version

# Install WasmEdge
RUN mkdir -p "${WASMEDGE_DIR:?}" \
	&& case "$(uname -m)" in x86_64) ARCH=x86_64 ;; aarch64) ARCH=aarch64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/WasmEdge/WasmEdge/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^WasmEdge-[0-9]+(\\.[0-9]+)*-manylinux2014_" + $a + "\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C "${WASMEDGE_DIR:?}" \
	&& PLUGIN_WASI_CRYPTO_URL_PARSER='.assets[] | select(.name | test("^WasmEdge-plugin-wasi_crypto-[0-9]+(\\.[0-9]+)*-manylinux2014_" + $a + "\\.tar\\.gz$")?) | .browser_download_url' \
	&& PLUGIN_WASI_CRYPTO_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PLUGIN_WASI_CRYPTO_URL_PARSER:?}") \
	&& patchelf --set-rpath '$ORIGIN/../lib' "${WASMEDGE_DIR:?}"/bin/wasmedge \
	&& mv "${WASMEDGE_DIR:?}"/lib64/ "${WASMEDGE_DIR:?}"/lib/ \
	&& curl -sSfL "${PLUGIN_WASI_CRYPTO_URL:?}" | bsdtar -x -C "${WASMEDGE_PLUGIN_PATH:?}"
RUN test -f "${WASMEDGE_DIR:?}"/lib/libwasmedge.so
RUN test -f "${WASMEDGE_PLUGIN_PATH:?}"/libwasmedgePluginWasiCrypto.so
RUN command -V wasmedge && wasmedge --version

# Install Wazero
RUN mkdir -p "${WAZERO_DIR:?}" \
	&& case "$(uname -m)" in x86_64) ARCH=amd64 ;; aarch64) ARCH=arm64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/tetratelabs/wazero/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wazero_[0-9]+(\\.[0-9]+)*_linux_" + $a + "\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x -C "${WAZERO_DIR:?}" \
	&& mkdir "${WAZERO_DIR:?}"/bin/ && mv "${WAZERO_DIR:?}"/wazero "${WAZERO_DIR:?}"/bin/
RUN command -V wazero && wazero version

# Install WABT
RUN mkdir -p "${WABT_DIR:?}" \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/WebAssembly/wabt/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wabt-[0-9]+(\\.[0-9]+)*\\.tar\\.xz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r "${PKG_URL_PARSER:?}") \
	&& cd "$(mktemp -d)" && curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C ./ \
	&& mkdir ./build/ && cd ./build/ \
	&& cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${WABT_DIR:?}" ./../ \
	&& ninja install \
	&& cd / && rm -rf "${OLDPWD:?}"
RUN command -V wat2wasm && wat2wasm --version
RUN command -V wasm2wat && wasm2wat --version

# Install wasm-tools
RUN mkdir -p "${WASM_TOOLS_DIR:?}" \
	&& case "$(uname -m)" in x86_64) ARCH=x86_64 ;; aarch64) ARCH=aarch64 ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/bytecodealliance/wasm-tools/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wasm-tools-[0-9]+(\\.[0-9]+)*-" + $a + "-linux\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg a "${ARCH:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C "${WASM_TOOLS_DIR:?}" \
	&& mkdir "${WASM_TOOLS_DIR:?}"/bin/ && mv "${WASM_TOOLS_DIR:?}"/wasm-tools "${WASM_TOOLS_DIR:?}"/bin/
RUN command -V wasm-tools && wasm-tools --version

# Install wasm-bindgen
RUN mkdir -p "${WASM_BINDGEN_DIR:?}" \
	&& case "$(uname -m)" in x86_64) TARGET=x86_64-unknown-linux-musl ;; aarch64) TARGET=aarch64-unknown-linux-gnu ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/rustwasm/wasm-bindgen/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wasm-bindgen-[0-9]+(\\.[0-9]+)*-" + $t + "\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg t "${TARGET:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C "${WASM_BINDGEN_DIR:?}" \
	&& mkdir "${WASM_BINDGEN_DIR:?}"/bin/ && mv "${WASM_BINDGEN_DIR:?}"/wasm-bindgen* "${WASM_BINDGEN_DIR:?}"/wasm2es6js "${WASM_BINDGEN_DIR:?}"/bin/
RUN command -V wasm-bindgen && wasm-bindgen --version

# Install wasm-pack
RUN mkdir -p "${WASM_PACK_DIR:?}" \
	&& case "$(uname -m)" in x86_64) TARGET=x86_64-unknown-linux-musl ;; aarch64) TARGET=aarch64-unknown-linux-musl ;; esac \
	&& RELEASE_JSON=$(curl -sSfL 'https://api.github.com/repos/rustwasm/wasm-pack/releases/latest') \
	&& PKG_URL_PARSER='.assets[] | select(.name | test("^wasm-pack-v[0-9]+(\\.[0-9]+)*-" + $t + "\\.tar\\.gz$")?) | .browser_download_url' \
	&& PKG_URL=$(printf '%s' "${RELEASE_JSON:?}" | jq -r --arg t "${TARGET:?}" "${PKG_URL_PARSER:?}") \
	&& curl -sSfL "${PKG_URL:?}" | bsdtar -x --strip-components=1 -C "${WASM_PACK_DIR:?}" \
	&& mkdir "${WASM_PACK_DIR:?}"/bin/ && mv "${WASM_PACK_DIR:?}"/wasm-pack "${WASM_PACK_DIR:?}"/bin/
RUN command -V wasm-pack && wasm-pack --version

# Copy config
COPY --chmod=644 ./config/meson/cross/ ${PREFIX}/share/meson/cross/

# Copy scripts
COPY --chmod=755 ./scripts/bin/ ${PREFIX}/bin/

m4_ifdef([[SKIP_BUILD_EM_TARGETS]],, [[
# Precompile some targets to speed up further builds
RUN mkdir "${HOME:?}"/src/ && cd "${HOME:?}"/src/ \
	&& printf '%s\n' 'int main(){return 0;}' > ./noop.c \
	&& parallel -j1 -k -v --lb --halt now,fail=1 \
		emcc ./noop.c -o ./noop.'{#}'.wasm '{=uq=}' -lembind \
			::: '-sMEMORY64=0' '-sMEMORY64=1' \
			::: '-O0' '-Oz' \
			::: '' '-fpic -sMAIN_MODULE=2' \
			::: '' '-flto=full' '-flto=thin' \
			::: '' '-pthread' \
	&& rm -rf "${HOME:?}"/src/
]])

# Build sample C program
RUN mkdir "${HOME:?}"/test/ && cd "${HOME:?}"/test/ \
	# Create program
	&& MSGIN='Hello, world!' \
	&& printf '%s\n' '#include <stdio.h>' 'int main(){puts("'"${MSGIN:?}"'");}' > ./hello.c \
	&& printf '%s\n' "project('hello', 'c')" "executable('hello', 'hello.c')" > ./meson.build \
	# Compile to native
	&& printf '%s\n' 'Compiling C to native...' \
	&& meson setup ./build/ \
	&& meson compile -C ./build/ \
	&& MSGOUT=$(./build/hello) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& rm -rf ./build/ \
	# Compile to WASM
	&& printf '%s\n' 'Compiling C to WASM...' \
	&& emconfigure meson setup --cross-file wasm32-unknown-emscripten ./build/ \
	&& emmake meson compile -C ./build/ \
	&& MSGOUT=$(node ./build/hello.js) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& rm -rf ./build/ \
	# Compile to WASI
	&& printf '%s\n' 'Compiling C to WASI...' \
	&& meson setup --cross-file wasm32-wasip1 ./build/ \
	&& meson compile -C ./build/ \
	&& MSGOUT=$(wasmtime run ./build/hello) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmer run ./build/hello) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmedge ./build/hello) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wazero run ./build/hello) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& rm -rf ./build/ \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/

# Build sample Rust program
RUN mkdir "${HOME:?}"/test/ && cd "${HOME:?}"/test/ \
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
	&& rustc ./hello.rs --target=wasm32-wasip1 -o ./hello.wasm \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmedge ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wazero run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/

# Build sample Zig program
RUN mkdir "${HOME:?}"/test/ && cd "${HOME:?}"/test/ \
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
	&& zig build-exe -target wasm32-wasi.0.1.0 ./hello.zig \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmedge ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wazero run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/

# Build sample Go program
RUN mkdir "${HOME:?}"/test/ && cd "${HOME:?}"/test/ \
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
	&& MSGOUT=$(GOWASIRUNTIME=wazero go_wasip1_wasm_exec ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& printf '%s\n' 'Compiling TinyGo to WASI...' \
	&& tinygo build -o ./hello.wasm -target wasi ./hello.go \
	&& MSGOUT=$(wasmtime run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmer run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wasmedge ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	&& MSGOUT=$(wazero run ./hello.wasm) \
	&& { [ "${MSGOUT-}" = "${MSGIN:?}" ] || exit 1; } \
	# Cleanup
	&& rm -rf "${HOME:?}"/test/

##################################################
## "main" stage
##################################################

FROM base AS main

# Drop root privileges
USER wasm:wasm

# Copy install prefix
COPY --from=build --chown=root:root ${PREFIX} ${PREFIX}

# Copy Emscripten cache
COPY --from=build --chown=wasm:wasm ${EM_CACHE} ${EM_CACHE}

WORKDIR ${HOME}
CMD ["/bin/bash"]
