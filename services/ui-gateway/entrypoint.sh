#!/bin/sh
# Hashes the basic-auth password at start-up (Caddy needs a bcrypt hash) and
# starts Caddy. The plain password only lives in the Railway variable.
set -eu

: "${BASIC_AUTH_USERNAME:?BASIC_AUTH_USERNAME must be set}"
: "${BASIC_AUTH_PASSWORD:?BASIC_AUTH_PASSWORD must be set}"
: "${UPSTREAM_URL:?UPSTREAM_URL must be set (e.g. http://temporal-ui.railway.internal:8080)}"

BASIC_AUTH_HASH="$(caddy hash-password --plaintext "${BASIC_AUTH_PASSWORD}")"
export BASIC_AUTH_HASH
unset BASIC_AUTH_PASSWORD

exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
