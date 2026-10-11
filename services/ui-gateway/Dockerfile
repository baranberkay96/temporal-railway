# Basic-auth reverse proxy for the Temporal Web UI.
FROM caddy:2.11.7-alpine

COPY Caddyfile /etc/caddy/Caddyfile
COPY --chmod=755 entrypoint.sh /usr/local/bin/ui-gateway-entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/ui-gateway-entrypoint.sh"]
