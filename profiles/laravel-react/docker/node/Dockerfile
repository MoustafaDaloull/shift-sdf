# syntax=docker/dockerfile:1.7
# =============================================================================
# {{PROJECT_NAME}} — Node / React 19 + TypeScript + Vite image
# -----------------------------------------------------------------------------
# Targets:
#   base         -> Node 22 LTS runtime + non-root user
#   development  -> long-running Vite dev server with HMR (code bind-mounted)
#                   + the distribution's Chromium for the browser gates
#   build        -> `npm run build`, emits the static bundle to /app/dist
#
# There is no `production` runtime target on purpose. A React SPA compiles to
# static files; shipping a Node process to serve them would add a runtime, a
# memory footprint, and an attack surface for zero benefit. compose.prod.yaml
# copies the `build` output into the Nginx image instead.
#
# This split matches an architecture where the frontend is fully decoupled
# from the backend and independently deployable.
# =============================================================================

ARG NODE_VERSION=22.21
ARG ALPINE_VERSION=3.22


# =============================================================================
# STAGE 1 — base
# =============================================================================
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS base

ARG APP_USER=app
ARG APP_UID=1000
ARG APP_GID=1000

# The official Node image already ships a `node` user at uid 1000. Reuse it when
# the requested uid matches, and only create a new user when it does not — this
# keeps bind-mounted files writable from the host on WSL2 without duplicating
# uid 1000.
RUN set -eux; \
    if [ "${APP_UID}" = "1000" ] && [ "${APP_GID}" = "1000" ]; then \
        # Rename the stock user so logs and `whoami` are project-consistent.
        deluser --remove-home node 2>/dev/null || true; \
        addgroup -g "${APP_GID}" "${APP_USER}"; \
        adduser -u "${APP_UID}" -G "${APP_USER}" -h /home/"${APP_USER}" -s /bin/sh -D "${APP_USER}"; \
    else \
        if ! getent group "${APP_GID}" >/dev/null; then addgroup -g "${APP_GID}" "${APP_USER}"; fi; \
        if ! getent passwd "${APP_UID}" >/dev/null; then \
            adduser -u "${APP_UID}" -G "$(getent group "${APP_GID}" | cut -d: -f1)" -h /home/"${APP_USER}" -s /bin/sh -D "${APP_USER}"; \
        fi; \
    fi

# tini: Vite spawns child processes (esbuild, the TypeScript watcher). Without a
# real init, those become zombies and Ctrl-C / `docker stop` leaves them running.
# curl is needed by the container HEALTHCHECK.
RUN apk add --no-cache tini curl \
    && rm -rf /var/cache/apk/*

# git is required because some npm dependencies resolve to git+https URLs.
RUN apk add --no-cache git

WORKDIR /app

# `node_modules` is created here, empty, on purpose. Docker initialises a
# named volume from whatever the image holds at the mount path - including
# its ownership - and creates it owned by root when the path does not exist.
# The container then runs as the app user and `npm install` dies with EACCES
# on the first package it tries to write. Measured while scaffolding the
# reference frontend: the service restart-looped, and the failure is
# invisible until something first tries to install.
RUN mkdir -p /app/node_modules && chown -R "${APP_UID}:${APP_GID}" /app

ENV APP_USER=${APP_USER} \
    # Disable npm's update nag: it writes to stderr and pollutes container logs.
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    # Keep the npm cache inside the image/volume rather than in a home directory
    # that may be shadowed by a bind mount.
    NPM_CONFIG_CACHE=/home/${APP_USER}/.npm

COPY --chmod=0755 docker/node/entrypoint.sh   /usr/local/bin/app-node-entrypoint
COPY --chmod=0755 docker/node/healthcheck.sh  /usr/local/bin/app-node-healthcheck


# =============================================================================
# STAGE 2 — development
# Runs the Vite dev server. Source arrives via bind mount from compose.dev.yaml.
# =============================================================================
FROM base AS development

# ── Chromium for the frontend browser gates (flows · visual · a11y) ──────────
# Playwright ships its own Chromium, and it is built against glibc: on Alpine it
# installs and then fails to start. The choices were a second, Debian-based
# image carried for one gate, or the distribution's own browser driven by
# Playwright. This takes the second - one image, one node service, and the
# browser Playwright launches is named explicitly in playwright.config.ts
# rather than discovered.
#
# The fonts are not optional decoration. Without them Chromium falls back to a
# box glyph for every Arabic character, and the visual gate would be comparing
# baselines of an unreadable page while reporting success. `ttf-dejavu` covers
# Arabic; each font added is another input the baselines depend on, so add
# none without a reason.
#
# Installed in the development stage alone: the production image serves static
# files built elsewhere and has no business carrying a browser.
USER root
RUN apk add --no-cache chromium ttf-dejavu \
    && chromium-browser --version

ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_PATH=/usr/bin/chromium-browser

ARG VITE_PORT=5173
ENV VITE_PORT=${VITE_PORT} \
    NODE_ENV=development \
    # Vite must bind 0.0.0.0, not localhost: a server bound to the container's
    # loopback is unreachable from the host even with a published port.
    VITE_HOST=0.0.0.0 \
    # Chokidar's native inotify does not fire for edits made on the Windows host
    # and propagated through the Docker Desktop 9p/virtiofs bridge. Polling is
    # slower but is the only reliable way to get HMR on Windows bind mounts.
    # Set to false when the checkout lives inside the WSL2 filesystem, where
    # native file events work and polling only wastes CPU.
    CHOKIDAR_USEPOLLING=true \
    CHOKIDAR_INTERVAL=400

USER ${APP_USER}

EXPOSE ${VITE_PORT}

# Reports healthy while idling (no app scaffolded yet) and probes Vite once the
# app exists — see docker/node/healthcheck.sh for why that distinction matters.
# `start-period` is generous because the first boot may run a full `npm install`.
HEALTHCHECK --interval=15s --timeout=8s --start-period=180s --retries=5 \
    CMD ["app-node-healthcheck"]

ENTRYPOINT ["/sbin/tini", "--", "app-node-entrypoint"]
CMD ["npm", "run", "dev"]


# =============================================================================
# STAGE 3 — build (build-only; output is copied into the Nginx image)
# =============================================================================
FROM base AS build

ENV NODE_ENV=production

# NOTE: requires frontend/package.json to exist. Until the React application is
# scaffolded this target cannot build — which is why compose.dev.yaml targets
# `development` only. See docker/README.md.
#
# Manifests are copied first and installed on their own layer so that editing a
# component does not invalidate the (slow) dependency install.
COPY frontend/package.json frontend/package-lock.json ./

# `npm ci` — not `npm install` — because it installs exactly what the lockfile
# pins and fails if the lockfile is stale. A build must be reproducible.
#
# `--include=dev` is required, not optional: NODE_ENV=production above makes
# npm skip devDependencies, and the compiler and bundler (`typescript`, `vite`)
# ARE devDependencies. Without it `npm run build` died with `sh: tsc: not
# found` (exit 127) on the first real build. Nothing installed here ships: the
# `web` image copies only /app/dist.
RUN --mount=type=cache,target=/root/.npm \
    npm ci --include=dev --no-audit --no-fund

COPY frontend/ ./

# Vite bakes VITE_*-prefixed variables into the bundle at BUILD time, so the API
# origin must be supplied here rather than at runtime. Anything passed here is
# publicly visible in the shipped JavaScript — never pass a secret.
ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

RUN npm run build

# Result: /app/dist — consumed by docker/nginx/Dockerfile's `web` target.
