# v1.1.0-rc1 change manifest

Compared with local baseline tag `v1.0.0` (`6d1dba5`). This list excludes ignored disposable `build/`, `.tools/` and `dist/` output.

## Created

- `audit/local-rc-test.json`
- `audit/packwiz-update-rollback.json`
- `audit/quest-mods.json`
- `audit/questbook-validation-detailed.json`
- `audit/quests.csv`
- `audit/rc1-change-manifest.md`
- `audit/runtime-data-errors-v1.1.0-rc1.md`
- `docs/QUEST-PROGRESSION.md`
- `scripts/Prepare-LocalRcTest.ps1`
- `scripts/Test-BaselineUpdateRollback.ps1`
- `scripts/audit_quest_mods.py`
- `scripts/validate_questbook.py`

## Changed: release metadata and documentation

- `README.md`
- `project-settings.json`
- `bootstrap/template/instance.cfg`
- `docs/OPERATIONS.md`
- `docs/QUESTBOOK.md`
- `packwiz/pack.toml`
- `packwiz/index.toml`

## Changed: quest payloads

- `payload/both/config/ftbquests/quests/chapters/archaeology.snbt`
- `payload/both/config/ftbquests/quests/chapters/create_basics.snbt`
- `payload/both/config/ftbquests/quests/chapters/endgame.snbt`
- `payload/both/config/ftbquests/quests/chapters/first_days.snbt`
- `payload/both/config/ftbquests/quests/chapters/homestead.snbt`
- `payload/both/config/ftbquests/quests/chapters/new_horizons.snbt`
- `payload/both/config/ftbquests/quests/chapters/tinkers_deferred.snbt`
- `payload/both/config/ftbquests/quests/chapters/travel_storage.snbt`
- `payload/both/config/ftbquests/quests/chapters/vehicles.snbt`
- `payload/both/config/ftbquests/quests/chapters/welcome.snbt`

## Changed: matching Packwiz hosted-file metadata

- `packwiz/config/ftbquests/quests/chapters/archaeology.snbt.pw.toml`
- `packwiz/config/ftbquests/quests/chapters/create_basics.snbt.pw.toml`
- `packwiz/config/ftbquests/quests/chapters/endgame.snbt.pw.toml`
- `packwiz/config/ftbquests/quests/chapters/first_days.snbt.pw.toml`
- `packwiz/config/ftbquests/quests/chapters/homestead.snbt.pw.toml`
- `packwiz/config/ftbquests/quests/chapters/new_horizons.snbt.pw.toml`
- `packwiz/config/ftbquests/quests/chapters/tinkers_deferred.snbt.pw.toml`
- `packwiz/config/ftbquests/quests/chapters/travel_storage.snbt.pw.toml`
- `packwiz/config/ftbquests/quests/chapters/vehicles.snbt.pw.toml`
- `packwiz/config/ftbquests/quests/chapters/welcome.snbt.pw.toml`

All quest definitions remain `side = "both"`. No mod metadata file changed and no content expansion JAR was added.

## Changed: generators, tests and generated audits

- `scripts/Build-BeginnerQuestBook.ps1`
- `scripts/Test-InstallerEndToEnd.ps1`
- `audit/end-to-end-result.json`
- `audit/managed-files.csv`
- `audit/questbook-item-ids.txt`
- `audit/questbook-validation.json`
- `audit/repository-files.csv`
- `audit/summary.json`
- `audit/validation-report.json`

## Ignored test output

- `dist/MilkyJ-VanillaPlus-v1.1.0-rc1-LOCAL-TEST-Prism.zip`
- `build/rc-local-host/`
- `build/end-to-end/`
- `build/baseline-update-rollback/`
- `.tools/forge-libraries/`

The existing `dist/MilkyJ-VanillaPlus-AutoUpdating-Prism.zip` was not overwritten.
