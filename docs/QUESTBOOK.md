# Beginner quest book

The release-candidate quest design, chapter counts, progression philosophy, reward rules, team behaviour, installed-system boundaries and validation gates are documented in [QUEST-PROGRESSION.md](QUEST-PROGRESSION.md).

Maintainer entry points:

- `scripts\Build-BeginnerQuestBook.ps1` deterministically generates and validates the quest definitions.
- `scripts\validate_questbook.py` performs independent ID, graph, item, icon, tag, layout and ledger checks.
- `audit\quests.csv` is the 118-row quest ledger.
- `audit\questbook-validation.json` and `audit\questbook-validation-detailed.json` are the generated reports.
- `audit\questbook-legacy-1.8.0` preserves the former definitions and is never shipped.

The repaired candidate is `1.9.0-rc1` for Minecraft `1.20.1` and Forge `47.4.10`. The established previous version is `1.8.1-packwiz.1`; the local `v1.0.0` Git label is a recovery baseline, not the pack's semantic version. The candidate remains test-only until all required manual checks pass.
