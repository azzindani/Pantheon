# Pantheon

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
`/docker/pantheon/agents/<name>/data`.

This control dir (`/docker/pantheon/`) holds the scripts, personas, seed, and
per-agent brains; the **generated compose lives in the hermes dir**, and that's
where you run `docker compose`.

## Layout

```
/docker/pantheon/            # control dir (scripts + data; in git)
  base/hermes-base.yml       #   pristine Hostinger compose (the 2 original services)
  gen-compose.sh             #   writes /docker/hermes-agent-z4gq/docker-compose.yml = base + agents
  shared.env                 #   OpenRouter+NVIDIA keys + ttyd admin login (gitignored)
  seed/                      #   blank-slate brain: shared config/skills, empty memory & persona
  personas/<name>.md         #   optional: persona text picked up at spawn time
  agents/<name>/data/        #   one agent's isolated brain (SOUL.md, memories/, kanban.db, .env)
  build-seed.sh  spawn-agent.sh  pair-agent.sh
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
3. Spawn from `/docker/pantheon/` (it regenerates the compose and starts the service automatically):
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

(brains live under `/docker/pantheon/agents/`; `docker compose` runs in `/docker/hermes-agent-z4gq/`)
```bash
cd /docker/pantheon
# back up a brain
tar czf athena-brain-$(date +%F).tgz -C agents/athena data
# wipe its memory but keep persona+bot (give it amnesia)
: > agents/athena/data/memories/MEMORY.md ; : > agents/athena/data/memories/USER.md
rm -f agents/athena/data/sessions/* ; (cd /docker/hermes-agent-z4gq && docker compose up -d --force-recreate athena)
# remove entirely: stop+remove the service, drop its dir, regenerate the compose
(cd /docker/hermes-agent-z4gq && docker compose rm -sf athena) && rm -rf agents/athena && ./gen-compose.sh
```

## Optional: web access via caddy-router

Telegram needs no inbound port. If you want the agent's ttyd terminal on the web,
add it to `/root/caddy-router` — **always `caddy validate` before recreating**, since
caddy owns 80/443 for every site. See the caddy-router notes.

## Rebuild the seed

`./build-seed.sh [reference-data-dir]` (default `/docker/hermes-agent-z4gq/data`).
Only affects agents spawned *after* the rebuild.
