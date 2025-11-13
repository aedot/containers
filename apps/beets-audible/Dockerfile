# syntax=docker/dockerfile:1

FROM docker.io/library/alpine:3.22
ARG VERSION

ENV PATH="/opt/venv/bin:$PATH" \
    BEETSDIR="/config" \
    HOME="/config" \
    EDITOR="nano"

RUN set -eux; \
    echo "**** install build packages ****"; \
    apk add --no-cache --virtual=build-dependencies \
        build-base \
        ca-certificates \
        cairo-dev \
        cargo \
        cmake \
        ffmpeg-dev \
        fftw-dev \
        git \
        gobject-introspection-dev \
        jpeg-dev \
        libpng-dev \
        mpg123-dev \
        openjpeg-dev \
        python3-dev \
        unzip \
        curl \
        jq \
        tzdata; \
    echo "**** install runtime packages ****"; \
    apk add --no-cache \
        bash \
        chromaprint \
        expat \
        ffmpeg \
        fftw \
        flac \
        gdbm \
        gobject-introspection \
        gst-plugins-good \
        gstreamer \
        imagemagick \
        jpeg \
        lame \
        libffi \
        libpng \
        mpg123 \
        nano \
        openjpeg \
        python3 \
        py3-pip \
        sqlite-libs \
        tini; \
    echo "**** compile mp3gain ****"; \
    mkdir -p /tmp/mp3gain-src; \
    curl -sL -o /tmp/mp3gain-src/mp3gain.zip \
        https://sourceforge.net/projects/mp3gain/files/mp3gain/1.6.2/mp3gain-1_6_2-src.zip; \
    cd /tmp/mp3gain-src; \
    unzip -qq mp3gain.zip; \
    sed -i "s#/usr/local/bin#/usr/bin#g" Makefile; \
    make && make install; \
    echo "**** compile mp3val ****"; \
    mkdir -p /tmp/mp3val-src; \
    curl -sL -o /tmp/mp3val-src/mp3val.tar.gz \
        https://downloads.sourceforge.net/mp3val/mp3val-0.1.8-src.tar.gz; \
    cd /tmp/mp3val-src; \
    tar xzf mp3val.tar.gz --strip 1; \
    make -f Makefile.linux; \
    cp -p mp3val /usr/bin; \
    echo "**** install pip packages ****"; \
    if [ -z "${VERSION}" ]; then \
        VERSION=$(curl -sL https://pypi.python.org/pypi/beets/json | jq -r '.info.version'); \
    fi; \
    python3 -m venv /opt/venv; \
    /opt/venv/bin/pip install --upgrade pip wheel; \
    /opt/venv/bin/pip install --no-cache-dir \
        beautifulsoup4 \
        beets==${VERSION} \
        beets-extrafiles \
        beets[plexupdate] \
        beets-audible \
        beetcamp \
        python3-discogs-client \
        flask \
        PyGObject \
        pyacoustid \
        pylast \
        requests \
        requests_oauthlib \
        typing-extensions \
        unidecode; \
    echo "**** cleanup ****"; \
    apk del --purge build-dependencies; \
    rm -rf /tmp/* /root/.cache /root/.cargo

# Copy entrypoint
COPY ./entrypoint.sh /entrypoint.sh

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

USER nobody:nogroup
WORKDIR /config
VOLUME ["/config"]

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
