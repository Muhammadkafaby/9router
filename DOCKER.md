# Docker

This project ships with a `Dockerfile` plus a `docker-compose.yml` that runs `9router` on a dedicated localhost-only backend port.

This default compose file is safe on servers that already have Nginx or Caddy bound to `80` and `443`.

If your existing reverse proxy itself runs in Docker, use the included `docker-compose.proxy.yml` override so that both containers can communicate on a shared Docker network.

## Recommended production flow

1. Copy the env file and set production values:

```bash
cp .env.example .env
```

Minimum production values for a reverse-proxied HTTPS setup:

```env
JWT_SECRET=change-me-to-a-long-random-secret
INITIAL_PASSWORD=change-me
DATA_DIR=/app/data
ROUTER_HOST_BIND=127.0.0.1
ROUTER_HOST_PORT=20128
REVERSE_PROXY_NETWORK=landstation-laravel_default
PORT=20128
HOSTNAME=0.0.0.0
NODE_ENV=production
BASE_URL=http://127.0.0.1:20128
NEXT_PUBLIC_BASE_URL=https://ai.devstacklabs.net
API_KEY_SECRET=endpoint-proxy-api-key-secret
MACHINE_ID_SALT=endpoint-proxy-salt
AUTH_COOKIE_SECURE=true
REQUIRE_API_KEY=true
```

2. Start the stack:

```bash
docker compose up -d --build
```

Or use the helper script:

```bash
./start.sh
```

`start.sh` reads `.env` automatically, so setting `REVERSE_PROXY_NETWORK` there is enough.

If your existing Caddy or Nginx runs in Docker, attach `9router` to that external network too:

```bash
docker network ls
docker compose -f docker-compose.yml -f docker-compose.proxy.yml up -d --build
```

The helper script also supports that mode:

```bash
./start.sh
```

3. Follow logs:

```bash
docker compose logs -f router
```

## What the stack exposes

- Host backend port: `ROUTER_HOST_BIND:ROUTER_HOST_PORT` on the VPS, default `127.0.0.1:20128`
- Internal app port: `20128` inside the container
- Public HTTPS URL stays on your existing reverse proxy, for example `https://ai.devstacklabs.net`

Example direct backend URL on the VPS:

```text
http://127.0.0.1:20128
```

If you change `ROUTER_HOST_PORT`, update the reverse proxy upstream to match.

Important:

- The compose file binds only to `127.0.0.1`, so `9router` is not directly reachable from the internet.
- You do not need to open `ROUTER_HOST_PORT` in `ufw` for a same-host reverse proxy setup.
- `ufw allow` rules are not the same thing as a port already being used; use `ss -tulpn` to see active listeners.
- A Dockerized reverse proxy cannot use `127.0.0.1:20128` to reach `9router` unless it shares the host network.
- `REVERSE_PROXY_NETWORK` should match the existing Docker network used by your reverse proxy stack.

If you intentionally want direct public access for testing, set:

```env
ROUTER_HOST_BIND=0.0.0.0
```

Then the backend becomes reachable at `http://<server-ip>:ROUTER_HOST_PORT`.

## Volumes

- `9router-data`: persistent app state under `/app/data`

## Restart or rebuild

```bash
docker compose up -d --build
docker compose restart
```

## Stop the stack

```bash
docker compose down
```

## Existing Caddy or Nginx

If another reverse proxy already owns ports `80` and `443`, keep using it and proxy your domain to the backend port exposed by `docker-compose.yml`.

Example Caddy site block when Caddy runs on the host:

```caddy
ai.devstacklabs.net {
    encode gzip zstd
    reverse_proxy 127.0.0.1:20128
}
```

If your existing Caddy runs in a different Docker project, either:

- attach both services to the same external Docker network and proxy to `9router:20128`
- or expose `9router` on a non-loopback host port and proxy to that host-reachable address

`Caddyfile.example` is included as a starting point.

Example Caddy site block when Caddy itself runs in Docker on the same external network:

```caddy
ai.devstacklabs.net {
    encode gzip zstd
    reverse_proxy 9router:20128
}
```

## Bare Docker alternative

If you do not want HTTPS or Caddy, you can still run the app directly:

```bash
docker build -t 9router .
docker run -d \
  --name 9router \
  -p 20128:20128 \
  --env-file .env \
  -v 9router-data:/app/data \
  9router
```

That mode serves plain HTTP on `http://<host>:20128`.
