# syntax=docker/dockerfile:1

FROM lscr.io/linuxserver/beets:2.5.1-ls306

# Build arguments
ARG PLUGIN_VERSION
ARG BUILD_DATE
ARG VERSION

# Add metadata labels
LABEL org.opencontainers.image.source="https://github.com/aedot/containers"
LABEL org.opencontainers.image.description="Beets with Audible plugin for audiobook management"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL io.linuxserver.base_version="${VERSION}"

# Install beets-audible plugin and dependencies
# Note: This runs as root during build, but runtime uses PUID/PGID
RUN \
  echo "**** install beets-audible plugin ****" && \
  if [ "${PLUGIN_VERSION}" = "latest" ]; then \
    pip install --no-cache-dir \
      beets-audible \
      beets-filetote; \
  else \
    pip install --no-cache-dir \
      beets-audible==${PLUGIN_VERSION} \
      beets-filetote; \
  fi && \
  echo "**** verify installation ****" && \
  pip list | grep beets && \
  echo "**** set permissions ****" && \
  # Ensure pip packages are accessible by non-root users
  chmod -R 755 /usr/local/lib/python*/site-packages 2>/dev/null || true && \
  echo "**** cleanup ****" && \
  rm -rf \
    /tmp/* \
    /root/.cache

# Verify plugin installation
RUN beet version || true

# Copy custom init script
# s6-overlay will run scripts in /etc/cont-init.d/ during initialization
COPY entrypoint.sh /etc/cont-init.d/99-beets-audible-init

# Make init script executable
RUN chmod +x /etc/cont-init.d/99-beets-audible-init

# Note: LinuxServer images use s6-overlay for init system
# The container will run as user 'beets' with UID/GID set by PUID/PGID env vars
# Scripts in /etc/cont-init.d/ run as root initially, then services run as beets

# Set working directory
WORKDIR /config

# Health check for web interface (optional, configure in compose)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD nc -z localhost 8337 || exit 1
