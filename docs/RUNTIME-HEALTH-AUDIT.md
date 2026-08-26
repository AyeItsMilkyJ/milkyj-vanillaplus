# Runtime health audit — updated 26 August 2026

The current MilkyCraft Vanilla+ `1.9.0-rc4` candidate has no missing mandatory Forge dependency, duplicate top-level mod ID, duplicate JAR payload, JAR hash mismatch, or client/server payload drift. The verified managed totals are 242 mod definitions, 240 client JARs, and 206 dedicated-server JARs.

This document combines the earlier RC1–RC3 runtime-maintenance history with the current disposable RC4 revalidation. The expansion evidence is `audit/create-expansion-validation.json`; `audit/runtime-health-20260822.json` and the live-deployment section below describe the preceding maintenance pass. RC3 is deployed on the stopped live dedicated server. The primary Prism instance uses the stable Packwiz feed and will receive RC4 on its next launch after publication; its newest retained client runtime log predates this candidate.

## Earlier runtime repairs retained

- Fusion 1.3.12 remains client-only. Rechiseled's Fusion dependency is client-only, Modrinth marks the server environment unsupported, and no server mod requires it. This continues to exclude one unnecessary dedicated-server JAR without changing Fusion's version.
- Every affected PowerShell maintenance script now resolves its default project root after parameter binding. Running the scripts normally with `powershell.exe -File` no longer produces an empty-path error.
- The selected local Prism instance's Packwiz pre-launch command was restored from the repository's tested template. A timestamped copy of the previous `instance.cfg` was saved first. No `options.txt`, controls, shader selection, saves, screenshots, accounts, or other personal Minecraft data was changed.
- The visible server supervisor now contains the exact historical Windows broken-console failure. Console rendering is optional, file/state logging remains authoritative, process identity uses more than a PID, stale state cannot impersonate a running server, and an orphaned Java process is reported as **RUNNING / UNMANAGED** and remains update-unsafe.
- The compatibility end-to-end test now accepts the improved result of zero loot-table warnings while still failing on any unexpected warning.

## RC4 disposable validation result

A clean 729-entry Packwiz update installed 240 client JARs and 206 server JARs. It preserved personal options, the keybinding container, screenshots, saves, shader settings, custom shaderpacks, and mod-specific client preferences. The same run retained the RC2-to-RC3 side-transition regression gate: all eleven customised preferences survived their change from managed-both to preserved-client, their obsolete copies were removed from the existing disposable server, and the five optional control-tool files were delivered only to the client. Fusion and SeasonHUD remained client-only.

The fresh 206-JAR Forge server reached `Done`, loaded all 234 quests and the compatibility datapack at final priority, reloaded data successfully, answered a post-reload command barrier, produced no targeted Domestication Innovation, Nether's Delight, Beautify, TF D&V, rice, or Aquatic Ambitions compatibility error, saved all seven loaded dimensions, exited with code 0, and released its port. The same 206-JAR payload also retains the earlier real-supervisor evidence: direct Java ownership, `Done`, normal save/stop, JVM exit, and port release.

An exact disposable `v1.9.0-rc3` to `1.9.0-rc4` loopback update installed the changed Create Projects quest definition, kept the client JAR count at 240, preserved options, keybindings, screenshots, saves, shader settings and personal shaderpacks, and removed an injected obsolete managed file. Rolling back restored the rc3 quest bytes and removed the rc4-only probe. No live path or public feed was used.

All seven live Forge starts retained on 22 August reached `Done`. Four scheduled three-hour restarts completed cleanly. The final GUI session stopped intentionally with exit code 0 after saving the Overworld, Nether, End, Aether, Twilight Forest, Otherside and Graveyard Past; Distant Horizons closed all seven databases with zero incomplete tasks. There was no fatal error, crash report, OOM, watchdog event or runtime tick-behind warning.

## Existing launcher and supervisor evidence

The launcher suites passed scheduled restart, visible one-console command forwarding, no second shell, exact `0xE9` broken-pipe injection, recycled-PID rejection, textual diagnostic false-positive rejection, unmanaged-process protection, stale-state reconciliation, duplicate-start/update blocking, clean recovery launch, and normal saved shutdown. No disposable test used production port 25565.

## Historical RC1 live deployment safety

During the earlier RC1 runtime-maintenance pass, the live server was confirmed stopped before changes. A new cold backup including the world was created and validated. The live Fusion JAR was moved to a timestamped recoverable quarantine, not deleted. The hardened management tools and root launchers were installed with previous copies preserved in deployment backups. The world was not opened or modified, and the final status was **STOPPED**, port 25565 was not listening, and updates were reported safe. None of those live operations was repeated for RC2.

## Known upstream limitations left intact

- JER may omit Supplementaries-modified cartographer trades from its display because Supplementaries' quill conversion receives JER's dummy trader. Actual villager trades are unaffected. Disabling the quill gameplay feature merely to silence a display warning was not justified.
- Smarter Farmers logs that it could not add every modded food to the villager food-point map. Its installed config has no isolated custom-food toggle or repair; changing the JAR or mod selection was avoided.
- Bloop 1.8.0 Alpha 3 loads but needs many Oculus compatibility patches. Treat it as an optional shader and switch to a known-good pack if it produces visual corruption.
- EMF can deliberately stop rebuilding a few Relics/cape models after reaching its safety cap; affected cosmetics may fall back rather than destabilising the client.
- The updater still never resets player controls. It now distributes an optional, backed-up control patcher that changes only untouched defaults and leaves intentional context-only overlaps alone; see `docs/CONTROLS.md`.
- Routine mixin metadata, version-check timeout, Distant Horizons GC-preference, and transient entity-sync warnings remain non-fatal. No OOM, current JVM crash, missing dependency, mixin-apply failure, shader compile failure, or framebuffer failure was found in the latest usable client/server sessions.
- Do not issue `stop` or trigger a supervised restart immediately after `/reload`. One disposable run stopped about six seconds after the advancement marker, saved every dimension, but left the reload lifecycle alive beyond five minutes. Waiting for a command-response barrier and then 30 seconds produced a normal code-0 exit in two controlled reproductions and the final end-to-end gate. Routine production stops never showed this race.

The local repository changes are not published automatically. Friends receive them only after the normal reviewed publish step updates the stable Packwiz URL.
