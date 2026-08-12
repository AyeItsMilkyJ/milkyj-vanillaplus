# MilkyJ Vanilla+ — Packwiz distribution

This repository is the permanent update source for the Forge 1.20.1 client and dedicated server. Players import one small Prism Launcher bootstrap ZIP once. Prism runs Packwiz before every launch; Packwiz downloads changed files and removes only files it previously managed.

Current locked platform:

- Minecraft `1.20.1`
- Forge `47.4.10`
- Pack version `1.8.1-packwiz.1`

The live world is not part of this repository and no update script is allowed to touch it without first producing a timestamped backup.

## First setup

1. Create a public GitHub repository, recommended name `milkyj-vanillaplus`.
2. Run `scripts\Set-PackUrl.ps1` with that repository's raw URL.
3. Run `scripts\Update-PackMetadata.ps1`, then `scripts\Validate-Pack.ps1`.
4. Commit and push the repository.
5. Run `scripts\Build-Prism-Bootstrap.ps1` and give players the generated ZIP once.

Detailed day-to-day publishing, player installation, server updating, backups, and rollback are in [docs/OPERATIONS.md](docs/OPERATIONS.md).

The current beginner progression contains 120 pack-specific quests across 10 chapters. Its exact chapter counts, progress-preservation audit, deferred systems, and verification checklist are in [docs/QUESTBOOK.md](docs/QUESTBOOK.md).

The generated audit reports in `audit/` are the source of truth for mod/file sides and exclusions.
