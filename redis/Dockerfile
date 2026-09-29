# syntax=docker/dockerfile:1
#
# Redis with a Railway-friendly data directory.
#
# Railway mounts volumes root-owned. The stock redis image drops privileges to
# the `redis` user, so on a fresh volume it cannot create its RDB/AOF files and
# exits with "MISCONF Redis is configured to save RDB snapshots ... but it is
# currently unable to persist" and crash-loops. This wrapper chowns /data to the
# redis user first, then delegates to the official entrypoint unchanged.
#
# The service must run with RAILWAY_RUN_UID=0 / RAILWAY_RUN_GID=0 for the chown
# to be possible at all.
FROM redis:8

COPY entrypoint.sh /usr/local/bin/railway-redis-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-redis-entrypoint.sh

USER root

ENTRYPOINT ["/usr/local/bin/railway-redis-entrypoint.sh"]
CMD ["redis-server"]
