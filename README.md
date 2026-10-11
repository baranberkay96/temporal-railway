# Deploy and Host Temporal with Railway

Temporal is an open-source durable execution platform: you write workflows as ordinary code in Go, Java, TypeScript, Python, .NET, PHP or Ruby, and Temporal persists every step so they survive crashes, retries and deploys. This community template runs a self-hosted Temporal Server with PostgreSQL and a password-protected Web UI on Railway.

## About Hosting Temporal

A self-hosted Temporal cluster needs the Temporal Server (frontend, history, matching and internal worker roles), a database for workflow state, a visibility store for searching workflows, and usually the Web UI. This template runs the server roles in one service on the official `temporalio/server` image, stores both persistence and visibility in PostgreSQL (SQL advanced visibility, no Elasticsearch required), and creates or upgrades the database schema with Temporal's own `temporal-sql-tool` in a Railway pre-deploy step. A one-shot job registers the `default` namespace. The Web UI stays on the private network behind a small Caddy gateway with basic authentication, and the gRPC frontend is reachable by your workers over Railway's private network.

## Common Use Cases

- Order, payment and subscription flows that must finish exactly once despite failures.
- Long-running business processes with timers, human approvals and compensation (sagas).
- Reliable background jobs and data pipelines with automatic retries and full history.
- Orchestrating AI agents and LLM tool calls that need durable state and replay.
- Coordinating microservices without hand-built state machines and queues.

## Dependencies for Temporal Hosting

- Temporal Server (`temporalio/server`) and admin tools (`temporalio/admin-tools`)
- PostgreSQL (persistence and visibility databases)
- Temporal Web UI (`temporalio/ui`)
- Caddy (basic-auth gateway for the UI)
- Your own worker services using a Temporal SDK

### Deployment Dependencies

- Temporal documentation: https://docs.temporal.io/
- Self-hosted deployment guide: https://docs.temporal.io/self-hosted-guide
- Upstream compose examples: https://github.com/temporalio/samples-server/tree/main/compose
- Temporal Server releases: https://github.com/temporalio/temporal/releases
- Temporal Web UI: https://github.com/temporalio/ui
- SDKs: https://docs.temporal.io/develop

### Implementation Details

| Service | Image | Role | Public |
|---|---|---|---|
| `temporal` | `temporalio/server:1.32.1` + schema tools | gRPC frontend `:7233`, history, matching, worker | Private (TCP proxy optional) |
| `temporal-ui-gateway` | `caddy:2.11.7-alpine` + config | Basic-auth entry point for the UI | HTTPS domain |
| `temporal-ui` | `temporalio/ui:2.55.0` | Web UI | Private |
| `temporal-namespace` | `temporalio/admin-tools:1.32.1` | One-shot: creates namespace `default` | — |
| `Postgres` | Railway Postgres | `temporal` and `temporal_visibility` databases | — |

**First login.** Open the `temporal-ui-gateway` domain and sign in with `BASIC_AUTH_USERNAME` (default `admin`) and the generated `BASIC_AUTH_PASSWORD` from that service's Variables tab.

**Connect your workers.** Deploy your worker service in the same Railway project and set `TEMPORAL_ADDRESS=${{temporal.TEMPORAL_ADDRESS}}` (resolves to `temporal.railway.internal:7233`) and `TEMPORAL_NAMESPACE=default`. To reach the server from outside Railway, add a TCP proxy on port 7233 to the `temporal` service — only together with mTLS, because the frontend has no authentication by default.

**Scaling.** Scale your worker services horizontally. Give `temporal` and `Postgres` more resources as throughput grows. The history shard count (512) is fixed at first start.

**Pinning and upgrades.** Server and admin-tools tags live in `services/temporal/Dockerfile`. Upgrade one minor version at a time; the pre-deploy step applies schema changes before the new server starts.

### Why Deploy Temporal on Railway?

Railway runs the Temporal Server, its database, the UI and your workers side by side on a private network, so workflows and workers talk without public exposure. You get managed volumes, deploy previews and per-service scaling without operating Kubernetes.
