#!/usr/bin/env bash
# Creates random DB credentials directly in the cluster (nothing stored in git).
set -euo pipefail

ROOT_PW=$(openssl rand -hex 16)
APP_PW=$(openssl rand -hex 16)

kubectl -n mydb create secret generic mysql-credentials \
  --from-literal=MYSQL_ROOT_PASSWORD="$ROOT_PW" \
  --from-literal=MYSQL_DATABASE=appdb \
  --from-literal=MYSQL_USER=appuser \
  --from-literal=MYSQL_PASSWORD="$APP_PW" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n myapp create secret generic app-db-credentials \
  --from-literal=DB_USER=appuser \
  --from-literal=DB_PASSWORD="$APP_PW" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secrets created in namespaces mydb and myapp."
