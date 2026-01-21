# Replay Plan: Docker MCP Gateway OAuth Integration

This document provides step-by-step instructions to apply all Docker MCP Gateway OAuth changes to a fresh clone of the Google Workspace MCP repository.

## Prerequisites

- Docker Desktop with MCP Toolkit enabled
- `docker mcp` CLI available
- Git installed

## Step 1: Clone the Repository

```bash
# Clone the repository
git clone https://github.com/taylorwilsdon/google_workspace_mcp.git
cd google_workspace_mcp
```

## Step 2: Create Dockerfile.gateway

Create the file `Dockerfile.gateway` with the following content:

```dockerfile
# Dockerfile for Docker MCP Gateway integration
# Uses streamable-http transport with Gateway mode enabled

FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv for faster dependency management
RUN pip install --no-cache-dir uv

COPY . .

# Install Python dependencies using uv sync
RUN uv sync --frozen --no-dev

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app

# Give read and write access to the store_creds volume (for fallback mode)
RUN mkdir -p /app/store_creds \
    && chown -R app:app /app/store_creds \
    && chmod 755 /app/store_creds

USER app

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Environment variables for Docker MCP Gateway mode
ENV PYTHONUNBUFFERED=1
ENV DOCKER_MCP_GATEWAY_MODE=true
ENV OAUTHLIB_INSECURE_TRANSPORT=1

# Server configuration via environment variables
ENV PORT=8000
ENV WORKSPACE_MCP_PORT=8000

# Tool configuration (optional)
ENV TOOL_TIER=""
ENV TOOLS=""

# Use venv Python directly for cleaner process management
ENTRYPOINT ["/app/.venv/bin/python", "main.py"]
CMD ["--transport", "streamable-http", "--single-user"]
```

## Step 3: Modify auth/google_auth.py

### 3.1: Add Gateway Mode Functions

Find the imports section at the top of `auth/google_auth.py` and ensure these imports exist:

```python
import os
from typing import Optional
from google.oauth2.credentials import Credentials
```

After the existing imports and before the main functions (around line 70), add:

```python
# --- Docker MCP Gateway Mode Support ---
# These functions enable the MCP server to receive OAuth tokens
# from Docker MCP Gateway instead of handling OAuth flow directly.

def is_gateway_mode() -> bool:
    """Check if running under Docker MCP Gateway.

    When running under Docker MCP Gateway, OAuth is handled by the gateway
    and tokens are injected via environment variables.

    Returns:
        bool: True if DOCKER_MCP_GATEWAY_MODE environment variable is set to "true"
    """
    return os.environ.get("DOCKER_MCP_GATEWAY_MODE") == "true"


def get_credentials_from_gateway() -> Optional[Credentials]:
    """Get credentials from Docker MCP Gateway injected token.

    Docker MCP Gateway handles the OAuth flow and injects the access token
    via the GOOGLE_ACCESS_TOKEN environment variable. This function creates
    Google credentials from that token.

    Note: Gateway handles token refresh, so we only need the access token.

    Returns:
        Optional[Credentials]: Google credentials if token is available, None otherwise
    """
    access_token = os.environ.get("GOOGLE_ACCESS_TOKEN")
    if not access_token:
        logger.debug("[gateway_mode] No GOOGLE_ACCESS_TOKEN environment variable found")
        return None

    logger.info("[gateway_mode] Creating credentials from Gateway-injected access token")
    # Create credentials from access token only
    # Gateway handles refresh, so we don't need refresh_token here
    return Credentials(token=access_token)
```

### 3.2: Modify get_credentials() Function

Find the `get_credentials()` function (search for `def get_credentials(`). At the very beginning of the function body, after the docstring, add:

```python
    # Check Docker MCP Gateway mode first
    if is_gateway_mode():
        credentials = get_credentials_from_gateway()
        if credentials:
            logger.info("[get_credentials] Running in Docker MCP Gateway mode with injected token")
            return credentials
        else:
            logger.warning("[get_credentials] Gateway mode enabled but no token found, falling back to normal flow")
```

