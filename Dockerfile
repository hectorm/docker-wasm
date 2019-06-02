FROM docker.io/ubuntu:18.04 AS emscripten

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		bash \
		build-essential \
		cmake \
		git \
		openjdk-8-jdk \
		pkg-config \
		python \
		python-pip \
	&& rm -rf /var/lib/apt/lists/*

# Create emscripten user and group
ARG EMSCRIPTEN_USER_UID=1000
ARG EMSCRIPTEN_USER_GID=1000
RUN groupadd \
		--gid "${EMSCRIPTEN_USER_GID}" \
		emscripten
RUN useradd \
		--uid "${EMSCRIPTEN_USER_UID}" \
		--gid "${EMSCRIPTEN_USER_GID}" \
		--shell="$(command -v bash)" \
		--home-dir /home/emscripten/ \
		--create-home \
		emscripten

# Create $EMSDK directory
ENV EMSDK=/opt/emsdk
RUN mkdir -p "${EMSDK}" && chown emscripten:emscripten "${EMSDK}"

# Drop root privileges
USER emscripten:emscripten

# Setup Emscripten
ARG EMSDK_TREEISH=master
ARG EMSDK_REMOTE=https://github.com/emscripten-core/emsdk.git
RUN cd "${EMSDK}" \
	&& git clone "${EMSDK_REMOTE}" ./ \
	&& git checkout "${EMSDK_TREEISH}" \
	&& git submodule update --init --recursive
RUN cd "${EMSDK}" \
	&& ./emsdk install --build=Release sdk-incoming-64bit binaryen-master-64bit \
	&& ./emsdk activate --build=Release sdk-incoming-64bit binaryen-master-64bit \
	&& ./emsdk construct_env

# Enable Emscripten SDK environment
ENV BASH_ENV="${EMSDK}/emsdk_set_env.sh"
RUN printf '%s\n' ". ${BASH_ENV}" >> ~/.bashrc
SHELL ["/bin/bash", "-c"]

# Pre-generate all system libraries
RUN embuilder.py build ALL

WORKDIR /home/emscripten/
CMD ["/bin/bash"]
