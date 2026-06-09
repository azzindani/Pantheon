#!/usr/bin/env bash
# Attach (or re-attach) a Telegram bot to a deployed Pantheon agent, then
# recreate just that service in the "pantheon" project (boot-only token read).
#
#   ./pair-agent.sh <name> <telegram_bot_token> <allowed_user_ids> [home_channel]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

NAME="${1:?usage: pair-agent.sh <name> <bot_token> <allowed_user_ids> [home_channel]}"
BOT_TOKEN="${2:?need a Telegram bot token from @BotFather}"
ALLOWED="${3:?need Telegram allowed user id(s), comma-separated}"
HOME_CHANNEL="${4:-}"

SAFE="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')"
ENVF="$ROOT/agents/$SAFE/data/.env"
[ -f "$ENVF" ] || { echo "no such agent '$SAFE' ($ENVF missing) — spawn it first"; exit 1; }

sed -i '/^TELEGRAM_/d' "$ENVF"
{
  echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN"
  echo "TELEGRAM_ALLOWED_USERS=$ALLOWED"
  [ -n "$HOME_CHANNEL" ] && echo "TELEGRAM_HOME_CHANNEL=$HOME_CHANNEL"
} >> "$ENVF"
chmod 600 "$ENVF"; chown 10000:10000 "$ENVF" 2>/dev/null || true

echo "==> paired '$SAFE' — recreating service to load the token"
( cd "$ROOT" && docker compose up -d --force-recreate "$SAFE" >/dev/null )
echo "    watch:   docker compose -f $ROOT/docker-compose.yml logs -f $SAFE"
echo "    healthy: '[Telegram] Connected to Telegram (polling mode)'"
