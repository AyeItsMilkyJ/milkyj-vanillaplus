# Windows 24/7 dedicated-server operations

Status: built and tested only against disposable installations. No scheduled task was installed, no production tools were deployed, and the live server/world were untouched.

## Architecture

`Server-Supervisor.ps1` is the single long-lived owner of the Minecraft process. It launches Java directly with Forge's `user_jvm_args.txt` and `libraries/.../win_args.txt`; it deliberately does not invoke legacy `run.bat` wrappers that may start a second watchdog. The supervisor owns Minecraft stdin, records process state under `server-management`, and writes a timestamped supervisor log per session.

`Start-Server.ps1` refuses a duplicate listener, supervisor, or recorded server PID. `Stop-Server.ps1` creates a server-local stop request. The supervisor writes Minecraft's normal `stop` command to stdin, waits for the launch process to exit, and checks that the configured port is no longer listening.

If a mod such as Distant Horizons leaves the JVM alive after world saving, the supervisor waits for the configured timeout (240 seconds by default), records `manual-intervention-required`, and leaves the process alive for diagnosis. It never immediately kills a production JVM.

Unexpected exits use backoff of 15, 30, 60, then 120 seconds. Four failures inside ten minutes stop automatic retry and surface `failed-repeatedly`. A stable 20-minute run resets the rapid-failure history. Intentional stop requests cancel restarts.

No Packwiz update occurs during startup, crash recovery, scheduled startup, or scheduled backup.

## One-time deployment (manual; not run)

After the RC is approved and while reviewing the target path:

```powershell
.\server-tools\Install-ServerTools.ps1 -ServerRoot "$env:USERPROFILE\Desktop\Minecraft Server"
```

This copies the management package to `Minecraft Server\packwiz-tools`. It does not install a task, start the server, apply Packwiz, or replace the world.

The double-click wrappers in that folder are:

- `START SERVER.bat`
- `STOP SERVER.bat`
- `RESTART SERVER.bat`
- `SERVER STATUS.bat`
- `BACKUP SERVER.bat`
- `UPDATE SERVER.bat`
- `VIEW LATEST LOG.bat`

Each wrapper delegates to PowerShell and contains no duplicated server logic.

## Automatic startup and daily backup

Generate and inspect the Task Scheduler XML without installing anything:

```powershell
.\packwiz-tools\Install-AutomaticStartup.ps1 -GenerateOnly -IncludeDailyBackup
```

Opt-in installation command:

```powershell
.\packwiz-tools\Install-AutomaticStartup.ps1 -IncludeDailyBackup
```

Removal command:

```powershell
.\packwiz-tools\Remove-AutomaticStartup.ps1 -IncludeDailyBackup
```

The startup task uses a BootTrigger, waits 60 seconds for networking, requests an S4U background logon for the installing Windows user, uses the server root as its working directory, and relies on duplicate-start locking. The optional daily task runs at 04:00 and calls the cold-backup workflow. Installation may require an elevated PowerShell depending on local Task Scheduler policy.

No task was installed or enabled during implementation. The disposable test parsed two generated XML files and confirmed the matching task count did not change.

## Backup policy

Backups are cold, timestamped ZIP archives. If the server is running, the scheduled or double-click backup path performs a controlled graceful stop, verifies full exit/port release, creates and reads every archive entry, records a SHA-256 validation sidecar, applies retention only after the newer archive validates, and then restarts.

Included recovery data covers:

- the complete world, including `data`, player/team state, advancements, stats, and `serverconfig` quest/team data;
- mods and Packwiz-managed config/defaultconfig/script/resourcepack/global-datapack state;
- Packwiz installer state;
- server properties, JVM arguments, allow/ban/operator lists, launch files, and management tools.

Defaults retain one representative for seven recent days and four recent weeks, always retain the new verified archive, and never delete archives without a validation sidecar. Invalid archives are quarantined as `.invalid`; incomplete staging is never treated as a usable backup. Backups and runtime management state are Git-ignored.

## Operator-controlled update

`UPDATE SERVER.bat` runs this sequence:

1. refuse while any server listener, supervisor, or recorded server process exists;
2. create and fully validate a cold backup;
3. record the prior pack version and Packwiz state hash;
4. run Packwiz server mode from the configured HTTPS URL;
5. validate the installed Forge/Packwiz structure;
6. start under the supervisor;
7. require a fresh Minecraft `Done` line;
8. if startup verification fails, request a graceful stop and print an explicit rollback command.

If the installer itself fails, only Packwiz-managed files are restored automatically from the verified pre-update archive. The world is never replaced. A successful-but-broken update is not silently rolled back because that could obscure a mod's world migration; use the recorded archive explicitly:

```powershell
.\packwiz-tools\Rollback-ServerUpdate.ps1 `
  -BackupPath ".\backups\packwiz\YYYYMMDD-HHMMSS.zip" `
  -StartAfterRollback
```

World restoration remains a separate high-impact option in `Restore-ServerBackup.ps1 -RestoreWorld`. It creates another verified backup of the current stopped world before replacement.

## Status output

`SERVER STATUS.bat` reports running/stopped state, listener/Minecraft PID, recorded launch PID, port, supervisor state/PID, current recorded pack version, latest verified backup, last start, latest crash/restart event, latest Minecraft log, and whether an update is safe.

## Disposable test evidence

The lightweight management harness at port 25577 passed:

- first start and running status;
- duplicate-start refusal;
- active backup and active update refusal;
- normal stop with world-save evidence;
- graceful restart;
- forced unexpected exit, watchdog restart, and backoff;
- repeated-failure cut-off;
- verified ZIP backup and managed-file rollback preparation;
- stopped status/update-safe reporting;
- scheduled-task generation without installation;
- simulated lingering JVM reported but not killed;
- production path and port guards.

The real Forge integration at port 25578 used a fresh clone of the clean 203-mod RC server. It passed direct Java ownership, reached `Done` in 100.442 seconds, accepted the normal `stop` command, saved all loaded dimensions, exited the JVM, and released the port.

Evidence: `audit/server-infrastructure-tests.json` and `audit/forge-supervisor-integration.json`.
