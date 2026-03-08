# Upstream Sync + Docker Gateway Overlay Runbook

This runbook is the canonical process for updating this repo from upstream and reapplying the SalesEngr Docker Gateway overlay safely.

---

## Scope

Use this when you need to:
- update from `upstream/main`
- reapply our Docker gateway-specific files
- verify Docker runtime availability
- build and smoke-test the gateway image
- merge to `dev` with minimal risk

---

## Prerequisites

- Local clone with both remotes configured:
  - `origin` = `salesengr/google_workspace_mcp`
  - `upstream` = `taylorwilsdon/google_workspace_mcp`
- Docker installed and running
- GitHub CLI (`gh`) authenticated (if opening/merging PRs)

Quick checks:

```bash
git remote -v
docker version
gh auth status
```

---

## 1) Start from a clean working tree

```bash
cd /path/to/google_workspace_mcp
git status --short
```

If dirty, either commit or stash before continuing.

---

## 2) Fetch latest refs and create fresh sync branch from upstream

```bash
git fetch --all --prune --tags
BRANCH="sync/upstream-gateway-overlay-$(date +%Y%m%d-%H%M)"
git checkout -B "$BRANCH" upstream/main
```

This avoids large conflict churn in long-lived local branches.

---

## 3) Reapply Docker gateway overlay

Preferred: use the helper script (maintained in this repo):

```bash
PUSH_BRANCH=0 RUN_BUILD=0 RUN_COMPOSE_BUILD=0 RUN_SMOKE_TEST=0 \
  BRANCH_NAME="$BRANCH" BASE_REF=upstream/main \
  bash scripts/update_from_upstream_and_build.sh
```

If needed, manually confirm overlay assets exist after reapply:

- `.env.sample`
- `Dockerfile.gateway`
- `docker-compose.gateway.yml`
- `workspace-mcp-local-catalog.yaml`
- `DOCKER_MCP_SETUP.md`
- `docs/DOCKER_DESKTOP_MCP_PANEL_SETUP.md`
- `docs/DOCKER_RELEASE_TAGGING.md`
- `scripts/update_from_upstream_and_build.sh`

---

## 4) Verify Docker daemon is running (required before build/test)

```bash
docker info >/dev/null && echo "Docker is running" || echo "Docker is NOT running"
```

If Docker is not running, start Docker Desktop/daemon first.

---

## 5) Build the gateway image

```bash
docker build -f Dockerfile.gateway -t workspace-mcp-gateway:sync-test .
```

Expected: build completes successfully and image is listed:

```bash
docker images | grep workspace-mcp-gateway
```

---

## 6) Smoke test the image (required gate)

Run container and verify `/health` returns HTTP 200.

```bash
docker rm -f gwmcp-smoke >/dev/null 2>&1 || true
docker run -d --name gwmcp-smoke -p 18000:8000 workspace-mcp-gateway:sync-test

# retry up to 20s for startup
for i in $(seq 1 20); do
  code=$(curl -s -o /tmp/gwmcp-health.out -w '%{http_code}' http://127.0.0.1:18000/health || true)
  echo "try $i -> $code"
  [ "$code" = "200" ] && break
  sleep 1
done

# optional: validate MCP route responds
curl -i http://127.0.0.1:18000/mcp || true

docker logs --tail 120 gwmcp-smoke || true
docker rm -f gwmcp-smoke >/dev/null 2>&1 || true
```

Pass criteria:
- container remains running
- `/health` returns `200`
- server logs show streamable HTTP server started on `:8000`

---

## 7) Commit and push sync branch

```bash
git add -A
git commit -m "chore(sync): upstream refresh + Docker gateway overlay + docs"
git push -u origin "$BRANCH"
```

---

## 8) Open PR to `dev` and merge strategy

Open PR:

```bash
gh pr create --base dev --head "$BRANCH" \
  --title "Sync upstream/main + reapply Docker gateway overlay" \
  --body "Includes upstream sync, gateway overlay reapply, docs update, and Docker smoke test."
```

### Merge policy

- Preferred: **Squash merge** to keep sync history concise.
- If GitHub reports PR is conflicting (DIRTY/CONFLICTING):
  1. Do **not** force-merge blindly.
  2. Resolve by regenerating a fresh sync branch from latest `upstream/main` + latest `origin/dev` context, then re-run build/smoke.
  3. Re-open PR.

---

## 9) Post-merge validation on `dev`

After merge, checkout `dev` and run one final gate:

```bash
git checkout dev
git pull --ff-only origin dev
docker build -f Dockerfile.gateway -t workspace-mcp-gateway:dev-check .
# repeat smoke test on :18000 /health
```

Only after this should `dev -> main` promotion be considered.

---

## Troubleshooting

### `curl: (52) Empty reply from server`
- Confirm container is still running: `docker ps`
- Check logs: `docker logs <container>`
- Retry health with startup delay (service warm-up)
- Verify host-port mapping (`-p 18000:8000`)

### PR not mergeable (conflicts)
- Typical with large upstream drift.
- Recreate a fresh sync branch and reapply overlay rather than forcing conflict-heavy merges on stale branches.

### Docker not running
- Build/smoke results are invalid until daemon is up.
- Validate with `docker info` before test runs.

---

## Operational Notes

- Keep overlay changes minimal and documented.
- Treat `upstream/main` as source of truth.
- Use this runbook for every upstream refresh cycle.
