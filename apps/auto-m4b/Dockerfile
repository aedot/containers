# =====================================
# STAGE 1: Build ffmpeg + mp4v2
# =====================================
FROM ubuntu:22.04 AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    autoconf automake build-essential cmake git-core libass-dev libfreetype6-dev \
    libgnutls28-dev libmp3lame-dev libtool libva-dev libvdpau-dev libvorbis-dev \
    libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev meson ninja-build pkg-config \
    texinfo wget yasm zlib1g-dev libfdk-aac-dev nasm \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# ---- Build mp4v2 ----
RUN git clone --depth=1 https://github.com/sandreas/mp4v2.git \
 && cd mp4v2 \
 && ./configure && make -j$(nproc) && make install

# ---- Build fdk-aac ----
RUN git clone --depth=1 https://github.com/mstorsjo/fdk-aac.git \
 && cd fdk-aac && autoreconf -fiv && ./configure --disable-shared && make -j$(nproc) && make install

# ---- Build ffmpeg ----
RUN mkdir -p /build/ffmpeg_sources && cd /build/ffmpeg_sources \
 && wget -q https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 \
 && tar xjf ffmpeg-snapshot.tar.bz2 && cd ffmpeg \
 && ./configure \
    --prefix=/usr/local \
    --pkg-config-flags="--static" \
    --extra-cflags="-I/usr/local/include" \
    --extra-ldflags="-L/usr/local/lib" \
    --extra-libs="-lpthread -lm" \
    --enable-libfdk-aac \
    --enable-nonfree \
 && make -j$(nproc) && make install

# =====================================
# STAGE 2: Runtime
# =====================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
LABEL Description="Lightweight container to run m4b-tool as a daemon."

# ---- Install runtime dependencies ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    fdkaac php-cli php-intl php-json php-mbstring php-xml \
    wget git crudini iputils-ping dnsutils python3-pip \
 && rm -rf /var/lib/apt/lists/*

# ---- Copy ffmpeg + mp4v2 from build stage ----
COPY --from=build /usr/local/ /usr/local/

# ---- Install m4b-tool ----
ARG M4B_TOOL_DOWNLOAD_LINK="https://github.com/sandreas/m4b-tool/releases/download/v0.5.2/m4b-tool.phar"
RUN echo "---- INSTALL M4B-TOOL ----" && \
    wget -q "${M4B_TOOL_DOWNLOAD_LINK}" -O /usr/local/bin/m4b-tool && \
    chmod +x /usr/local/bin/m4b-tool

# ---- Copy your scripts ----
ADD runscript.sh /etc/service/bot/run
ADD ./apps/auto-m4b/auto-m4b-tool.sh /

# ---- Environment and Volumes ----
ENV PUID="" \
    PGID="" \
    CPU_CORES="" \
    SLEEPTIME=""

VOLUME ["/temp", "/config"]

# Create a non-root user
RUN useradd -m -s /bin/bash appuser

# ---- Set permissions for mounted volumes ----
RUN mkdir -p /temp /config \
 && chown -R appuser:appuser /temp /config /etc/service /auto-m4b-tool.sh

# ---- Switch to non-root user ----
USER appuser
WORKDIR /home/appuser

# ---- Default entrypoint ----
ENTRYPOINT ["/usr/local/bin/m4b-tool"]
