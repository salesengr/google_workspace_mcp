# Release Notes: `salesengr/google-workspace-mcp:v1.12.0-r1`

**Release date:** 2026-02-20  
**Image:** `salesengr/google-workspace-mcp`

## Published tags
- `v1.12.0-r1` (immutable release tag)
- `upstream-v1.12.0` (upstream tracking alias)
- `sha-<build-sha>` (build traceability)

> `latest` is intentionally **not** auto-published unless explicitly requested.

---

## Highlights
- New upstream-aligned Docker publishing model.
- Standardized image naming to `salesengr/google-workspace-mcp`.
- Multi-arch builds published for `linux/amd64` and `linux/arm64`.
- Secret scan gate added to CI before publish.
- Panel-first setup docs for Docker Desktop MCP server configuration.

---

## CI/CD updates
The Docker publish workflow now uses manual release inputs:
- `upstream_tag` (example: `v1.12.0`)
- `packaging_rev` (example: `1`)
- `publish_latest` (`true` / `false`)

Tagging policy:
- Immutable: `vX.Y.Z-rN`
- Upstream alias: `upstream-vX.Y.Z`
- Trace tag: `sha-<shortsha>`
- Optional promotion: `latest`

Reference: `docs/DOCKER_RELEASE_TAGGING.md`

---

## Security posture
- No hardcoded secrets in image defaults.
- OAuth 2.1 is the recommended mode (`MCP_ENABLE_OAUTH21=true`).
- Secure transport default is enforced in templates (`OAUTHLIB_INSECURE_TRANSPORT=0`).
- Release pipeline includes hardcoded secret scanning.

---

## User setup docs
- Docker Desktop panel setup: `docs/DOCKER_DESKTOP_MCP_PANEL_SETUP.md`
- Environment template: `.env.sample`
- Tagging/release policy: `docs/DOCKER_RELEASE_TAGGING.md`

---

## Upgrade guidance
For next release:
1. Select upstream release tag (e.g., `v1.12.1`).
2. Run publish workflow with `packaging_rev=1`.
3. Validate startup + OAuth flow.
4. Optionally promote to `latest`.
