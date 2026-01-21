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
echo "4. Test a tool (example):"
echo "   docker mcp tools call google-workspace search_gmail_messages '{\"query\": \"is:inbox\", \"max_results\": 5}'"
echo ""
echo "5. Stop local server when done:"
echo "   docker-compose -f docker-compose.gateway.yml down"
echo ""
echo "=============================================="
