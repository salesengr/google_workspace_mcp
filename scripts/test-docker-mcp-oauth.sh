#!/bin/bash
# Google Workspace MCP - Docker MCP Gateway Setup Script
#
# This script sets up Google Workspace MCP to work with Docker MCP Gateway.
# The server manages its own OAuth flow using your Google Cloud credentials.
#
# Prerequisites:
#   - Docker Desktop with MCP Toolkit enabled
#   - docker mcp CLI available
#   - .env file configured with your Google OAuth credentials
#
# Usage:
#   ./scripts/test-docker-mcp-oauth.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "=============================================="
echo "Google Workspace MCP - Docker MCP Gateway Setup"
echo "=============================================="
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "⚠ WARNING: .env file not found!"
    echo "  Copy .env.sample to .env and add your Google OAuth credentials"
    echo "  See DOCKER_MCP_SETUP.md for details"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Step 1: Build gateway image
echo "Step 1: Building gateway image..."
docker-compose -f docker-compose.gateway.yml build
echo "✓ Gateway image built successfully"
echo ""

# Step 2: Start local server
echo "Step 2: Starting local server on localhost:8000..."
docker-compose -f docker-compose.gateway.yml up -d
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
        echo "  Check logs with: docker-compose -f docker-compose.gateway.yml logs"
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

# Step 5: Show server status
echo "Step 5: Current server status:"
docker mcp server ls 2>/dev/null || echo "  (Could not retrieve server status)"
echo ""

echo "=============================================="
echo "Setup Complete!"
echo "=============================================="
echo ""
echo "Next Steps:"
echo ""
echo "1. Enable the server:"
echo "   docker mcp server enable google-workspace"
echo ""
echo "2. List available tools:"
echo "   docker mcp tools ls google-workspace"
echo ""
echo "3. Call a tool (OAuth will trigger on first use):"
echo "   docker mcp tools call google-workspace search_gmail_messages '{\"query\": \"is:inbox\", \"max_results\": 5}'"
echo ""
echo "   NOTE: First tool call will return an authorization URL."
echo "   Open it in your browser, authorize, then retry the tool call."
echo ""
echo "4. Stop local server when done:"
echo "   docker-compose -f docker-compose.gateway.yml down"
echo ""
echo "=============================================="
