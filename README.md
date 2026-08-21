# MilkyCraft Vanilla+ — Packwiz distribution

This repository is the permanent update source for the Forge 1.20.1 client and dedicated server. Players import one small Prism Launcher bootstrap ZIP once. Prism runs Packwiz before every launch; Packwiz downloads changed files and removes only files it previously managed.

`MilkyCraft Vanilla+` is the public pack name. Existing internal distribution identifiers, repository URLs, namespaces and managed paths retain their established `MilkyJ` names to preserve installed-instance compatibility.

Current locked platform:

- Minecraft `1.20.1`
- Forge `47.4.10`
- Established previous pack version `1.8.1-packwiz.1`
- Current Packwiz release `1.9.0-rc1`

Permanent public update feed:

```text
https://raw.githubusercontent.com/AyeItsMilkyJ/milkyj-vanillaplus/main/packwiz/pack.toml
```

The live world is not part of this repository and no update script is allowed to touch it without first producing a timestamped backup.

## Player setup

1. Build or download `MilkyJ-VanillaPlus-AutoUpdating-Prism.zip`.
2. Import it into Prism Launcher once.
3. Press **Play** normally. Packwiz checks this repository and downloads only changed managed files before Minecraft starts.

Detailed day-to-day publishing, player installation, server updating, backups, and rollback are in [docs/OPERATIONS.md](docs/OPERATIONS.md).

The Prism quoting repair is documented in [docs/PRISM-BOOTSTRAP-REPAIR.md](docs/PRISM-BOOTSTRAP-REPAIR.md). The opt-in, not-yet-deployed 24/7 Windows supervisor, cold backups, scheduled tasks, status, update, and rollback tooling are documented in [docs/SERVER-24-7-OPERATIONS.md](docs/SERVER-24-7-OPERATIONS.md).

The current beginner progression contains 200 pack-specific quests across 14 chapters. Its connected branch map, exact chapter counts, progress-preservation audit, installed-system boundaries, research sources, and verification checklist are in [docs/QUEST-PROGRESSION.md](docs/QUEST-PROGRESSION.md).

The optional creator replay/cinematic evaluation, current fail-closed status and future enablement gates are in [docs/CREATOR-CAPTURE.md](docs/CREATOR-CAPTURE.md). Prophet's immutable replay-media boundary is in [docs/CREATOR-REPLAY-INTEGRATION.md](docs/CREATOR-REPLAY-INTEGRATION.md).

The generated audit reports in `audit/` are the source of truth for mod/file sides and exclusions.
