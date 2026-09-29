# syntax=docker/dockerfile:1
#
# Agenta's bundled Postgres, with the three databases the platform expects
# created on first boot.
#
# This matters on Railway because a template deploys every service at once: the
# SuperTokens service and the API both need their database to already exist the
# moment Postgres starts accepting TCP connections. The stock postgres image only
# runs /docker-entrypoint-initdb.d on an empty data directory, so the schemas
# would otherwise be created later by the one-shot `alembic` service - after
# SuperTokens has already burned its restart budget.
#
# The `alembic` service still creates the same databases idempotently, so this is
# belt and braces: it makes the first deploy deterministic, and it keeps working
# if the volume already existed before this template.
FROM postgres:17

COPY initdb/ /docker-entrypoint-initdb.d/
