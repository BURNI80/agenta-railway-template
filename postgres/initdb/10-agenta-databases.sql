-- Databases required by the Agenta OSS platform.
--
-- Runs once, on the very first start of an empty data directory, as
-- POSTGRES_USER - which owns every connection on a Railway Postgres service and
-- is therefore a superuser, so CREATE DATABASE is allowed here and the created
-- databases are already owned by the role Agenta connects with.
--
-- Agenta splits its state across three databases on one server:
--   agenta_oss_core         organizations, users, agents, configurations
--   agenta_oss_tracing      run traces, spans, token usage and cost
--   agenta_oss_supertokens  the auth core (sessions, API keys)

SELECT 'CREATE DATABASE agenta_oss_core'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'agenta_oss_core')\gexec

SELECT 'CREATE DATABASE agenta_oss_tracing'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'agenta_oss_tracing')\gexec

SELECT 'CREATE DATABASE agenta_oss_supertokens'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'agenta_oss_supertokens')\gexec
