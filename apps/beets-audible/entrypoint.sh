#!/bin/sh
set -eu

# seed a default config on first run; never overwrite a user-edited one
if [ ! -f "${BEETSDIR}/config.yaml" ]; then
  cp /defaults/config.yaml "${BEETSDIR}/config.yaml"
fi

trap 'exit 0' TERM INT

while true; do
  # -q: never prompt; anything without a confident match is skipped (and
  # recorded by `incremental`, so it is not retried every loop)
  beet import -q /input || echo "beet import exited with status $?" >&2
  sleep "${IMPORT_INTERVAL:-300}" &
  wait $!
done
