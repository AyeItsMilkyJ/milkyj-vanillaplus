# Operations guide

## Permanent repository

The public repository and stable Packwiz URL are configured:

```text
https://raw.githubusercontent.com/AyeItsMilkyJ/milkyj-vanillaplus/main/packwiz/pack.toml
```

Build the one-time Prism import with:

   ```powershell
   .\scripts\Build-Prism-Bootstrap.ps1
   ```

The player ZIP appears in `dist\MilkyJ-VanillaPlus-AutoUpdating-Prism.zip`. `dist` is ignored by Git because it is a generated release artefact.

The final pack URL is:

```text
https://raw.githubusercontent.com/AyeItsMilkyJ/milkyj-vanillaplus/main/packwiz/pack.toml
```

Do not make the repository private unless you replace GitHub raw hosting with another public HTTPS host. Packwiz clients do not have your GitHub credentials.

## New-player installation

1. Install Prism Launcher and Java 17.
2. In Prism select **Add Instance → Import → ZIP**.
3. Select `MilkyJ-VanillaPlus-AutoUpdating-Prism.zip`.
4. Sign into Minecraft in Prism and press **Play**.

That ZIP is imported only once. The configured pre-launch command runs `packwiz-installer-bootstrap.jar` before Minecraft. On first launch it downloads the pack; later launches download only changes and delete only obsolete files that Packwiz previously managed.

Players may change RAM in **Edit Instance → Settings → Memory**. The bootstrap starts at 4–8 GiB and does not contain an account, token, server list, options, saves, screenshots, logs, or shader settings.

## Existing-player updates

Existing players do nothing beyond pressing **Play**. Once a repository commit is pushed to `main`, Packwiz compares the new index with its local state before launch.

Do not send another full installation ZIP for ordinary updates. A replacement bootstrap is needed only if the repository URL, Minecraft version, Forge version, or pre-launch mechanism changes.

## Adding a mod

Work in the `packwiz` directory. Prefer Packwiz's supported source commands so the metadata includes a legal upstream download and update IDs:

```powershell
cd packwiz
packwiz modrinth add <project-or-version-url>
# or
packwiz curseforge add <project-or-file-url>
cd ..
```

Open the new `.pw.toml` and explicitly set one of:

```toml
side = "client"
side = "server"
side = "both"
```

Use `client` only when a dedicated server neither needs nor can load the mod. Use `server` only when clients do not need the JAR. Content mods that add blocks, items, entities, dimensions, registries, or networking normally belong on `both`.

Then refresh and run the full disposable test:

```powershell
.\scripts\Update-PackMetadata.ps1
.\scripts\Validate-Pack.ps1
.\scripts\Test-InstallerEndToEnd.ps1
```

The server can remain online while you prepare a repository update, but do not run its Packwiz updater until it has stopped cleanly.

## Updating a mod

Update one mod at a time unless a coordinated dependency update requires more:

```powershell
cd packwiz
packwiz update <metadata-name-without-.pw.toml>
cd ..
.\scripts\Update-PackMetadata.ps1
.\scripts\Validate-Pack.ps1
.\scripts\Test-InstallerEndToEnd.ps1
```

Review dependency/version changes before publishing. The project intentionally preserves the audited Minecraft `1.20.1`, Forge `47.4.10`, and current mod versions until you explicitly update them.

## Removing a mod

Delete only its `packwiz\mods\<name>.pw.toml`, then refresh and test:

```powershell
.\scripts\Update-PackMetadata.ps1
.\scripts\Validate-Pack.ps1
.\scripts\Test-InstallerEndToEnd.ps1
```

On the next update Packwiz removes the old JAR because it was previously managed. It does not recursively clean unfamiliar JARs or personal files. Check for dependencies and remove obsolete configs only when ownership is certain.

## Config, defaultconfigs, KubeJS, scripts, and resource packs

Hosted files live under `payload\<side>\...`; their corresponding Packwiz metadata lives at the same destination under `packwiz\...` with `.pw.toml` appended.

To add a new managed file safely:

```powershell
.\scripts\Add-HostedFile.ps1 `
  -SourcePath C:\path\to\edited-file.toml `
  -DestinationPath config\example-common.toml `
  -Side both
