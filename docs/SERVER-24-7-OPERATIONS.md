# Windows 24/7 dedicated-server operations

Status: the management tools, visible console launcher, three-hour restart policy, and optional Discord helper are installed on the dedicated-server PC. Automated validation used disposable installations, followed by a supervised cold-backed rc2 deployment and live visible-console startup. No scheduled task was installed, and no webhook secret is stored in this repository.

## Architecture

`Server-Supervisor.ps1` is the single long-lived owner of the Minecraft process. It launches Java directly with Forge's `user_jvm_args.txt` and `libraries/.../win_args.txt`; it deliberately does not invoke legacy wrappers that may start a second watchdog. The supervisor owns Minecraft stdin, records process state under `server-management`, and writes a timestamped supervisor log per session.

Forge runs with `nogui`, so there is no separate graphical Java server window. When root `run.bat` or `packwiz-tools\START SERVER.bat` is double-clicked, CMD, PowerShell, and Java share one visible console window titled **MilkyCraft Vanilla+ Server - Java Console**. Raw Forge/Minecraft stdout and stderr appear there. The supervisor reads the console through a non-blocking `StreamReader` and forwards ordinary commands to Java; it handles `restart` and `stop` as safe lifecycle requests. This avoids Windows PowerShell 5.1's synchronized `Console.In.ReadLineAsync` startup block. There are separate processes in Task Manager, but only one terminal window.

`Start-Server.ps1` refuses a duplicate listener, supervisor, or recorded server PID. `Stop-Server.ps1` creates a server-local stop request. The supervisor writes Minecraft's normal `stop` command to stdin, waits for the launch process to exit, and checks that the configured port is no longer listening.

Runtime state records a process fingerprint (PID, creation time, executable, command-line hash, and parent PID) for both the supervisor and Minecraft. A recycled Windows PID is never accepted by number alone. Status/start checks also honour the configured port and the held supervisor lock. If both processes and the listener are gone after an abrupt exit, stale active state is atomically reconciled to `stopped-after-abrupt-exit` and active identities are cleared. If Minecraft is still alive but its supervisor is gone, status reports **RUNNING / UNMANAGED**, updates and duplicate starts remain blocked, and no process is killed automatically.

If a mod such as Distant Horizons leaves the JVM alive after world saving, the supervisor waits for the configured timeout (240 seconds by default), records `manual-intervention-required`, and leaves the process alive for diagnosis. It never immediately kills a production JVM.

After each fresh `Done`, the normal policy schedules a clean restart 180 minutes later. Players receive warnings at 10 minutes, 5 minutes, 1 minute, 30 seconds, and 10 seconds. The supervisor runs `save-all flush`, sends the normal `stop`, verifies process exit and port release, waits 10 seconds, and launches Java again in the same console. A stop request during the wait cancels relaunch.

Unexpected exits use separate backoff of 15, 30, 60, then 120 seconds. Four failures inside ten minutes stop automatic retry and surface `failed-repeatedly`. A stable 20-minute run resets the rapid-failure history. Intentional stop requests cancel restarts.

No Packwiz update occurs during startup, crash recovery, scheduled startup, or scheduled backup.

## Normal visible start

Double-click root `run.bat` (preferred) or `packwiz-tools\START SERVER.bat`. Do not launch both. The apparent CMD window is the real interactive Java server console:

- type normal Minecraft commands such as `list`, `say hello`, or `save-all` directly;
- type `restart` for a clean save, stop, and relaunch in the same window;
- type `stop` for a clean save and full shutdown; and
- do not close the window with **X** or press Ctrl+C while the server is running or saving.

The window remains open after shutdown so an error can be read. Press any key only after it says the server console is closed.

Console display is deliberately non-critical: if Windows detaches the output pipe and `Write-Host` raises the historical `0xE9` `HostException`, the supervisor disables further host writes, keeps file logging/state persistence active, and continues lifecycle handling. This does **not** make the window's **X** button a safe shutdown mechanism. Windows can terminate console-attached processes before Minecraft receives its full save timeout, so always type `stop`.

## Discord status notifications

Discord incoming-webhook notifications are optional and require no bot account. When configured, the supervisor posts colour-coded messages for:

- server online after a fresh `Done` line;
- clean offline shutdown;
- operator or scheduled restart;
- unexpected crash plus recovery delay; and
- repeated failures or supervisor errors that need attention.

The webhook is a secret. It is stored only in `discord-webhook.txt` at the dedicated-server root, is covered by `.gitignore`, is never printed by the setup script, and is not part of a Packwiz update or backup. Notification delivery failure only emits a warning and cannot stop Minecraft or its restart supervisor.

To configure it:

