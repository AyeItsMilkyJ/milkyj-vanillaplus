# 1.9.0-rc1 integration report

Final status: **NOT RELEASE-READY — MANUAL QUEST/TEAM AND COPIED-WORLD TESTS REQUIRED**

## Identity and safety boundary

- Branch: `integration/v1.9.0-rc1-final`
- Integration commit: `75a1c21c3742e7f5e338a3be12ad26538fb9c111`
- Release-candidate base: `8a15a8c40df21f4d9e975a27591156f368b55c5d`
- Validated compatibility source: `bb62f885457e37c20b45bd52717f498aa0859b86`
- Minecraft: 1.20.1
- Forge: 47.4.10

No remote was used. Nothing was published, pushed, merged, deployed, or installed into the live server, live world, normal Prism instance, or production port 25565. The live server configuration was inspected read-only while no process was listening on 25565.

## Integrated compatibility payload

These five exact client-and-server payload files were added to the existing high-priority Moonlight global datapack:

1. `payload/both/moonlight-global-datapacks/milkyj-compat-fixes/data/domesticationinnovation/loot_modifiers/blazing_enchanted_book.json`
2. `payload/both/moonlight-global-datapacks/milkyj-compat-fixes/data/nethersdelight/loot_modifiers/chopping_leather.json`
3. `payload/both/moonlight-global-datapacks/milkyj-compat-fixes/data/nethersdelight/loot_modifiers/chopping_string.json`
4. `payload/both/moonlight-global-datapacks/milkyj-compat-fixes/data/beautify/advancements/progression/candelabra.json`
5. `payload/both/moonlight-global-datapacks/milkyj-compat-fixes/data/tf_dnv/loot_tables/chests/dungeon_shroom_barrel.json`

The matching five Packwiz descriptors were added at the identical paths beneath `packwiz/moonlight-global-datapacks/milkyj-compat-fixes/`, with `.pw.toml` appended. All are side `both`.

