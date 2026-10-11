# Temporal Server (all roles: frontend, history, matching, worker) for Railway.
#
# Follows the current upstream layout (temporalio/samples-server compose):
# the plain temporalio/server image plus schema management with the
# admin-tools binaries. auto-setup is deprecated and not used.
# Server and admin-tools tags must match.
FROM temporalio/admin-tools:1.32.1 AS admintools

FROM temporalio/server:1.32.1

# temporal-sql-tool + versioned SQL schemas, used by the Railway pre-deploy
# command to create/upgrade the databases before every deployment.
COPY --from=admintools /usr/local/bin/temporal-sql-tool /usr/local/bin/temporal-sql-tool
COPY --from=admintools /etc/temporal/schema /etc/temporal/schema

COPY --chown=temporal:temporal dynamicconfig.yaml /etc/temporal/config/dynamicconfig/railway.yaml
COPY --chmod=755 setup-schema.sh /etc/temporal/railway/setup-schema.sh

ENV DYNAMIC_CONFIG_FILE_PATH=/etc/temporal/config/dynamicconfig/railway.yaml

# 7233 gRPC frontend, 7243 HTTP API (healthcheck)
EXPOSE 7233 7243

# Default CMD of the base image: /etc/temporal/entrypoint.sh -> temporal-server start
