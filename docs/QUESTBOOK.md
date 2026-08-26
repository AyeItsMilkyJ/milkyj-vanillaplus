# Beginner quest book

The release-candidate quest design, chapter counts, progression philosophy, reward rules, team behaviour, installed-system boundaries and validation gates are documented in [QUEST-PROGRESSION.md](QUEST-PROGRESSION.md).

Maintainer entry points:

- `scripts\Build-BeginnerQuestBook.ps1` deterministically generates and validates the quest definitions.
- `scripts\validate_questbook.py` performs independent ID, graph, item, icon, tag, layout and ledger checks.
- `scripts\quest-content\ProgressionExpansion.ps1` contains the maintained 90-lesson progression expansion.
- `scripts\quest-content\ComedyExpansion.ps1` contains the 24 optional RC4 help/comedy leaves.
- `audit\quests.csv` is the 234-row quest ledger.
- `audit\questbook-validation.json` and `audit\questbook-validation-detailed.json` are the generated reports.
- `audit\questbook-legacy-1.8.0` preserves the former definitions and is never shipped.
- `docs\QUEST-RESEARCH-SOURCES.md` records exact installed versions, primary sources, showcase cross-checks and manual-test boundaries.

The current pre-release is `1.9.0-rc4` for Minecraft `1.20.1` and Forge `47.4.10`. It contains 234 quests: 175 manual/tutorial checks and 59 automatic detections. The established previous version is `1.8.1-packwiz.1`; the local `v1.0.0` Git label is a recovery baseline, not the pack's semantic version. Every previously published quest, task and reward ID remains stable, and the 24 new quests are optional side branches. Packwiz updates the managed guide without replacing personal controls, video options, resource-pack or shader settings, screenshots, saves or maps. Automated data validation passes; the documented authenticated two-client interaction checks remain outstanding.
