#!/bin/sh

set -eu

# Make the persistent data directory writable by the redis user before handing
# over to the official entrypoint (which drops privileges to that user itself).
mkdir -p /data

REDIS_UID="$(id -u redis)"
REDIS_GID="$(id -g redis)"
DATA_OWNER="$(stat -c '%u:%g' /data 2>/dev/null || true)"

if [ "$DATA_OWNER" != "${REDIS_UID}:${REDIS_GID}" ]; then
    chown -R redis:redis /data
fi

exec /usr/local/bin/docker-entrypoint.sh "$@"
