# NOTICE — Temporal template

This is a community template. It is not affiliated with or endorsed by Temporal Technologies Inc.

## Upstream sources checked (2026-10-11)

| Source | Version / path | License | Use |
|---|---|---|---|
| temporalio/samples-server | `main` (2026-10-07): `compose/docker-compose-postgres.yml`, `compose/.env`, `compose/scripts/setup-postgres.sh`, `compose/scripts/create-namespace.sh`, `compose/dynamicconfig/development-sql.yaml` | MIT | Reference topology (server + admin-tools schema setup + namespace job + UI), env vars, `limit.maxIDLength` value. `setup-schema.sh` and the namespace command were rewritten for Railway (idempotent re-runs, bounded waits); no file copied verbatim |
| temporalio/docker-compose | archived; `README.md`, `.env` | MIT | Confirms move to samples-server |
| temporalio/temporal | `v1.32.1`: `docker/targets/server.Dockerfile`, `docker/scripts/sh/entrypoint.sh`, `common/config/config_template_embedded.yaml`, `tools/sql/{main,handler}.go`, `tools/common/schema/setuptask.go`, `common/persistence/sql/sqlplugin/postgresql/admin.go` | MIT | Env-var names, `BIND_ON_IP`/broadcast behaviour, schema tool idempotency |
| temporalio/ui | `v2.55.0`: `server/config/docker.yaml`, `server/Dockerfile`, `server/server/route/health.go` | MIT | UI env vars, `/healthz` |
| caddyserver/caddy | `v2.11.7` docs (`basic_auth`, `hash-password`) | Apache-2.0 | Gateway configuration |

## Market templates and repos reviewed

| Code / repo | License | Use |
|---|---|---|
| `temporal-light`, `temporal` → github.com/6ixfalls/railway-temporal | none (all rights reserved) | Ideas only (server image + admin-tools binaries, pre-deploy schema step, basic-auth UI proxy). No files or text copied. |
| `temporal-starter` → github.com/railwayapp-templates/temporal | MIT (Copyright (c) 2023 Railway) | Reviewed; uses deprecated `auto-setup`; nothing reused |
| `railwayapp-templates/elasticsearch` | — | Not used (Elasticsearch dropped in favour of SQL visibility) |
| `ghcr.io/brody192/railway-caddy-basic-auth` (image used by market templates) | n/a | Not used; own Caddy configuration written instead |

## Railway base services

`Postgres` definition copied from `templates/_railway-base/postgres.json`.

## Runtime images

`temporalio/server:1.32.1`, `temporalio/admin-tools:1.32.1`, `temporalio/ui:2.55.0` (MIT), `caddy:2.11.7-alpine` (Apache-2.0), `ghcr.io/railwayapp-templates/postgres-ssl:18`.
