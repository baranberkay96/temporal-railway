# Temporal v1 Durable Workflows Server — composer spec

| Field | Value |
|---|---|
| Listing name | **Temporal v1 Durable Workflows Server** (version label `v1` = Temporal Server major; tags are `v1.32.1`) |
| Description | Run reliable, retryable workflows in any language. Temporal server plus Web UI. (79 chars, unchanged) |
| Category | Queues |
| Tags | temporal, workflows, durable-execution, orchestration, microservices, grpc |
| Base market template | `temporal-light` (6ixfalls/railway-temporal, 265 projects: server image + admin-tools schema setup in a pre-deploy command, Elasticsearch, UI behind a Caddy basic-auth proxy). Repo has **no license** → structure/ideas only, nothing copied. Also reviewed `temporal` (same author, multi-role) and `temporal-starter` (`railwayapp-templates/temporal`, MIT, uses deprecated `auto-setup:1.21.3`). |
| Upstream checked | Temporal Server `v1.32.1` (2026-10-08) and `admin-tools:1.32.1`; Temporal UI `v2.55.0` (2026-10-01); `temporalio/samples-server` `compose/docker-compose-postgres.yml`, `scripts/setup-postgres.sh`, `scripts/create-namespace.sh`, `dynamicconfig/development-sql.yaml` (the maintained successor of the archived `temporalio/docker-compose`); `temporalio/temporal` `docker/targets/server.Dockerfile`, `docker/scripts/sh/entrypoint.sh`, `common/config/config_template_embedded.yaml`, `tools/sql/*`. Pinned 2026-10-11. |

## Architecture

```
 your workers / clients on Railway ──gRPC (private)──► temporal :7233  (frontend + history + matching + worker roles)
                                                         │   HTTP API :7243 (healthcheck)
                                                         ▼
                                              Postgres: temporal (persistence) + temporal_visibility (SQL visibility)
 browser ──HTTPS──► temporal-ui-gateway (Caddy, basic auth) ──private──► temporal-ui :8080 ──gRPC──► temporal
 temporal-namespace (one-shot): waits for the frontend, creates namespace "default"
 pre-deploy (on every temporal deploy): temporal-sql-tool create / setup-schema / update-schema
```

### Why visibility on PostgreSQL instead of Elasticsearch

Since Temporal 1.20, "advanced visibility" (list/count/filter workflows with SQL-like queries and custom search attributes) works on PostgreSQL 12+. The upstream `docker-compose-postgres.yml` uses exactly this. Elasticsearch adds a 1.5–4 GB JVM service and is only needed at high workflow-start rates or for very large visibility queries. It is therefore not part of this template; the server supports switching later (`ENABLE_ES=true` + `ES_*` variables + `temporal-elasticsearch-tool` setup) if you outgrow SQL visibility.

## Services

| Service | Source | Start / pre-deploy | Public | Healthcheck | Volume | Restart |
|---|---|---|---|---|---|---|
| `temporal` | repo `/services/temporal` (FROM `temporalio/server:1.32.1` + `temporal-sql-tool` and schemas from `temporalio/admin-tools:1.32.1`) | pre-deploy `/etc/temporal/railway/setup-schema.sh`; start = image entrypoint (`temporal-server start`) | none by default (TCP proxy optional, see below) | `/api/v1/system-info` on PORT=7243, 300 s | — | ON_FAILURE ×10 |
| `temporal-namespace` | image `temporalio/admin-tools:1.32.1` | inline `/bin/sh -c '…temporal operator cluster health… namespace create…'` | — | — (one-shot, exits 0) | — | ON_FAILURE ×5 |
| `temporal-ui` | image `temporalio/ui:2.55.0` | image default | none (private) | `/healthz` on 8080, 300 s | — | ON_FAILURE ×10 |
| `temporal-ui-gateway` | repo `/services/ui-gateway` (FROM `caddy:2.11.7-alpine`) | image entrypoint (hashes password, runs Caddy) | domain → 8080 | `/healthz`, 120 s | — | ON_FAILURE ×10 |
| `Postgres` | `ghcr.io/railwayapp-templates/postgres-ssl:18` (from `_railway-base`) | image | — | — | `/var/lib/postgresql/data` | ON_FAILURE ×10 |

`preDeployCommand` (Railway "Pre-deploy command") runs in a container from the new `temporal` image before each deployment goes live, so the schema is always created or upgraded before the server starts — no race between services.

## Variables

