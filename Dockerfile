# syntax=docker/dockerfile:1.7
# Grok Register + Live Panel — container image.
#
# Runtime notes (matching DEPLOYMENT.md / README.md):
#   * Linux headless detection auto-enables Xvfb (GROK_USE_XVFB=auto).
#   * The panel relies on `psutil` reading /proc to safely start/stop jobs,
#     so the container MUST expose a readable procfs at /proc (see
#     docker-compose.yml) — do not mask it.
#   * Runtime credentials / logs are owner-only (UMask 0077 + harden script).

FROM python:3.11-slim-bookworm AS base

# Keep the environment deterministic and locale-safe.
ENV PYTHONUNBUFFERED=1 \
    PYTHONUTF8=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UMask=0077 \
    HOME=/opt/grok-register-panel \
    # Camoufox installs via platformdirs.user_cache_dir(); pin it inside the app
    # dir so the browser (fetched during build) is found by the runtime user.
    XDG_CACHE_HOME=/opt/grok-register-panel/.cache

# System packages required by Camoufox/Firefox (headless), Xvfb and network tooling.
# Keep procps for process visibility and ca-certificates for TLS.
RUN apt-get update && apt-get install -y --no-install-recommends \
        xvfb \
        xauth \
        libgtk-3-0 \
        libdbus-glib-1-2 \
        libxt6 \
        libxtst6 \
        libx11-xcb1 \
        libasound2 \
        libglib2.0-0 \
        libnss3 \
        libxcomposite1 \
        libxdamage1 \
        libxrandr2 \
        libgbm1 \
        libpango-1.0-0 \
        libcairo2 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libcups2 \
        libpci3 \
        libvpx7 \
        libevent-2.1-7 \
        libxslt1.1 \
        libwoff1 \
        libopus0 \
        libwebp7 \
        libwebpdemux2 \
        libenchant-2-0 \
        libgudev-1.0-0 \
        libsecret-1-0 \
        libhyphen0 \
        libgdk-pixbuf-2.0-0 \
        fonts-liberation \
        procps \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Dedicated non-root runtime user (UID/GID 1000 so host bind mounts are easy to
# own). Runtime directories stay owner-only (0700/0600).
RUN groupadd --gid 1000 grok-register \
    && useradd --gid 1000 --uid 1000 --home-dir /opt/grok-register-panel grok-register \
    && mkdir -p /opt/grok-register-panel

WORKDIR /opt/grok-register-panel

# Create the .venv and fetch the Camoufox browser engine inside the image.
# Copy only the dependency manifests first so layer cache is reused on code changes.
COPY requirements.txt requirements.lock.txt* ./
RUN python3 -m venv .venv \
    && .venv/bin/python -m pip install --upgrade pip \
    && .venv/bin/python -m pip install -r requirements.txt \
    && .venv/bin/python -m camoufox fetch \
    && .venv/bin/python -m pip check \
    && .venv/bin/python -m camoufox version

# Copy the full application source.
COPY . .

# Run the repository checks in-image, then enforce safe permissions on runtime dirs.
RUN PYTHON_BIN=.venv/bin/python scripts/run_tests.sh \
    && .venv/bin/python scripts/harden_runtime_permissions.py . \
    && chown -R grok-register:grok-register /opt/grok-register-panel

USER grok-register

EXPOSE 8787

VOLUME ["/opt/grok-register-panel/accounts", \
        "/opt/grok-register-panel/cpa_auth", \
        "/opt/grok-register-panel/grok2api_auth", \
        "/opt/grok-register-panel/log"]

ENTRYPOINT ["/opt/grok-register-panel/docker-entrypoint.sh"]