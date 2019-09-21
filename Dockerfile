FROM docker.io/ubuntu:18.04 AS emscripten

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		bash \
		bash-completion \
		build-essential \
		ca-certificates \
		cmake \
		curl \
		file \
		git \
		gnupg \
		libssl-dev \
		libtool \
		locales \
		lsb-release \
		mime-support \
		nano \
		openjdk-8-jdk \
		openssh-client \
		pkgconf \
		python \
		python-dev \
		python-pip \
		python-setuptools \
		python-wheel \
		python3 \
		python3-dev \
		python3-pip \
		python3-setuptools \
		python3-wheel \
		tzdata \
		unzip \
		wget \
		zip \
	&& rm -rf /var/lib/apt/lists/*

# Create emscripten user and group
ARG EMSCRIPTEN_USER_UID=1000
ARG EMSCRIPTEN_USER_GID=1000
RUN groupadd \
		--gid "${EMSCRIPTEN_USER_GID:?}" \
		emscripten
RUN useradd \
		--uid "${EMSCRIPTEN_USER_UID:?}" \
		--gid "${EMSCRIPTEN_USER_GID:?}" \
		--shell "$(command -v bash)" \
		--home-dir /home/emscripten/ \
		--create-home \
		emscripten

# Setup locale
RUN printf '%s\n' 'en_US.UTF-8 UTF-8' > /etc/locale.gen
RUN localedef -c -i en_US -f UTF-8 en_US.UTF-8 ||:
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Setup timezone
ENV TZ=UTC
RUN ln -snf "/usr/share/zoneinfo/${TZ:?}" /etc/localtime
RUN printf '%s\n' "${TZ:?}" > /etc/timezone

# Drop root privileges
USER emscripten:emscripten
ENV USER=emscripten
ENV HOME=/home/emscripten

# Initialize PATH
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV PATH=${HOME}/.local/bin:${PATH}

# Install Emscripten
ARG EMSDK_TREEISH=master
ARG EMSDK_REMOTE=https://github.com/emscripten-core/emsdk.git
ENV EMSDK=${HOME}/.emsdk
ENV EMSDK_NODE=${EMSDK}/node/latest/bin/node
ENV EM_CONFIG=${HOME}/.emscripten
ENV EM_CACHE=${HOME}/.emscripten_cache
RUN mkdir -p "${EMSDK:?}" "${EM_CACHE:?}"
RUN cd "${EMSDK:?}" \
	&& git clone "${EMSDK_REMOTE:?}" ./ \
	&& git checkout "${EMSDK_TREEISH:?}" \
	&& git submodule update --init --recursive
RUN cd "${EMSDK:?}" \
	&& ./emsdk install latest-upstream \
	&& ./emsdk activate latest-upstream \
	&& ln -rs "${EMSDK:?}"/node/*/ "${EMSDK:?}"/node/latest
ENV PATH=${EMSDK}:${PATH}
ENV PATH=${EMSDK}/upstream/emscripten:${PATH}
ENV PATH=${EMSDK}/upstream/bin:${PATH}
ENV PATH=${EMSDK}/node/latest/bin:${PATH}
RUN command -V emcc && emcc --version
RUN command -V em++ && em++ --version
RUN command -V asm2wasm && asm2wasm --version
RUN command -V clang && clang --version
RUN command -V llvm-ar && llvm-ar --version
RUN command -V node && node --version
RUN command -V npm && npm --version

# Install Rust
ENV RUSTUP_HOME=${HOME}/.rustup
ENV CARGO_HOME=${HOME}/.cargo
RUN mkdir -p "${RUSTUP_HOME:?}" "${CARGO_HOME:?}"
RUN URL='https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init' \
	&& curl -sSfL "${URL:?}" -o "${HOME:?}"/rustup-init && chmod 755 "${HOME:?}"/rustup-init \
	&& "${HOME:?}"/rustup-init -y --no-modify-path && rm -f "${HOME:?}"/rustup-init
ENV PATH=${CARGO_HOME}/bin:${PATH}
RUN command -V rustup && rustup --version
RUN command -V rustc && rustc --version
RUN command -V cargo && cargo --version

# Install some packages from Cargo
RUN cargo install cargo-generate wasm-pack wasm-snip
RUN rustup target add wasm32-unknown-unknown
RUN command -V cargo-generate && cargo-generate --version
RUN command -V wasm-pack && wasm-pack --version
RUN command -V wasm-snip && wasm-snip --version

# Install Go
ENV GOROOT=${HOME}/.goroot
ENV GOPATH=${HOME}/.gopath
RUN mkdir -p "${GOROOT:?}" "${GOPATH:?}/bin" "${GOPATH:?}/src"
RUN VERSION=$(curl -sSfL 'https://golang.org/VERSION?m=text') \
	&& URL="https://dl.google.com/go/${VERSION:?}.linux-amd64.tar.gz" \
	&& curl -sSfL "${URL:?}" | tar -xz --strip-components=1 -C "${GOROOT:?}"
ENV PATH=${GOROOT}/bin:${PATH}
ENV PATH=${GOROOT}/misc/wasm:${PATH}
ENV PATH=${GOPATH}/bin:${PATH}
RUN command -V go && go version

# Install Wasmer
ENV WASMER_DIR=${HOME}/.wasmer
ENV WASMER_CACHE_DIR=${WASMER_DIR}/cache
RUN mkdir -p "${WASMER_DIR:?}" "${WASMER_CACHE_DIR:?}"
RUN URL='https://github.com/wasmerio/wasmer/releases/latest/download/wasmer-linux-amd64.tar.gz' \
	&& curl -sSfL "${URL:?}" | tar -xz -C "${WASMER_DIR:?}"
ENV PATH=${WASMER_DIR}/bin:${PATH}
ENV PATH=${WASMER_DIR}/globals/wapm_packages/.bin:${PATH}
RUN command -V wasmer && wasmer --version

# Install Yarn
ENV YARN_DIR=${HOME}/.yarn
ENV YARN_GLOBAL_DIR=${HOME}/.config/yarn/global
RUN mkdir -p "${YARN_DIR:?}" "${YARN_GLOBAL_DIR:?}"
RUN URL='https://yarnpkg.com/latest.tar.gz' \
	&& curl -sSfL "${URL:?}" | tar -xz --strip-components=1 -C "${YARN_DIR:?}"
ENV PATH=${YARN_DIR}/bin:${PATH}
ENV PATH=${YARN_GLOBAL_DIR}/node_modules/.bin:${PATH}
RUN command -V yarn && yarn --version

# Pre-generate all Emscripten system libraries
RUN embuilder.py build ALL

# Build and run example asm.js and WebAssembly program
RUN TESTDIR="${HOME:?}"/test/ && mkdir "${TESTDIR:?}" && cd "${TESTDIR:?}" \
	&& PRINTMSG='Hello, World!' \
	&& printf '%s\n' '#include <stdio.h>' "int main(){puts(\"${PRINTMSG:?}\");}" > ./hello.c \
	&& printf '%s\n' 'Testing asm.js build...' \
	&& emcc -s WASM=0 ./hello.c -o ./hello.js && [ "$(node ./hello.js)" = "${PRINTMSG:?}" ] \
	&& printf '%s\n' 'Testing WebAssembly build...' \
	&& emcc -s WASM=1 ./hello.c -o ./hello.js && [ "$(node ./hello.js)" = "${PRINTMSG:?}" ] \
	&& rm -rf "${TESTDIR:?}"

WORKDIR ${HOME}
CMD ["/bin/bash"]
