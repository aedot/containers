# syntax=docker/dockerfile:1

# beets-audible — beets with the Neurrone/beets-audible plugin, importing
# finished audiobooks from /input into /audiobooks on a loop. Built on a plain
# python image instead of linuxserver/beets, whose s6 init needs root.

FROM python:3.14-slim

ARG VERSION
LABEL org.opencontainers.image.version="${VERSION}"

# beets-audible pins the compatible beets range itself; the extra pulls in the
# plexupdate plugin's dependencies
RUN pip install --no-cache-dir "beets-audible==${VERSION}" "beets[plexupdate]"

COPY defaults/config.yaml /defaults/config.yaml
COPY --chmod=0755 entrypoint.sh /entrypoint.sh

# nobody's home is /nonexistent; point HOME at a writable path under a
# read-only rootfs (with /tmp mounted as tmpfs). Library db and config live
# on the /config volume.
ENV HOME=/tmp \
    BEETSDIR=/config

VOLUME ["/config", "/input", "/audiobooks"]

USER 65534:65534

ENTRYPOINT ["/entrypoint.sh"]
