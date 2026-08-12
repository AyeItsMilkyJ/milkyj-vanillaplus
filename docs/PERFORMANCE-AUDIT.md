# 1.9.0-rc1 performance audit

Audit date: 13 August 2026. Scope: read-only inspection of the current Windows server configuration plus disposable testing under `build/performance-audit`. No live configuration, mod selection, server, world, Prism instance, port 25565, recipe, quest, or gameplay rule was changed.

## Outcome

The current configuration is healthy enough to continue RC testing. The repeatable clean-world benchmark held 20 TPS in all four bounded scenarios, used no full garbage collections, saved all seven loaded dimensions, and exited normally. The main risk is concurrent new-terrain generation, especially when Distant Horizons and the unusually large worldgen/structure stack compete for CPU. A deliberately excessive burst of eight far-region forced-load commands proved that boundary by triggering the 60-second watchdog; spaced single-chunk exploration completed without a watchdog failure.

These results do **not** measure the production world, real player concurrency, a developed Create base, or active trains. A stopped copied-world test remains mandatory.

## Host and current runtime

| Item | Audited value | Finding |
|---|---:|---|
| CPU | Intel Core i7-12700KF, 12 cores / 20 logical processors | Strong single-thread performance; enough background capacity, but Minecraft's main tick remains the bottleneck |
| RAM | 31.8 GiB usable; about 19.2 GiB free at inspection | Suitable for hosting and playing on the same PC with the current server cap |
| Java | Temurin OpenJDK 17.0.19+10, 64-bit HotSpot | Correct major version for Forge 1.20.1 |
| Forge launch | `@user_jvm_args.txt @libraries/net/minecraftforge/forge/1.20.1-47.4.10/win_args.txt nogui` | Correct argument-file launch; no shell-concatenation issue |
| Heap | `-Xms2G -Xmx8G` | Appropriate for this host and current measurements; leaves room for the local client |
| Collector | G1, parallel reference processing, 150 ms pause target | Sensible for this heap; Java 17 already defaults to G1, so the explicit choice is harmless |
| Explicit GC | disabled | Distant Horizons warns about this exact flag; test an alternative rather than changing blindly |

Oracle documents G1 as the default collector in Java 17 and describes it as suitable for large heaps with bounded pause goals. Oracle also documents `-XX:+ExplicitGCInvokesConcurrent`, which allows `System.gc()` requests to use G1's concurrent path. See the [Java 17 launcher options](https://docs.oracle.com/en/java/javase/17/docs/specs/man/java.html) and [HotSpot GC tuning guide](https://docs.oracle.com/en/java/javase/17/gctuning/).

Recommended JVM candidate for a separate performance branch:

```text
-Xmx8G
-Xms2G
-XX:+UseG1GC
-XX:+ParallelRefProcEnabled
-XX:MaxGCPauseMillis=150
-XX:+ExplicitGCInvokesConcurrent
```

This is **TEST FIRST**, not applied. Expected effect: retain G1 and the 8 GiB cap while allowing Distant Horizons' explicit collection requests to run concurrently instead of being ignored. Rollback: restore `-XX:+DisableExplicitGC`. Do not add an unverified “Aikar flags” bundle; the current collector showed zero full GCs and low measured GC time.

## Server properties

| Property | Current | Assessment |
|---|---:|---|
| `view-distance` | 12 | High but intentional; up to a 25×25 nearby chunk square per separated player before overlap |
| `simulation-distance` | 6 | Sensible; substantially limits ticking/spawning relative to view 12 |
| `entity-broadcast-range-percentage` | 80 | Reduces entity network visibility; it does not reduce server AI or spawning cost |
| `sync-chunk-writes` | false | Appropriate for throughput; clean backup/shutdown discipline remains important |
| `max-tick-time` | 60000 | Keep the watchdog; it correctly caught the artificial synchronous worldgen burst |
| `max-players` | 10 | Capacity setting only; performance depends on separation and exploration pattern |

