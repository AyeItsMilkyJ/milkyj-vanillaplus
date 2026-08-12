# MilkyJ Vanilla+ — Packwiz distribution

This repository is the permanent update source for the Forge 1.20.1 client and dedicated server. Players import one small Prism Launcher bootstrap ZIP once. Prism runs Packwiz before every launch; Packwiz downloads changed files and removes only files it previously managed.

Current locked platform:

- Minecraft `1.20.1`
- Forge `47.4.10`
- Established previous pack version `1.8.1-packwiz.1`
- Repaired candidate `1.9.0-rc1` (unpublished; manual tests required)

The live world is not part of this repository and no update script is allowed to touch it without first producing a timestamped backup.

## First setup

1. Create a public GitHub repository, recommended name `milkyj-vanillaplus`.
2. Run `scripts\Set-PackUrl.ps1` with that repository's raw URL.
3. Run `scripts\Update-PackMetadata.ps1`, then `scripts\Validate-Pack.ps1`.
4. Commit and push the repository.
5. Run `scripts\Build-Prism-Bootstrap.ps1` and give players the generated ZIP once.

Detailed day-to-day publishing, player installation, server updating, backups, and rollback are in [docs/OPERATIONS.md](docs/OPERATIONS.md).

The Prism quoting repair is documented in [docs/PRISM-BOOTSTRAP-REPAIR.md](docs/PRISM-BOOTSTRAP-REPAIR.md). The opt-in, not-yet-deployed 24/7 Windows supervisor, cold backups, scheduled tasks, status, update, and rollback tooling are documented in [docs/SERVER-24-7-OPERATIONS.md](docs/SERVER-24-7-OPERATIONS.md).

The current beginner progression contains 118 pack-specific quests across 9 chapters. Its exact chapter counts, progress-preservation audit, installed-system boundaries, and verification checklist are in [docs/QUEST-PROGRESSION.md](docs/QUEST-PROGRESSION.md).

The generated audit reports in `audit/` are the source of truth for mod/file sides and exclusions.
