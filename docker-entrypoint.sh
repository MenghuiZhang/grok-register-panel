#!/usr/bin/env bash
#
# Container entrypoint for Grok Register + Live Panel.
# 1. Hardens runtime permission on bind-mounted dirs (matches DEPLOYMENT.md).
# 2. Applies sane defaults for the panel.
# 3. Starts webui/monitor.py by default.
#
# To run a different command (e.g. a CLI batch), override argv:
#   docker run --rm <image> python run_batch_headless.py 5 2

set -euo pipefail

ROOT=/opt/grok-register-panel
cd "$ROOT"

# Allow overriding the entrypoint command with `... <image> python <args>`.
if [[ "${1:-}" == "python" ]]; then
    shift
    exec .venv/bin/python "$@"
fi

# Re-apply owner-only permissions in case host bind mounts reset ownership.
.venv/bin/python scripts/harden_runtime_permissions.py "$ROOT" || true

umask 0077

# Generate a token if none is set, mirroring the local quickstart.
: "${MONITOR_TOKEN:=$(.venv/bin/python -c 'import secrets; print(secrets.token_urlsafe(32))')}"
export MONITOR_TOKEN

: "${MONITOR_HOST:=0.0.0.0}"
: "${MONITOR_PORT:=8787}"
: "${PANEL_INCLUDE_TAIL:=0}"
: "${CPA_AUTH_DIR:=$ROOT/cpa_auth}"

echo "[entrypoint] panel at ${MONITOR_HOST}:${MONITOR_PORT} (PANEL_INCLUDE_TAIL=${PANEL_INCLUDE_TAIL})"
exec .venv/bin/python -u webui/monitor.py