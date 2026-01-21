# Google Workspace MCP - Credentials Guide

This guide explains all the ways to provide Google OAuth credentials to the MCP server.

## Quick Start (Docker MCP Gateway)

1. **Edit the `.env` file** (already created for you):
   ```bash
   nano .env
   ```

2. **Replace placeholder values** with your Google Cloud credentials:
   ```
   GOOGLE_OAUTH_CLIENT_ID="your-actual-client-id"
   GOOGLE_OAUTH_CLIENT_SECRET="your-actual-client-secret"
   ```

3. **Done!** Docker Compose automatically loads `.env` files for Docker MCP Gateway.

## Three Credential Methods

### Method 1: .env File (✅ Recommended for Docker MCP Gateway)

**File**: `.env` in project root

```bash
# Already created for you - just edit it
GOOGLE_OAUTH_CLIENT_ID="your-client-id"
GOOGLE_OAUTH_CLIENT_SECRET="your-client-secret"
OAUTHLIB_INSECURE_TRANSPORT=1
```

**Pros:**
- ✅ Docker Compose loads automatically via `env_file: - .env`
- ✅ Git-ignored by default (safe from commits)
- ✅ Easy to edit and manage
- ✅ Best for local development and Docker deployments

**How it works:**
- Python loads via `python-dotenv` at startup ([main.py:20-21](main.py:20-21))
- Docker Compose loads via `env_file` directive ([docker-compose.gateway.yml:28-29](docker-compose.gateway.yml:28-29))

### Method 2: Environment Variables

**Shell export** before running:

```bash
export GOOGLE_OAUTH_CLIENT_ID="your-client-id"
export GOOGLE_OAUTH_CLIENT_SECRET="your-client-secret"
export OAUTHLIB_INSECURE_TRANSPORT=1

# Then run
uv run main.py
```

**Pros:**
- ✅ Works in production environments
- ✅ CI/CD pipelines (GitHub Actions, etc.)
- ✅ Cloud platforms (Heroku, Railway, etc.)
- ✅ Kubernetes/Docker secrets

**Cons:**
- ❌ Must export before every session
- ❌ Lost when terminal closes

### Method 3: client_secret.json File

**File**: `client_secret.json` in project root (or custom path)

Download from Google Cloud Console with this structure:
```json
{
  "web": {
    "client_id": "your-client-id.apps.googleusercontent.com",
    "client_secret": "your-client-secret",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token"
  }
}
```

**Custom path** (optional):
```bash
export GOOGLE_CLIENT_SECRET_PATH=/path/to/client_secret.json
```

**Pros:**
- ✅ Traditional Google API development workflow
- ✅ Can download directly from Google Cloud Console
- ✅ Includes auth/token URIs automatically

**Cons:**
- ❌ Must be careful not to commit to git
- ❌ More complex file structure

## Loading Priority

The server checks credentials in this order ([auth/google_auth.py:205-318](auth/google_auth.py:205-318)):

1. **Environment variables** - `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET`
2. **`.env` file** - Loaded by `python-dotenv` at startup
3. **Custom `client_secret.json`** - Via `GOOGLE_CLIENT_SECRET_PATH` env var
4. **Default `client_secret.json`** - In project root

**First match wins!** The server uses the first valid credentials it finds.

## Getting Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a new project or select existing
3. Click **Create Credentials → OAuth Client ID**
4. Choose **Desktop Application** (no redirect URIs needed!)
5. Download credentials and copy Client ID and Client Secret

## Required APIs to Enable

Enable these in [Google Cloud Console API Library](https://console.cloud.google.com/apis/library):

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

## Configuration Reference

### Minimal .env for Docker

```bash
GOOGLE_OAUTH_CLIENT_ID="your-client-id"
GOOGLE_OAUTH_CLIENT_SECRET="your-client-secret"
OAUTHLIB_INSECURE_TRANSPORT=1
```

### Recommended .env for Docker

```bash
# Required
GOOGLE_OAUTH_CLIENT_ID="your-client-id"
GOOGLE_OAUTH_CLIENT_SECRET="your-client-secret"

# Development
OAUTHLIB_INSECURE_TRANSPORT=1

# Single-user mode (simpler)
MCP_SINGLE_USER_MODE=1

# Optional: default email
USER_GOOGLE_EMAIL=your.email@gmail.com

# Optional: tool filtering
TOOL_TIER=core
# or
TOOLS=gmail drive calendar
```

### Full .env Template

See [.env.oauth21](.env.oauth21) for the complete template with all options including:
- OAuth 2.1 configuration
- Storage backends (memory, disk, valkey)
- Encryption settings
- Advanced options

## Troubleshooting

### "OAuth client credentials not found"

**Cause**: No credentials provided via any method.

**Solutions:**
1. Check `.env` file exists and has valid values
2. Ensure variables are not commented out (no `#` at start)
3. Verify Docker is loading the env file (check logs)

### "Invalid client_secret.json format"

**Cause**: JSON file doesn't have the expected structure.

**Solution**: Ensure it has `{"web": {...}}` or `{"installed": {...}}` structure.

### Docker not seeing credentials

**Cause**: `.env` file not loaded by docker-compose.

**Solution**: Verify `env_file: - .env` in [docker-compose.gateway.yml](docker-compose.gateway.yml:28-29)

### Credentials work locally but not in Docker

**Cause**: Docker container can't access host environment variables.

**Solution**: Use `.env` file or pass via `environment:` in docker-compose.

## Security Best Practices

1. ✅ **Never commit credentials** to git
   - `.env` is in `.gitignore`
   - `client_secret.json` is in `.gitignore`

2. ✅ **Use environment variables** in production
   - Not `.env` files
   - Use platform-specific secret management

3. ✅ **Rotate credentials** if exposed
   - Delete old credentials in Google Cloud Console
   - Create new ones

4. ✅ **Restrict OAuth scopes** to minimum needed
   - Server requests only necessary scopes per tool
   - See [auth/scopes.py](auth/scopes.py) for scope groups

## Related Files

- [.env](.env) - Your credentials (edit this!)
- [.env.oauth21](.env.oauth21) - Template with all options
- [auth/google_auth.py](auth/google_auth.py) - Credential loading logic
- [docker-compose.gateway.yml](docker-compose.gateway.yml) - Docker configuration
- [DOCKER_MCP_SETUP.md](DOCKER_MCP_SETUP.md) - Docker setup guide
- [README.md](README.md) - Main documentation
