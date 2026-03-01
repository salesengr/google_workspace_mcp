# Docker Release Tagging and Publish Policy

## Canonical image
- `salesengr/google-workspace-mcp`

## Tags produced by workflow
For input `upstream_tag=vX.Y.Z` and `packaging_rev=N`, workflow pushes:
- `salesengr/google-workspace-mcp:vX.Y.Z-rN` (immutable release)
- `salesengr/google-workspace-mcp:upstream-vX.Y.Z` (moving upstream alias)
- `salesengr/google-workspace-mcp:sha-<shortsha>` (traceability)
- `salesengr/google-workspace-mcp:latest` (optional, only when enabled)

## Policy
- Keep image public when no hardcoded secrets are found.
- Publish is blocked if secret scan finds leaks.
- If sensitive material is discovered, remediate before release.

## Usage
Run workflow dispatch with:
- `upstream_tag`: upstream release tag (e.g., `v1.12.0`)
- `packaging_rev`: integer revision for packaging updates (`1`, `2`, ...)
- `publish_latest`: true/false

## Recommended update flow
1. Run `bash scripts/update_from_upstream_and_build.sh` to:
   - fetch `origin` + `upstream`
   - create a fresh sync branch from `upstream/main`
   - re-apply gateway overlay files from `origin/main`
2. (Optional) run local build checks with:
   - `RUN_BUILD=1 RUN_COMPOSE_BUILD=1 bash scripts/update_from_upstream_and_build.sh`
3. Open a PR from the sync branch into `main`.
4. After merge, dispatch Docker publish workflow with the new upstream tag/revision.

## Revision rules
- New upstream version -> reset packaging revision to `1`
- Packaging-only changes on same upstream -> increment revision (`r2`, `r3`, ...)
- Do not overwrite immutable tags
