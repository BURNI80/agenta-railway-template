#!/bin/sh
#
# Railway entrypoint for the Agenta API service.
#
# Two jobs, then hand over to the real command (gunicorn by default):
#
#  1. Durable store signing key.
#     Agenta's bundled SeaweedFS store vends short-lived S3 credentials through
#     STS AssumeRoleWithWebIdentity, which only validates an RS256 web-identity
#     token against a JWKS the store fetches from this API. The signing key must
#     therefore be stable across process restarts AND across API replicas: if it
#     changed while SeaweedFS was still holding a cached JWKS, every store mount
#     would fail to authenticate until that cache expired.
#     We generate an RSA-2048 key once and keep it on a Railway volume, so it
#     survives deploys and restarts. If no volume is attached and the key cannot
#     be written, we warn and let Agenta use its own built-in key rather than
#     crash-looping the service.
#
#  2. Ordered startup.
#     A Railway template deploys every service at once, so this process can come
#     up before Postgres is accepting connections or before the `alembic` service
#     has finished migrating. Both waits share one deadline: past it we start
#     anyway instead of wedging the deployment.
#
# Environment (all optional, defaults in brackets):
#   PGHOST [unset: skip DB waits] / PGPORT [5432] / PGUSER / PGPASSWORD
#   PGDATABASE [agenta_oss_core]
#   AGENTA_STORE_JWT_KEY_FILE [/var/lib/agenta/store-jwt-private-key.pem]
#   AGENTA_DB_WAIT_SECONDS   [300] max seconds to wait for Postgres + migrations

set -eu

PYTHON="${PYTHON:-/opt/venv/bin/python}"
KEY_FILE="${AGENTA_STORE_JWT_KEY_FILE:-/var/lib/agenta/store-jwt-private-key.pem}"
DB_WAIT_SECONDS="${AGENTA_DB_WAIT_SECONDS:-300}"

log() {
    printf '%s railway-entrypoint: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" >&2
}

# psql must never fall back to an interactive password prompt: stdin here is the
# container's, and a prompt would hang the deploy instead of failing the check.
PSQL="psql -w -tAc"

# --- 1. Durable store signing key -----------------------------------------

if [ -s "$KEY_FILE" ]; then
    log "reusing the store signing key at $KEY_FILE"
else
    KEY_DIR="$(dirname "$KEY_FILE")"
    if mkdir -p "$KEY_DIR" 2>/dev/null && [ -w "$KEY_DIR" ]; then
        if "$PYTHON" -c '
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
pem = key.private_bytes(
    serialization.Encoding.PEM,
    serialization.PrivateFormat.PKCS8,
    serialization.NoEncryption(),
)
import sys

sys.stdout.write(pem.decode())
' > "$KEY_FILE.tmp" 2>/dev/null; then
            mv "$KEY_FILE.tmp" "$KEY_FILE"
            chmod 600 "$KEY_FILE"
            log "generated a new store signing key at $KEY_FILE"
        else
            rm -f "$KEY_FILE.tmp"
            log "WARNING: could not generate a store signing key; using Agenta's built-in key"
        fi
    else
        log "WARNING: $KEY_DIR is not writable; using Agenta's built-in store key"
    fi
fi

if [ -s "$KEY_FILE" ]; then
    AGENTA_STORE_JWT_PRIVATE_KEY="$(cat "$KEY_FILE")"
    export AGENTA_STORE_JWT_PRIVATE_KEY
fi

# --- 2. Ordered startup ---------------------------------------------------

if [ -n "${PGHOST:-}" ]; then
    export PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-5}"

    # Single deadline shared by both waits, so a slow Postgres can never spend
    # twice the budget.
    deadline=$DB_WAIT_SECONDS
    waited=0

    while [ "$waited" -lt "$deadline" ]; do
        if $PSQL 'SELECT 1' >/dev/null 2>&1; then
            break
        fi
        if [ "$waited" -eq 0 ]; then
            log "waiting for Postgres at ${PGHOST}:${PGPORT:-5432}"
        fi
        sleep 3
        waited=$((waited + 3))
    done

    if [ "$waited" -ge "$deadline" ]; then
        log "WARNING: Postgres unreachable after ${DB_WAIT_SECONDS}s; starting anyway"
    else
        # Migrations run in a separate one-shot service. Wait for them so the
        # first real request after a deploy does not hit an empty schema.
        budget=$((deadline - waited))
        elapsed=0
        while [ "$elapsed" -lt "$budget" ]; do
            if $PSQL "SELECT 1 FROM pg_tables WHERE schemaname = 'public' LIMIT 1" 2>/dev/null | grep -q 1; then
                log "database is migrated; starting"
                break
            fi
            if [ "$elapsed" -eq 0 ]; then
                log "waiting for database migrations on ${PGDATABASE:-agenta_oss_core}"
            fi
            sleep 3
            elapsed=$((elapsed + 3))
        done

        if [ "$elapsed" -ge "$budget" ]; then
            log "WARNING: migrations not visible after ${budget}s; starting anyway"
        fi
    fi
fi

exec "$@"
