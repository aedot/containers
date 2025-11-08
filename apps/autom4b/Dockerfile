# syntax=docker/dockerfile:1

FROM docker.io/library/ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake build-essential ca-certificates gcc g++ cmake yasm pkg-config libtool \
    nasm wget git texinfo libfdk-aac-dev libmp3lame-dev zlib1g-dev \
    libass-dev libfreetype6-dev libgnutls28-dev libvorbis-dev libsdl2-dev \
    libva-dev libvdpau-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/ffmpeg_sources /tmp/ffmpeg_build
RUN cd /tmp/ffmpeg_sources && \
    git clone --verbose --depth 1 https://github.com/mstorsjo/fdk-aac && \
    cd fdk-aac && autoreconf -fiv && \
    ./configure --prefix=/tmp/ffmpeg_build --disable-shared && \
    make && make install && make distclean

RUN cd /tmp/ffmpeg_sources && \
    wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
    tar xjvf ffmpeg-snapshot.tar.bz2

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

ARG VERSION
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip wget git dnsutils iputils-ping crudini catatonit \
    php-cli php-intl php-json php-mbstring php-xml \
    libasound2 libsdl2-2.0-0 libva-drm2 libvdpau1 libxcb1 libxcb-shm0 libxcb-xfixes0 \
    gosu \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/ffmpeg /usr/local/bin/
COPY --from=builder /usr/local/bin/ffprobe /usr/local/bin/
COPY --from=builder /usr/local/bin/ffplay /usr/local/bin/


RUN wget https://github.com/sandreas/m4b-tool/releases/download/${VERSION}/m4b-tool.phar -O /usr/local/bin/m4b-tool && chmod +x /usr/local/bin/m4b-tool

COPY . /

RUN chmod +x /entrypoint.sh \
    && mkdir -p /config \
    && chown -R nobody:nogroup /config /entrypoint.sh

VOLUME /temp
VOLUME /config

ENV PUID=1000
ENV PGID=100
ENV CPU_CORES=$(nproc)
ENV SLEEPTIME=5m
ENV MAKE_BACKUP=Y

ENTRYPOINT ["/usr/bin/catatonit", "--", "/entrypoint.sh"]
