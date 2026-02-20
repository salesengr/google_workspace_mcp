# Executive Summary: Google Workspace MCP Docker Release (`v1.12.0-r1`)

## Decision outcome
We have moved to a maintainable Docker release model that stays aligned with upstream while preserving enterprise-friendly controls.

## What shipped
- Canonical image: `salesengr/google-workspace-mcp`
- First standardized release: `v1.12.0-r1`
- Upstream alignment tag: `upstream-v1.12.0`
- Multi-architecture support (`amd64`, `arm64`)

## Why this matters
- **Lower maintenance risk:** release process tied to upstream versions
- **Better governance:** immutable tags + controlled `latest` promotion
- **Security improvements:** pre-publish secret scanning and secure OAuth defaults
- **Better adoption:** Docker Desktop panel-first setup for easier onboarding

## Security position
- No hardcoded credentials in released defaults
- OAuth 2.1 preferred configuration enabled in templates
- Insecure OAuth transport disabled by default

## Operating model going forward
- Track upstream tags regularly
- Publish immutable `vX.Y.Z-rN` releases
- Promote `latest` only after validation
- Keep setup docs and env templates current with each release

## Current ask
Approve this release process as the team standard for Docker-based Google Workspace MCP distribution.
