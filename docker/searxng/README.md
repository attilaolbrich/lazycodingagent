# SearXNG (local dev)

End users: the same setup steps are in the in-app guide **Help → Web Search** (topic **Local SearXNG with Docker**).

Docker Compose stack for a **local** SearXNG instance used with LazyCodingAgent **Web Search** (SearXNG provider). JSON search is enabled in `core-config/settings.yml` (required for the app).

## Quick start

```bash
cd docker/searxng
cp .env.example .env
# Edit .env and set SEARXNG_SECRET to a long random string if you reuse this stack beyond local dev.
docker compose up -d
```

Verify JSON search:

```bash
curl -s 'http://127.0.0.1:8080/search?q=test&format=json' | head -c 200
```

You should see JSON (not an HTML page).

Stop:

```bash
docker compose down
```

If `core-config/settings.yml` becomes root-owned after a container run, fix ownership so you can edit it:  
`docker run --rm -v "$PWD/core-config:/data" alpine chown $(id -u):$(id -g) /data/settings.yml`

## LazyCodingAgent

1. Open **Settings** → **Tools** → **Web Search**.
2. Enable Web Search and **Add** a connection: provider **SearXNG**, instance URL `http://127.0.0.1:8080`.
3. Click **Test**, then **OK**.

### Allow local instance URL

By default the app blocks private/local hosts. For this stack, use one of:

- Set `AllowPrivateInstances=true` under `[WebSearch]` in your user `config.ini`, or
- Launch LazyCodingAgent with `LCA_WEB_SEARCH_TRUSTED_LOCAL=1`.

## Upgrades

```bash
docker compose down
docker compose pull
docker compose up -d
```

See [SearXNG container installation](https://docs.searxng.org/admin/installation-docker.html) for upstream details.
