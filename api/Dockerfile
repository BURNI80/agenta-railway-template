# syntax=docker/dockerfile:1
#
# Thin wrapper around the upstream Agenta API image.
#
# It adds exactly one thing the stock image cannot do on Railway: a durable,
# per-deployment RSA key for the bundled SeaweedFS store's OIDC/STS handshake.
# See entrypoint.sh for the full contract. The base image is pinned, so this
# wrapper inherits Agenta's own build and changes only when the pin moves.
FROM ghcr.io/agenta-ai/agenta-api:v0.121.5

COPY --chmod=0755 entrypoint.sh /app/railway-entrypoint.sh

ENTRYPOINT ["/app/railway-entrypoint.sh"]
CMD ["gunicorn", "entrypoints.routers:app", "--bind", "0.0.0.0:8000", "--worker-class", "uvicorn.workers.UvicornWorker", "--workers", "2", "--max-requests", "10000", "--max-requests-jitter", "1000", "--timeout", "60", "--graceful-timeout", "60", "--log-level", "info", "--access-logfile", "-", "--error-logfile", "-"]
