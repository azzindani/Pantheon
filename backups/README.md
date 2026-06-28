# Config backups

Point-in-time backups of configs touched outside this repo. Secrets are redacted
to `${PLACEHOLDER}` form — supply real values from the relevant `.env` when
restoring.

## hermes-workspace-xo2x/

The separate Nous/outsourc-e Hermes stack at `/docker/hermes-workspace-xo2x/`
(gateway `nousresearch/hermes-agent` + web UI `ghcr.io/outsourc-e/hermes-workspace`).

- **`docker-compose.yml`** — the live compose. Note it joins the external
  `harnesses_net` network so the gateway can reach the shared `web-mcp` sidecar.
- **`config.yaml`** — the gateway config from the `hermes-agent-data` volume
  (`/opt/data/config.yaml`). The `mcp_servers:` block at the bottom wires two
  MCP servers (added 2026-06-28, mirroring the Harnesses `claude` harness):
    - `folio` → `https://folio.example.com/mcp` (Bearer `${FOLIO_MCP_TOKEN}` — redacted)
    - `web`   → `http://web-mcp:7070/mcp` (DuckDuckGo `search` + `fetch_content`, no auth)

### Restore
1. Restore files: `docker-compose.yml` → `/docker/hermes-workspace-xo2x/`;
   `config.yaml` → the `hermes-agent-data` volume at `/opt/data/config.yaml`.
2. Put the real Folio token back in `config.yaml` (it lives in
   `/root/Harnesses/.env` as `FOLIO_MCP_TOKEN`).
3. Ensure `harnesses_net` exists (it's owned by the Harnesses stack) and the
   `web-mcp` container is up.
4. `cd /docker/hermes-workspace-xo2x && docker compose up -d`
5. Verify: `docker exec …-hermes-agent-1 hermes mcp list` → both `✓ enabled`.

## web-mcp/

Source for the free DuckDuckGo web-search MCP sidecar (`harness-web-mcp:latest`,
container `web-mcp` on `harnesses_net`). Built from the Harnesses repo
(`/root/Harnesses/web-mcp/`); copied here so the hermes-workspace MCP setup is
self-contained. Serves Streamable HTTP at `:7070/mcp` with Host-header
allow-listing disabled (private network).
