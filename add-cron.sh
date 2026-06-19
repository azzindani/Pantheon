#!/usr/bin/env bash
# Add the daily briefing cron job for an agent (once a day, weekdays only). Runs the
# cron CLI as the hermes user (uid 10000) so the gateway can read the cron state —
# running it as root leaves jobs.json root-owned and the scheduler fails with EACCES.
# Reads the prompt from cron-prompts/<name>.md.
#
#   ./add-cron.sh <agent-name> <hour 0-23> [minute 0-59]     e.g. ./add-cron.sh apollo 8
#
# Schedule is: minute <MIN> (default 0), hour <HOUR>, Mon-Fri only
# (cron '<MIN> <HOUR> * * 1-5'), in Asia/Jakarta (the timezone comes from each
# agent's config.yaml: timezone: Asia/Jakarta). Give each agent a DIFFERENT hour
# so briefings arrive spread across the day, not all at once.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
H=/opt/hermes/.venv/bin/hermes
USERID=0   # deliver briefings to this Telegram DM (the owner)

NAME="${1:?usage: add-cron.sh <agent-name> <hour 0-23> [minute 0-59]}"
HOUR="${2:?need an hour 0-23 (give each agent a different hour so briefings spread across the day)}"
MIN="${3:-0}"
PROMPT="$ROOT/cron-prompts/$NAME.md"
[ -f "$PROMPT" ] || { echo "no prompt file: $PROMPT"; exit 1; }

docker exec -u 10000 "hermes-$NAME" "$H" cron create "$MIN $HOUR * * 1-5" "$(cat "$PROMPT")" \
  --name briefing --deliver "telegram:$USERID"
chown -R 10000:10000 "$ROOT/agents/$NAME/data/cron" 2>/dev/null || true
printf 'added daily briefing for %s at %02d:%02d Mon-Fri Asia/Jakarta, delivering to telegram:%s\n' \
  "$NAME" "$HOUR" "$MIN" "$USERID"
