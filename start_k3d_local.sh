#!/bin/bash
# Deploy SuperTokens + a dedicated PostgreSQL pod to the local k3d cluster.
# Does not touch the host machine's PostgreSQL.
set -e

NAMESPACE=default
SECRET_NAME=supertokens-db
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 1. Deploy PostgreSQL inside k3d ──────────────────────────────────────────
kubectl apply -n "$NAMESPACE" -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: supertokens-postgres
spec:
  selector:
    app: supertokens-postgres
  ports:
    - port: 5432
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: supertokens-postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: supertokens-postgres
  template:
    metadata:
      labels:
        app: supertokens-postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15
          env:
            - name: POSTGRES_USER
              value: supertokens
            - name: POSTGRES_PASSWORD
              value: supertokens
            - name: POSTGRES_DB
              value: supertokens
          ports:
            - containerPort: 5432
          readinessProbe:
            exec:
              command: ["pg_isready", "-U", "supertokens"]
            initialDelaySeconds: 5
            periodSeconds: 5
EOF

echo "Waiting for postgres to be ready..."
kubectl rollout status deployment/supertokens-postgres -n "$NAMESPACE"

# ── 2. Create (or update) the k8s secret ─────────────────────────────────────
kubectl create secret generic "$SECRET_NAME" \
  --from-literal=POSTGRESQL_HOST="supertokens-postgres" \
  --from-literal=POSTGRESQL_PORT="5432" \
  --from-literal=POSTGRESQL_USER="supertokens" \
  --from-literal=POSTGRESQL_PASSWORD="supertokens" \
  --from-literal=POSTGRESQL_DATABASE_NAME="supertokens" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# ── 3. Deploy SuperTokens ─────────────────────────────────────────────────────
helm upgrade --install supertokens "$SCRIPT_DIR/helm" \
  -f "$SCRIPT_DIR/helm/values/base.yaml" \
  --set db.useUri=false \
  -n "$NAMESPACE"

echo "Waiting for supertokens to be ready..."
kubectl rollout status deployment/supertokens -n "$NAMESPACE"

echo ""
echo "SuperTokens is running. Verify with:"
echo "  kubectl exec -n $NAMESPACE deploy/supertokens -- curl -s localhost:3567/hello"
