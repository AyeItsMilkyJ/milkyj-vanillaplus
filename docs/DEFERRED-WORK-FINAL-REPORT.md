# Deferred manual-gate work report

Date: 12 August 2026

Current RC branch: `repair/v1.9.0-rc1-release-blockers`

Compatibility investigation branch/worktree: `audit/preexisting-compatibility` at commit `54dea7e`, in sibling directory `MilkyJ-Packwiz-compat-audit`

## Task A — Prism bootstrap generation

Root cause: the generator wrote visually quoted but unescaped embedded quotes in Prism's INI format. Prism consumed them, allowing the expanded Java executable and `-jar` boundary to become malformed. All bootstrap sources now serialize:

```ini
PreLaunchCommand=\"$INST_JAVA\" -jar packwiz-installer-bootstrap.jar <PACK_URL>
```

The process-level regression test built the same generator used for production, decoded the instance value, launched the generated command with a Java path containing spaces, observed a Java child with a distinct `-jar packwiz-installer-bootstrap.jar` argument, found none of the forbidden concatenation patterns, and stopped only the disposable child. Result: **PASS**.

Replacement LAN bootstrap:

```text
dist/MilkyJ-VanillaPlus-1.9.0-rc1-LAN-TEST-r2-Prism.zip
3eac0a7fce9029d023182e276dea5da1695ad34b817c4f0582ea88d3fe34a907
```

The ZIP and `instance.cfg` were inspected directly. R2 has not been imported manually; the earlier real manual test succeeded only after the user corrected the command through Prism's UI.

## Task B — opt-in Windows 24/7 management

Architecture and operator commands are in `SERVER-24-7-OPERATIONS.md`. The system provides start, normal stop, restart, status, verified cold backup, backup validation/retention, log viewing, manual update-and-start, explicit rollback, scheduled-task generation/install/removal, and a bounded crash supervisor.

The supervisor launches Forge Java directly instead of calling the live installation's legacy `run.bat`, which itself starts an older watchdog. This avoids nested supervisors, owns the real JVM stdin/PID, and preserves reliable normal shutdown.

Crash policy: 15/30/60/120-second backoff; four failures in ten minutes stop retries; a 20-minute stable run resets the window. Intentional stop cancels restart. A shutdown that outlives 240 seconds is surfaced for manual intervention and is not killed.

Backup policy: verified timestamped cold ZIPs, SHA-256 sidecars, seven daily plus four weekly representatives, no retention until the newest backup validates, no deletion of unverified archives, and explicit world restore with a new safety backup first.

Startup policy: opt-in Task Scheduler BootTrigger with network delay and S4U background execution. The daily 04:00 cold-backup task is separately opt-in. Neither task was installed or enabled.

Disposable results:

- lightweight lifecycle/crash/backup/task harness on 25577: **PASS** for every requested case;
- full clean 203-mod Forge server on 25578: reached `Done` in 100.442 seconds, direct Java ownership **PASS**, normal stop **PASS**, all dimensions saved, JVM exited, port released;
- production 25565 before/after guard: unchanged and never bound by a test;
- no live production path used by either harness.

## Task C — pre-existing data errors

The investigation was isolated from this branch. Its sole committed file is `docs/PREEXISTING-COMPATIBILITY-AUDIT.md` on `audit/preexisting-compatibility`.

Recommendations:

- Central Kitchen missing Miner's Delight recipe item: **IGNORE SAFELY**; it targets absent optional content.
- Aether's Delight empty shield overrides: **IGNORE SAFELY**; they achieve intentional recipe removal with log noise.
- Beautify misspelled advancement item: **FIX NEXT RELEASE**.
- Domestication `blazing`/`blazed` loot-modifier mismatch: **FIX NOW** in a separate tested compatibility datapack.
- Nether's Delight invalid `alternative(s)` conditions: **FIX NOW** in that compatibility datapack using `minecraft:any_of`.
- Relics' unregistered `talisman` reference: **IGNORE SAFELY**; the release ships only orphaned talisman assets, no registered talisman item.

No fixes were applied, and no mod version changes were made.

## File inventory — current RC branch