Recommendation: **DO NOT CHANGE** simulation distance 6, the 80% broadcast range, or the watchdog. Treat view 12 as **TEST FIRST** on a stopped copied world with the expected player count. If concurrent exploration produces lag, compare view 10/simulation 6; Distant Horizons can retain distant terrain silhouettes, but that is still a visible behaviour change and is not an automatic “safe” edit.

## Disposable benchmark

The repeatable harness is `scripts/Test-ServerPerformance.ps1`. It rebuilds only `build/performance-audit`, refuses port 25565, binds Minecraft to 25579, requires Java 17 and exactly 203 server JARs, and performs a normal save/stop. The authoritative machine output is `audit/performance-benchmark.json`.

| Scenario | Duration | Average / peak working set | Average / peak used heap | End snapshot | Entities | GC during sample |
|---|---:|---:|---:|---:|---:|---:|
| Clean idle | 31.32 s | 4,912 / 4,956 MiB | 3,170 / 3,515 MiB | 4.470 MSPT, 20 TPS | 182 | 6 young, 0 full |
| Fresh Chunky generation | 25.80 s | 4,921 / 4,943 MiB | 3,076 / 3,401 MiB | 5.811 MSPT, 20 TPS | 178 | 16 young, 0 full |
| Spaced far exploration | 46.19 s | 4,931 / 4,947 MiB | 3,104 / 3,478 MiB | 5.239 MSPT, 20 TPS | 278 | 24 young, 0 full |
| Synthetic loaded base | 46.20 s | 4,955 / 4,956 MiB | 3,253 / 3,617 MiB | 11.513 MSPT, 20 TPS | 251 | 5 young, 0 full |

Additional results:

- process start to `Done`: 98.77 seconds; Minecraft's internal `Done` phase reported 56.829 seconds;
- Chunky generated 289 fresh Overworld chunks at a far center in 21 seconds (about 13.8 chunks/second overall);
- explicit `save-all flush`: 0.51 seconds to completion marker;
- shutdown: 1.46 seconds;
- Overworld, Nether, End, Aether, Twilight Forest, Otherside, and Past all saved;
- Distant Horizons closed its server world, worldgen pools, and seven SQLite connections;
- JVM exit code 0; and
- loaded-chunk total was not exposed reliably by available Forge console output, so it is reported as unavailable rather than guessed.

Forge's TPS output was sampled immediately after each workload and is cumulative rather than a per-tick profiler. The synthetic base requested 24 villagers, 32 cows, and 16 bees in a 12×12 forced area. It is a bounded scheduler/entity test, not a claim about a real base or Create machinery.

The failed exploratory stress attempt is also useful evidence: forcing eight far 4×4-chunk regions back-to-back blocked a single worldgen tick for 60 seconds and the normal watchdog stopped the disposable server. The final harness instead spaces eight single-chunk requests and passes. Operational consequence: run one bounded Chunky job during maintenance; do not stack Chunky, mass `/forceload`, Distant Horizons generation, and active players.

## Distant Horizons

Installed: Distant Horizons 3.2.0-b, side `both`. Its dedicated-server component is active, not inert:

- starts a `SERVER_ONLY` DH world;
- opens one SQLite database for each of seven loaded dimensions;
- enables server generation and real-time updates;
- uses `FEATURES` distant generation;
- permits 20 generation and 50 sync requests per second per client;
- allows up to 500 KiB/s per player with no global bandwidth cap;
- exposes generation/synchronization distances of 4,096 chunks;
- creates 10 worker threads at a 1.0 run-time ratio; and
- closes all pools/databases normally in the authoritative test.

