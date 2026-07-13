# Pantheon

[![CI](https://github.com/azzindani/Pantheon/actions/workflows/ci.yml/badge.svg)](https://github.com/azzindani/Pantheon/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/tag/azzindani/Pantheon?label=release)](https://github.com/azzindani/Pantheon/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

> **Status: v0.1.0, early/reference.** This is a working setup the author runs
> personally, published as a reference for the pattern (isolated-brain agent
> fleet on Hermes) rather than a polished, general-purpose tool. It assumes a
> Hostinger VPS with the Hermes agent stack already deployed — see
> [Prerequisites](#prerequisites). See [CHANGELOG.md](CHANGELOG.md) for release notes.

A fleet of distinct Hermes agents. Each agent is its own "human": its own
**persona**, its own **isolated memory**, its own **Telegram bot** — all sharing
one OpenRouter key and the same model.

Cloned from the Hostinger Hermes image (`ghcr.io/hostinger/hvps-hermes-agent`),
chosen because its data dir is bind-mounted, so each agent's whole brain is a
plain host folder you can copy, reset, back up, and inspect.

**Every agent runs in the SAME compose project as the existing Hostinger agent —
`hermes-agent-z4gq`** — so the whole thing is ONE group/stack (the original
`hermes-agent` + `hermes-dashboard` + the ten fleet agents), not a separate
project. `gen-compose.sh` writes `/docker/hermes-agent-z4gq/docker-compose.yml`
as `base/hermes-base.yml` (the pristine Hostinger services) + one service per
agent. Each agent still bind-mounts its own isolated brain at
`/root/Pantheon/agents/<name>/data`.

This control dir (`/root/Pantheon/`) holds the scripts, personas, seed, and
per-agent brains; the **generated compose lives in the hermes dir**, and that's
where you run `docker compose`.

## Prerequisites

- A host already running the Hostinger Hermes agent stack (`ghcr.io/hostinger/hvps-hermes-agent`,
  public image) via Docker Compose — this repo adds a fleet *alongside* that
  existing deployment, it doesn't stand one up from scratch.
- `docker` + `docker compose`, `bash`, `python3` with `pyyaml` (used by `gen-compose.sh`/CI).
- An OpenRouter API key (shared across the fleet) and, per agent you want reachable
  over Telegram, a bot token from [@BotFather](https://t.me/BotFather).
- Your own `shared.env` (gitignored, never committed) — see `README`'s
  [What's shared vs. isolated](#whats-shared-vs-isolated) for the keys it must hold.

## Layout

```
/root/Pantheon/            # control dir (scripts + data; in git)
  base/hermes-base.yml       #   pristine Hostinger compose (the 2 original services)
  gen-compose.sh             #   writes /docker/hermes-agent-z4gq/docker-compose.yml = base + agents
  shared.env                 #   OpenRouter+NVIDIA keys + ttyd admin login (gitignored)
  seed/                      #   blank-slate brain: shared config/skills, empty memory & persona
  personas/<name>.md         #   optional: persona text picked up at spawn time
  cron-prompts/<name>.md     #   daily briefing prompt per agent (used by add-cron.sh)
  web-helpers/               #   websearch.py / webfetch.py (deployed into each agent's data/bin)
  agents/<name>/data/        #   one agent's isolated brain (SOUL.md, memories/, kanban.db, .env)
  build-seed.sh  spawn-agent.sh  pair-agent.sh  add-cron.sh  gen-compose.sh
  ci/checks.sh               #   the checks run locally and by .github/workflows/ci.yml
  backups/                   #   redacted config snapshots of related stacks (see backups/README.md)
/docker/hermes-agent-z4gq/
  docker-compose.yml         # GENERATED — project hermes-agent-z4gq (run docker compose HERE)
```

Manage the fleet from `/docker/hermes-agent-z4gq/`, targeting a service by agent
name — e.g. `docker compose logs -f athena`, `docker compose up -d --force-recreate plutus`.
(The original `hermes-agent`/`hermes-dashboard` services are in the same group; don't recreate
them unless you mean to.)

## What's shared vs. isolated

| | Source | Shared or isolated |
|---|---|---|
| OpenRouter key | `shared.env` → stamped into each `data/.env` at spawn | **shared** value |
| Model + skills | `seed/config.yaml`, `seed/skills/` | **shared** |
| Persona | `agents/<name>/data/SOUL.md` | **isolated** |
| Memory ("its life") | `agents/<name>/data/memories/` + `state.db` | **isolated** |
| Tasks / cron / sessions | `agents/<name>/data/kanban.db`, `cron/`, `sessions/` | **isolated** |
| Telegram bot | `agents/<name>/data/.env` | **isolated** |

> The Hostinger gateway reads provider keys + Telegram token **only** from
> `/opt/data/.env` (= `data/.env`), not from container env. `shared.env` is the
> canonical key store that `spawn-agent.sh` copies into each agent's `data/.env`;
> it's also the compose `env_file` so `ADMIN_USERNAME/ADMIN_PASSWORD` reach ttyd.

## Add an agent

1. **Make its bot** in Telegram with [@BotFather](https://t.me/BotFather) → `/newbot` → copy the token.
   Each agent needs its **own** bot — a token can only be polled by one process.
2. *(optional)* Write its persona to `personas/<name>.md` (or edit `data/SOUL.md` after spawn).
3. Spawn from `/root/Pantheon/` (it regenerates the compose and starts the service automatically):
   ```bash
   ./spawn-agent.sh athena <BOT_TOKEN> <YOUR_TELEGRAM_USER_ID>
   (cd /docker/hermes-agent-z4gq && docker compose logs -f athena)
   ```
   Or deploy unpaired now and pair later: `./spawn-agent.sh athena` then `./pair-agent.sh athena <BOT_TOKEN> <USER_ID>`.
   Find `<YOUR_TELEGRAM_USER_ID>` by messaging `@userinfobot`.
   Healthy looks like: `[Telegram] Connected to Telegram (polling mode)`.

## Gotchas (baked in from prior ops)

- **`.env` is read at BOOT only.** After editing `.env`, persona, or model, run
  `docker compose up -d --force-recreate` — a plain `restart` re-reads `.env` but
  `--force-recreate` is the reliable path for env_file changes.
- **Telegram silently dead?** If the log shows only `api_server` platform and
  `No user allowlists configured`, the bot token / allowed-users weren't loaded —
  check `.env` then force-recreate.
- **One bot ↔ one process.** Never reuse the same bot token across two agents
  (Telegram drops to 409 conflicts). New agent ⇒ new BotFather bot.
- **Model is shared** in `seed/config.yaml` (`model.default` /
  `model.provider: openrouter`). Change it there and rebuild the seed to affect
  *new* agents; edit a live agent's `data/config.yaml` for just that one.
- **Rotating the OpenRouter key:** update `shared.env`, then re-stamp live agents —
  `for d in agents/*/data; do sed -i "/^OPENROUTER_API_KEY=/d" "$d/.env"; grep '^OPENROUTER_API_KEY=' shared.env >> "$d/.env"; done` —
  then `docker compose up -d --force-recreate`. New agents pick it up automatically.

## Reset / back up / remove an agent

(brains live under `/root/Pantheon/agents/`; `docker compose` runs in `/docker/hermes-agent-z4gq/`)
```bash
cd /root/Pantheon
# back up a brain
tar czf athena-brain-$(date +%F).tgz -C agents/athena data
# wipe its memory but keep persona+bot (give it amnesia)
: > agents/athena/data/memories/MEMORY.md ; : > agents/athena/data/memories/USER.md
rm -f agents/athena/data/sessions/* ; (cd /docker/hermes-agent-z4gq && docker compose up -d --force-recreate athena)
# remove entirely: stop+remove the service, drop its dir, regenerate the compose
(cd /docker/hermes-agent-z4gq && docker compose rm -sf athena) && rm -rf agents/athena && ./gen-compose.sh
```

## Daily research briefings (cron, weekdays only)

> **Status: opt-in, currently unscheduled.** No agent has a briefing cron job
> right now — the mechanism below works, but nothing fires until you run
> `add-cron.sh`.

Each agent *can* run **one briefing per day, Mondays–Fridays only** (`<min> <hour> * * 1-5`),
researching a deep/edge topic in its domain and delivering it to the owner's Telegram
DM. Give each agent a **different hour** so briefings arrive spread across the day
instead of all at once — no weekend noise.

Suggested spread (previously used, all currently unscheduled):

| hour (Asia/Jakarta) | agent | hour | agent |
|---|---|---|---|
| 06:00 | hestia | 11:00 | atlas |
| 07:00 | plutus | 13:00 | peitho |
| 08:00 | apollo | 14:00 | themis |
| 09:00 | prometheus | 15:00 | nemesis |
| 10:00 | athena | 16:00 | hephaestus |

```bash
./add-cron.sh hestia 6      # hour 6, Mon-Fri, Asia/Jakarta, -> telegram DM
./add-cron.sh plutus 7      # give each agent its own hour so they don't pile up
./add-cron.sh apollo 8 30   # optional 3rd arg = minute (default 0)
```

- The prompt comes from `cron-prompts/<name>.md`; jobs **store the prompt at
  create time**, so after editing a prompt you must remove+recreate the job
  (`docker exec -u 10000 hermes-<name> hermes cron remove briefing`, then re-add).
- Timezone is `Asia/Jakarta`, read from each agent's `config.yaml`
  (`timezone: Asia/Jakarta`); a gateway **restart** is needed for the scheduler
  to pick up a timezone change.
- **Run cron commands as the hermes user (`-u 10000`)** — `add-cron.sh` does this.
  Creating a job as root leaves `/opt/data/cron/jobs.json` root-owned and the
  scheduler fails with `EACCES`.
- **Deliveries only arrive after you open each bot in Telegram and press
  `/start`** (Telegram blocks bot-initiated DMs otherwise).
- Manage: `docker exec -u 10000 hermes-<name> hermes cron list|pause|resume|remove ...`

## Web access (local SearXNG, no API key)

The built-in `web_search` needs a paid key (Exa/Tavily/Firecrawl) and the browser
needs Chrome (excluded from the seed), so agents research via the local SearXNG
instance instead. `web-helpers/{websearch,webfetch}.py` are installed into each
agent's `data/bin/` and query `http://kea-prod-searxng-1:8080`. For that to work,
`gen-compose.sh` joins every agent to the external **`kea-prod_default`** network
(where SearXNG lives) — so if that stack's network is recreated, recreate the agents.

## Optional: web access via caddy-router

Telegram needs no inbound port. If you want the agent's ttyd terminal on the web,
add it to `/root/caddy-router` — **always `caddy validate` before recreating**, since
caddy owns 80/443 for every site. See the caddy-router notes.

## Rebuild the seed

`./build-seed.sh [reference-data-dir]` (default `/docker/hermes-agent-z4gq/data`).
Only affects agents spawned *after* the rebuild.

## Backups

`backups/` holds point-in-time snapshots of configs for related stacks that live
outside this repo (e.g. the `hermes-workspace` MCP setup). **Secrets are redacted
to `${PLACEHOLDER}` form** — supply real values from the relevant `.env` when
restoring. See [`backups/README.md`](backups/README.md) for what's captured and
how to restore. Same rule as everywhere else here: never commit real tokens,
keys, IDs, or `.env` files (the `.gitignore` enforces this; CI also scans tracked
files for secret-shaped strings).

## License

Apache License 2.0 — see [LICENSE](LICENSE). This is a personal reference
project (see [Status](#pantheon) above); issues/PRs aren't actively triaged,
but the code is free to use, fork, and adapt under the license terms.
