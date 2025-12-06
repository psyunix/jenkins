#!/bin/bash
# Diagnostic script to check Docker socket permissions and Jenkins connectivity
set -euo pipefail

echo "═══════════════════════════════════════════════════════════════"
echo "🔍 Docker Socket Permission Diagnostic"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if Docker socket exists
if [ ! -S /var/run/docker.sock ]; then
    echo "❌ Docker socket not found at /var/run/docker.sock"
    exit 1
fi

echo "✓ Docker socket found at /var/run/docker.sock"
echo ""

# Check socket permissions
echo "📋 Socket Permissions:"
ls -l /var/run/docker.sock
echo ""

# Check socket ownership
SOCKET_OWNER=$(stat -c '%U:%G' /var/run/docker.sock 2>/dev/null || stat -f '%Su:%Sg' /var/run/docker.sock 2>/dev/null)
echo "Socket owner: $SOCKET_OWNER"
echo ""

# Check if running inside Docker
if grep -q docker /proc/self/cgroup 2>/dev/null || [ -f /.dockerenv ]; then
    echo "✓ Running inside a Docker container"
    echo ""
    echo "Current user: $(whoami)"
    echo "User ID: $(id -u)"
    echo "Groups: $(id -G)"
    echo ""
    
    # Try to connect to Docker
    if docker ps &>/dev/null; then
        echo "✅ Docker daemon is accessible"
    else
        echo "❌ Docker daemon is NOT accessible"
        echo ""
        echo "FIXES:"
        echo "1. Inside the Jenkins container, run:"
        echo "   sudo usermod -aG docker jenkins"
        echo ""
        echo "2. Or restart the Jenkins container with Docker socket mounted:"
        echo "   docker run -v /var/run/docker.sock:/var/run/docker.sock ..."
    fi
else
    echo "⚠️  Not running inside a Docker container (might be local test)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
