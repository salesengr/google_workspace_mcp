# Draft Release Notes - `salesengr/google-workspace-mcp:v1.12.0-r1`

## Summary
This release establishes a maintainable Docker publication model aligned to upstream Google Workspace MCP while preserving secure, panel-friendly configuration.

## Published image
- `salesengr/google-workspace-mcp:v1.12.0-r1`
- `salesengr/google-workspace-mcp:upstream-v1.12.0`
- `salesengr/google-workspace-mcp:sha-<build-sha>`

## What changed
- New release workflow with manual controls:
  - `upstream_tag`
  - `packaging_rev`
  - optional `publish_latest`
- Secret scanning gate before publish
- Multi-arch publish (`linux/amd64`, `linux/arm64`)
- Standardized tagging policy
- Added panel-first setup docs and updated `.env.sample`

## Security posture
- No hardcoded secrets in image defaults
- OAuth 2.1 recommended (`MCP_ENABLE_OAUTH21=true`)
- Secure transport default (`OAUTHLIB_INSECURE_TRANSPORT=0`)

## User setup references
- `docs/DOCKER_DESKTOP_MCP_PANEL_SETUP.md`
- `.env.sample`
- `docs/DOCKER_RELEASE_TAGGING.md`

## Known notes
- `latest` is intentionally not auto-published unless explicitly requested.

## Next release process
1. Pick upstream tag (ex: `v1.12.1`)
2. Run workflow with `packaging_rev=1`
3. Validate smoke test + OAuth flow
4. Optionally promote to `latest`
