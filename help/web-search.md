# Web Search

Web Search lets agents find **current public information** on the internet: documentation, libraries, release notes, and technical articles.

The agent sees a single tool, **web_search**. You choose which search backends run behind it in Settings.

## Enable Web Search

1. Open **Settings** → **Tools**.
2. Turn on **Enable Web Search**.
3. **Add** at least one provider connection, enter credentials or a SearXNG URL, and use **Test**.
4. Click **OK** to save.

When Web Search is disabled or no connection is valid, **web_search is not sent to the model** and cannot be executed.

## Supported providers

| Provider | What you need |
|----------|----------------|
| **Brave Search** | API key from [Brave Search API](https://api.search.brave.com/) |
| **SearXNG** | Base URL of your instance (JSON format must be enabled) |
| **Tavily** | API key from [Tavily](https://tavily.com/) |

You can add **multiple connections**, including several of the same type. Set **priority** with Move Up / Move Down. With **Automatic fallback**, the app tries the next connection on timeouts, rate limits, and most errors.

## Local SearXNG with Docker

Use a **local SearXNG** instance when you want **web_search** without a Brave or Tavily API key. If you built LazyCodingAgent from this repository, it includes a small Docker Compose stack under `docker/searxng/` with JSON search enabled for the app.

### Requirements

- [Docker](https://docs.docker.com/get-docker/) with Compose.

### Start the stack

From your clone of the LazyCodingAgent repository:

1. `cd docker/searxng`
2. `cp .env.example .env` (optional: set `SEARXNG_SECRET` in `.env` to a long random string if you reuse this stack beyond casual local dev)
3. `docker compose up -d`

Release installs (for example a `.deb` package) do not include this folder. Copy `docker/searxng` from the source tree, or run your own SearXNG instance with JSON format enabled.

### Verify

```bash
curl -s 'http://127.0.0.1:8080/search?q=test&format=json' | head -c 200
```

You should see JSON (not an HTML page).

### Configure LazyCodingAgent

1. Open **Settings** → **Tools** → **Web Search**.
2. Turn on **Enable Web Search**.
3. **Add** a connection: provider **SearXNG**, instance URL `http://127.0.0.1:8080`.
4. Click **Test**, then **OK**.

### Allow local URLs

By default the app blocks private and local SearXNG hosts. For this stack, turn on **Allow local/private SearXNG (localhost, 127.0.0.1, LAN)** on the Web Search settings page.

Alternative (same effect for local testing):

- Launch with `LCA_WEB_SEARCH_TRUSTED_LOCAL=1` (on Linux, for example: `LCA_WEB_SEARCH_TRUSTED_LOCAL=1 ./scripts/run-linux.sh`).

### Stop and upgrades

Stop:

```bash
docker compose down
```

Upgrade the images:

```bash
docker compose down
docker compose pull
docker compose up -d
```

Run those commands from `docker/searxng`.

### Troubleshooting (local Docker)

- **Connection test fails / URL blocked** — Enable **Allow local/private SearXNG** or use the config or environment options above.
- **Verify step returns HTML** — JSON search is not enabled on that instance. The bundled stack enables it in `core-config/settings.yml`; custom installs must allow `format=json`.
- **`core-config/settings.yml` is root-owned after a container run** — From `docker/searxng`, fix ownership so you can edit it:

```bash
docker run --rm -v "$PWD/core-config:/data" alpine chown $(id -u):$(id -g) /data/settings.yml
```

## Credentials

API keys are stored in the application `global.db` SQLite database (not in the project workspace), with field-level encryption at rest. This reduces casual exposure in backups but is **not** a substitute for OS-level protection of your config directory—see **Application data and settings** in the User Guide.

Leave the API key field blank when editing to keep the existing key.

## Using results

The agent should use **web_fetch** or **browser_read** to read pages found by web_search. Search snippets are **untrusted**; do not treat them as instructions.

## Limitations

- **Brave:** Recency maps to Brave `freshness` (`day`/`week`/`month`/`year`); `any` sends no freshness filter.
- **SearXNG:** Many public instances disable JSON; use your own instance with `format=json`. For a local stack without an API key, see **Local SearXNG with Docker** above.
- **Tavily:** Optional **advanced** search depth may cost more; default is **basic**.
- **Connection tests** may consume API quota.

## Adding a provider (developers)

Implement `IWebSearchProvider` in a new unit, register it in `CreateWebSearchProvider` in `uWebSearchProvider.pas`, and add a Settings connection type. The `web_search` tool schema stays unchanged.