The function should look like:

```python
def get_credentials(
    account_id: str,
    credentials_dir: Optional[str] = None,
    interactive: bool = False,
    use_oauth_2_1: bool = False,
) -> Optional[Credentials]:
    """Get valid Google credentials for specified account.

    ... existing docstring ...
    """
    # Check Docker MCP Gateway mode first
    if is_gateway_mode():
        credentials = get_credentials_from_gateway()
        if credentials:
            logger.info("[get_credentials] Running in Docker MCP Gateway mode with injected token")
            return credentials
        else:
            logger.warning("[get_credentials] Gateway mode enabled but no token found, falling back to normal flow")

    # ... rest of existing function ...
```

## Step 4: Update docker-compose.gateway.yml

Replace the entire `docker-compose.gateway.yml` file with:

```yaml
# Docker Compose for Google Workspace MCP with Docker Gateway Support
#
# Architecture:
#   1. auth-helper: One-time authentication for new users (fallback mode)
#   2. gateway: HTTP server for Docker MCP Gateway with native OAuth
#   3. stdio: Ephemeral stdio containers spawned by Docker MCP Gateway
#
# Usage:
#   # Option 1: Native Docker MCP OAuth (recommended)
#   docker-compose -f docker-compose.gateway.yml --profile gateway up -d
#   docker mcp catalog import ./workspace-mcp-local-catalog.yaml
#   docker mcp oauth authorize workspace-mcp
#   docker mcp server enable workspace-mcp
#
#   # Option 2: Auth helper fallback (if native OAuth doesn't work)
#   docker-compose -f docker-compose.gateway.yml run --rm auth user@example.com
#
#   # Build images:
#   docker-compose -f docker-compose.gateway.yml --profile build build
#   docker-compose -f docker-compose.gateway.yml --profile gateway build

services:
  # Gateway-compatible HTTP server for Docker MCP Gateway native OAuth
  # Runs on localhost:8000 and receives OAuth tokens from Gateway
  gateway:
    build:
      context: .
      dockerfile: Dockerfile.gateway
    image: workspace-mcp-gateway:latest
    ports:
      - "8000:8000"
    environment:
      - GOOGLE_ACCESS_TOKEN=${GOOGLE_ACCESS_TOKEN:-}
      - DOCKER_MCP_GATEWAY_MODE=true
      - OAUTHLIB_INSECURE_TRANSPORT=1
      - MCP_SINGLE_USER_MODE=1
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    profiles:
      - gateway

  # Authentication helper - run on-demand to authenticate new users (fallback)
  auth:
    build:
      context: .
      dockerfile: Dockerfile.auth
    image: workspace-mcp-auth:latest
    ports:
      - "8080:8080"
    environment:
      - GOOGLE_OAUTH_CLIENT_ID=${GOOGLE_OAUTH_CLIENT_ID}
      - GOOGLE_OAUTH_CLIENT_SECRET=${GOOGLE_OAUTH_CLIENT_SECRET}
      - GOOGLE_MCP_CREDENTIALS_DIR=/app/store_creds
      - AUTH_HELPER_PORT=8080
    volumes:
      - workspace_mcp_creds:/app/store_creds:rw
    profiles:
      - auth

  # Build the stdio image for Docker MCP Gateway (legacy mode)
  # This service just builds the image - Gateway spawns containers from it
  build-gateway-image:
    build:
      context: .
      dockerfile: Dockerfile.stdio
    image: workspace-mcp-stdio:latest
    profiles:
      - build

  # Build all images
  build-all:
    build:
      context: .
      dockerfile: Dockerfile.gateway
    image: workspace-mcp-gateway:latest
    profiles:
      - build

volumes:
  workspace_mcp_creds:
    name: workspace_mcp_creds
```

## Step 5: Create workspace-mcp-local-catalog.yaml

Create the file `workspace-mcp-local-catalog.yaml` in the repository root:

