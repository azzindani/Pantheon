#!/usr/bin/env bash
# Spawn a Pantheon agent: own isolated brain + (optionally) its own Telegram bot,
# sharing the fleet's OpenRouter key and model.
#
#   ./spawn-agent.sh <name> [telegram_bot_token] [allowed_user_ids] [home_channel]
#
# Omit the Telegram args to deploy an UNPAIRED agent (boots provider-only, no bot).
# Pair it later with:  ./pair-agent.sh <name> <bot_token> <allowed_user_ids>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

NAME="${1:?usage: spawn-agent.sh <name> [bot_token] [allowed_user_ids] [home_channel]}"
BOT_TOKEN="${2:-}"
ALLOWED="${3:-}"
HOME_CHANNEL="${4:-}"

SAFE="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')"
DIR="$ROOT/agents/$SAFE"

[ -d "$ROOT/seed" ] || { echo "seed/ missing — run ./build-seed.sh first"; exit 1; }
[ -e "$DIR" ]       && { echo "agent '$SAFE' already exists at $DIR"; exit 1; }

echo "==> creating agent '$SAFE'"
mkdir -p "$DIR"
cp -a "$ROOT/seed" "$DIR/data"

# persona: personas/<name>.md if present, else a stub to edit later
if [ -f "$ROOT/personas/$SAFE.md" ]; then
  cp "$ROOT/personas/$SAFE.md" "$DIR/data/SOUL.md"
  echo "    persona <- personas/$SAFE.md"
else
  printf 'You are %s, an agent in the Pantheon.\n\nDefine this persona here, then: docker compose restart\n' "$SAFE" > "$DIR/data/SOUL.md"
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

sed "s/__NAME__/pantheon-$SAFE/g" "$ROOT/template/docker-compose.yml" > "$DIR/docker-compose.yml"

# Pre-create the gateway log as hermes (uid 10000). The root entrypoint opens this
# path with a shell '>>' redirect; if the file doesn't exist yet it's created
# ROOT-owned and the gateway (running as hermes) crashes with PermissionError.
mkdir -p "$DIR/data/logs"
: > "$DIR/data/logs/gateway.log"
chown -R 10000:10000 "$DIR/data" 2>/dev/null || true

echo "==> agent '$SAFE' ready (paired=$PAIRED) at $DIR"
echo "    start it:  cd $DIR && docker compose up -d && docker compose logs -f"
if [ "$PAIRED" = no ]; then
  echo "    UNPAIRED — boots provider-only (no Telegram). Pair when you have a token:"
  echo "               ./pair-agent.sh $SAFE <bot_token> <allowed_user_ids>"
else
  echo "    healthy:   '[Telegram] Connected to Telegram (polling mode)' + 'Gateway running with N platform(s)'"
fi
