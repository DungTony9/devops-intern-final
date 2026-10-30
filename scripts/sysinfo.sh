#!/usr/bin/env bash
set -euo pipefail

echo "=== System Information ==="
echo "Current User : $(whoami) (Effective UID: $(id -u))"
echo "Host & Kernel: $(hostname) / $(uname -r)"
echo "System Date  : $(date -Iseconds)"
echo ""
echo "--- Disk Usage ---"
df -h /
echo ""
echo "--- Memory Usage ---"
free -h
echo ""
echo "--- Docker Daemon Status ---"
if docker info >/dev/null 2>&1; then
    echo "Docker daemon is running."
else
    echo "Docker daemon is NOT running or not accessible."
fi