```yaml
# Docker MCP Catalog Entry for Google Workspace MCP (Local Testing)
#
# This catalog entry configures Google Workspace MCP as a remote server
# that uses Docker MCP Gateway's native OAuth support.
#
# Usage:
#   docker mcp catalog import ./workspace-mcp-local-catalog.yaml
#   docker mcp oauth authorize workspace-mcp
#   docker mcp server enable workspace-mcp

version: 3
name: workspace-mcp-local
displayName: Google Workspace MCP (Local)

registry:
  google-workspace:
    title: "Google Workspace MCP"
    description: "Full Google Workspace integration: Gmail, Drive, Calendar, Docs, Sheets, Forms, Slides, Tasks, Search"
    type: remote

    # Dynamic tool discovery - tools are fetched from the server
    dynamic:
      tools: true

    # Metadata for catalog display
    meta:
      category: productivity
      tags:
        - google-workspace
        - gmail
        - drive
        - calendar
        - docs
        - sheets
        - forms
        - slides
        - tasks
        - productivity
        - remote

    # Display information
    about:
      title: Google Workspace MCP
      description: "Comprehensive Google Workspace integration providing access to Gmail, Google Drive, Calendar, Docs, Sheets, Forms, Slides, and Tasks through the Model Context Protocol."
      icon: https://workspace.google.com/favicon.ico

    # Remote server configuration
    remote:
      transport_type: streamable-http
      url: http://localhost:8000/mcp

    # OAuth configuration using Docker's built-in gdrive provider
    # Note: The gdrive provider handles Google OAuth
    oauth:
      provider: gdrive
      secret: workspace-mcp.access_token
      env: GOOGLE_ACCESS_TOKEN
```

## Step 6: Create Test Script

Create the directory and script `scripts/test-docker-mcp-oauth.sh`:

```bash
mkdir -p scripts
```

Create `scripts/test-docker-mcp-oauth.sh`:

```bash
#!/bin/bash
# Google Workspace MCP - Docker MCP Gateway OAuth Test Script
#
# This script tests the integration between Google Workspace MCP
# and Docker MCP Gateway's native OAuth support.
#
# Prerequisites:
#   - Docker Desktop with MCP Toolkit enabled
#   - docker mcp CLI available
#
# Usage:
#   ./scripts/test-docker-mcp-oauth.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "=============================================="
echo "Google Workspace MCP - Docker MCP OAuth Test"
echo "=============================================="
echo ""

# Step 1: Build gateway image
echo "Step 1: Building gateway image..."
docker-compose -f docker-compose.gateway.yml --profile gateway build
echo "✓ Gateway image built successfully"
echo ""

# Step 2: Start local server
echo "Step 2: Starting local server on localhost:8000..."
docker-compose -f docker-compose.gateway.yml --profile gateway up -d
echo "✓ Server started"
echo ""

# Wait for health check
echo "Step 3: Waiting for server to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        echo "✓ Server is healthy"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "✗ Server failed to become healthy after $MAX_RETRIES attempts"
        echo "  Check logs with: docker-compose -f docker-compose.gateway.yml --profile gateway logs"
        exit 1
    fi
    sleep 1
done
echo ""

# Step 4: Import local catalog
echo "Step 4: Importing local catalog to Docker MCP..."
if docker mcp catalog import ./workspace-mcp-local-catalog.yaml 2>/dev/null; then
    echo "✓ Catalog imported successfully"
else
    echo "⚠ Catalog import may have issues. Continuing..."
fi
echo ""

# Step 5: Show current OAuth status
echo "Step 5: Current OAuth status:"
docker mcp oauth ls 2>/dev/null || echo "  (Could not retrieve OAuth status)"
echo ""

# Step 6: Show server status
echo "Step 6: Current server status:"
docker mcp server ls 2>/dev/null || echo "  (Could not retrieve server status)"
echo ""

echo "=============================================="
echo "Setup Complete!"
echo "=============================================="
echo ""
echo "Next Steps:"
echo ""
echo "1. Authorize Google OAuth (opens browser):"
echo "   docker mcp oauth authorize google-workspace"
echo ""
echo "2. Enable the server:"
echo "   docker mcp server enable google-workspace"
echo ""
echo "3. List available tools:"
echo "   docker mcp tools ls google-workspace"
echo ""
echo "4. Test a tool:"
echo "   docker mcp tools call google-workspace gmail_list_messages"
echo ""
echo "5. Stop local server when done:"
echo "   docker-compose -f docker-compose.gateway.yml --profile gateway down"
echo ""
echo "=============================================="
```