The first four are the three requested compatibility issues (Nether's Delight has two resources). The fifth is the separately validated trivial `tf_dnv` correction found during the mandated warning investigation: it changes only `tf_dnv:dungeon_shroom` to the installed `tf_dnv:chests/dungeon_shroom` table.

No mod JAR or mod version changed. The ignored Central Kitchen, Aether's Delight, and Relics findings were not integrated. The unresolved `twilightforest:chests/casket_loot` reference remains untouched.

## Packwiz result

| Invariant | Result |
|---|---:|
| Final destinations | 689 |
| Mod definitions | 238 |
| Clean client JARs | 236 |
| Clean server JARs | 203 |
| FTB quests | 118 |
| Sides | 512 both, 162 client, 15 server |
| Hosted / external downloads | 445 / 244 |
| Minecraft / Forge | 1.20.1 / 47.4.10 |

The mod-definition directory has no diff from the RC base. The quest payload has no content diff; quest IDs and rewards remain unchanged.

During integration, a Windows line-ending defect was found: local LAN tests hashed CRLF working copies while future GitHub raw URLs would serve LF blobs. `.gitattributes` and `Update-PackMetadata.ps1` now make LF bytes canonical before hashing. Consequently, 221 existing hosted-payload descriptors contain hash-only corrections and `index.toml` was regenerated. This changes delivery integrity, not payload content, mod versions, or quests.

## Compatibility validation

Static validation pins exact installed JAR hashes and compares object semantics. The clean runtime gate then proved:

- client and server installs completed from the generated Packwiz graph;
- `file/milkyj-compat-fixes` was automatically enabled and listed last at highest effective priority;
- 1,258 advancements loaded at startup and after explicit `/reload`;
- the Domestication Innovation missing-resource error was absent;
- both Nether's Delight unsupported-condition errors were absent;
- the Beautify advancement and corrected item ID resolved;
- the corrected `tf_dnv` shroom path warning was absent;
- zero new global-loot-modifier decode, advancement parse, or datapack-load failures appeared;
- FTB reported 4 groups, 9 chapters, 118 quests, and 0 reward tables;
- all seven loaded dimensions saved; and
- the JVM exited normally with code 0.

Baseline → candidate → baseline Packwiz testing passed. All five candidate resources and an obsolete managed sentinel were removed on rollback. Options/keybindings, screenshots, saves, shader settings, and shader packs remained unchanged.

Evidence: `audit/compatibility-fix-validation.json`, `audit/packwiz-update-rollback.json`, and ignored complete logs under `build/end-to-end`.

## Performance audit result

The current production configuration is Java 17, G1, 2–8 GiB heap, view 12, simulation 6, entity broadcast 80%, asynchronous chunk writes, and a 60-second watchdog. The disposable benchmark reproduced those performance-relevant settings on port 25579.

| Scenario | End MSPT | TPS | Peak used heap | Peak working set |
|---|---:|---:|---:|---:|
| Clean idle | 4.470 | 20 | 3,515 MiB | 4,956 MiB |
| Fresh 289-chunk Chunky region | 5.811 | 20 | 3,401 MiB | 4,943 MiB |
| Spaced exploration/worldgen | 5.239 | 20 | 3,478 MiB | 4,947 MiB |
| Synthetic loaded base | 11.513 | 20 | 3,617 MiB | 4,956 MiB |

Process start to `Done` was 98.77 seconds (Minecraft internal phase: 56.829 seconds). Chunky processed 289 fresh chunks in 21 seconds. No full GC occurred. Explicit save took 0.51 seconds, all seven dimensions saved, Distant Horizons closed its server world/thread pools/seven databases, shutdown took 1.46 seconds, and the JVM exited code 0.

The top risks are:

1. **HIGH:** concurrent fresh chunk/structure/dimension generation combined with Distant Horizons generation;
2. **MEDIUM:** real persistent entities, Productive Bees, pets, villagers, Create contraptions, and trains in developed bases;
3. **MEDIUM:** Distant Horizons' 10 full-duty workers, 4,096-chunk request ceilings, and unlimited global LOD bandwidth; and
4. **LOW:** current heap/GC capacity and optimization-mod overlap.

An intentionally excessive batch of far-region forced loads made a single disposable tick exceed the 60-second watchdog. The authoritative harness uses spaced single-chunk exploration and passes. This is operational evidence to pregenerate with one bounded Chunky task while players are offline, not a reason to disable content.

Detailed measurements and recommendations are in `docs/PERFORMANCE-AUDIT.md`, `audit/performance-audit.json`, and `audit/performance-benchmark.json`.

## JVM, view distance, and optimization stack

Keep the current 8 GiB cap and G1 collector for RC1. Distant Horizons warns that `-XX:+DisableExplicitGC` can cause memory pressure; the documented **TEST FIRST** candidate is to replace it with `-XX:+ExplicitGCInvokesConcurrent`, not to add a generic flag bundle.

Keep simulation distance 6. View 12 is high but intentional and passed the disposable workloads. Compare view 10 only if stopped copied-world, multi-player exploration shows lag; Distant Horizons can preserve distant LODs, but changing near view remains visible and is not automatic.

ModernFix, FerriteCore, Alternate Current, AI Improvements, FastSuite, Clumps, Let Me Despawn, and Chunky showed no harmful overlap. Embeddium, Entity Culling, and ImmediatelyFast JARs are correctly client-only. Three inert configs for Embeddium/Entity Culling are unnecessarily side `both`; that is later **CLIENT ONLY** cleanup, not a release performance issue. No new optimization mod is recommended for this RC.

## Distant Horizons recommendation

Retain Distant Horizons on both client and dedicated server for RC1, then **TEST FIRST** lower server concurrency. The server component has demonstrable value: it generates, synchronizes, and sends distant LODs and real-time changes. Clients can run without the server component, but then build LODs from normally explored chunks and lose server-generated/synchronized updates. The earlier intermittent lingering JVM was not reproduced in either authoritative clean shutdown; continue monitoring rather than declaring it impossible.

## `tf_dnv` classification

- `tf_dnv:dungeon_shroom` missing `chests/` path: **FIX BEFORE 1.9.0** — trivial, isolated, now integrated and validated.
- `twilightforest:chests/casket_loot`: **FIX LATER** — referenced by real add-on dungeon barrel structures, but no unambiguous target exists in Twilight Forest 4.3.2508 or its upstream 1.20 data. Guessing would alter loot semantics.

## R3 LAN bootstrap

- File: `dist/MilkyJ-VanillaPlus-1.9.0-rc1-LAN-TEST-r3-Prism.zip`
- SHA-256: `725b1562e116cd505d993432d784012822c01de378165240aae9ba1f6bcb30c3`
- Bytes: 91,704
- Pack URL: `http://<PRIVATE_LAN_ADDRESS>:8765/packwiz/pack.toml`
- Pre-launch value: `\"$INST_JAVA\" -jar packwiz-installer-bootstrap.jar http://<PRIVATE_LAN_ADDRESS>:8765/packwiz/pack.toml`

Archive inspection and the process-level Java-path-with-spaces regression passed. There is no placeholder GitHub URL in R3. The LAN host was not started and manual Prism import was not claimed. R2 remains unchanged at SHA-256 `3eac0a7fce9029d023182e276dea5da1695ad34b817c4f0582ea88d3fe34a907`.

## Exact substantive file changes

Integration commit `75a1c21` contains 252 paths: 226 Packwiz descriptors (five new compatibility descriptors and 221 line-ending hash repairs), five new payload resources, seven scripts, seven audit files, three documentation files, `.gitattributes`, `.gitignore`, `packwiz/index.toml`, and `packwiz/pack.toml`. `git show --name-status 75a1c21c3742e7f5e338a3be12ad26538fb9c111` is the exact machine-verifiable path list.

Substantive tooling changes:

- `scripts/validate_integrated_compatibility.py`
- `scripts/Test-InstallerEndToEnd.ps1`
- `scripts/Test-BaselineUpdateRollback.ps1`
- `scripts/Test-ServerPerformance.ps1`
- `scripts/Update-PackMetadata.ps1`
- `scripts/Start-RcLanTest.ps1`
- `scripts/Stop-RcLanTest.ps1`

Documentation/audit additions and updates:

- `docs/COMPATIBILITY-FIXES.md`
- `docs/PERFORMANCE-AUDIT.md`
- `docs/RC1-INTEGRATION-REPORT.md` (this handoff report)
- `docs/MANUAL-RC-TEST.md`
- `audit/compatibility-fix-validation.json`
- `audit/performance-audit.json`
- `audit/performance-benchmark.json`
- `audit/prism-bootstrap-lan-r3.json`
- `audit/prism-bootstrap-regression.json`
- `audit/packwiz-update-rollback.json`
- `audit/encoding-validation.json`

## Remaining manual release gates

1. Import R3 into two fresh disposable Prism application roots; do not reuse normal player instances.
2. Run the full two-account quest/team test in `docs/MANUAL-RC-TEST.md`, including team membership, shared and per-player quest behaviour, rewards, relog, restart, and rollback.
3. Stop the live server and take a timestamped backup before copying the world to a disposable test root.
4. Test the copied world with the real player count, developed bases, Create contraptions/trains, bees/pets/storage, major dimensions, exploration, save, restart, and rollback.
5. Confirm the host's current private LAN address before using R3; rebuild R3 if DHCP changed it.
6. Configure and validate a real stable HTTPS Packwiz URL only after the manual gates pass.

No publication, push, merge, deployment, live-world change, live-server start, production port binding, or normal Prism change is authorized by this report.

**NOT RELEASE-READY — MANUAL QUEST/TEAM AND COPIED-WORLD TESTS REQUIRED**
