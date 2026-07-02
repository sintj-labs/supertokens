#!/bin/bash
# Deploy SuperTokens to local k3d cluster using the host machine's PostgreSQL.
# Assumes PostgreSQL is installed via Homebrew with user=surat and no password.
set -e

NAMESPACE=default
DB_USER=surat
DB_HOST=host.k3d.internal
DB_PORT=5432
DB_NAME=supertokens
SECRET_NAME=supertokens-db

# ── 1. Find Homebrew PostgreSQL ───────────────────────────────────────────────
BREW_PREFIX=$(brew --prefix)

PG_SERVICE=$(ls "$BREW_PREFIX/opt/" | grep -E "^postgresql(@[0-9]+)?$" | sort -V | tail -1)
if [ -z "$PG_SERVICE" ]; then
  echo "ERROR: No PostgreSQL found in $BREW_PREFIX/opt/. Install with: brew install postgresql"
  exit 1
fi

PG_VERSION=$(echo "$PG_SERVICE" | grep -oE '[0-9]+' || true)
if [ -n "$PG_VERSION" ]; then
  PG_DATA="$BREW_PREFIX/var/postgresql@$PG_VERSION"
else
  PG_DATA="$BREW_PREFIX/var/postgresql"
fi

echo "Found $PG_SERVICE (data: $PG_DATA)"

# ── 2. Start PostgreSQL if not running ────────────────────────────────────────
if ! brew services list | grep -qE "^$PG_SERVICE\s+started"; then
  echo "Starting $PG_SERVICE..."
  brew services start "$PG_SERVICE"
  sleep 4
fi

# ── 3. Configure PostgreSQL to accept connections from Docker (k3d) ───────────
# k3d pods reach the host via host.k3d.internal (Docker bridge IP), not 127.0.0.1.
# Only patches and restarts if not already configured.
CHANGED=false

if ! grep -qF "listen_addresses = '*'" "$PG_DATA/postgresql.conf"; then
  echo "Setting listen_addresses = '*' in postgresql.conf..."
  sed -i '' "s/^#\?listen_addresses = .*/listen_addresses = '*'/" "$PG_DATA/postgresql.conf"
  CHANGED=true
fi

if ! grep -qF "0.0.0.0/0" "$PG_DATA/pg_hba.conf"; then
  echo "Adding trust rule for Docker networks in pg_hba.conf..."
  echo "host    all    all    0.0.0.0/0    trust" >> "$PG_DATA/pg_hba.conf"
  CHANGED=true
fi

if [ "$CHANGED" = true ]; then
  echo "Restarting $PG_SERVICE to apply config changes..."
  brew services restart "$PG_SERVICE"
  sleep 5
fi

# ── 4. Create the supertokens database if it doesn't exist ────────────────────
psql -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || true

# ── 5. Create (or update) the k8s secret ─────────────────────────────────────
kubectl create secret generic "$SECRET_NAME" \
  --from-literal=POSTGRESQL_HOST="$DB_HOST" \
  --from-literal=POSTGRESQL_PORT="$DB_PORT" \
  --from-literal=POSTGRESQL_USER="$DB_USER" \
  --from-literal=POSTGRESQL_PASSWORD="" \
  --from-literal=POSTGRESQL_DATABASE_NAME="$DB_NAME" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# ── 6. Deploy ─────────────────────────────────────────────────────────────────
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
