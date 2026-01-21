# Changelog: Docker MCP Gateway OAuth Integration

All changes made to enable Docker MCP Gateway native OAuth support.

## [Unreleased] - 2026-01-20

### Added

#### New Files

**`Dockerfile.gateway`**
- New Dockerfile for Docker MCP Gateway HTTP transport
- Based on `python:3.11-slim`
- Installs `uv` for dependency management
- Creates non-root `app` user for security
- Exposes port 8000
- Includes health check at `/health`
- Sets gateway mode environment variables:
  - `DOCKER_MCP_GATEWAY_MODE=true`
  - `OAUTHLIB_INSECURE_TRANSPORT=1`
  - `PORT=8000`
  - `WORKSPACE_MCP_PORT=8000`
- Entry point: `/app/.venv/bin/python main.py --transport streamable-http --single-user`

**`workspace-mcp-local-catalog.yaml`**
- Docker MCP catalog entry for local testing
- Version 3 catalog format
- Server name: `google-workspace`
- Type: `remote` with `streamable-http` transport
- URL: `http://localhost:8000/mcp`
- Dynamic tool discovery enabled
- OAuth configuration:
  - Provider: `gdrive`
  - Secret: `workspace-mcp.access_token`
  - Environment variable: `GOOGLE_ACCESS_TOKEN`
- Metadata tags for Google Workspace services

**`scripts/test-docker-mcp-oauth.sh`**
- Automated test script for Docker MCP Gateway integration
- Steps:
  1. Builds gateway image via docker-compose
  2. Starts local server on port 8000
  3. Waits for health check (30 retries)
  4. Imports catalog to Docker MCP
  5. Displays OAuth and server status
  6. Prints next steps for manual testing
- Error handling with informative messages

**`docs/DOCKER_MCP_GATEWAY.md`**
- Comprehensive documentation for the integration
- Architecture diagram
- Quick start guide
- Environment variables reference
- Catalog configuration explanation
- Troubleshooting section
- Production deployment notes

**`docs/DOCKER_MCP_GATEWAY_CONVERSION_GUIDE.md`**
- Generic guide for converting any MCP server to Docker Gateway
- Step-by-step conversion process
- Code examples in Python and TypeScript
- Common issues and solutions
- Security considerations

**`docs/CHANGELOG_DOCKER_GATEWAY.md`**
- This file - detailed changelog of all modifications

**`docs/REPLAY_DOCKER_GATEWAY_CHANGES.md`**
- Step-by-step plan to replay all changes on a fresh clone

### Modified

#### `auth/google_auth.py`

**Lines 71-105: Added gateway mode functions**

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

**Lines 585-599: Modified `get_credentials()` function**

Added gateway mode check at the beginning of the function:

```python
def get_credentials(
    account_id: str,
    credentials_dir: Optional[str] = None,
    interactive: bool = False,
    use_oauth_2_1: bool = False,
) -> Optional[Credentials]:
    """Get valid Google credentials for specified account.
    ...
    """
    # Check Docker MCP Gateway mode first
    if is_gateway_mode():
        credentials = get_credentials_from_gateway()
        if credentials:
            logger.info("[get_credentials] Running in Docker MCP Gateway mode with injected token")
            return credentials
        else:
            logger.warning("[get_credentials] Gateway mode enabled but no token found, falling back to normal flow")

    # ... rest of existing function
```

#### `docker-compose.gateway.yml`

**Added `gateway` service (lines 22-44)**

```yaml
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
```

**Updated file header comments (lines 1-20)**

Added documentation for:
- Architecture overview (auth-helper, gateway, stdio modes)
- Usage instructions for native Docker MCP OAuth
- Usage instructions for auth-helper fallback
- Build commands for images

### Technical Details

#### Gateway Mode Flow

1. Docker MCP Gateway handles OAuth authorization via `docker mcp oauth authorize`
2. User completes Google OAuth consent in browser
3. Gateway stores tokens securely
4. When MCP server is called, Gateway injects `GOOGLE_ACCESS_TOKEN` env var
5. Server's `get_credentials()` detects gateway mode
6. Server creates `Credentials` object from injected token
7. Server uses credentials for Google API calls

#### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `DOCKER_MCP_GATEWAY_MODE` | `true` | Enable gateway mode detection |
| `GOOGLE_ACCESS_TOKEN` | (injected) | OAuth access token from gateway |
| `PORT` | `8000` | HTTP server port |
| `WORKSPACE_MCP_PORT` | `8000` | Alternative port variable |
| `OAUTHLIB_INSECURE_TRANSPORT` | `1` | Allow HTTP for local dev |
| `MCP_SINGLE_USER_MODE` | `1` | Single user mode for containers |
| `TOOL_TIER` | (optional) | Tool tier configuration |
| `TOOLS` | (optional) | Specific tools to enable |

#### Catalog Configuration

The catalog uses Docker MCP's built-in `gdrive` OAuth provider:

```yaml
oauth:
  provider: gdrive
  secret: workspace-mcp.access_token
  env: GOOGLE_ACCESS_TOKEN
```

This tells Docker MCP to:
1. Use the `gdrive` OAuth provider for authorization
2. Store the token in secret `workspace-mcp.access_token`
3. Inject the token as `GOOGLE_ACCESS_TOKEN` environment variable

### Bug Fixes During Implementation

1. **CLI argument error**: `main.py` doesn't accept `--host` and `--port` arguments
   - Fix: Use environment variables `PORT` and `WORKSPACE_MCP_PORT` instead

2. **YAML unmarshal error**: OAuth configuration was using list syntax
   - Fix: Changed from `- provider: gdrive` to `provider: gdrive` (object syntax)

3. **Server name conflict**: `workspace-mcp` conflicted with existing catalog entry
   - Fix: Renamed to `google-workspace` in the catalog

### Verification Results

- Gateway image builds successfully
- Server starts and health check passes at `http://localhost:8000/health`
- Catalog imports to Docker MCP
- Server enables in Docker MCP
- 55+ tools discovered dynamically
- Tools visible via `docker mcp tools ls`