Make the script executable:

```bash
chmod +x scripts/test-docker-mcp-oauth.sh
```

## Step 7: Create Documentation

Create the docs directory if it doesn't exist:

```bash
mkdir -p docs
```

Copy the documentation files:
- `docs/DOCKER_MCP_GATEWAY.md` - Main integration documentation
- `docs/DOCKER_MCP_GATEWAY_CONVERSION_GUIDE.md` - Generic conversion guide
- `docs/CHANGELOG_DOCKER_GATEWAY.md` - Detailed changelog

(These files contain extensive documentation - copy from the original implementation)

## Step 8: Test the Integration

```bash
# Run the test script
./scripts/test-docker-mcp-oauth.sh

# Or manually:

# 1. Build the gateway image
docker-compose -f docker-compose.gateway.yml --profile gateway build

# 2. Start local server
docker-compose -f docker-compose.gateway.yml --profile gateway up -d

# 3. Verify health check
curl http://localhost:8000/health

# 4. Import catalog
docker mcp catalog import ./workspace-mcp-local-catalog.yaml

# 5. Enable server
docker mcp server enable google-workspace

# 6. Authorize OAuth (opens browser)
docker mcp oauth authorize google-workspace

# 7. List tools
docker mcp tools ls | grep -i google

# 8. Test a tool
docker mcp tools call google-workspace gmail_list_messages
```

## Step 9: Cleanup

```bash
# Stop the local server
docker-compose -f docker-compose.gateway.yml --profile gateway down

# Disable the server in Docker MCP
docker mcp server disable google-workspace

# Remove the catalog (optional)
docker mcp catalog remove workspace-mcp-local
```

## Summary of Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `Dockerfile.gateway` | Create | HTTP server Dockerfile for gateway mode |
| `auth/google_auth.py` | Modify | Add `is_gateway_mode()` and `get_credentials_from_gateway()` |
| `docker-compose.gateway.yml` | Modify | Add gateway service with profile |
| `workspace-mcp-local-catalog.yaml` | Create | Docker MCP catalog entry |
| `scripts/test-docker-mcp-oauth.sh` | Create | Automated test script |
| `docs/DOCKER_MCP_GATEWAY.md` | Create | Integration documentation |
| `docs/DOCKER_MCP_GATEWAY_CONVERSION_GUIDE.md` | Create | Generic conversion guide |
| `docs/CHANGELOG_DOCKER_GATEWAY.md` | Create | Detailed changelog |
| `docs/REPLAY_DOCKER_GATEWAY_CHANGES.md` | Create | This replay plan |

## Verification Checklist

After applying all changes, verify:

- [ ] `Dockerfile.gateway` exists and is valid
- [ ] `auth/google_auth.py` contains `is_gateway_mode()` function
- [ ] `auth/google_auth.py` contains `get_credentials_from_gateway()` function
- [ ] `get_credentials()` checks gateway mode first
- [ ] `docker-compose.gateway.yml` has gateway service
- [ ] `workspace-mcp-local-catalog.yaml` exists with correct format
- [ ] `scripts/test-docker-mcp-oauth.sh` is executable
- [ ] Gateway image builds successfully
- [ ] Server starts and health check passes
- [ ] Catalog imports without errors
- [ ] Server enables in Docker MCP
- [ ] Tools are discovered (55+ tools)
