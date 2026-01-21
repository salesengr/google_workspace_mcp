# Docker MCP Gateway OAuth Conversion Guide

This guide documents how to convert any MCP server to work with Docker MCP Gateway's native OAuth system.

## Overview

Docker MCP Gateway provides centralized OAuth management for MCP servers. Instead of each server handling its own OAuth flow, the Gateway:
1. Manages OAuth authorization via `docker mcp oauth authorize`
2. Stores tokens securely
3. Injects tokens into containers via environment variables or headers

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    DOCKER MCP GATEWAY OAUTH                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────┐         ┌──────────────────────────┐  │
│  │  docker mcp oauth   │         │  Your MCP Server         │  │
│  │  authorize          │         │  (HTTP or stdio)         │  │
│  │                     │         │                          │  │
│  │  Handles OAuth flow │         │  Receives token via      │  │
│  │  Stores tokens      │         │  environment variable    │  │
│  └─────────────────────┘         └──────────────────────────┘  │
│            │                                   ▲                │
│            │                                   │                │
│            └──────── Docker Gateway ───────────┘                │
│                      injects token                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Built-in OAuth Providers

Docker MCP Gateway includes these OAuth providers:

| Provider | Environment Variable | Use Case |
|----------|---------------------|----------|
| `github` | `GITHUB_TOKEN` | GitHub API access |
| `gdrive` | `GOOGLE_ACCESS_TOKEN` | Google APIs (Drive, Gmail, etc.) |

Check available providers:
```bash
docker mcp oauth ls
```

## Conversion Steps

### Step 1: Add Gateway Mode Detection

Add functions to detect when running under Docker MCP Gateway and extract the injected token.

**Python Example:**
```python
import os
from typing import Optional

def is_gateway_mode() -> bool:
    """Check if running under Docker MCP Gateway."""
    return os.environ.get("DOCKER_MCP_GATEWAY_MODE") == "true"

def get_token_from_gateway() -> Optional[str]:
    """Get OAuth token injected by Docker MCP Gateway."""
    # The env var name depends on your catalog oauth.env setting
    return os.environ.get("YOUR_TOKEN_ENV_VAR")
```

**TypeScript/Node.js Example:**
```typescript
function isGatewayMode(): boolean {
  return process.env.DOCKER_MCP_GATEWAY_MODE === "true";
}

function getTokenFromGateway(): string | undefined {
  return process.env.YOUR_TOKEN_ENV_VAR;
}
```

### Step 2: Modify Authentication Logic

Update your authentication code to check gateway mode first:

```python
def get_credentials():
    # Check Docker MCP Gateway mode first
    if is_gateway_mode():
        token = get_token_from_gateway()
        if token:
            logger.info("Using token from Docker MCP Gateway")
            return create_credentials_from_token(token)

    # Fall back to normal authentication flow
    return normal_auth_flow()
```

### Step 3: Create Gateway Dockerfile

Create a Dockerfile optimized for Docker MCP Gateway:

```dockerfile
FROM python:3.11-slim
# Or your preferred base image

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

# Create non-root user for security
RUN useradd --create-home app && chown -R app:app /app
USER app

# Expose port for HTTP transport
EXPOSE 8000

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Gateway mode environment variables
ENV PYTHONUNBUFFERED=1
ENV DOCKER_MCP_GATEWAY_MODE=true
ENV PORT=8000

# Start with HTTP transport
ENTRYPOINT ["python", "main.py"]
CMD ["--transport", "streamable-http"]
```

**Key Requirements:**
- HTTP transport (`streamable-http` or `sse`)
- Health check endpoint at `/health`
- `DOCKER_MCP_GATEWAY_MODE=true` environment variable
- Non-root user for security

### Step 4: Create Docker Compose Service

Add a gateway service to your docker-compose file:

```yaml
services:
  gateway:
    build:
      context: .
      dockerfile: Dockerfile.gateway
    image: your-mcp-server-gateway:latest
    ports:
      - "8000:8000"
    environment:
      - YOUR_TOKEN_ENV_VAR=${YOUR_TOKEN_ENV_VAR:-}
      - DOCKER_MCP_GATEWAY_MODE=true
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    profiles:
      - gateway
```

### Step 5: Create MCP Catalog Entry

Create a YAML catalog file for Docker MCP:

