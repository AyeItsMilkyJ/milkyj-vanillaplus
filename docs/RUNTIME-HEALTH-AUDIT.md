# Runtime health audit — 22 August 2026

The current MilkyCraft Vanilla+ candidate has no missing mandatory Forge dependency, duplicate top-level mod ID, duplicate JAR payload, JAR hash mismatch, or client/server payload drift. The verified managed totals are 237 mod entries, 235 client JARs, and 202 dedicated-server JARs.

## Repairs made

- Fusion 1.3.12 is now client-only. Rechiseled's Fusion dependency is client-only, Modrinth marks the server environment unsupported, and no server mod requires it. This keeps all 235 client JARs and removes one unnecessary dedicated-server JAR without changing a mod version.
- Every affected PowerShell maintenance script now resolves its default project root after parameter binding. Running the scripts normally with `powershell.exe -File` no longer produces an empty-path error.
- The selected local Prism instance's Packwiz pre-launch command was restored from the repository's tested template. A timestamped copy of the previous `instance.cfg` was saved first. No `options.txt`, controls, shader selection, saves, screenshots, accounts, or other personal Minecraft data was changed.
- The visible server supervisor now contains the exact historical Windows broken-console failure. Console rendering is optional, file/state logging remains authoritative, process identity uses more than a PID, stale state cannot impersonate a running server, and an orphaned Java process is reported as **RUNNING / UNMANAGED** and remains update-unsafe.
- The compatibility end-to-end test now accepts the improved result of zero loot-table warnings while still failing on any unexpected warning.

## Validation result

A clean Packwiz update installed 235 client JARs and 202 server JARs. It preserved personal options, the keybinding container, screenshots, saves, shader settings, custom shaderpacks, and preserved mod-specific client preferences. Fusion was present on the client and absent on the server.

The fresh 202-JAR Forge server reached `Done`, loaded all 118 quests and the compatibility datapack at final priority, reloaded data successfully, produced no targeted Domestication Innovation, Nether's Delight, Beautify, TF D&V, or rice compatibility error, saved all seven loaded dimensions, exited with code 0, and released its port. The same 202-JAR payload also passed the real supervisor integration: direct Java ownership, `Done`, normal save/stop, JVM exit, and port release.

The launcher suites passed scheduled restart, visible one-console command forwarding, no second shell, exact `0xE9` broken-pipe injection, recycled-PID rejection, textual diagnostic false-positive rejection, unmanaged-process protection, stale-state reconciliation, duplicate-start/update blocking, clean recovery launch, and normal saved shutdown. No disposable test used production port 25565.

## Live deployment safety

The live server was confirmed stopped before changes. A new cold backup including the world was created and validated. The live Fusion JAR was moved to a timestamped recoverable quarantine, not deleted. The hardened management tools and root launchers were installed with previous copies preserved in deployment backups. The world was not opened or modified, and the final status is **STOPPED**, port 25565 is not listening, and updates are reported safe.

## Known upstream limitations left intact

- JER may omit Supplementaries-modified cartographer trades from its display because Supplementaries' quill conversion receives JER's dummy trader. Actual villager trades are unaffected. Disabling the quill gameplay feature merely to silence a display warning was not justified.
- Smarter Farmers logs that it could not add every modded food to the villager food-point map. Its installed config has no isolated custom-food toggle or repair; changing the JAR or mod selection was avoided.
- Bloop 1.8.0 Alpha 3 loads but needs many Oculus compatibility patches. Treat it as an optional shader and switch to a known-good pack if it produces visual corruption.
- EMF can deliberately stop rebuilding a few Relics/cape models after reaching its safety cap; affected cosmetics may fall back rather than destabilising the client.
- The collision-heavy `R`, `B`, `Z`, `K`, `G`, `U`, `V`, and `T` bindings remain personal. Controlling's conflict screen should be used to choose them; the updater must not reset player controls.
- Routine mixin metadata, version-check timeout, Distant Horizons GC-preference, and transient entity-sync warnings remain non-fatal. No OOM, current JVM crash, missing dependency, mixin-apply failure, shader compile failure, or framebuffer failure was found in the latest usable client/server sessions.

The local repository changes are not published automatically. Friends receive them only after the normal reviewed publish step updates the stable Packwiz URL.
