# supertokens

Self-hosted [SuperTokens](https://supertokens.com) authentication core deployed on Kubernetes via Helm.

SuperTokens Core is the stateless auth API (port 3567) that manages session tokens, users, and auth recipes. Backend SDKs call it — never the frontend.

---

## Architecture

```
┌────────────────────────────────────────────────┐
│                  Per Namespace                  │
│                                                 │
│  Backend Services                               │
│       │  (supertokens-node / python SDK)        │
│       ▼                                         │
│  ┌──────────────────┐                           │
│  │  SuperTokens     │  :3567                    │
│  │  Core (Helm)     │                           │
│  └────────┬─────────┘                           │
│           │                                     │
│           ▼                                     │
│  ┌──────────────────┐                           │
│  │  PostgreSQL      │  (external RDS)           │
│  │  >= 13.0         │                           │
│  └──────────────────┘                           │
└────────────────────────────────────────────────┘
```

## Local Development

Run SuperTokens + PostgreSQL with Docker Compose (in-memory alternative also available):

```bash
# Full stack (SuperTokens + Postgres)
docker compose up

# Quick test — in-memory, no Postgres needed
docker run -p 3567:3567 -d supertokens/supertokens-postgresql:latest

# Health check
curl http://localhost:3567/hello   # → OK
```

## Kubernetes Deployment

```bash
./helm/deploy.sh <env> <namespace>

# Examples
./helm/deploy.sh uat default
./helm/deploy.sh prod default
```

Or manually:

```bash
helm upgrade --install supertokens ./helm \
  -f helm/values/base.yaml \
  -f helm/values/uat.yaml \
  -n default
```

## Key Environment Variables

| Variable | Description |
|----------|-------------|
| `POSTGRESQL_CONNECTION_URI` | Full Postgres URI (preferred over individual vars) |
| `POSTGRESQL_USER` | DB username |
| `POSTGRESQL_PASSWORD` | DB password |
| `POSTGRESQL_HOST` | DB host |
| `POSTGRESQL_PORT` | DB port (default 5432) |
| `POSTGRESQL_DATABASE_NAME` | Database name |
| `POSTGRESQL_TABLE_NAMES_PREFIX` | Optional prefix to namespace tables |
| `API_KEYS` | Comma-separated keys to lock down the core |
| `DISABLE_TELEMETRY` | Set `"true"` to disable usage stats |

## Connecting Backend SDKs

```typescript
SuperTokens.init({
  supertokens: {
    connectionURI: "http://supertokens:3567",  // use K8s service name
    apiKey: "<optional>",
  },
  ...
});
```

## File Structure

```
supertokens/
├── docker-compose.yaml        # local dev (SuperTokens + Postgres)
├── helm/
│   ├── Chart.yaml
│   ├── deploy.sh
│   ├── templates/
│   │   ├── _helpers.tpl
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── values/
│       ├── base.yaml          # shared defaults
│       ├── uat.yaml
│       ├── sandbox.yaml
│       └── prod.yaml
├── CLAUDE.md
└── README.md
```

## Enterprise License

```bash
curl -X PUT http://<host>:3567/ee/license \
  -H "Content-Type: application/json" \
  -d '{"licenseKey": "<key>"}'
```