```yaml
version: 3
name: your-mcp-local
displayName: Your MCP Server (Local)

registry:
  your-mcp-server:
    title: "Your MCP Server"
    description: "Description of your server"
    type: remote

    # Enable dynamic tool discovery
    dynamic:
      tools: true

    # Metadata for catalog display
    meta:
      category: your-category
      tags:
        - tag1
        - tag2

    # Display information
    about:
      title: Your MCP Server
      description: "Detailed description"
      icon: https://example.com/icon.png

    # Remote server configuration
    remote:
      transport_type: streamable-http
      url: http://localhost:8000/mcp

    # OAuth configuration (use appropriate provider)
    oauth:
      provider: github  # or gdrive, or custom
      secret: your-mcp.access_token
      env: YOUR_TOKEN_ENV_VAR
```

**OAuth Configuration Options:**

For GitHub:
```yaml
oauth:
  provider: github
  secret: your-mcp.github_token
  env: GITHUB_TOKEN
```

For Google:
```yaml
oauth:
  provider: gdrive
  secret: your-mcp.access_token
  env: GOOGLE_ACCESS_TOKEN
```

### Step 6: Test the Integration

```bash
# 1. Build the gateway image
docker-compose -f docker-compose.gateway.yml --profile gateway build

# 2. Start the server
docker-compose -f docker-compose.gateway.yml --profile gateway up -d

# 3. Verify health check
curl http://localhost:8000/health

# 4. Import catalog to Docker MCP
docker mcp catalog import ./your-mcp-local-catalog.yaml

# 5. Enable the server
docker mcp server enable your-mcp-server

# 6. Authorize OAuth (opens browser)
docker mcp oauth authorize your-mcp-server

# 7. List available tools
docker mcp tools ls | grep your-mcp

# 8. Test a tool
docker mcp tools call your-mcp-server tool_name

# 9. Cleanup
docker-compose -f docker-compose.gateway.yml --profile gateway down
docker mcp server disable your-mcp-server
```

## Common Issues and Solutions

### Issue: Tools not discovered

**Symptoms:** `docker mcp tools ls` returns empty or missing tools

**Solutions:**
1. Verify server is running: `curl http://localhost:8000/health`
2. Check MCP endpoint: `curl http://localhost:8000/mcp` (should return MCP response)
3. Verify catalog import: `docker mcp catalog show your-catalog-name`
4. Check server is enabled: `docker mcp server ls`

### Issue: OAuth token not received

**Symptoms:** Server doesn't receive the OAuth token

**Solutions:**
1. Verify OAuth is authorized: `docker mcp oauth ls`
2. Check environment variable name matches catalog `oauth.env` setting
3. Check container logs for token-related messages

### Issue: YAML unmarshal errors

**Symptoms:** `cannot unmarshal !!seq into catalog.OAuth`

**Solution:** OAuth must be an object, not a list:

```yaml
# WRONG
oauth:
  - provider: github

# CORRECT
oauth:
  provider: github
  secret: name.token
  env: TOKEN_VAR
```

### Issue: Server name conflicts

**Symptoms:** Overlapping key warnings or "server not found"

**Solution:** Use unique server names across all catalogs:

```yaml
registry:
  unique-server-name:  # Must be unique across all catalogs
    title: "..."
```

## Environment Variables Reference

| Variable | Purpose | Required |
|----------|---------|----------|
| `DOCKER_MCP_GATEWAY_MODE` | Indicates gateway mode | Yes (set to `true`) |
| `PORT` | HTTP server port | Yes (usually `8000`) |
| `YOUR_TOKEN_ENV_VAR` | OAuth token from gateway | Yes (name from catalog) |
| `OAUTHLIB_INSECURE_TRANSPORT` | Allow HTTP (dev only) | Optional (`1` for local) |

## Transport Types

Docker MCP Gateway supports these transport types:

| Type | Description | Use Case |
|------|-------------|----------|
| `streamable-http` | HTTP with streaming | Recommended for remote servers |
| `sse` | Server-Sent Events | Alternative HTTP transport |
| `stdio` | Standard I/O | Local containers only |

## Security Considerations

1. **Non-root user**: Always run as non-root in containers
2. **HTTPS in production**: Only use HTTP for local development
3. **Token scope**: Request minimum required OAuth scopes
4. **Health checks**: Implement proper health check endpoints
5. **Secrets management**: Never hardcode tokens in images

## Production Deployment

After local testing:

1. **Push to registry:**
   ```bash
   docker tag your-mcp-gateway:latest ghcr.io/org/your-mcp:latest
   docker push ghcr.io/org/your-mcp:latest
   ```

2. **Deploy to cloud** (AWS ECS, GCP Cloud Run, Azure Container Apps)

3. **Update catalog URL:**
   ```yaml
   remote:
     url: https://your-server.example.com/mcp
   ```

4. **Submit to Docker MCP Registry** for public availability
