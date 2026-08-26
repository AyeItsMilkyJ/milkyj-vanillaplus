# MilkyCraft Vanilla+ 1.9.0-rc4

RC4 is an additive quest-guide update for Forge 1.20.1. It does not change the mod selection or require players to import another Prism instance.

## Quest guide

- The Beginner Field Guide now contains 234 connected quests across 15 chapters.
- Totals are 175 manual/tutorial checks and 59 automatic detections.
- 24 new optional side quests explain common multiplayer pain points with useful instructions and the pack's lightly chaotic voice.
- Topics include controls, Polymorph recipe selection, shader recovery, three-hour server restarts, Corpse recovery, signage, contextual lanterns, building palettes, safe storage filters, shulker previews, Create shutdowns and contraption clearance, station names, rice paddies, winter pantry planning, bee labels, Lootr, Waystones, Distant Horizons, portal return routes, low-lag aquariums and villages, equipment durability and recovery chests.
- Every new quest is a manual checkmark with a fresh deterministic quest/task/reward ID, an optional-side-quest label and a small three-XP reward.
- All 210 previously published quest IDs, their task and reward IDs, dependencies, completion and reward meaning remain unchanged.
- No established quest depends on a new one, so the additions cannot block existing progression.
- Chapter and group display names are clearer and funnier, while their IDs, files and order remain stable.

## Automatic update and player data

Existing players keep using the same Prism instance. Packwiz checks the public feed before launch and downloads the changed managed quest definitions.

The update does not overwrite personal data, including:

- `options.txt` or customised keybindings;
- video and render settings;
- resource-pack order;
- shader selection or per-shader settings;
- screenshots, saves, maps, waypoints, logs or crash reports; and
- Minecraft account or authentication data.

The optional recommended-controls tool remains manual and reversible. It is not run by Packwiz.

## Validation status

The generated candidate reports 15 chapters, 234 unique quest IDs, 282 unique task IDs and 251 unique reward IDs. Static validation found no duplicate IDs, missing dependencies, dependency cycles, unresolved item/icon references or malformed beginner-format lessons. The required authenticated two-client UI, team-sharing, settings-preservation and copied-progress checks remain documented in `docs/MANUAL-RC-TEST.md` and must not be represented as completed until they are actually run.
