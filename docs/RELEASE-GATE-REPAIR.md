# 1.9.0-rc1 release-blocker repair

## Overall gate

**NOT RELEASE-READY — MANUAL TESTS REQUIRED**

All scoped automated blocker repairs pass. The two-client interaction test and stopped-production copied-world/real-progress test remain **NOT RUN**. Nothing was published, pushed, deployed, or applied to the live server, live world, or working Prism instance.

Repair branch: `repair/v1.9.0-rc1-release-blockers`

Implementation commit: `3f73cd01f66d32dd36dc3b7bbca1a1f2a16f21c9`

Sanitized recovery baseline/tag: `04be5d83c92c7ea76a35968a8cfac69a4b6c1bb5` (`main`, `v1.0.0`)

Established previous pack version: `1.8.1-packwiz.1`

Repaired candidate: `1.9.0-rc1`

The `v1.0.0` Git label is a local recovery baseline, not the pack's semantic version. No stable release tag was created.

## Security and privacy

Removed from all Packwiz-managed/publishable data and purged from every reachable publication ref:

- `payload/both/config/resourceful-config-web.json`
- `packwiz/config/resourceful-config-web.json.pw.toml`
- `payload/both/config/dawnoftimebuilder/patrons_cache.json`
- `packwiz/config/dawnoftimebuilder/patrons_cache.json.pw.toml`

The generated secret file belongs to Resourceful Config `2.1.3`. The matching official source and clean startup test establish that omission is supported: it regenerates a per-install file, generates a fresh random value, and leaves the web service disabled by default. The clean server reached `Done` with the Packwiz-managed file absent; its regenerated local config had `enabled=false`. No generated value is printed or committed.

The Dawn of Time Builder patron cache was absent from the clean install, was not regenerated during server startup, and was unnecessary for launch, quest loading, saving, and exit.

Production use/rotation result: **UNKNOWN / NOT INSPECTED**, because the live server was intentionally untouched. Before later publication, regenerate or rotate the live Resourceful Config value during an authorized stopped-server window only if the live installation ever reused the removed repository value. Do not publish a universal password. See `docs/SECURITY-SANITIZATION.md`.

History result:

- A verified complete private pre-sanitization bundle exists outside the repository; it must never be published.
- The obsolete feature ref was deleted, reflogs expired, and unreachable objects pruned.
- The old RC commit object is no longer present in the repository.
- Final pre-evidence-commit scan: 3 reachable refs, 1,449 reachable blobs, 1,239 publishable worktree paths considered, **0 findings**.
- `audit/security-history-scan.json`: **PASS**.

`.gitignore` now covers root/nested playerdata, stats, advancements, worlds, backups, logs, crash reports, account/session/auth files, screenshots, saves, options/keybindings containers, shader data, server identity lists/caches, generated secrets, and patron identity caches.

## Quest ID and reward repair

The two repurposed quest IDs were restored to their exact baseline quest/task/reward meaning and moved outside active required progression as optional compatibility quests:

- `1885CF9658AB663D`: restored to `Foreword: A World of Many Ages`. The unrelated Create lesson `Power Beyond the First Water Wheel` now uses quest `2990526585709C54`, task `11ED8A66BEDD2038`, reward `2F306E70149D5856`.
- `22B69CA315389C48`: restored to `The Covenant of the Hearth`. The unrelated Create lesson `Create Food Addons: Kitchen to Factory` now uses quest `069DD3EFDF3EF83F`, task `6CD534112A16F2A1`, reward `4F8E7ADAA685C0A5`.

The earlier gate's “17 altered rewards” wording referred to 17 affected **quest IDs**:

`1725341D3243AFDD`, `1A354ABA1BE5171F`, `1E4FFC70B08D7689`, `22F6D8A7A571B2DF`, `2AD044CDEA61410E`, `2E34979BCE044BF5`, `31CF2E051B43098D`, `34B44EE7DDB53F36`, `3522AB4192F75013`, `36D9A2651A27AA32`, `3F4DB5EEDFFAC808`, `4201CE5BFBBC062D`, `54C781F3CD01DB25`, `576F3B9264ED1F4B`, `60435D16835B3DCE`, `71BB70B3127ECE00`, `7DA1925406767A08`.

Exact definition comparison found **18** altered reward IDs, because `7DA1925406767A08` originally had two item rewards. All 18 are restored to their original definition:

