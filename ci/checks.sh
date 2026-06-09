#!/usr/bin/env bash
# Pantheon repo checks — the SAME script runs locally and in CI
# (.github/workflows/ci.yml). Run from anywhere: ./ci/checks.sh
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
hdr(){ printf '\n=== %s ===\n' "$1"; }

hdr "shellcheck"
shellcheck ./*.sh ci/*.sh && echo ok

hdr "bash syntax (-n)"
for f in ./*.sh ci/*.sh; do bash -n "$f"; done && echo ok

hdr "executable bits"
for f in ./*.sh ci/checks.sh; do
  test -x "$f" || { echo "not executable: $f"; fail=1; }
done
echo checked

hdr "personas present + non-empty"
for p in plutus hephaestus athena atlas themis nemesis apollo peitho hestia prometheus; do
  test -s "personas/$p.md" || { echo "missing/empty: $p"; fail=1; }
done
echo "checked 10"

hdr "yaml: base/hermes-base.yml parses"
python3 -c "import yaml; yaml.safe_load(open('base/hermes-base.yml'))" && echo ok

hdr "gen-compose smoke test"
tmp="$(mktemp)"
mkdir -p agents/_citest/data
PANTHEON_COMPOSE_OUT="$tmp" ./gen-compose.sh >/dev/null
python3 -c "
import yaml
d = yaml.safe_load(open('$tmp'))
s = d.get('services', {})
assert d.get('name') == 'hermes-agent-z4gq', 'wrong project name: %r' % d.get('name')
assert '_citest' in s, 'generated agent service missing'
assert 'hermes-dashboard' in s, 'base dashboard service missing'
print('services:', sorted(s))
"
rm -rf agents/_citest "$tmp"
echo ok

hdr "secret scan (tracked files only)"
if git ls-files -z | xargs -0 grep -IEn \
     'sk-or-v1-[A-Za-z0-9]|nvapi-[A-Za-z0-9]|gh[opsu]_[A-Za-z0-9]{20}|[0-9]{8,}:AA[A-Za-z0-9_-]{20}'; then
  echo "secret-shaped string found in a tracked file"; fail=1
else
  echo "ok: none"
fi

echo
if [ "$fail" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; exit 1; fi