### temporal
| Variable | Default | Notes |
|---|---|---|
| `PORT` | `7243` | Only for the Railway healthcheck (HTTP API). |
| `DB` | `postgres12` | Upstream compose value. |
| `DB_PORT` | `5432` | |
| `POSTGRES_SEEDS` | `${{Postgres.RAILWAY_PRIVATE_DOMAIN}}` | |
| `POSTGRES_USER` / `POSTGRES_PWD` | `${{Postgres.PGUSER}}` / `${{Postgres.PGPASSWORD}}` | Needs CREATE DATABASE on first deploy. |
| `DBNAME` / `VISIBILITY_DBNAME` | `temporal` / `temporal_visibility` | Two databases on the same Postgres. |
| `NUM_HISTORY_SHARDS` | `512` | **Immutable after first start.** Upstream compose uses the dev default 4; 512 follows Temporal's small-production guidance and allows later throughput growth at the cost of some idle DB polling. |
| `BIND_ON_IP` | `::0` | All interfaces, IPv4 + IPv6 (legacy Railway environments are IPv6-only). |
| `TEMPORAL_BROADCAST_ADDRESS` | `127.0.0.1` | Single node runs all roles in one process; avoids guessing the container IP. |
| `LOG_LEVEL` | `info` | |
| `TEMPORAL_ADDRESS` | `${{RAILWAY_PRIVATE_DOMAIN}}:7233` | Convenience value for clients: reference `${{temporal.TEMPORAL_ADDRESS}}`. |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `30` | |

### temporal-namespace
`TEMPORAL_ADDRESS=${{temporal.TEMPORAL_ADDRESS}}`, `DEFAULT_NAMESPACE=default`, `DEFAULT_NAMESPACE_RETENTION=7d`.

### temporal-ui
`PORT=8080`, `TEMPORAL_UI_PORT=8080`, `TEMPORAL_ADDRESS=${{temporal.TEMPORAL_ADDRESS}}`, `TEMPORAL_DEFAULT_NAMESPACE=default`, `TEMPORAL_CORS_ORIGINS=https://${{temporal-ui-gateway.RAILWAY_PUBLIC_DOMAIN}}`, `TEMPORAL_AUTH_ENABLED=false`.
Optional OIDC (in addition to basic auth): `TEMPORAL_AUTH_ENABLED=true`, `TEMPORAL_AUTH_PROVIDER_URL`, `TEMPORAL_AUTH_CLIENT_ID`, `TEMPORAL_AUTH_CLIENT_SECRET`, `TEMPORAL_AUTH_CALLBACK_URL=https://<gateway domain>/auth/sso/callback`, `TEMPORAL_AUTH_SCOPES=openid,profile,email`. Read-only mode: `TEMPORAL_DISABLE_WRITE_ACTIONS=true`.

### temporal-ui-gateway
`PORT=8080`, `BASIC_AUTH_USERNAME=admin`, `BASIC_AUTH_PASSWORD=${{secret(32, alnum)}}`, `UPSTREAM_URL=http://${{temporal-ui.RAILWAY_PRIVATE_DOMAIN}}:8080`.

## Connecting workers and clients

**On Railway (recommended):** add to your worker/client service
```
TEMPORAL_ADDRESS=${{temporal.TEMPORAL_ADDRESS}}      # temporal.railway.internal:7233
TEMPORAL_NAMESPACE=default
```
and pass them to the SDK (e.g. Go `client.Dial(client.Options{HostPort: os.Getenv("TEMPORAL_ADDRESS")})`, TypeScript `NativeConnection.connect({ address })`, Python `await Client.connect(address)`; recent SDKs also read `TEMPORAL_ADDRESS`/`TEMPORAL_NAMESPACE` through environment configuration). Traffic stays on the private network; no TLS or auth needed inside the project.

**From outside Railway (optional TCP proxy):** in `temporal` → Settings → Networking add a TCP proxy for port **7233** and use `<proxy-domain>:<proxy-port>`. The Temporal frontend has **no authentication by default**: anyone who finds the proxy address can start, signal or terminate workflows. Only enable it together with mTLS (`TEMPORAL_TLS_SERVER_CERT_DATA`, `TEMPORAL_TLS_SERVER_KEY_DATA`, `TEMPORAL_TLS_SERVER_CA_CERT_DATA`, `TEMPORAL_TLS_REQUIRE_CLIENT_AUTH=true`, plus the internode/frontend TLS variables in the server config template) or remove it after use.

## Composer steps (Railway dashboard)

1. Add `Postgres` from `_railway-base/postgres.json`.
2. `temporal`: GitHub repo `baranberkay96/temporal-railway`, root `/services/temporal`; Settings → Deploy → Pre-deploy command `/etc/temporal/railway/setup-schema.sh`; healthcheck `/api/v1/system-info`; variables; no domain.
3. `temporal-namespace`: Docker image `temporalio/admin-tools:1.32.1`, start command from `template.json`, restart ON_FAILURE ×5.
4. `temporal-ui`: Docker image `temporalio/ui:2.55.0`, healthcheck `/healthz`, no domain.
5. `temporal-ui-gateway`: repo root `/services/ui-gateway`, domain → 8080, healthcheck `/healthz`.

## Improvements over market templates

