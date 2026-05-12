# syntax=docker/dockerfile:1.7
ARG BUN_IMAGE=oven/bun:1.3.2-alpine

FROM ${BUN_IMAGE} AS base
WORKDIR /app

# =========================
# Builder
# =========================
FROM base AS builder

RUN apk --no-cache add \
    nodejs \
    npm \
    python3 \
    make \
    g++ \
    linux-headers

COPY package.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm install

COPY . ./

ENV NEXT_TELEMETRY_DISABLED=1

RUN npm run build

# =========================
# Runner
# =========================
FROM ${BUN_IMAGE} AS runner

WORKDIR /app

LABEL org.opencontainers.image.title="9router"

ENV NODE_ENV=production
ENV PORT=20128
ENV HOSTNAME=0.0.0.0
ENV DATA_DIR=/app/data
ENV NEXT_TELEMETRY_DISABLED=1

# Next standalone output
COPY --from=builder /app/.next/standalone ./

# Static assets
COPY --from=builder /app/.next/static ./app/.next/static
COPY --from=builder /app/public ./app/public

# Extra runtime files
# Extra runtime files
COPY --from=builder /app/open-sse ./app/open-sse
COPY --from=builder /app/src/mitm ./app/src/mitm
COPY --from=builder /app/src/shared ./app/src/shared

# Extra dependency required by MITM child process
COPY --from=builder /app/node_modules/node-forge ./app/node_modules/node-forge

# Prepare writable data dir
RUN mkdir -p /app/data && chown -R bun:bun /app

# Runtime entrypoint
RUN apk --no-cache add su-exec && \
    printf '#!/bin/sh\n\
DATA_PATH="${DATA_DIR:-/app/data}"\n\
mkdir -p "$DATA_PATH"\n\
chown -R bun:bun /app\n\
exec su-exec bun "$@"\n' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

EXPOSE 20128

ENTRYPOINT ["/entrypoint.sh"]

# IMPORTANT:
# Based on your standalone output:
# .next/standalone/9router/server.js
CMD ["node","app/server.js"]
