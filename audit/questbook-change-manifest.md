# Quest-book change manifest

This manifest covers the `1.8.1-packwiz.1` beginner-guide rebuild.

## Created

- `scripts/Build-BeginnerQuestBook.ps1`
- `docs/QUESTBOOK.md`
- `audit/questbook-validation.json`
- `audit/questbook-item-ids.txt`
- `audit/end-to-end-result.json`
- `audit/questbook-change-manifest.md`
- `audit/questbook-legacy-1.8.0/**` — all 33 previous quest-definition/research files, preserved and never shipped
- `payload/both/config/ftbquests/quests/chapters/endgame.snbt`
- `payload/both/config/ftbquests/quests/chapters/tinkers_deferred.snbt`
- `payload/both/config/ftbquests/quests/chapters/vehicles.snbt`
- matching `.pw.toml` metadata for those three chapter files

## Rebuilt in place

- `payload/both/config/ftbquests/quests/data.snbt`
- `payload/both/config/ftbquests/quests/chapter_groups.snbt`
- `payload/both/config/ftbquests/quests/chapters/archaeology.snbt`
- `payload/both/config/ftbquests/quests/chapters/create_basics.snbt`
- `payload/both/config/ftbquests/quests/chapters/first_days.snbt`
- `payload/both/config/ftbquests/quests/chapters/homestead.snbt`
- `payload/both/config/ftbquests/quests/chapters/new_horizons.snbt`
- `payload/both/config/ftbquests/quests/chapters/travel_storage.snbt`
- `payload/both/config/ftbquests/quests/chapters/welcome.snbt`
- matching `.pw.toml` metadata for every rebuilt file

## Removed from managed delivery

The following old chapter files and matching `.pw.toml` metadata were removed after their retained quests were merged into the 10 new chapters:

- `aether.snbt`
- `alex_caves.snbt`
- `building.snbt`
- `combat_enchanting.snbt`
- `create_addons.snbt`
- `create_factory.snbt`
- `creative_expeditions.snbt`
- `creatures_companions.snbt`
- `culture_collection.snbt`
- `frozen_ocean.snbt`
- `graduation.snbt`
- `mod_index.snbt`
- `nether_end.snbt`
- `otherside.snbt`
- `productivebees.snbt`
- `seasons_ecology.snbt`
- `settlements_bounties.snbt`
- `structures_dungeons.snbt`
- `tea_storage.snbt`
- `twilight.snbt`
- `wildlife_fishing.snbt`
- `world_lore.snbt`

The old delivered `RESEARCH-SOURCES.txt` and `STAGING-NOTES.txt` plus their metadata were also removed; the historical copies remain in the audit backup.

## Regenerated or updated

- `packwiz/index.toml`
- `packwiz/pack.toml`
- `project-settings.json`
- `README.md`
- `docs/OPERATIONS.md`
- `docs/FILE-CLASSIFICATION.md`
- `audit/managed-files.csv`
- `audit/summary.json`
- `audit/validation-report.json`
- `audit/repository-files.csv`

No live server file, world file, player progress file, account file, client options file, shader setting, save, screenshot, log, or crash report was changed.
