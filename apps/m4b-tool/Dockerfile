# syntax=docker/dockerfile:1

FROM docker.io/library/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
LABEL Description="Container to run m4b-tool as a daemon."

# Install runtime packages
RUN echo "---- INSTALL RUNTIME PACKAGES ----" && \
    apt-get update && apt-get install -y --no-install-recommends \
    nasm \
    python3-pip \
    git \
    dnsutils \
    iputils-ping \
    wget \
    bc \
    crudini \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install all build dependencies and build FFmpeg + mp4v2
RUN echo "---- INSTALL ALL BUILD-DEPENDENCIES ----" && \
    buildDeps='gcc \
    g++ \
    make \
    autoconf \
    automake \
    build-essential \
    cmake \
    git-core \
    libass-dev \
    libfreetype6-dev \
    libgnutls28-dev \
    libmp3lame-dev \
    libsdl2-dev \
    libtool \
    libva-dev \
    libvdpau-dev \
    libvorbis-dev \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    meson \
    ninja-build \
    pkg-config \
    texinfo \
    yasm \
    libfdk-aac-dev \
    zlib1g-dev' && \
    set -x && \
    apt-get update && apt-get install -y $buildDeps --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* && \
    \
    echo "---- BUILD & INSTALL MP4V2 ----" && \
    mkdir -p /tmp && \
    cd /tmp && \
    git clone https://github.com/sandreas/mp4v2 && \
    cd mp4v2 && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    make distclean && \
    cd / && \
    rm -rf /tmp/mp4v2 && \
    \
    echo "---- BUILD & INSTALL ffmpeg ----" && \
    mkdir -p ~/ffmpeg_sources ~/bin && \
    cd ~/ffmpeg_sources && \
    git clone --depth 1 https://github.com/mstorsjo/fdk-aac && \
    cd fdk-aac && \
    autoreconf -fiv && \
    ./configure --prefix="$HOME/ffmpeg_build" --disable-shared && \
    make -j$(nproc) && \
    make install && \
    make distclean && \
    cd ~/ffmpeg_sources && \
    wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
    tar xjf ffmpeg-snapshot.tar.bz2 && \
    cd ffmpeg && \
    PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
      --prefix="$HOME/ffmpeg_build" \
      --pkg-config-flags="--static" \
      --extra-cflags="-I$HOME/ffmpeg_build/include" \
      --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
      --extra-libs="-lpthread -lm" \
      --ld="g++" \
      --bindir="$HOME/bin" \
      --enable-libfdk-aac \
      --enable-nonfree && \
    PATH="$HOME/bin:$PATH" make -j$(nproc) && \
    make install && \
    hash -r && \
    make distclean && \
    mv ~/bin/* /usr/local/bin/ && \
    \
    echo "---- REMOVE ALL BUILD-DEPENDENCIES ----" && \
    apt-get purge -y --auto-remove $buildDeps && \
    ldconfig && \
    rm -rf /tmp/* ~/ffmpeg_sources ~/bin /var/lib/apt/lists/*

# Install m4b-tool dependencies
RUN echo "---- INSTALL M4B-TOOL DEPENDENCIES ----" && \
    apt-get update && apt-get install -y --no-install-recommends \
    fdkaac \
    php-cli \
    php-intl \
    php-json \
    php-mbstring \
    php-xml \
    php-curl \
    php-zip \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    libasound-dev \
    libsdl2-dev \
    libva-dev \
    libvdpau-dev && \
    rm -rf /var/lib/apt/lists/*

# Install m4b-tool
ARG VERSION
RUN echo "---- INSTALL M4B-TOOL ${VERSION} ----" && \
    wget https://github.com/sandreas/m4b-tool/releases/download/${VERSION}/m4b-tool.phar \
    -O /usr/local/bin/m4b-tool && \
    chmod +x /usr/local/bin/m4b-tool && \
    m4b-tool --version

# Create directories and set permissions
RUN mkdir -p /temp /config && \
    chmod 755 /temp /config

# Copy scripts
COPY auto-m4b-tool.sh /auto-m4b-tool.sh
COPY runscript.sh /runscript.sh

# Set execute permissions on scripts
RUN chmod +x /auto-m4b-tool.sh && \
    chmod +x /runscript.sh && \
    ls -la /auto-m4b-tool.sh && \
    ls -la /runscript.sh

# Create non-root user (default 1000:1000)
RUN groupadd -g 1000 m4buser || true && \
    useradd -u 1000 -g 1000 -s /bin/bash -d /config m4buser || true && \
    chown -R 1000:1000 /temp /config /auto-m4b-tool.sh /runscript.sh

# Define volumes
VOLUME ["/temp", "/config"]

ENV SLEEPTIME=""

# Final cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Switch to non-root user
USER 1000:1000

# Run the script directly
CMD ["/runscript.sh"]
