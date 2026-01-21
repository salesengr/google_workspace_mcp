# Docker Gateway Setup Guide

This guide explains how to run Google Workspace MCP with Docker Gateway's built-in OAuth support.

## Prerequisites

- Docker Desktop with MCP Toolkit enabled
- `docker mcp` CLI available (comes with Docker Desktop MCP Toolkit)
- **No Google OAuth credentials needed!** Docker Gateway provides them.

## What You DON'T Need

When using Docker Gateway mode, you **do NOT need**:
- ❌ Google OAuth Client ID
- ❌ Google OAuth Client Secret
- ❌ `.env` file
- ❌ `client_secret.json` file

Docker Gateway handles all OAuth configuration using its built-in `gdrive` provider.

## Quick Start

### Option 1: Automated Setup (Recommended)

Run the test script which handles everything:

```bash
./scripts/test-docker-mcp-oauth.sh
```

Then follow the on-screen instructions to authorize and enable the server.

### Option 2: Manual Setup

```bash
# 1. Build the Docker image
docker-compose -f docker-compose.gateway.yml build

# 2. Start the local server
docker-compose -f docker-compose.gateway.yml up -d

# 3. Wait for server to be healthy (check with curl)
curl http://localhost:8000/health

# 4. Import the MCP catalog
docker mcp catalog import ./workspace-mcp-local-catalog.yaml

# 5. Authorize OAuth (opens browser for Google login)
docker mcp oauth authorize google-workspace

# 6. Enable the server
docker mcp server enable google-workspace

# 7. Verify tools are available
docker mcp tools ls google-workspace
```

## How It Works

1. **Docker Gateway's OAuth Provider**: The [workspace-mcp-local-catalog.yaml](workspace-mcp-local-catalog.yaml) file configures Docker Gateway to use its built-in `gdrive` OAuth provider.

2. **Token Injection**: When Docker Gateway spawns the container, it automatically injects the `GOOGLE_ACCESS_TOKEN` environment variable with a valid access token.

3. **Gateway Mode Detection**: The MCP server detects `DOCKER_MCP_GATEWAY_MODE=true` and uses `get_credentials_from_gateway()` instead of the normal OAuth flow.

4. **Automatic Refresh**: Docker Gateway handles token refresh automatically - the server doesn't need to manage refresh tokens.

## Testing the Integration

```bash
# Search Gmail
docker mcp tools call google-workspace search_gmail_messages '{"query": "is:inbox", "max_results": 5}'

# List calendars
docker mcp tools call google-workspace list_calendars '{}'

# Search Drive files
docker mcp tools call google-workspace search_drive_files '{"query": "type:document", "max_results": 10}'
```

## Troubleshooting

### Server won't start
```bash
# Check logs
docker-compose -f docker-compose.gateway.yml logs

# Check health endpoint
curl http://localhost:8000/health
```

### OAuth authorization fails
```bash
# Check OAuth status
docker mcp oauth ls

# Re-authorize
docker mcp oauth authorize google-workspace
```

### Tools not discovered
```bash
# Check server status
docker mcp server ls

# Ensure server is enabled
docker mcp server enable google-workspace
```

## Cleanup

```bash
# Stop the local server
docker-compose -f docker-compose.gateway.yml down

# Disable the server in Docker MCP
docker mcp server disable google-workspace

# Remove the catalog (optional)
docker mcp catalog remove workspace-mcp-local
```

## Architecture

```
┌─────────────────────┐
│  Docker Gateway     │
│  - Manages OAuth    │
│  - Injects tokens   │
└──────────┬──────────┘
           │ GOOGLE_ACCESS_TOKEN
           ▼
┌─────────────────────┐
│  MCP Server         │
│  (This container)   │
│  - Uses injected    │
│    token            │
│  - No OAuth flow    │
└─────────────────────┘
```

## Environment Variables (All Handled Automatically)

The following are set in [Dockerfile.gateway](Dockerfile.gateway) and [docker-compose.gateway.yml](docker-compose.gateway.yml):

- `DOCKER_MCP_GATEWAY_MODE=true` - Enables gateway mode
- `GOOGLE_ACCESS_TOKEN` - Injected by Docker Gateway at runtime
- `GOOGLE_OAUTH_CLIENT_ID=gateway-mode-not-used` - Dummy value (not used)
- `GOOGLE_OAUTH_CLIENT_SECRET=gateway-mode-not-used` - Dummy value (not used)
- `MCP_SINGLE_USER_MODE=1` - Simplified auth for gateway mode
- `OAUTHLIB_INSECURE_TRANSPORT=1` - Required for local testing

## Related Files

- [Dockerfile.gateway](Dockerfile.gateway) - Docker image for gateway mode
- [docker-compose.gateway.yml](docker-compose.gateway.yml) - Compose configuration
- [workspace-mcp-local-catalog.yaml](workspace-mcp-local-catalog.yaml) - MCP catalog entry
- [scripts/test-docker-mcp-oauth.sh](scripts/test-docker-mcp-oauth.sh) - Automated test script
- [auth/google_auth.py](auth/google_auth.py) - Gateway mode implementation
