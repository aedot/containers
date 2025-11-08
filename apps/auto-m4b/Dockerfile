FROM docker.io/library/ubuntu:22.04 AS builder

ARG VERSION
# Set noninteractive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake build-essential ca-certificates gcc g++ cmake yasm pkg-config libtool \
    nasm wget git texinfo libfdk-aac-dev libmp3lame-dev zlib1g-dev \
    libass-dev libfreetype6-dev libgnutls28-dev libvorbis-dev libsdl2-dev \
    libva-dev libvdpau-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev \
    && rm -rf /var/lib/apt/lists/*

# Prepare directories
RUN mkdir -p /tmp/ffmpeg_sources /tmp/ffmpeg_build

# Build fdk-aac
RUN cd /tmp/ffmpeg_sources && \
    git clone --verbose --depth 1 https://github.com/mstorsjo/fdk-aac && \
    cd fdk-aac && autoreconf -fiv && \
    ./configure --prefix=/tmp/ffmpeg_build --disable-shared && \
    make && make install && make distclean

# Download and extract ffmpeg
RUN cd /tmp/ffmpeg_sources && \
    wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
    tar xjvf ffmpeg-snapshot.tar.bz2

# Build ffmpeg
RUN cd /tmp/ffmpeg_sources/ffmpeg && \
    PKG_CONFIG_PATH=/tmp/ffmpeg_build/lib/pkgconfig ./configure \
      --prefix=/tmp/ffmpeg_build \
      --pkg-config-flags="--static" \
      --extra-cflags="-I/tmp/ffmpeg_build/include" \
      --extra-ldflags="-L/tmp/ffmpeg_build/lib" \
      --extra-libs="-lpthread -lm" \
      --bindir=/usr/local/bin \
      --enable-libfdk-aac \
      --enable-libmp3lame \
      --enable-nonfree && \
    make && make install && hash -r && make distclean

FROM docker.io/library/ubuntu:22.04
ARG M4B_TOOL_DOWNLOAD_LINK="https://github.com/sandreas/m4b-tool/releases/download/v0.5.2/m4b-tool.phar"
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip wget git dnsutils iputils-ping crudini \
    php-cli php-intl php-json php-mbstring php-xml \
    libasound2 libsdl2-2.0-0 libva-drm2 libvdpau1 libxcb1 libxcb-shm0 libxcb-xfixes0 \
    && rm -rf /var/lib/apt/lists/*

# Copy ffmpeg binaries from builder
COPY --from=builder /usr/local/bin/ffmpeg /usr/local/bin/
COPY --from=builder /usr/local/bin/ffprobe /usr/local/bin/
COPY --from=builder /usr/local/bin/ffplay /usr/local/bin/

# Install m4b-tool
RUN wget "$M4B_TOOL_DOWNLOAD_LINK" -O /usr/local/bin/m4b-tool && chmod +x /usr/local/bin/m4b-tool

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create mountable volumes
VOLUME /temp
VOLUME /config

# Environment defaults
ENV PUID=""
ENV PGID=""
ENV CPU_CORES=""
ENV SLEEPTIME=""

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]
