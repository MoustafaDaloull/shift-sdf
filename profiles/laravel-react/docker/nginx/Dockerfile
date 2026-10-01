# syntax=docker/dockerfile:1.7
# =============================================================================
# {{PROJECT_NAME}} — Nginx image
# -----------------------------------------------------------------------------
# Targets:
#   base        -> Nginx + shared config + healthz + placeholder page
#   development -> base; Laravel's public/ arrives via bind mount
#   api         -> base + Laravel public/ baked in (production API edge)
#   web         -> base + compiled React bundle baked in (production SPA host)
#
# WHY two production targets: the frontend and the backend deploy as
# independent units (app.<domain> and api.<domain>). Baking both into one
# image would couple their release cycles and force a full redeploy of the API
# to ship a CSS change.
# =============================================================================

ARG NGINX_VERSION=1.29
ARG ALPINE_VERSION=alpine

# Declared here, before the first FROM, because an ARG used in a `FROM`
# instruction must live in the global scope. Consumed by the `web` target.
ARG NODE_BUILD_IMAGE=local/node:build


# =============================================================================
# STAGE 1 — base
# =============================================================================
FROM nginx:${NGINX_VERSION}-${ALPINE_VERSION} AS base

# curl backs the container HEALTHCHECK. tzdata keeps access-log timestamps in
# the platform's timezone so logs line up with the PHP and MySQL containers.
RUN apk add --no-cache curl tzdata \
    && rm -rf /var/cache/apk/*

# Replace the stock config wholesale. The default ships a `server` block on :80
# that would shadow ours and serve the Nginx welcome page.
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf

# Reusable fragments, included by the vhosts.
COPY docker/nginx/snippets/ /etc/nginx/snippets/

# Served at `/` when Laravel is not installed yet, so a developer gets a useful
# page instead of a raw FastCGI "File not found".
COPY docker/nginx/html/placeholder.html /usr/share/nginx/placeholder/index.html

# The Laravel document root. Created empty so Nginx can start and pass its
# config test even before the application is scaffolded — without this, Nginx
# fails at boot on a missing `root` directory.
RUN mkdir -p /var/www/html/public

EXPOSE 80

# Asserts that Nginx itself is accepting and routing requests. `/healthz` is
# answered by Nginx directly and never touches PHP, so this checks exactly one
# service — see the comment in snippets/healthz.conf.
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -fsS http://127.0.0.1/healthz >/dev/null || exit 1


# =============================================================================
# STAGE 2 — development
# =============================================================================
FROM base AS development

# Laravel's public/ is bind-mounted at runtime by compose.dev.yaml. Nothing is
# copied in, so a change to a public asset needs no rebuild.
COPY docker/nginx/conf.d/laravel.dev.conf /etc/nginx/conf.d/default.conf


# =============================================================================
# STAGE 3 — api  (production Laravel edge)
# =============================================================================
FROM base AS api

COPY docker/nginx/conf.d/laravel.prod.conf /etc/nginx/conf.d/default.conf

# Where php-fpm answers. Compose reaches it by service name; a platform that
# runs php as a sidecar of the same service passes `127.0.0.1:9000`.
# Resolved at build time like CSP_API_ORIGIN below, so the image is
# self-consistent, and the grep fails the build if the placeholder survives.
# No `nginx -t` here: it resolves upstream host names, and `php` exists only on
# the Compose network, never at build time.
ARG PHP_FPM_UPSTREAM=php:9000
RUN sed -i "s|\${PHP_FPM_UPSTREAM}|${PHP_FPM_UPSTREAM}|g" /etc/nginx/conf.d/default.conf \
    && ! grep -q 'PHP_FPM_UPSTREAM' /etc/nginx/conf.d/default.conf

# Only public/ is copied — never the application source. Nginx must not be able
# to read .env, routes, or vendor code even if a path-traversal bug is found,
# because those files are simply not present in this image.
COPY backend/public/ /var/www/html/public/


# =============================================================================
# STAGE 4 — web  (production React SPA host)
# -----------------------------------------------------------------------------
# The compiled bundle comes from the Node image's `build` target, which is built
# first as its own image. Referencing it through a build ARG (rather than a
# hard-coded name) keeps this Dockerfile independent of the registry path and
# tag, which differ between local builds and a remote registry.
#
#   docker build --build-arg NODE_BUILD_IMAGE=<image:tag> --target web ...
#
# compose.prod.yaml wires this automatically. NODE_BUILD_IMAGE is declared at
# the top of this file (global scope) because ARGs used in FROM must be.
# =============================================================================

# `FROM ${ARG}` is resolved by BuildKit, so this aliases whatever image was
# passed in and lets the COPY below use a stable stage name.
FROM ${NODE_BUILD_IMAGE} AS node-assets

FROM base AS web

COPY docker/nginx/conf.d/spa.prod.conf /etc/nginx/conf.d/default.conf

# The SPA's CSP must name the API origin it is allowed to call, or every request
# is blocked by connect-src. Resolved at BUILD time — the same lifecycle as
# VITE_API_BASE_URL, which is likewise baked into the bundle — so the shipped
# image is self-consistent and needs no runtime templating.
ARG CSP_API_ORIGIN=https://api.example.com
RUN sed -i "s|\${CSP_API_ORIGIN}|${CSP_API_ORIGIN}|g" /etc/nginx/snippets/csp-spa.conf \
    && grep -q 'connect-src' /etc/nginx/snippets/csp-spa.conf

# Only the compiled static bundle ships. The Node runtime, node_modules, and the
# TypeScript sources are all discarded here.
COPY --from=node-assets /app/dist/ /usr/share/nginx/html/
