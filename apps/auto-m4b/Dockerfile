# syntax=docker/dockerfile:1

# auto-m4b — watches /temp/recentlyadded and converts audiobooks to chapterized
# m4b via m4b-tool. Built on the official m4b-tool image (ffmpeg, mp4v2, fdkaac,
# php) instead of seanap/auto-m4b, whose phusion/runit init needs root. The
# upstream script is fetched at a pinned commit and checksum-verified; it is
# not vendored because upstream publishes no license.

ARG VERSION
FROM docker.io/sandreas/m4b-tool:${VERSION}

ARG VERSION
ARG AUTO_M4B_COMMIT=94760b1e1ad9a46f85b75073eca8b8530b468d42
ARG AUTO_M4B_SHA256=940e75c40221c105d6e66f6e41621a52f285d562c1f9c2be3f1d3f1f2cf0c3e9
LABEL org.opencontainers.image.version="${VERSION}"

# the upstream script needs bash, GNU find/xargs/cp/ls (busybox lacks find -printf)
# and ffprobe, which the m4b-tool image omits. apk's ffmpeg installs to /usr/bin, so
# the base image's libfdk_aac-enabled /usr/local/bin/ffmpeg stays first on PATH.
RUN apk add --no-cache bash coreutils findutils grep sed ffmpeg

ADD --chmod=0755 --checksum=sha256:${AUTO_M4B_SHA256} \
    https://raw.githubusercontent.com/seanap/auto-m4b/${AUTO_M4B_COMMIT}/auto-m4b-tool.sh \
    /usr/local/bin/auto-m4b-tool.sh

# nobody's home is /nonexistent; point HOME at a writable path for php/m4b-tool
# under a read-only rootfs (with /tmp mounted as tmpfs).
ENV HOME=/tmp

WORKDIR /tmp

USER 65534:65534

ENTRYPOINT ["/usr/local/bin/auto-m4b-tool.sh"]
