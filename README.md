# supertokens

Self-hosted [SuperTokens](https://supertokens.com) authentication core deployed on Kubernetes via Helm.

SuperTokens Core is the stateless auth API service. It manages session tokens, user records, and auth recipes (email/password, passwordless, OAuth2, etc.) and is called by backend SDKs — never directly by clients.

---

## Architecture

```
┌────────────────────────────────────────────────┐
│                  Per Namespace                  │
│                                                 │
│  Backend Services                               │
│       │  (supertokens SDK)                      │
│       ▼                                         │
│  ┌──────────────────┐                           │
│  │  SuperTokens     │  :3567                    │
│  │  Core (Helm)     │◄──── API key (optional)   │
│  └────────┬─────────┘                           │
│           │                                     │
│           ▼                                     │
│  ┌──────────────────┐                           │
│  │  PostgreSQL      │  (external RDS)           │
│  │  >= 13.0         │                           │
│  └──────────────────┘                           │
└────────────────────────────────────────────────┘
```

## Prerequisites

- Kubernetes cluster (k3d for local)
- Helm 3
- PostgreSQL 13.0+ (RDS or in-cluster)
- `kubectl` configured for target namespace

## Deployment

### Helm install

```bash
helm repo add supertokens https://supertokens.github.io/supertokens-docker-postgresql/helm-chart
helm repo update

helm upgrade --install supertokens supertokens/supertokens \
  -f helm/values/base.yaml \
  -f helm/values/<env>.yaml \
  -n <namespace>
```

### Key environment variables

| Variable | Description |
|----------|-------------|
| `POSTGRESQL_CONNECTION_URI` | Full Postgres URI (preferred) |
| `POSTGRESQL_USER` | DB username |
| `POSTGRESQL_PASSWORD` | DB password |
| `POSTGRESQL_HOST` | DB host |
| `POSTGRESQL_PORT` | DB port (default 5432) |
| `POSTGRESQL_DATABASE_NAME` | Database name |
| `POSTGRESQL_TABLE_NAMES_PREFIX` | Optional table prefix for multi-tenant setups |
| `API_KEYS` | Comma-separated API keys (none by default) |

### Health check

```bash
curl http://<supertokens-host>:3567/hello
# returns: OK
```

## Connecting Backend SDKs

```typescript
import SuperTokens from "supertokens-node";

SuperTokens.init({
  supertokens: {
    connectionURI: "http://supertokens:3567",
    apiKey: "<optional>",
  },
  appInfo: { ... },
  recipeList: [ ... ],
});
```

> Use the Kubernetes service name (`supertokens`) as the host, not `localhost`.

## Environments

| Environment | Namespace | PostgreSQL Host |
|-------------|-----------|-----------------|
| UAT         | jupiter   | prosperix-uat-17 |
| Sandbox     | default   | prosperix-uat-17 |
| Prod        | default   | prosperix-prod-17 |

## Enterprise License

Add a license key via the API after deployment:

```bash
curl -X PUT http://<host>:3567/ee/license \
  -H "Content-Type: application/json" \
  -d '{"licenseKey": "<key>"}'
```
