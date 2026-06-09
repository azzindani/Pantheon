#!/usr/bin/env bash
# Spawn a Pantheon agent: own isolated brain + (optionally) its own Telegram bot,
# sharing the fleet's OpenRouter key and model. All agents live in ONE compose
# project ("pantheon") = one group/stack; each keeps its own brain at agents/<name>/data.
#
#   ./spawn-agent.sh <name> [telegram_bot_token] [allowed_user_ids] [home_channel]
#
# Omit the Telegram args to deploy UNPAIRED (boots provider-only, no bot).
# Pair later with:  ./pair-agent.sh <name> <bot_token> <allowed_user_ids>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
HERMES_DIR=/docker/hermes-agent-z4gq   # the fleet lives in THIS compose project (one group)

NAME="${1:?usage: spawn-agent.sh <name> [bot_token] [allowed_user_ids] [home_channel]}"
BOT_TOKEN="${2:-}"; ALLOWED="${3:-}"; HOME_CHANNEL="${4:-}"

SAFE="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')"
DIR="$ROOT/agents/$SAFE"

[ -d "$ROOT/seed" ] || { echo "seed/ missing — run ./build-seed.sh first"; exit 1; }
[ -e "$DIR" ]       && { echo "agent '$SAFE' already exists at $DIR"; exit 1; }

echo "==> creating agent '$SAFE'"
mkdir -p "$DIR"
cp -a "$ROOT/seed" "$DIR/data"

if [ -f "$ROOT/personas/$SAFE.md" ]; then
  cp "$ROOT/personas/$SAFE.md" "$DIR/data/SOUL.md"; echo "    persona <- personas/$SAFE.md"
else
  printf 'You are %s, an agent in the Pantheon.\n\nDefine this persona here, then: re-run gen-compose and restart.\n' "$SAFE" > "$DIR/data/SOUL.md"
  echo "    persona <- stub (edit $DIR/data/SOUL.md)"
fi

# data/.env = what the gateway reads at boot: shared provider keys (+ Telegram if paired now)
grep -E '^(OPENROUTER_API_KEY|NVIDIA_API_KEY)=' "$ROOT/shared.env" > "$DIR/data/.env"
if [ -n "$BOT_TOKEN" ] && [ -n "$ALLOWED" ]; then
  {
    echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN"
    echo "TELEGRAM_ALLOWED_USERS=$ALLOWED"
    [ -n "$HOME_CHANNEL" ] && echo "TELEGRAM_HOME_CHANNEL=$HOME_CHANNEL"
  } >> "$DIR/data/.env"
  PAIRED=yes
else
  PAIRED=no
fi
chmod 600 "$DIR/data/.env"

# Pre-create gateway.log as hermes (uid 10000): the root entrypoint opens it with a
# shell '>>' redirect; if absent it's created root-owned and the gateway crashes.
mkdir -p "$DIR/data/logs"; : > "$DIR/data/logs/gateway.log"
chown -R 10000:10000 "$DIR/data" 2>/dev/null || true

# regenerate the hermes-agent-z4gq compose (base + all agents) and start this service
"$ROOT/gen-compose.sh" >/dev/null
( cd "$HERMES_DIR" && docker compose up -d "$SAFE" >/dev/null 2>&1 ) \
  && echo "    started service '$SAFE' in group 'hermes-agent-z4gq'" \
  || echo "    created; start with: (cd $HERMES_DIR && docker compose up -d $SAFE)"

echo "==> agent '$SAFE' ready (paired=$PAIRED)"
echo "    logs:  (cd $HERMES_DIR && docker compose logs -f $SAFE)"
[ "$PAIRED" = no ] && echo "    pair:  ./pair-agent.sh $SAFE <bot_token> <allowed_user_ids>"
