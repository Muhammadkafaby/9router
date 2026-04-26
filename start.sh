#!/usr/bin/env sh
set -eu

detect_reverse_proxy_network() {
  docker ps --format '{{.Names}}' 2>/dev/null |
    while IFS= read -r container_name; do
      case "$container_name" in
        *caddy*|*nginx*|*traefik*)
          docker inspect "$container_name" --format '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' 2>/dev/null || true
          ;;
      esac
    done |
    grep -Ev '^(bridge|host|none)$' |
    grep -Ev '^9router(_default)?$' |
    head -n 1
}

# Load .env so helper flags like REVERSE_PROXY_NETWORK work without manual export.
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

if [ -z "${REVERSE_PROXY_NETWORK:-}" ]; then
  REVERSE_PROXY_NETWORK="$(detect_reverse_proxy_network || true)"
  export REVERSE_PROXY_NETWORK
fi

set -- -f docker-compose.yml

if [ -n "${REVERSE_PROXY_NETWORK:-}" ] && [ -f docker-compose.proxy.yml ]; then
  set -- "$@" -f docker-compose.proxy.yml
fi

docker compose "$@" down --remove-orphans
docker rm -f 9router 2>/dev/null || true
docker compose "$@" up -d --build

if [ -n "${REVERSE_PROXY_NETWORK:-}" ]; then
  docker network connect "$REVERSE_PROXY_NETWORK" 9router 2>/dev/null || true
fi