Modified:

- `.gitignore`
- `README.md`
- `audit/encoding-validation.json` (final 1,207-file encoding revalidation)
- `audit/questbook-validation-detailed.json` (final frozen-content revalidation timestamp)
- `audit/quest-mods.json` (final exact-JAR revalidation timestamp)
- `audit/rc-lan-harness.json` (earlier real LAN manual-test evidence retained)
- `bootstrap/template/instance.cfg`
- `docs/MANUAL-RC-TEST.md`
- `docs/OPERATIONS.md`
- `docs/RELEASE-GATE-REPAIR.md`
- `scripts/Build-Prism-Bootstrap.ps1`
- `scripts/Set-PackUrl.ps1`
- `scripts/Start-RcLanTest.ps1`
- `scripts/Stop-RcLanTest.ps1`
- `server-tools/Backup-Server.ps1`
- `server-tools/Common.ps1`
- `server-tools/Restore-ServerBackup.ps1`
- `server-tools/server-settings.json`
- `server-tools/Start-Server.ps1`
- `server-tools/Update-And-Start-Server.ps1`
- `server-tools/Update-Server.ps1`

Created:

- `audit/forge-supervisor-integration.json`
- `audit/prism-bootstrap-lan-r2.json`
- `audit/prism-bootstrap-regression.json`
- `audit/server-infrastructure-tests.json`
- `docs/DEFERRED-WORK-FINAL-REPORT.md`
- `docs/PRISM-BOOTSTRAP-REPAIR.md`
- `docs/SERVER-24-7-OPERATIONS.md`
- `scripts/Test-ForgeSupervisorIntegration.ps1`
- `scripts/Test-PrismBootstrapCommand.ps1`
- `scripts/Test-ServerInfrastructure.ps1`
- `server-tools/BACKUP SERVER.bat`
- `server-tools/Get-ServerStatus.ps1`
- `server-tools/Install-AutomaticStartup.ps1`
- `server-tools/Invoke-BackupRetention.ps1`
- `server-tools/Invoke-ScheduledBackup.ps1`
- `server-tools/Open-LatestServerLog.ps1`
- `server-tools/RESTART SERVER.bat`
- `server-tools/Remove-AutomaticStartup.ps1`
- `server-tools/Restart-Server.ps1`
- `server-tools/Rollback-ServerUpdate.ps1`
- `server-tools/SERVER STATUS.bat`
- `server-tools/Server-Supervisor.ps1`
- `server-tools/START SERVER.bat`
- `server-tools/Start-AutomaticServer.ps1`
- `server-tools/STOP SERVER.bat`
- `server-tools/Stop-Server.ps1`
- `server-tools/Test-ServerBackup.ps1`
- `server-tools/Test-ServerInstallation.ps1`
- `server-tools/UPDATE SERVER.bat`
- `server-tools/VIEW LATEST LOG.bat`
- `tests/fake_minecraft_server.py`

Generated but intentionally Git-ignored:

- `dist/MilkyJ-VanillaPlus-1.9.0-rc1-LAN-TEST-r2-Prism.zip`
- disposable test installations, logs, worlds, backups, task previews, and transient bootstrap artefacts below `build/`

## File inventory — compatibility branch

Created only in the separate investigation worktree:

- `docs/PREEXISTING-COMPATIBILITY-AUDIT.md`

## Frozen-content and safety confirmations

- Quest definitions: unchanged (118 definitions; no ID or reward edit).
- Mod metadata/selection: unchanged (238 mod metadata files; no add/remove/update).
- `packwiz/` and `payload/`: unchanged.
- Production Packwiz URL/configuration: unchanged.
- No repository remote exists; nothing was published, pushed, or deployed.
- No scheduled task was installed or enabled.
- Production port 25565 was never used by an automated test.
- Live server, world, Prism instance, firewall, and router were not modified.
- The live server log, legacy `run.bat`, and one Prism `PreLaunchCommand` field were inspected read-only to establish root cause and deployment compatibility.
- Remaining manual action: import/test the R2 bootstrap and complete the deferred authenticated two-client quest/progress and copied-world gates before release.
