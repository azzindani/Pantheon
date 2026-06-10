#!/usr/bin/env bash
# Add the briefing cron job for an agent (every 3 hours). Runs the cron CLI as the hermes
# user (uid 10000) so the gateway can read the cron state — running it as root
# leaves jobs.json root-owned and the scheduler fails with EACCES.
# Reads the prompt from cron-prompts/<name>.md.
#
#   ./add-cron.sh <agent-name> <minute 0-59>     e.g. ./add-cron.sh apollo 0
#
# Schedule is fixed: minute <MIN>, hours 05,08,11,14,17,20 (every 3h), Asia/Jakarta
# (the timezone comes from each agent's config.yaml: timezone: Asia/Jakarta).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
H=/opt/hermes/.venv/bin/hermes
USERID=0   # deliver briefings to this Telegram DM (the owner)

NAME="${1:?usage: add-cron.sh <agent-name> <minute 0-59>}"
MIN="${2:?need a minute offset 0-59 (stagger agents so browsers do not all fire at once)}"
PROMPT="$ROOT/cron-prompts/$NAME.md"
[ -f "$PROMPT" ] || { echo "no prompt file: $PROMPT"; exit 1; }

docker exec -u 10000 "hermes-$NAME" "$H" cron create "$MIN 5-21/3 * * *" "$(cat "$PROMPT")" \
  --name briefing --deliver "telegram:$USERID"
chown -R 10000:10000 "$ROOT/agents/$NAME/data/cron" 2>/dev/null || true
echo "added briefing for $NAME at minute $MIN (every 3h 05-21, Asia/Jakarta), delivering to telegram:$USERID"