| Area | Market templates | This template |
|---|---|---|
| Server image | `temporal-starter`: deprecated `temporalio/auto-setup:1.21.3` | `temporalio/server:1.32.1` + admin-tools schema tooling, as upstream documents now |
| Schema lifecycle | `temporal-light`: pre-deploy also boots a temporary server to register the namespace; light/multirole repos unlicensed | Pre-deploy only runs idempotent `create`/`setup-schema`/`update-schema` (doubles as the upgrade path); namespace via a separate one-shot admin-tools service, mirroring upstream `create-namespace.sh` |
| Visibility | Elasticsearch with `-Xmx4g` (light/multirole) | SQL advanced visibility on Postgres (upstream postgres compose); ~1.5–4 GB less RAM |
| Shards | 4 (dev default) | 512, documented as immutable |
| UI security | `temporal-starter`: UI public without auth; others use a third-party `:main` Caddy image | Own pinned Caddy 2.11.7 gateway with bcrypt basic auth; UI stays private; OIDC documented |
| gRPC exposure | `temporal-starter`: public TCP proxy without auth | Private by default; TCP proxy documented as opt-in with mTLS warning |
| Versions | UI `2.17.1` / `:latest` / `2.49.1` | Server 1.32.1, admin-tools 1.32.1, UI 2.55.0, Caddy 2.11.7 |
| Health | none on server/UI | HTTP API, UI `/healthz`, gateway `/healthz` |

## Resource profile and cost (Railway: RAM $10/GB-mo, vCPU $20/mo, volume $0.15/GB-mo)

| Service | Idle RAM | Typical RAM | Idle CPU | Typical CPU |
|---|---|---|---|---|
| temporal (all roles, 512 shards) | 0.4 GB | 0.6–1.2 GB | 0.05–0.1 | 0.2–0.6 |
| Postgres | 0.15 GB | 0.3–0.5 GB | 0.05 | 0.1–0.3 |
| temporal-ui | 0.05 GB | 0.08 GB | 0 | 0.01 |
| temporal-ui-gateway | 0.03 GB | 0.04 GB | 0 | 0.01 |
| temporal-namespace | 0 (exits) | 0 | 0 | 0 |
| **Total** | **~0.65 GB** | **~1.0–1.8 GB** | **~0.1–0.15 vCPU** | **~0.3–0.9 vCPU** |

Estimated monthly cost: **idle ≈ $10** (0.65 GB × $10 + 0.12 vCPU × $20 + ~1 GB volume); **typical (tens of workflows/second, 7-day retention) ≈ $25–40**; Postgres volume grows with retention. Your own workers are extra. Minimum plan: **Hobby**. Pro for sustained high throughput or multi-replica workers.

## Scaling

- Scale your **workers** (your code) horizontally first; they do the actual work.
- Give `temporal` and `Postgres` more CPU/RAM as throughput grows. Splitting the server into frontend/history/matching/worker services is possible but requires per-node broadcast addresses for membership — out of scope for this template.
- Do not add replicas to `temporal` (single-node membership with `127.0.0.1` broadcast address).

## Pinning and upgrades

Pinned 2026-10-11: `temporalio/server:1.32.1`, `temporalio/admin-tools:1.32.1` (both in `services/temporal/Dockerfile`; also the `temporal-namespace` image), `temporalio/ui:2.55.0`, `caddy:2.11.7-alpine`, `postgres-ssl:18`. Upgrade one minor version at a time (Temporal requirement): change both tags in the Dockerfile, push; the pre-deploy command applies the new schema versions before the new server starts.

## Verification checklist

- [ ] `temporal` deploy logs show the pre-deploy step: databases created, `setup-schema`, `update-schema` complete; then server starts and `/api/v1/system-info` returns 200.
- [ ] `temporal-namespace` logs: frontend healthy → namespace `default` created; exits 0. On redeploy: "already exists".
- [ ] Open the gateway domain → browser asks for basic auth → `admin` / `BASIC_AUTH_PASSWORD` → Temporal UI shows namespace `default`. `/healthz` works without auth.
- [ ] From another Railway service: `temporal workflow list --address temporal.railway.internal:7233` (admin-tools image) succeeds.
- [ ] Run a sample worker (e.g. samples-go hello world) with `TEMPORAL_ADDRESS=${{temporal.TEMPORAL_ADDRESS}}`; the workflow completes and appears in the UI with its history.
- [ ] Filter in the UI with a visibility query (`ExecutionStatus="Completed"`) → SQL visibility works.
- [ ] Redeploy all services: workflows and history persist.

## Open questions

- Not deployed end-to-end here. Points to confirm on first deploy: `BIND_ON_IP=::0` with `TEMPORAL_BROADCAST_ADDRESS=127.0.0.1` (dual-stack bind, local membership), the HTTP API healthcheck path, and that Railway's pre-deploy container reaches Postgres on the private network.
- Postgres 18 (Railway base image) vs Temporal's documented PostgreSQL support (12+, compose tests 16): expected to work with the `postgres12` plugin; not verified.
- Temporal uses the Postgres superuser to create its two databases. For stricter setups create a dedicated role and point `POSTGRES_USER`/`POSTGRES_PWD` at it before first deploy.
