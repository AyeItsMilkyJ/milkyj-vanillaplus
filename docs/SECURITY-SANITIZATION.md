# Security and privacy sanitization

Status: repaired locally; final reachable-ref scan is required after the repair commit is installed.

No secret value or full third-party identity record is reproduced in this document.

## Removed from Packwiz and hosted payloads

- `payload/both/config/resourceful-config-web.json`
- `packwiz/config/resourceful-config-web.json.pw.toml`
- `payload/both/config/dawnoftimebuilder/patrons_cache.json`
- `packwiz/config/dawnoftimebuilder/patrons_cache.json.pw.toml`

The first file belongs to Resourceful Config `2.1.3` (`resourcefulconfig`). Inspection of the matching official v2.1.3 source shows that `WebServer` reads `config/resourceful-config-web.json`, writes `WebServerConfig.DEFAULT` when it is absent, and starts only when `enabled` is true. `WebServerConfig.DEFAULT` has the web server disabled and creates a fresh random password. The clean disposable server proved this supported behavior: startup succeeded, a local file was regenerated, and its web server remained disabled. The generated value is not Packwiz-managed and is ignored.

The patron/supporter cache is generated under Dawn of Time Builder's config directory. It is no longer hosted or managed, is ignored, and was not created during the clean dedicated-server startup. Its omission did not prevent launch, quest loading, saving, or normal JVM exit.

## Rotation guidance

The task did not inspect or change the live production server. Therefore production reuse cannot be proved from repository data alone. Before any later publication, the maintainer should remove/regenerate or rotate the live Resourceful Config web value during an authorized stopped-server maintenance window **if** the live installation ever imported or reused the removed repository value. Do not create one universal public password. If the live server has always had an independently generated value and the web interface remains disabled, the repository repair does not itself require an emergency live change.

## Ignore protection

`.gitignore` now covers root and nested playerdata, stats, advancements, worlds, backups, logs, crash reports, cache/ops/whitelist/ban files, account/session/auth files, screenshots, saves, options/keybindings containers, shader data, the generated Resourceful Config file, and the Dawn of Time patron cache.

## History handling

The original unpublished history was saved outside the publishable repository before ref replacement:

`C:\Users\MilkyJ\Documents\Codex\2026-07-19\ar\MilkyJ-Packwiz-private-pre-sanitization-20260812.bundle`

- Size: `1,067,004` bytes
- SHA-256: `593af57ca53dd4da5f072712f630921b454c6d0ecbc1f4b691f15f3bc82f59fa`
- `git bundle verify`: complete history, verified OK

This bundle is a private offline recovery artifact and must not be published. The local recovery baseline `main`/`v1.0.0` was replaced with a valid sanitized `1.8.1-packwiz.1` snapshot. The final repair procedure removes the old feature ref, attaches the repair commit to that sanitized baseline, expires reflogs, prunes unreachable objects, and runs `scripts/security_history_scan.py` over every reachable branch/tag and publishable worktree file.

The machine-readable final result is `audit/security-history-scan.json`. It reports only paths/object IDs and never secret values or cached identity contents.