`00A1BC229E245A15`, `05902C78CA9A4EB5`, `0FE7EE9D493A0A1D`, `204890B0227A96D9`, `2118F4E2E4032CAB`, `2297FDCA42E6B81D`, `26950E0D69255D49`, `3445D7161409CCDF`, `37C462912CB4ED85`, `3A27AE16432C0F16`, `47348F50B1E09486`, `4EB68D63AE8A3A25`, `5F90D88A9406C845`, `6F57BAD901B52DB3`, `7253FC5D69D7838C`, `739D94F2E58EEE97`, `73EE0892EA05E606`, `7D96755589912CE6`.

Final ID audit:

- 420 unchanged baseline definitions
- 9 intentionally removed definitions belonging to unreleased absent-mod placeholders
- 6 new Create quest/task/reward definitions with fresh deterministic IDs
- 0 repurposed baseline IDs
- 0 altered retained baseline reward definitions
- 0 duplicate chapter/quest/task/reward IDs
- 0 dependency cycles or unreachable required quests

The synthetic logical migration fixture passes baseline quest/task completion, claimed reward, unclaimed reward, new quest incomplete, new reward unclaimed, and team-scoped representation. This proves the deterministic ID-level migration model only. The unavailable real 99-ID fixture was not claimed or accessed; real production progress remains **NOT RUN** until a clean stopped-server snapshot is authorized.

## Truthful installed-content guide

Removed from visible progression:

- 3 Tinkers' Construct placeholder quests and their chapter
- 1 Botany Pots/Botany Trees placeholder quest

The guide has no item/icon/task namespace for Tinkers' Construct, Botany Pots/Trees, Fossils Revival, Prehistoric Fauna, or KubeJS. Existing archaeology wording distinguishes installed Better Archeology from absent revival systems without instructing players to obtain absent content.

Final quest book:

- Chapters: 9
- Quests: 118
- Manual checkmark quests: 61
- Automatic detection quests: 57
- Task IDs: 165
- Reward IDs: 134

## Automated validation

- Packwiz: 684 unique destinations; 507 both, 162 client-only, 15 server-only; 440 hosted payloads, 244 external downloads.
- Encoding: 1,197 publishable text files checked; 0 invalid UTF-8/mojibake findings.
- Quest definitions: 118/118 graph nodes visited; 0 missing dependencies, items, icons, or tags.
- Baseline → candidate → baseline: **PASS**; obsolete managed file removed on rollback.
- Personal options/keybindings, screenshots, saves, shader settings, and shader packs: preserved.
- Clean client install: 236 JARs.
- Clean server install: 203 JARs.
- Disposable server: reached `Done` in 46.672 seconds; FTB loaded 4 groups, 9 chapters, 118 quests; all loaded dimensions saved; JVM exited normally.
- Generated Resourceful Config omission: startup **PASS**, local regeneration **PASS**, web disabled.
- Patron cache omission: startup **PASS**, cache remained unnecessary.
- LAN harness: `192.168.0.159:8765` Packwiz and `192.168.0.159:25566` Minecraft reached `Done`, loaded 9/118, saved, and stopped both owned processes. Production port `25565` was refused/untouched.
- LAN-test ZIP: `dist/MilkyJ-VanillaPlus-1.9.0-rc1-LAN-TEST-Prism.zip`, SHA-256 `988553f8a88d420300811114d1cfa8461463b59607f956bfd91ce978e9533b4f`.

The server log still contains previously known non-fatal third-party recipe/advancement/config warnings. They did not block startup, quest loading, save, or exit and were not expanded into unrelated mod/content work in this release-blocker-only task.

## Required manual gates

- Two authenticated fresh Prism clients: **NOT RUN**. Complete every step in `docs/MANUAL-RC-TEST.md`.
- Real stopped-production copied-world/player-progress test: **NOT RUN**. Follow `docs/COPIED-WORLD-RC-TEST.md`; do not hot-copy or point the RC at production.
- Production URL and public bootstrap: not configured or created. Publication remains unauthorized.

## Complete file inventory

`audit/release-repair-files.csv` is the exact 286-row file inventory: 277 candidate-vs-sanitized-baseline paths, the strengthened ignore file, four history-purged paths, and four final evidence files. It records every added, modified, deleted, or history-purged path without dumping sensitive contents.

Final safety confirmation: no remote is configured; nothing was pushed/published/deployed; the live server, live world, production port, and working Prism instance remained untouched.
