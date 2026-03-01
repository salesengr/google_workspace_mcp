#!/usr/bin/env bash
set -euo pipefail

# Update fork from upstream/main with gateway overlay files,
# then optionally build/test Docker gateway artifacts.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
ORIGIN_REMOTE="${ORIGIN_REMOTE:-origin}"
BASE_REF="${BASE_REF:-upstream/main}"
BRANCH_NAME="${BRANCH_NAME:-sync/upstream-gateway-overlay-$(date +%Y%m%d-%H%M)}"
PUSH_BRANCH="${PUSH_BRANCH:-1}"
RUN_BUILD="${RUN_BUILD:-0}"
RUN_COMPOSE_BUILD="${RUN_COMPOSE_BUILD:-0}"
RUN_SMOKE_TEST="${RUN_SMOKE_TEST:-0}"

OVERLAY_FILES=(
  ".env.sample"
  "DOCKER_MCP_SETUP.md"
  "Dockerfile.gateway"
  "docker-compose.gateway.yml"
  "docs/DOCKER_DESKTOP_MCP_PANEL_SETUP.md"
  "docs/DOCKER_RELEASE_TAGGING.md"
  "scripts/test-docker-mcp-oauth.sh"
  "workspace-mcp-local-catalog.yaml"
  ".github/workflows/docker-publish.yml"
)

echo "== Fetching remotes =="
git fetch "$ORIGIN_REMOTE" --prune --tags
git fetch "$UPSTREAM_REMOTE" --prune --tags

echo "== Creating branch: $BRANCH_NAME from $BASE_REF =="
git checkout -B "$BRANCH_NAME" "$BASE_REF"

echo "== Reapplying overlay files from ${ORIGIN_REMOTE}/main =="
for file in "${OVERLAY_FILES[@]}"; do
  git checkout "${ORIGIN_REMOTE}/main" -- "$file"
done

chmod +x scripts/test-docker-mcp-oauth.sh || true

echo "== Git status =="
git status --short

echo "== Validating Python project metadata =="
python -m py_compile main.py >/dev/null 2>&1 || true

if [[ "$RUN_BUILD" == "1" ]]; then
  echo "== docker build (gateway) =="
  docker build -f Dockerfile.gateway -t workspace-mcp-gateway:latest .
fi

if [[ "$RUN_COMPOSE_BUILD" == "1" ]]; then
  echo "== docker compose build (gateway) =="
  docker compose -f docker-compose.gateway.yml build gateway
fi

if [[ "$RUN_SMOKE_TEST" == "1" ]]; then
  echo "== running gateway oauth smoke script =="
  bash scripts/test-docker-mcp-oauth.sh
fi

if [[ "$PUSH_BRANCH" == "1" ]]; then
  echo "== Pushing branch to $ORIGIN_REMOTE =="
  git push -u "$ORIGIN_REMOTE" "$BRANCH_NAME"
fi

echo "Done. Next: open a PR from $BRANCH_NAME into main."
