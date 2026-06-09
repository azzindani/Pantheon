#!/usr/bin/env bash
# Build the blank-slate "brain" seed every Pantheon agent is cloned from.
# Source = a working Hermes data dir (default: the live Hostinger agent).
# We KEEP shared capability (config.yaml, skills, bin, .local) and SCRUB
# everything that makes an agent a specific individual (memory, sessions,
# tasks, channel identity) + heavy re-downloadable caches.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REF="${1:-/docker/hermes-agent-z4gq/data}"
SEED="$ROOT/seed"

[ -d "$REF" ] || { echo "reference data dir not found: $REF"; exit 1; }
[ -f "$REF/config.yaml" ] || { echo "no config.yaml in $REF — not a Hermes data dir"; exit 1; }

echo "==> building blank-slate seed from $REF"
rm -rf "$SEED"; mkdir -p "$SEED"

rsync -a \
  --exclude 'home/.agent-browser/' \
  --exclude 'sessions/' \
  --exclude 'logs/' \
  --exclude 'cron/output/' \
  --exclude 'audio_cache/' --exclude 'image_cache/' --exclude 'images/' \
  --exclude 'pairing/' --exclude 'sandboxes/' --exclude '.cache/' \
  --exclude '.env' \
  --exclude 'auth.json' --exclude 'auth.lock' \
  --exclude 'skills/.curator_backups/' \
  --exclude 'channel_directory.json' \
  --exclude 'gateway_state.json' --exclude 'gateway.lock' --exclude 'gateway.pid' \
  --exclude 'response_store.db*' --exclude 'state.db*' \
  --exclude 'kanban.db' --exclude 'kanban.db.init.lock' \
  --exclude '.hermes_history' --exclude '.skills_prompt_snapshot.json' \
  --exclude 'config.yaml.bak*' \
  --exclude 'discord_threads.json' --exclude 'workspace-sessions.json' \
  "$REF/" "$SEED/"

# reset identity -> a freshly-born human: no memories, placeholder persona
printf 'You are a Pantheon agent. Replace this file with the persona.\n' > "$SEED/SOUL.md"
mkdir -p "$SEED/memories"
: > "$SEED/memories/MEMORY.md"
: > "$SEED/memories/USER.md"
rm -f "$SEED/memories/"*.lock

echo "==> seed ready: $(du -sh "$SEED" | cut -f1) at $SEED"