The official DH FAQ says clients can operate alone, but then must explore ordinary chunks to build/save their own LODs. With the mod on both Forge server and client, LODs can be generated/sent automatically and real-time distant updates are available. See the [official multiplayer FAQ](https://gitlab.com/distant-horizons-team/distant-horizons/-/wikis/1-user-guide/1-frequently-asked-questions/1-general/General) and [server-owner guidance](https://gitlab.com/distant-horizons-team/distant-horizons/-/wikis/1-user-guide/1-frequently-asked-questions/5-server-owners/Server-Owners).

Recommendation: **TEST FIRST; retain it on the server for RC1**. Its current `both` classification is correct for the desired shared long-distance experience. Removing only the server JAR would not stop DH clients rendering their own previously/explored LODs, but it would remove server-provided distant generation, synchronization, and real-time updates. The prior lingering-JVM symptom was not reproduced: the clean compatibility run and performance run both exited normally, with the performance run explicitly proving DH closure. Because it is intermittent, monitor rather than declare it fixed.

First DH experiments for a separate performance branch:

1. reduce `numberOfThreads` from 10 to 6 and `threadRunTimeRatio` from 1.0 to 0.5–0.75;
2. cap global bandwidth instead of unlimited and confirm friends still receive LODs promptly;
3. reduce the 4,096-chunk request ceilings to a value just above the intended 256-chunk LOD radius; and
4. test the JVM explicit-GC replacement above.

All four are **TEST FIRST**. Rollback is restoring the generated `DistantHorizons.toml` from the stopped-server backup. Do not simultaneously change all four when comparing results.

## Existing optimization stack

| Component | Current side | Function / overlap assessment |
|---|---|---|
| ModernFix 5.27.72 | both | Broad loading, memory, and bug fixes; defaults remain active. Only async JEI plugin `jepb` is blacklisted. No harmful overlap observed |
| FerriteCore 6.0.1 | both | Blockstate/model memory deduplication; complementary to ModernFix. Most useful deduplication options are enabled |
| Alternate Current 1.7.0 | server | Redstone implementation optimization; correctly server-only |
| AI Improvements 0.5.2 | both | Cached look-controller replacement enabled; behaviour-removing AI options remain false |
| FastSuite 1.2.3 | both | Recipe lookup caching; unsafe mode and crafting-stack locking are false |
| Clumps 12.0.0.4 | both | XP-orb merging; no conflicting optimization identified |
| Let Me Despawn | both | Despawn correction; no broad persistence enablers configured. Tamed animals and managed bees still require sensible farm design |
| Chunky 1.3.146 | server | Maintenance-time pregeneration; correctly server-only and valuable for this worldgen stack |
| Embeddium | client | Rendering optimization; correctly client-only JAR |
| Entity Culling | client | Rendering/culling optimization; correctly client-only JAR |
| ImmediatelyFast | client | Rendering optimization; correctly client-only JAR |
| Distant Horizons | both | LOD renderer/client plus active server LOD service; intentional, but the largest optimization-related server workload |

No server optimization is incorrectly marked client-only. No harmful ModernFix/FerriteCore/FastSuite/AI Improvements overlap appeared in clean startup or benchmark logs.

Three inert configs are unnecessarily sent to dedicated servers: `embeddium-fingerprint.json`, `embeddium-mixins.properties`, and `entityculling.json`. Their corresponding JARs are absent server-side, so these files provide no optimization and no runtime code. Reclassifying them is **CLIENT ONLY** cleanup for a later metadata-only update; it is not a performance emergency.

Do not add Lithium or Sodium JARs: those names target Fabric, while Embeddium already supplies the Forge client rendering role. Do not add Starlight, Canary/Radium, generic memory-leak mods, or C2ME-style concurrent chunk engines merely by popularity; this pack's mixed dimensions and structure stack need exact Forge 1.20.1 compatibility proof and copied-world regression tests. A server-only profiler such as spark is a **FUTURE OPTION** if real-world evidence needs attribution, not an automatic release dependency.

## Workload risks

### HIGH — concurrent fresh world generation

Terralith, Biomes O' Plenty/TerraBlender, Alex's Caves, YUNG's structure suite, Repurposed Structures, Dungeons and Taverns, IDAS, Better Archaeology and other structure mods all add work during new chunk generation. Aether, Twilight Forest, Otherside, Past, Nether/Incendium, and End/Nullscape add separate generation surfaces. Distant Horizons can request additional LOD generation at the same time. The disposable watchdog event proves that synchronous bursts can exceed the 60-second boundary.

Mitigation: pregenerate bounded areas with Chunky while nobody is playing; never run multiple generation systems as stress tools; test copied-world multi-player exploration before release.

### MEDIUM — persistent/ticking entities and developed bases

Productive Bees, Doggy Talents, Alex's Mobs, Naturalist, Mowzie's Mobs, Friends & Foes, villagers and livestock can accumulate. Let Me Despawn cannot remove intentionally persistent/tamed entities. Create contraptions and trains can tick across loaded chunks and keep machinery active. The synthetic entity test passed, but it did not reproduce real Create networks, train schedules, bee nests, storage automation, or chunk loading.

Mitigation: profile the copied world under real base load; avoid uncontrolled breeder/bee populations and unnecessary force-loaded machinery. Do not change spawn rules or remove mobs as a “performance fix” without evidence.

### MEDIUM — server-side Distant Horizons concurrency

Ten full-duty DH workers plus unlimited global LOD bandwidth can compete with Forge worldgen and the local Minecraft client. It provides genuine value, so tune it experimentally rather than removing it.

### LOW — heap/GC and installed optimization overlap

The 8 GiB cap retained headroom, peak sampled used heap was 3.62 GiB, and no full GC occurred. Existing optimization mods started and coexisted successfully. The explicit-GC flag is a DH-specific concern, not evidence of current heap exhaustion.

## Classified recommendations

### SAFE NOW (documented; not applied)

- Disable Distant Horizons' self-update check so Packwiz remains the only version authority. Expected effect: remove one startup network check and prevent unmanaged version drift. Rollback: re-enable `client.advanced.autoUpdater.enableAutoUpdater`.
- Reduce routine DH file logging from `INFO` to `WARN` after retaining one known-good diagnostic log. Expected effect: less disk/log churn. Rollback: restore `INFO`.
- Operationally run Chunky only during maintenance and one world at a time. This changes no gameplay data or content.

### TEST FIRST

- Replace `-XX:+DisableExplicitGC` with `-XX:+ExplicitGCInvokesConcurrent` under G1; compare heap, GC time, shutdown, and play-session stability.
- Test DH with 6 threads and a lower run-time ratio, then tune request/bandwidth ceilings one variable at a time.
- Compare view 12/simulation 6 with view 10/simulation 6 only if copied-world multiplayer exploration shows lag.
- Run the required stopped copied-world test with active Create machinery, trains, bees, pets, storage, and several separated players.

### DO NOT CHANGE

- Keep Forge 47.4.10, Minecraft 1.20.1, the 8 GiB maximum heap, simulation distance 6, watchdog, mob/structure selection, recipes, dimensions, quests, and progression for this RC.
- Do not blanket-disable AI, spawning, structures, dimensions, Create stress, trains, or Distant Horizons to manufacture a benchmark win.
- Do not add random overlapping optimization mods or Fabric-only Lithium/Sodium builds.

### CLIENT ONLY

- Keep Embeddium, Entity Culling, and ImmediatelyFast JARs client-only.
- Later reclassify their inert Embeddium/Entity Culling config files from `both` to `client` after an ordinary client update/rollback test.

### FUTURE OPTION

- Add a temporary server profiler only when a copied production snapshot produces a specific lag symptom.
- Consider a proven concurrent chunk engine only if an exact Forge 1.20.1 build, dependency audit, world-conversion rollback, and extensive copied-world validation exist. No current evidence justifies that risk.

## Remaining gate

The benchmark validates a disposable new world, not the established world. Before release, copy the stopped world, use the planned player count, visit existing bases and dimensions, run trains/contraptions/bees, then repeat save/restart/rollback checks. Preserve the live world and make a timestamped backup before any later performance experiment.
