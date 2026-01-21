# Docker MCP Gateway Integration

This document describes how to use Google Workspace MCP with Docker MCP Gateway's native OAuth support.

## Overview

Docker MCP Gateway provides a centralized way to manage MCP servers with built-in OAuth handling. This integration allows Google Workspace MCP to run as a remote HTTP server that receives OAuth tokens from the gateway.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOCAL TESTING ARCHITECTURE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────┐         ┌──────────────────────────┐  │
│  │  docker mcp oauth   │         │  workspace-mcp           │  │
│  │  authorize          │         │  localhost:8000          │  │
│  │                     │         │                          │  │
│  │  Opens browser →    │         │  Receives OAuth token    │  │
│  │  Google consent     │         │  via env var or header   │  │
│  └─────────────────────┘         └──────────────────────────┘  │
│            │                                   ▲                │
│            │                                   │                │
│            └──────── Docker Gateway ───────────┘                │
│                      injects token                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Files Created/Modified

| File | Action | Purpose |
|------|--------|---------|
| `Dockerfile.gateway` | Created | HTTP server for Docker MCP Gateway |
| `auth/google_auth.py` | Modified | Added gateway mode with `is_gateway_mode()` and `get_credentials_from_gateway()` |
| `docker-compose.gateway.yml` | Modified | Added gateway service profile |
| `workspace-mcp-local-catalog.yaml` | Created | Docker MCP catalog entry |
| `scripts/test-docker-mcp-oauth.sh` | Created | Test automation script |

## Key Features

### Gateway Mode Detection

Located in `auth/google_auth.py:74-105`:

```python
def is_gateway_mode() -> bool:
    """Check if running under Docker MCP Gateway."""
    return os.environ.get("DOCKER_MCP_GATEWAY_MODE") == "true"

def get_credentials_from_gateway() -> Optional[Credentials]:
    """Get credentials from Docker MCP Gateway injected token."""
    access_token = os.environ.get("GOOGLE_ACCESS_TOKEN")
    if not access_token:
        return None
    return Credentials(token=access_token)
```

### Docker Integration

- Server runs on `localhost:8000` with `streamable-http` transport
- Tools are dynamically discovered (55+ tools visible in Docker MCP)
- Health check endpoint at `/health`

## Quick Start

### 1. Build and Start the Gateway Server

```bash
# Build the gateway image
docker-compose -f docker-compose.gateway.yml --profile gateway build

# Start the server
docker-compose -f docker-compose.gateway.yml --profile gateway up -d

# Verify health
curl http://localhost:8000/health
```

### 2. Register with Docker MCP

```bash
# Import the catalog
docker mcp catalog import ./workspace-mcp-local-catalog.yaml

# Enable the server
docker mcp server enable google-workspace

# Verify tools are discovered
docker mcp tools ls | grep -i google
```

### 3. Authorize OAuth

```bash
# Check OAuth status
docker mcp oauth ls

# Authorize Google OAuth (opens browser)
docker mcp oauth authorize google-workspace
```

### 4. Test a Tool

```bash
# List available tools
docker mcp tools ls

# Call a tool (example)
docker mcp tools call google-workspace get_events
```

### 5. Cleanup

```bash
# Stop the server
docker-compose -f docker-compose.gateway.yml --profile gateway down

# Disable the server
docker mcp server disable google-workspace
```

## Using the Test Script

A convenience script is provided for testing:

```bash
./scripts/test-docker-mcp-oauth.sh
```

This script will:
1. Build the gateway image
2. Start the local server
3. Wait for health check
4. Import the catalog
5. Display next steps for OAuth authorization

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOCKER_MCP_GATEWAY_MODE` | Enable gateway mode | `true` in Dockerfile |
| `GOOGLE_ACCESS_TOKEN` | OAuth token injected by gateway | - |
| `PORT` | Server port | `8000` |
| `OAUTHLIB_INSECURE_TRANSPORT` | Allow HTTP for local dev | `1` |
| `MCP_SINGLE_USER_MODE` | Single user mode | `1` |

## Catalog Configuration

The catalog entry (`workspace-mcp-local-catalog.yaml`) configures:

```yaml
registry:
  google-workspace:
    type: remote
    remote:
      transport_type: streamable-http
      url: http://localhost:8000/mcp
    oauth:
      provider: gdrive
      secret: workspace-mcp.access_token
      env: GOOGLE_ACCESS_TOKEN
```

## Troubleshooting

### Server not starting

Check container logs:
```bash
docker-compose -f docker-compose.gateway.yml --profile gateway logs
```

### Tools not discovered

1. Verify server is running: `curl http://localhost:8000/health`
2. Check catalog import: `docker mcp catalog show workspace-mcp-local`
3. Verify server is enabled: `docker mcp server ls`

### OAuth not working

1. Check OAuth status: `docker mcp oauth ls`
2. The `gdrive` provider must be authorized first
3. Ensure the catalog OAuth configuration is correct

## Production Deployment

After local testing succeeds:

1. **Push image to registry**:
   ```bash
   docker tag workspace-mcp-gateway:latest ghcr.io/YOUR_ORG/workspace-mcp:latest
   docker push ghcr.io/YOUR_ORG/workspace-mcp:latest
   ```

2. **Deploy to cloud infrastructure** (AWS, GCP, etc.)

3. **Update catalog URL** to public endpoint:
   ```yaml
   remote:
     url: https://your-server.example.com/mcp
   ```

4. **Submit to Docker MCP Registry** for public availability

## Fallback: Auth Helper

If native Docker OAuth doesn't support all required Google scopes, use the auth-helper fallback:

```bash
# Run auth helper to authenticate
docker-compose -f docker-compose.gateway.yml run --rm auth user@gmail.com

# This stores credentials in the shared volume
# The gateway server can then use these credentials
```
