# supertokens — Project Context

## Overview
Self-hosted SuperTokens Core running on Kubernetes (Helm). Provides authentication primitives (sessions, users, recipes) to all backend services via the SuperTokens SDK. Services never call it directly from the frontend.

## Architecture

```
Backend SDK (supertokens-node / supertokens-python / etc.)
    |
    | HTTP  connectionURI: http://supertokens:3567
    v
SuperTokens Core  (Helm: supertokens/supertokens-postgresql)
    |
    | JDBC
    v
PostgreSQL >= 13.0  (RDS — shared with other services per namespace)
```

## Key Facts
- **Default port:** 3567
- **Database:** PostgreSQL only (MySQL/MongoDB dropped in v11)
- **Tables:** auto-created on first run if DB user has CREATE TABLE permission
- **API key:** optional; not set by default — add via `API_KEYS` env var
- **Image:** `supertokens/supertokens-postgresql`
- **Helm chart:** `supertokens/supertokens` (from supertokens Helm repo)

## Environments & Namespaces

| Environment | Namespace | RDS Host |
|-------------|-----------|----------|
| UAT | jupiter, venus, saturn, mars, mercury | prosperix-uat-17 |
| Sandbox | default | prosperix-uat-17 |
| Prod | default | prosperix-prod-17 |

## Configuration

Primary config via environment variables (prefer `POSTGRESQL_CONNECTION_URI` over individual vars):

```yaml
# helm/values/base.yaml
env:
  POSTGRESQL_CONNECTION_URI: "postgresql://<user>:<pass>@<host>:5432/<db>"
  API_KEYS: ""   # leave empty unless you need to lock down the core
```

Secrets (DB credentials) live in K8s secrets: `uat-env`, `sandbox-env`, `prod-env` — same pattern as service-bus.

## File Structure

```
supertokens/
├── helm/
│   └── values/
│       ├── base.yaml        # shared defaults
│       ├── uat.yaml         # UAT overrides
│       ├── sandbox.yaml
│       └── prod.yaml
└── .github/workflows/
    ├── deploy_uat.yml
    └── deploy_production.yml
```

## Common Tasks

### Deploy to a namespace
```bash
helm upgrade --install supertokens supertokens/supertokens \
  -f helm/values/base.yaml \
  -f helm/values/uat.yaml \
  -n jupiter
```

### Health check
```bash
kubectl exec -n jupiter deploy/supertokens -- curl localhost:3567/hello
```

### Add enterprise license
```bash
kubectl exec -n jupiter deploy/supertokens -- \
  curl -X PUT localhost:3567/ee/license \
  -H "Content-Type: application/json" \
  -d '{"licenseKey": "<key>"}'
```

### Troubleshooting
```bash
# Check core logs
kubectl logs -n jupiter deploy/supertokens

# Verify DB connectivity (should return table rows)
kubectl exec -n jupiter deploy/supertokens -- \
  curl localhost:3567/recipe/jwt/jwks
```
