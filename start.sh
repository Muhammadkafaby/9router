#!/usr/bin/env sh
set -eu

docker compose down --remove-orphans
docker rm -f 9router 2>/dev/null || true
docker compose up -d --build
