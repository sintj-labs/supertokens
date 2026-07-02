# supertokens — Project Context

## Overview
Self-hosted SuperTokens Core on Kubernetes (Helm). Provides auth primitives (sessions, users, recipes) to backend services via the SuperTokens SDK. Never called from the frontend.

## Architecture

```
Backend SDK (supertokens-node / supertokens-python)
    |
    | HTTP  connectionURI: http://supertokens:3567
    v
SuperTokens Core  (supertokens/supertokens-postgresql)
    |
    | JDBC
    v
PostgreSQL >= 13.0  (RDS — shared per namespace)
```

## Key Facts
- **Port:** 3567
- **Database:** PostgreSQL only (13.0+)
- **Tables:** auto-created on first run if DB user has CREATE TABLE permission
- **Image:** `supertokens/supertokens-postgresql`
- **API key:** disabled by default; enable via `API_KEYS` env var
- **In-memory mode:** `docker run -p 3567:3567 supertokens/supertokens-postgresql:latest` — no Postgres needed, for testing only

## File Structure

```
supertokens/
├── docker-compose.yaml     # local dev with Postgres
├── helm/
│   ├── Chart.yaml
│   ├── deploy.sh           # ./deploy.sh <env> <namespace>
│   ├── templates/
│   │   ├── _helpers.tpl
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── values/
│       ├── base.yaml       # image, resources, probe defaults
│       ├── local.yaml      # k3d local — in-memory mode, no Postgres
│       ├── uat.yaml        # uat-env secret, tableNamesPrefix: uat
│       ├── sandbox.yaml    # sandbox-env secret
│       └── prod.yaml       # 2 replicas, prod-env secret, higher resources
```

## Secrets Convention
DB connection URI comes from K8s secrets (same pattern as service-bus):
- `uat-env` → key `SUPERTOKENS_DB_URI`
- `sandbox-env` → key `SUPERTOKENS_DB_URI`
- `prod-env` → key `SUPERTOKENS_DB_URI`

## Common Tasks

### Local dev (Docker Compose)
```bash
docker compose up                    # SuperTokens + Postgres
curl http://localhost:3567/hello     # → OK
```

### Local k3d (in-memory mode — no Postgres required)
```bash
cd helm
helm upgrade --install supertokens ./ -f ./values/base.yaml -f ./values/local.yaml -n default
kubectl exec deploy/supertokens -- curl -s localhost:3567/hello   # → OK
```

### Deploy to Kubernetes
```bash
./helm/deploy.sh uat default
./helm/deploy.sh prod default
```

### Health check in cluster
```bash
kubectl exec -n <ns> deploy/supertokens -- curl localhost:3567/hello
```

### Add enterprise license
```bash
kubectl exec -n <ns> deploy/supertokens -- \
  curl -X PUT localhost:3567/ee/license \
  -H "Content-Type: application/json" \
  -d '{"licenseKey": "<key>"}'
```

### Troubleshooting
```bash
# Logs
kubectl logs -n <ns> deploy/supertokens

# Verify DB connectivity
kubectl exec -n <ns> deploy/supertokens -- \
  curl localhost:3567/recipe/jwt/jwks
```
