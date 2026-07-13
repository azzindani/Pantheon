# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Pre-1.0: minor version bumps may include breaking changes.

## [0.1.0] - 2026-07-13

Initial public release.

### Added
- Fleet scaffolding (`spawn-agent.sh`, `pair-agent.sh`, `gen-compose.sh`, `build-seed.sh`)
  for running N isolated Hermes agents inside a single Docker Compose project —
  each with its own persona, isolated memory, and Telegram bot, sharing one
  OpenRouter key and model.
- 10 personas (plutus, athena, atlas, hephaestus, themis, nemesis, apollo,
  prometheus, peitho, hestia) plus an example persona template.
- Local SearXNG-backed web search/fetch helpers (`web-helpers/`) — no paid
  search API key required.
- Optional daily research-briefing cron mechanism (`add-cron.sh`,
  `cron-prompts/`), delivering to the owner's Telegram DM. Currently
  unscheduled by default — opt-in per agent.
- CI (`ci/checks.sh`, run locally and via GitHub Actions): shellcheck, bash
  syntax check, YAML validation, a `gen-compose.sh` smoke test, and a scan for
  secret-shaped strings in tracked files.
- Redacted config backups of a related Hermes MCP workspace (`backups/`).
- Apache-2.0 license.

### Changed
- Consolidated the fleet into the same compose project/group as the
  pre-existing Hostinger agent rather than running it as a separate stack.
- Briefing cadence iterated (hourly → 2h → 3h → 6h → once/day on weekdays,
  one hour per agent) before being removed entirely; the mechanism remains as
  an opt-in capability.
- Hardened for public release: the owner's Telegram ID is now read from the
  gitignored `shared.env` instead of being hardcoded in a script.

[0.1.0]: https://github.com/azzindani/Pantheon/releases/tag/v0.1.0