```

To update an existing managed file, edit its copy under `payload`, then run `Update-PackMetadata.ps1`. That script refreshes the payload hash, metadata hash, index, and `pack.toml` index hash in the correct order.

To remove a hosted file, delete both its payload and its matching `.pw.toml`, then refresh and validate. The same mechanism is ready for `kubejs` and `scripts`; the audited pack currently has no files in either folder.

Resource-pack archives from Modrinth and the custom **MilkyJ Stability Fixes** files are client-only and managed. Shader packs are deliberately unmanaged, so players' shader archives, selected shader, and per-shader `.txt` settings remain personal.

### Player settings and Packwiz preservation

Players must keep using the same imported Prism instance. Importing a newer ZIP creates a different instance and cannot inherit personal settings from the old one.

`options.txt` remains completely outside Packwiz management, so Minecraft video settings, render distance, controls, selected resource packs and selected shader are never replaced by an update. Shader sidecars, saves, screenshots, Xaero player data and Distant Horizons caches are also unmanaged.

Text settings under `payload/client/config` are installed as the pack's defaults on a clean client and emitted into `index.toml` with Packwiz `preserve = true`. After that first install, Packwiz leaves the player's existing mod-specific settings alone. Client binary assets, `defaultconfigs`, resource packs and every `both`/`server` config remain normally managed so compatibility and gameplay fixes still update.

If one preserved mod config becomes corrupt or the player wants the newest pack default, close Minecraft, delete only that individual file from the instance's `minecraft/config` folder, and press Play. Packwiz will restore the current default. Do not remove a preserved entry from the manifest casually: an entry removed from the Packwiz index is obsolete managed content and may be deleted by the updater.

## Publishing an update

1. Increment `version` in `packwiz\pack.toml` and `packVersion`/`ExportVersion` when appropriate.
2. Run the validation commands above.
3. Commit and push. The helper can perform the guarded commit/push:

   ```powershell
   .\scripts\Publish-Update.ps1 -CommitMessage "Pack 1.8.1" -Push
   ```

The publish helper refuses obvious world/account/personal paths. Inspect `git status` before every release anyway.

## Rebuilding the beginner quest book

The maintained quest source is generated by `scripts\Build-BeginnerQuestBook.ps1`. The script reads the preserved 1.8.0 definitions under `audit\questbook-legacy-1.8.0`, retains selected quest/task/reward IDs, validates the 118-quest graph, and then refreshes the hosted Packwiz payload.

Preview and validate without changing the managed payload:

```powershell
.\scripts\Build-BeginnerQuestBook.ps1
```

Deploy the validated result into Packwiz:

```powershell
.\scripts\Build-BeginnerQuestBook.ps1 -Deploy
.\scripts\Validate-Pack.ps1 -AllowPlaceholder
.\scripts\Test-InstallerEndToEnd.ps1
```

Do not hand-copy the generated chapter files into a running server. Publish the repository update, stop the server cleanly, and use `Update-And-Start-Server.bat`; that path creates a timestamped backup before Packwiz changes the managed definitions.

## Installing the server tools

After setting the real URL, copy the tools into the dedicated server folder:

```powershell
.\server-tools\Install-ServerTools.ps1 -ServerRoot "$env:USERPROFILE\Desktop\Minecraft Server"
```

The copy operation creates `Minecraft Server\packwiz-tools`; it does not install scheduled tasks, run Packwiz, start a server, or replace a world. Deployment remains manual and was not performed for `1.9.0-rc1`.

Use the double-click `START SERVER.bat`, `STOP SERVER.bat`, `RESTART SERVER.bat`, `SERVER STATUS.bat`, `BACKUP SERVER.bat`, and operator-controlled `UPDATE SERVER.bat` wrappers in that folder. The new supervisor launches Forge directly, gracefully stops through Minecraft stdin, restarts unexpected crashes with bounded backoff, and never applies an update by itself.

Cold backups are verified timestamped ZIPs under `backups\packwiz`. `UPDATE SERVER.bat` refuses active server processes, validates a backup before Packwiz, validates installation/startup afterward, and retains an explicit rollback path. Full architecture, scheduled-task install/remove commands, retention, status fields, and test evidence are in [SERVER-24-7-OPERATIONS.md](SERVER-24-7-OPERATIONS.md).

## Rollback

### Broken repository update

Revert the bad commit and push the revert:

```powershell
git log --oneline
git revert <bad-commit-id>
git push
```

Clients receive the reverted Packwiz index on next launch.

For the server, stop it and run Update-And-Start again. That action first backs up the current world and restores the previous mod/config set described by the reverted index.

### Immediate server-file rollback

With the server stopped:

```powershell
.\packwiz-tools\Restore-ServerBackup.ps1 `
  -BackupPath ".\backups\packwiz\YYYYMMDD-HHMMSS.zip" `
  -Confirm:$false
```

This restores managed mods/config/scripts but does not replace the world. Add `-RestoreImportantFiles` only if server properties/allowlists also need restoration.

World restoration is intentionally explicit:

```powershell
.\packwiz-tools\Restore-ServerBackup.ps1 `
  -BackupPath ".\backups\packwiz\YYYYMMDD-HHMMSS.zip" `
  -RestoreWorld
```

Before replacing the world, the restore script automatically backs up the current world again. It never performs an unbacked world replacement.

## What is never managed

The Packwiz index and repository ignore rules exclude `options.txt`, keybinding data stored in options, `servers.dat`, saves, screenshots, logs, crash reports, account/token files, shader packs/settings, Xaero player data, Distant Horizons local cache, live worlds, and backups. Mod-specific client text settings are managed only for their first-install defaults and are then preserved as described above.

Exact managed/excluded file and side reports are in `audit\mods.csv`, `audit\managed-files.csv`, and `audit\excluded-files.csv`.

## Optional 1.9.0-rc1 multiplayer interaction gate

The automated manifest, clean-install, dedicated-server startup, save, and shutdown checks are required before publishing. The following manual multiplayer checks remain useful when quest or team behaviour changes; run them in disposable installations rather than using the live world.

For the final interaction test, use a separate disposable Prism application root and disposable offline-mode Forge server. Start a local repository host on port 8765, import the RC ZIP, and use an authenticated Minecraft account without copying account files into the project. Then:

1. connect the clean client to the disposable server;
2. open the quest book and verify `WHERE THE FUCK DO I START?` is immediately visible;
3. complete and claim a simple tutorial checkmark;
4. hold one inexpensive requested item and verify an item-detection quest completes;
5. claim its XP reward;
6. connect a second client, join the same FTB Team and verify shared progress;
7. leave another player outside the team and verify their progress remains separate;
8. reopen a teammate-completed quest and verify its description is still readable;
9. stop the disposable server normally and confirm every loaded dimension saves.

An existing-world compatibility test requires a clean offline snapshot made after the production server has stopped. Never hot-copy the running world and never use a backup in place without explicit approval.
