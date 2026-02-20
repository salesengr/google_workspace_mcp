# Docker Desktop MCP Panel Setup (Google Workspace MCP)

This guide shows the **panel-first setup** path so users can run `salesengr/google-workspace-mcp` without editing repo files.

## Image
- `salesengr/google-workspace-mcp`

## Recommended tag
- Start with immutable tag format: `vX.Y.Z-rN` (example: `v1.12.0-r1`)

---

## 1) Add server in Docker Desktop MCP
1. Open Docker Desktop -> MCP Toolkit / MCP Servers.
2. Add a new server using image:
   - `salesengr/google-workspace-mcp:v1.12.0-r1`
3. Transport/path should point to streamable HTTP MCP endpoint (`/mcp`) when prompted.

---

## 2) Set required config values in panel
Set these values in the server config panel fields:

### Required
- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET` (secret field)
- `GOOGLE_CLOUD_PROJECT`
- `GOOGLE_CLOUD_LOCATION=global`
- `PORT=8000`

### Security defaults
- `MCP_ENABLE_OAUTH21=true`
- `OAUTHLIB_INSECURE_TRANSPORT=0`

### Recommended for single-user desktop use
- `MCP_SINGLE_USER_MODE=1`
- Optional: `USER_GOOGLE_EMAIL=you@company.com`

### Optional runtime controls
- `TOOL_TIER=core` (or `extended`, `complete`)
- `TOOLS=gmail drive calendar` (optional service subset)

---

## 3) Start + authorize
1. Start/enable the server.
2. Trigger a tool call.
3. Complete Google OAuth in browser.
4. Retry the tool call.

---

## 4) Security notes
- Do **not** put secrets into image defaults.
- Keep `OAUTHLIB_INSECURE_TRANSPORT=0` unless temporarily testing local non-production callback behavior.
- Prefer OAuth 2.1 mode for long-term compatibility.

---

## 5) Troubleshooting
- Auth failure: re-check client ID/secret and GCP project API enablement.
- Startup failure: confirm required vars are set.
- Tool discovery issues: verify server points at `/mcp` endpoint and is healthy.
