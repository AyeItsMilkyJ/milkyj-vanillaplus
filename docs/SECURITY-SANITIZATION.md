# Security and privacy sanitization

Status: **PASS** for the current publishable tree, secret/path rules, and prevention of new historical privacy leaks. Thirteen reviewed legacy privacy-metadata blobs remain reachable in already-published history and are reported explicitly rather than hidden.

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

`<PRIVATE_OFFLINE_LOCATION>\MilkyJ-Packwiz-private-pre-sanitization-20260812.bundle`

- Size: `1,067,004` bytes
- SHA-256: `593af57ca53dd4da5f072712f630921b454c6d0ecbc1f4b691f15f3bc82f59fa`
- `git bundle verify`: complete history, verified OK

This bundle is a private offline recovery artifact and must not be published. The local recovery baseline `main`/`v1.0.0` was replaced with a valid sanitized `1.8.1-packwiz.1` snapshot. The old feature ref was removed, the repair commit attached to that sanitized baseline, reflogs expired, and unreachable objects pruned. Later release-audit documents nevertheless introduced several literal private-LAN and local user-profile-path values into already-published commits. Their current versions are redacted. Because rewriting published Git history is disruptive and was not authorised, the old blob objects remain reachable.

`scripts/security_history_scan.py` now checks those location patterns in every current file and every reachable blob. The immutable reviewed baseline is `audit/security-known-history.json`; it contains only object IDs, paths and reason categories for the 13 known legacy blobs. The scan fails on any new occurrence, every current-tree occurrence, every secret-like value, and every forbidden runtime/identity path. Secrets and forbidden paths can never be baselined.

The machine-readable result is `audit/security-history-scan.json`. It separately reports zero blocking findings and the 13 known legacy privacy findings without reproducing any address, username, secret value or identity record.
