#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${1:-http://localhost:8080}"

echo "Checking health at: ${TARGET_URL}"

if RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${TARGET_URL}"); then
    if [ "${RESPONSE_CODE}" -eq 200 ]; then
        echo "[SUCCESS] Service is healthy (HTTP ${RESPONSE_CODE})."
        exit 0
    else
        echo "[FAILURE] Service returned HTTP ${RESPONSE_CODE} (expected 200)." >&2
        exit 1
    fi
else
    echo "[ERROR] Failed to connect to ${TARGET_URL}." >&2
    exit 1
fi