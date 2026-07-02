#!/bin/bash
# Deploy SuperTokens to local k3d cluster, connecting to the host machine's
# PostgreSQL via host.k3d.internal.
#
# One-time postgres setup (run once if supertokens can't reach the host DB):
#   1. In /opt/homebrew/var/postgresql@14/postgresql.conf:
#        listen_addresses = '*'
#   2. In /opt/homebrew/var/postgresql@14/pg_hba.conf (append):
#        host    all    all    0.0.0.0/0    trust
#   3. brew services restart postgresql@14
set -e

NAMESPACE=default
DB_USER=surat
DB_HOST=host.k3d.internal
DB_PORT=5432
DB_NAME=supertokens
SECRET_NAME=supertokens-db
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 1. Create the database if it doesn't exist ───────────────────────────────
CONNECT_DB=$(psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" &>/dev/null && echo "$DB_NAME" || echo "postgres")
if ! psql -U "$DB_USER" -d "$CONNECT_DB" -lqt | cut -d'|' -f1 | grep -qw "$DB_NAME"; then
  echo "Creating database '$DB_NAME'..."
  psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;"
else
  echo "Database '$DB_NAME' already exists."
fi

# ── 2. Create (or update) the k8s secret ─────────────────────────────────────
kubectl create secret generic "$SECRET_NAME" \
  --from-literal=POSTGRESQL_HOST="$DB_HOST" \
  --from-literal=POSTGRESQL_PORT="$DB_PORT" \
  --from-literal=POSTGRESQL_USER="$DB_USER" \
  --from-literal=POSTGRESQL_PASSWORD="" \
  --from-literal=POSTGRESQL_DATABASE_NAME="$DB_NAME" \
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
