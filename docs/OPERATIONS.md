# Operations guide

## One-time repository setup

The project is fully generated and validated, but it cannot have a real public URL until you create the remote repository.

1. Create a **public** GitHub repository. The recommended name is `milkyj-vanillaplus`.
2. From this repository directory, configure the one value that cannot be inferred locally:

   ```powershell
   .\scripts\Set-PackUrl.ps1 -RawRepositoryBaseUrl "https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/milkyj-vanillaplus/main"
   ```

3. Validate, create the first commit, connect the remote, and push:

   ```powershell
   .\scripts\Update-PackMetadata.ps1
   .\scripts\Validate-Pack.ps1
   git add -- .
   git commit -m "Initial permanent Packwiz release"
   git branch -M main
   git remote add origin https://github.com/YOUR_GITHUB_USERNAME/milkyj-vanillaplus.git
   git push -u origin main
   ```

4. Build the one-time Prism import:

   ```powershell
   .\scripts\Build-Prism-Bootstrap.ps1
   ```

The player ZIP appears in `dist\MilkyJ-VanillaPlus-AutoUpdating-Prism.zip`. `dist` is ignored by Git because it is a generated release artefact.

The final pack URL is:

```text
https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/milkyj-vanillaplus/main/packwiz/pack.toml
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

## Publishing an update

1. Increment `version` in `packwiz\pack.toml` and `packVersion`/`ExportVersion` when appropriate.
2. Run the validation commands above.
3. Commit and push. The helper can perform the guarded commit/push:

   ```powershell
   .\scripts\Publish-Update.ps1 -CommitMessage "Pack 1.8.1" -Push
   ```

The publish helper refuses obvious world/account/personal paths. Inspect `git status` before every release anyway.

## Rebuilding the beginner quest book

The maintained quest source is generated by `scripts\Build-BeginnerQuestBook.ps1`. The script reads the preserved 1.8.0 definitions under `audit\questbook-legacy-1.8.0`, retains selected quest/task/reward IDs, validates the 120-quest graph, and then refreshes the hosted Packwiz payload.

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

The copy operation does not stop or modify the running server. It creates `Minecraft Server\packwiz-tools`.

For an update:

1. Stop the server cleanly with the existing stop command.
2. Wait until port 25565 and the supervisor are both stopped.
3. Run `packwiz-tools\Update-And-Start-Server.bat`.

`Update-Server.ps1` refuses to continue while the server port or supervisor is active. It finds Java 17, creates a timestamped backup under `backups\packwiz`, runs Packwiz with `-g -s server`, and restores the previous managed files if installation fails. Only after success does `Start-Server.ps1` launch the existing two-hour restart supervisor.

`Start-Server.bat` starts without updating. `Backup-Server.bat` creates a manual backup without starting or updating.

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
  -BackupPath ".\backups\packwiz\YYYYMMDD-HHMMSS" `
  -Confirm:$false
```

This restores managed mods/config/scripts but does not replace the world. Add `-RestoreImportantFiles` only if server properties/allowlists also need restoration.

World restoration is intentionally explicit:

```powershell
.\packwiz-tools\Restore-ServerBackup.ps1 `
  -BackupPath ".\backups\packwiz\YYYYMMDD-HHMMSS" `
  -RestoreWorld
```

Before replacing the world, the restore script automatically backs up the current world again. It never performs an unbacked world replacement.

## What is never managed

The Packwiz index and repository ignore rules exclude `options.txt`, keybinding data stored in options, `servers.dat`, saves, screenshots, logs, crash reports, account/token files, shader packs/settings, Xaero player data, Distant Horizons local cache, live worlds, and backups.

Exact managed/excluded file and side reports are in `audit\mods.csv`, `audit\managed-files.csv`, and `audit\excluded-files.csv`.
