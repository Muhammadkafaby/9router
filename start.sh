#!/usr/bin/env sh
set -eu

# Load .env so helper flags like REVERSE_PROXY_NETWORK work without manual export.
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

set -- -f docker-compose.yml

if [ -n "${REVERSE_PROXY_NETWORK:-}" ] && [ -f docker-compose.proxy.yml ]; then
  set -- "$@" -f docker-compose.proxy.yml
fi

docker compose "$@" down --remove-orphans
docker rm -f 9router 2>/dev/null || true
docker compose "$@" up -d --build
