# syntax=docker/dockerfile:1
#
# Edge gateway for the Agenta Railway template.
#
# Single public entrypoint. Everything else in the stack is reachable only over
# Railway's private network (`*.railway.internal`), so this is the one service
# that needs public HTTP networking.
#
# Routing:
#   /            -> Web        (Next.js desktop app)
#   /m, /m/*     -> Web-mobile (Next.js mobile app, built with basePath /m)
#   /api/*       -> API        (prefix stripped)
#   /services/*  -> Services   (prefix stripped)
#   /healthz     -> this nginx (liveness for the Railway healthcheck)
FROM nginx:1.27-alpine

# Every value below is overridable from the service's variables. The defaults
# match the service names created by this template.
ENV PORT=8080 \
    AGENTA_WEB_UPSTREAM="web.railway.internal:8080" \
    AGENTA_WEB_MOBILE_UPSTREAM="web-mobile.railway.internal:8080" \
    AGENTA_API_UPSTREAM="api.railway.internal:8000" \
    AGENTA_SERVICES_UPSTREAM="services.railway.internal:8080"

COPY nginx.conf /etc/nginx/nginx.conf.template

# envsubst is called with an explicit variable list on purpose: the config also
# contains nginx runtime variables ($host, $remote_addr, $scheme, ...) which
# must survive untouched.
CMD ["/bin/sh", "-c", "envsubst '${PORT} ${AGENTA_WEB_UPSTREAM} ${AGENTA_WEB_MOBILE_UPSTREAM} ${AGENTA_API_UPSTREAM} ${AGENTA_SERVICES_UPSTREAM}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && exec nginx -g 'daemon off;'"]
