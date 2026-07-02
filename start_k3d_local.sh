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

# ── 1. Ensure PostgreSQL listens on all interfaces ────────────────────────────
# k3d pods reach the host via host.k3d.internal, which resolves to the Docker
# bridge IP — not 127.0.0.1. Postgres must listen on * (not just localhost).

PG_DATA=$(psql -U "$DB_USER" -t -A -c "SHOW data_directory;" 2>/dev/null | tr -d ' ')
if [ -z "$PG_DATA" ]; then
  echo "ERROR: Cannot connect to PostgreSQL as user $DB_USER"
  exit 1
fi

LISTEN=$(psql -U "$DB_USER" -t -A -c "SHOW listen_addresses;" | tr -d ' ')
if [[ "$LISTEN" != "*" ]]; then
  echo "Updating PostgreSQL to listen on all interfaces..."

  if grep -q "^listen_addresses" "$PG_DATA/postgresql.conf"; then
    sed -i '' "s/^listen_addresses = .*/listen_addresses = '*'/" "$PG_DATA/postgresql.conf"
  else
    sed -i '' "s/^#listen_addresses = .*/listen_addresses = '*'/" "$PG_DATA/postgresql.conf"
  fi

  # Allow password-less connections from Docker bridge networks
  if ! grep -q "0.0.0.0/0.*trust" "$PG_DATA/pg_hba.conf"; then
    echo "host    all    all    0.0.0.0/0    trust" >> "$PG_DATA/pg_hba.conf"
  fi

  # Restart to apply
  PG_MAJOR=$(psql -U "$DB_USER" -t -A -c "SHOW server_version_num;" | cut -c1-2)
  brew services restart "postgresql@$PG_MAJOR" 2>/dev/null || \
    brew services restart postgresql 2>/dev/null
  echo "Waiting for PostgreSQL to restart..."
  sleep 5
fi

# ── 2. Create the supertokens database if it doesn't exist ────────────────────
psql -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || true

# ── 3. Create (or update) the k8s secret with individual params ───────────────
# Individual params avoid SuperTokens v9.x URI port-parsing bug.
kubectl create secret generic "$SECRET_NAME" \
  --from-literal=POSTGRESQL_HOST="$DB_HOST" \
  --from-literal=POSTGRESQL_PORT="$DB_PORT" \
  --from-literal=POSTGRESQL_USER="$DB_USER" \
  --from-literal=POSTGRESQL_PASSWORD="" \
  --from-literal=POSTGRESQL_DATABASE_NAME="$DB_NAME" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# ── 4. Deploy ─────────────────────────────────────────────────────────────────
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