1. In the desired Discord text channel, open **Edit Channel → Integrations → Webhooks**, create a webhook named `MilkyCraft Server Status`, and copy its URL.
2. Double-click `packwiz-tools\SET UP DISCORD STATUS.bat` on the server PC.
3. Paste the URL into the hidden prompt and press Enter. A green connection-test message must appear in the channel.
4. Keep using the normal root `run.bat` launcher. The newly configured lifecycle messages begin the next time that supervisor starts.

Never paste the webhook URL into chat, commit it, include it in the mate ZIP, or show it in a screenshot. If it leaks, delete that webhook in Discord and create a replacement.

This is a server-local notifier. If Java crashes while Windows and the internet are available, it can report the crash. If the entire PC, router, power, or internet connection dies, it cannot send an immediate offline message; that case requires a separate externally hosted uptime monitor.

## One-time deployment

After the RC is approved and while reviewing the target path:

```powershell
.\server-tools\Install-ServerTools.ps1 `
  -ServerRoot "$env:USERPROFILE\Desktop\Minecraft Server" `
  -InstallRootLaunchers
```

This copies the management package to `Minecraft Server\packwiz-tools` and installs the root visible `run.bat` plus stop/status aliases. Existing management tools and root launchers are preserved first under `server-management\deployment-backups\<timestamp>`. It does not install a task, start the server, apply Packwiz, change mods, or replace the world. The server must be stopped when `-InstallRootLaunchers` is used.

The double-click wrappers in that folder are:

- `START SERVER.bat`
- `STOP SERVER.bat`
- `RESTART SERVER.bat`
- `SERVER STATUS.bat`
- `BACKUP SERVER.bat`
- `UPDATE SERVER.bat`
- `VIEW LATEST LOG.bat`
- `SET UP DISCORD STATUS.bat`

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

The startup task uses a BootTrigger, waits 60 seconds for networking, requests an S4U background logon for the installing Windows user, uses the server root as its working directory, and relies on duplicate-start locking. An S4U boot task is intentionally background-only and cannot show an interactive desktop console. Log in and use root `run.bat` whenever a visible terminal is wanted. The optional daily task runs at 04:00 and calls the cold-backup workflow. Installation may require an elevated PowerShell depending on local Task Scheduler policy.

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

`SERVER STATUS.bat` reports running/stopped/unmanaged state, listener/Minecraft PID, verified recorded launch PID, port, supervisor state/PID, stale-state reconciliation time, visible/background console mode, next scheduled restart, restart interval, current recorded pack version, latest verified backup, last start, latest crash/restart event, latest Minecraft log, whether Discord notifications are configured, and whether an update is safe. It never prints the webhook URL.

## Disposable test evidence

The lightweight management harness at port 25577 passed:

- first start and running status;
- duplicate-start refusal;
- active backup and active update refusal;
- normal stop with world-save evidence;
- graceful restart;
- forced unexpected exit, watchdog restart, and backoff;
- Discord online/offline/restart/crash/failure lifecycle messages against a loopback-only fake webhook;
- repeated-failure cut-off;
- verified ZIP backup and managed-file rollback preparation;
- stopped status/update-safe reporting;
- scheduled-task generation without installation;
- simulated lingering JVM reported but not killed;
- production path and port guards.

The focused one-console harness at port 25579 also passed its non-blocking input-reader guard, inline supervisor ownership, direct Minecraft child ownership, no second CMD/PowerShell child, inherited raw stdout/stderr, interactive command forwarding, external clean-stop recognition, save-before-stop order, warnings, and a compressed scheduled restart/relaunch cycle. Port 25565 and all live data remained untouched by the harness. A supervised live launch additionally confirmed that Java starts before any command is typed and the one-window state is reported as `VISIBLE / INTERACTIVE`; issuing `list` remains a simple operator-facing visual check.

The supervisor-resilience harness at port 25581 injected the exact historical broken-pipe `HostException`, rejected a live unrelated recycled PID, force-ended a disposable supervisor while its fake Minecraft child remained online, and then ended the child. It confirmed no escaped console exception, continued file logging, cleared terminal process identities, reported the orphan as **RUNNING / UNMANAGED** and update-unsafe, blocked a duplicate start, reconciled state only after every real process/listener was gone, and completed a clean recovery launch/save/exit. It never used port 25565 or a live path.

The latest real Forge integration at port 25578 used the clean disposable 206-JAR Packwiz server installation; it did not read a live server path, world or private server file. It passed direct Java ownership, reached `Done` in 79.339 seconds, accepted the normal `stop` command, saved all loaded dimensions, exited the JVM, and released the port.

Evidence: `audit/server-infrastructure-tests.json`, `audit/visible-server-console.json`, `audit/server-supervisor-resilience.json`, and `audit/forge-supervisor-integration.json`.
