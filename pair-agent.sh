#!/usr/bin/env bash
# Attach (or re-attach) a Telegram bot to an already-deployed Pantheon agent,
# then restart it so the gateway reads the token (boot-only read).
#
#   ./pair-agent.sh <name> <telegram_bot_token> <allowed_user_ids> [home_channel]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

NAME="${1:?usage: pair-agent.sh <name> <bot_token> <allowed_user_ids> [home_channel]}"
BOT_TOKEN="${2:?need a Telegram bot token from @BotFather}"
ALLOWED="${3:?need Telegram allowed user id(s), comma-separated}"
HOME_CHANNEL="${4:-}"

SAFE="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')"
DIR="$ROOT/agents/$SAFE"
ENVF="$DIR/data/.env"
[ -f "$ENVF" ] || { echo "no such agent '$SAFE' ($ENVF missing) — spawn it first"; exit 1; }

# replace any existing Telegram lines, keep provider keys
sed -i '/^TELEGRAM_/d' "$ENVF"
{
  echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN"
  echo "TELEGRAM_ALLOWED_USERS=$ALLOWED"
  [ -n "$HOME_CHANNEL" ] && echo "TELEGRAM_HOME_CHANNEL=$HOME_CHANNEL"
} >> "$ENVF"
chmod 600 "$ENVF"
chown 10000:10000 "$ENVF" 2>/dev/null || true

echo "==> paired '$SAFE' — restarting to load the token"
( cd "$DIR" && docker compose up -d --force-recreate >/dev/null )
echo "    watch:   cd $DIR && docker compose logs -f"
echo "    healthy: '[Telegram] Connected to Telegram (polling mode)' + 'Gateway running with N platform(s)'"
