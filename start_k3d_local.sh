#!/bin/bash
# Deploy SuperTokens to local k3d cluster using the host machine's PostgreSQL.
# Assumes postgres is running locally with user=surat and no password.
set -e

NAMESPACE=default
DB_USER=surat
DB_HOST=host.k3d.internal
DB_PORT=5432
DB_NAME=supertokens
SECRET_NAME=supertokens-db

# Create the supertokens database if it doesn't exist
psql -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || true

# Create (or update) the k8s secret with individual params
# Individual params avoid SuperTokens URI port-parsing bug in v9.x
kubectl create secret generic "$SECRET_NAME" \
  --from-literal=POSTGRESQL_HOST="$DB_HOST" \
  --from-literal=POSTGRESQL_PORT="$DB_PORT" \
  --from-literal=POSTGRESQL_USER="$DB_USER" \
  --from-literal=POSTGRESQL_PASSWORD="" \
  --from-literal=POSTGRESQL_DATABASE_NAME="$DB_NAME" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy with individual params mode (db.useUri=false)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
helm upgrade --install supertokens "$SCRIPT_DIR/helm" \
  -f "$SCRIPT_DIR/helm/values/base.yaml" \
  --set db.useUri=false \
  -n "$NAMESPACE"

echo "Waiting for supertokens to be ready..."
kubectl rollout status deployment/supertokens -n "$NAMESPACE"

echo ""
echo "SuperTokens is running. Verify with:"
echo "  kubectl exec -n $NAMESPACE deploy/supertokens -- curl -s localhost:3567/hello"
