#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WAIT=0
if [ "${1:-}" = "--wait" ]; then
    WAIT=1
fi

[ -f .env ] || {
    echo "Missing $ROOT/.env. Run configure first." >&2
    exit 1
}

set -a
# shellcheck source=/dev/null
source .env
set +a

check_url() {
    local label="$1" url="$2"
    if curl -fsS "$url" >/dev/null 2>&1; then
        echo "✓ $label : $url"
        return 0
    fi
    echo "✗ $label : not responding ($url)"
    return 1
}

wait_for_url() {
    local label="$1" url="$2" attempts=30
    local i
    for i in $(seq 1 "$attempts"); do
        if curl -fsS "$url" >/dev/null 2>&1; then
            echo "✓ $label : $url"
            return 0
        fi
        sleep 5
    done
    echo "✗ $label : not responding ($url)"
    return 1
}

if [ "$WAIT" = "1" ]; then
    wait_for_url "OPAC" "http://localhost:${UI_PORT}" || wait_for_url "Staff interface" "http://localhost:${REST_PORT}"
else
    check_url "OPAC" "http://localhost:${UI_PORT}" || check_url "Staff interface" "http://localhost:${REST_PORT}"
fi
