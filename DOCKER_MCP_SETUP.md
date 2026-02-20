# Docker MCP Gateway Setup Guide

This guide explains how to run Google Workspace MCP with Docker MCP Gateway (Docker Desktop MCP Toolkit).

## Prerequisites

- Docker Desktop with MCP Toolkit enabled
- `docker mcp` CLI available (comes with Docker Desktop MCP Toolkit)
- **Google OAuth credentials from Google Cloud Console**

## Important: OAuth Credentials Required

**Docker MCP Gateway's built-in `gdrive` provider only supports Drive read-only scope**, which is insufficient for Google Workspace MCP. You need Gmail, Calendar, Docs, Sheets, Forms, Slides, and Tasks scopes.

Therefore, you must provide your own Google OAuth credentials.

### Getting Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Navigate to **APIs & Services → Credentials**
4. Click **Create Credentials → OAuth Client ID**
5. Choose **Desktop Application** as the application type
6. Download the credentials and note the Client ID and Client Secret

### Enable Required APIs

Enable these APIs in Google Cloud Console:
- Gmail API
- Google Drive API
- Google Calendar API
- Google Docs API
- Google Sheets API
- Google Slides API
- Google Forms API
- Google Tasks API
- Google Chat API (optional)
- Custom Search API (optional)

[Quick enable links in README.md](README.md#quick-api-enable-links)

## Setup

### 1. Configure Credentials

A `.env` file template has been created for you. Just edit it with your credentials:

```bash
# Edit the .env file
nano .env

# Or use any text editor
code .env
```

Replace these values:
- `GOOGLE_OAUTH_CLIENT_ID="REPLACE-WITH-YOUR-CLIENT-ID"`
- `GOOGLE_OAUTH_CLIENT_SECRET="REPLACE-WITH-YOUR-CLIENT-SECRET"`

**That's it!** The file already has `OAUTHLIB_INSECURE_TRANSPORT=1` set for local testing.

### 2. Build and Start Server

```bash
# Build the Docker image
docker-compose -f docker-compose.gateway.yml build

# Start the server
docker-compose -f docker-compose.gateway.yml up -d

# Check health
curl http://localhost:8000/health
```

### 3. Import Catalog

```bash
docker mcp catalog import ./workspace-mcp-local-catalog.yaml
```

### 4. Enable Server

```bash
docker mcp server enable google-workspace
```

### 5. Use the Tools

The server will handle OAuth automatically when you call a tool for the first time. It will return an authorization URL - open it in your browser, authorize, and retry the tool call.

```bash
# List available tools
docker mcp tools ls google-workspace

# Test a tool (will prompt for OAuth on first use)
docker mcp tools call google-workspace search_gmail_messages '{"query": "is:inbox", "max_results": 5}'
```

## How It Works

1. **MCP Server** runs in Docker on `http://localhost:8000`
2. **OAuth Flow** is handled by the server itself (not Docker MCP Gateway)
3. **First Tool Call** triggers OAuth - server returns authorization URL
4. **You Authorize** in browser
5. **Server Stores Token** locally and retries the tool
6. **Subsequent Calls** use stored token (auto-refreshed as needed)

## Architecture

```
┌─────────────────────┐
│  Docker MCP Client  │
└──────────┬──────────┘
           │ HTTP
           ▼
┌─────────────────────┐
│  MCP Server         │
│  (localhost:8000)   │
│  - Manages OAuth    │
│  - Stores tokens    │
└─────────────────────┘
```

## Testing

```bash
# Search Gmail
docker mcp tools call google-workspace search_gmail_messages '{"query": "is:inbox", "max_results": 5}'

# List calendars
docker mcp tools call google-workspace list_calendars '{}'

# Search Drive files
docker mcp tools call google-workspace search_drive_files '{"query": "type:document", "max_results": 10}'
```

## Troubleshooting

### Server won't start - OAuth credentials missing
```bash
# Check logs
docker-compose -f docker-compose.gateway.yml logs

# Ensure .env file exists with credentials
cat .env
```

### OAuth authorization fails
The server will return an authorization URL. Open it in your browser:
```
https://accounts.google.com/o/oauth2/auth?...
```

After authorizing, retry your tool call.

### Tools not discovered
```bash
# Check server status
docker mcp server ls

# Ensure server is enabled
docker mcp server enable google-workspace

# Verify catalog is imported
docker mcp catalog ls
```

## Cleanup

```bash
# Stop the server
docker-compose -f docker-compose.gateway.yml down

# Disable the server
docker mcp server disable google-workspace

# Remove catalog (optional)
docker mcp catalog remove workspace-mcp-local
```

## Why Not Docker MCP Gateway's Native OAuth?

Docker MCP Gateway has built-in OAuth providers (like `gdrive`), but they have limitations:
- The `gdrive` provider only requests Drive read-only scope
- Google Workspace MCP needs Gmail, Calendar, Docs, Sheets, Forms, Slides, and Tasks scopes
- Docker MCP Gateway doesn't allow configuring custom scopes for built-in providers

Therefore, you must provide your own Google OAuth Client ID/Secret from Google Cloud Console. The server uses your credentials to manage its own OAuth flow, giving it access to all required scopes.

## Related Files

- [Dockerfile.gateway](Dockerfile.gateway) - Docker image configuration
- [docker-compose.gateway.yml](docker-compose.gateway.yml) - Compose configuration
- [workspace-mcp-local-catalog.yaml](workspace-mcp-local-catalog.yaml) - MCP catalog entry
- [auth/google_auth.py](auth/google_auth.py) - OAuth implementation
- [README.md](README.md) - Full project documentation
