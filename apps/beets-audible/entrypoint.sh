#!/bin/sh
set -eu

# seed a default config on first run; never overwrite a user-edited one
if [ ! -f "${BEETSDIR}/config.yaml" ]; then
  cp /defaults/config.yaml "${BEETSDIR}/config.yaml"
fi

# YAML single-quoted scalar
yaml_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

# Plex connection settings come from the environment so the same config works
# on any setup. They are written to an overlay that overrides config.yaml.
plex_overlay="${TMPDIR:-/tmp}/plex.yaml"
if [ -n "${PLEX_HOST:-}${PLEX_PORT:-}${PLEX_LIBRARY_NAME:-}" ]; then
  {
    echo "plex:"
    if [ -n "${PLEX_HOST:-}" ]; then
      printf '  host: %s\n' "$(yaml_quote "${PLEX_HOST}")"
    fi
    if [ -n "${PLEX_PORT:-}" ]; then
      case "${PLEX_PORT}" in
        *[!0-9]*)
          echo "PLEX_PORT must be a number, got '${PLEX_PORT}'" >&2
          exit 1
          ;;
      esac
      printf '  port: %s\n' "${PLEX_PORT}"
    fi
    if [ -n "${PLEX_LIBRARY_NAME:-}" ]; then
      printf '  library_name: %s\n' "$(yaml_quote "${PLEX_LIBRARY_NAME}")"
    fi
  } >"${plex_overlay}"
  set -- -c "${plex_overlay}"
else
  set --
fi

trap 'exit 0' TERM INT

while true; do
  # -q: never prompt; anything without a confident match is skipped (and
  # recorded by `incremental`, so it is not retried every loop)
  beet "$@" import -q /input || echo "beet import exited with status $?" >&2
  sleep "${IMPORT_INTERVAL:-300}" &
  wait $!
done
