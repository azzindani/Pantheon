#!/usr/bin/env bash
# Spawn a new Pantheon agent: own isolated brain + own Telegram bot,
# sharing the fleet's OpenRouter key and model.
#
#   ./spawn-agent.sh <name> <telegram_bot_token> <allowed_user_ids> [home_channel]
#
#   name              short id, e.g. athena   (becomes container "pantheon-athena-agent")
#   telegram_bot_token token from @BotFather  (each agent needs its OWN bot)
#   allowed_user_ids  comma-separated Telegram numeric user id(s) allowed to talk to it
#   home_channel      (optional) default channel/chat id the agent posts to
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

NAME="${1:?usage: spawn-agent.sh <name> <bot_token> <allowed_user_ids> [home_channel]}"
BOT_TOKEN="${2:?need a Telegram bot token from @BotFather}"
ALLOWED="${3:?need Telegram allowed user id(s), comma-separated}"
HOME_CHANNEL="${4:-}"

SAFE="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')"
DIR="$ROOT/agents/$SAFE"

[ -d "$ROOT/seed" ] || { echo "seed/ missing — run ./build-seed.sh first"; exit 1; }
[ -e "$DIR" ]       && { echo "agent '$SAFE' already exists at $DIR"; exit 1; }

echo "==> creating agent '$SAFE'"
mkdir -p "$DIR"
cp -a "$ROOT/seed" "$DIR/data"

# persona: personas/<name>.md if you wrote one, else a stub to edit later
if [ -f "$ROOT/personas/$SAFE.md" ]; then
  cp "$ROOT/personas/$SAFE.md" "$DIR/data/SOUL.md"
  echo "    persona <- personas/$SAFE.md"
else
  printf 'You are %s, an agent in the Pantheon.\n\nDefine this persona here, then: docker compose restart\n' "$SAFE" > "$DIR/data/SOUL.md"
  echo "    persona <- stub (edit $DIR/data/SOUL.md)"
fi

# The gateway reads /opt/data/.env (= data/.env) at boot. It gets NOTHING from
# container env except the ttyd admin login. So data/.env carries the shared
# provider keys (copied from shared.env) + this agent's own Telegram identity.
grep -E '^(OPENROUTER_API_KEY|NVIDIA_API_KEY)=' "$ROOT/shared.env" > "$DIR/data/.env"
{
  echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN"
  echo "TELEGRAM_ALLOWED_USERS=$ALLOWED"
  [ -n "$HOME_CHANNEL" ] && echo "TELEGRAM_HOME_CHANNEL=$HOME_CHANNEL"
} >> "$DIR/data/.env"
chmod 600 "$DIR/data/.env"

sed "s/__NAME__/pantheon-$SAFE/g" "$ROOT/template/docker-compose.yml" > "$DIR/docker-compose.yml"

# match the in-container hermes uid (entrypoint also chowns, this is belt-and-suspenders)
chown -R 10000:10000 "$DIR/data" 2>/dev/null || true

cat <<EOF
==> agent '$SAFE' ready at $DIR
    start it:   cd $DIR && docker compose up -d && docker compose logs -f
    healthy:    "[Telegram] Connected to Telegram (polling mode)" + "Gateway running with N platform(s)"
    note:       .env is read at BOOT only — after editing .env, persona, or model, run: docker compose up -d --force-recreate
EOF
