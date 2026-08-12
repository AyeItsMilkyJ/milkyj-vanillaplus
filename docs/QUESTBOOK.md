# Beginner quest book

Pack version: `1.8.1-packwiz.1`  
Minecraft: `1.20.1`  
Forge: `47.4.10`

## Result

The visible guide contains exactly 120 pack-specific quests across 10 chapters. It teaches the installed pack rather than copying advancements or generating one quest per mod. Recipes remain ungated and every chapter can be approached independently.

| Chapter | Quests |
|---|---:|
| WHERE THE FUCK DO I START? | 14 |
| Surviving the First Night | 10 |
| Food That Isn't Raw Chicken | 14 |
| Tinkers' Construct for Absolute Idiots | 3 |
| Create Without Having a Brain Aneurysm | 20 |
| Stop Living Out of 46 Chests | 11 |
| Exploration Without Getting Completely Lost | 15 |
| Fossils, Archaeology and Dinosaurs | 10 |
| Vehicles and Transport | 9 |
| Dangerous Shit and Endgame | 14 |

The graph uses 63 manual understanding/testing quests and 57 automatic item, advancement, dimension, or kill detections. Optional decoration, photography, wildlife, biome collecting, relic, ship, and aircraft activities are visibly labelled as side quests and do not advance the required dependency chain.

## FTB stack audit

No framework mod was added or replaced. The exact working client and server already contain:

| File | Side |
|---|---|
| `architectury-9.2.14-forge.jar` | both |
| `ftb-library-forge-2001.2.13.jar` | both |
| `ftb-quests-forge-2001.4.22.jar` | both |
| `ftb-teams-forge-2001.3.2.jar` | both |
| `ftb-xmod-compat-forge-2.1.3.jar` | both |
| `ftb-filter-system-forge-20.0.1.jar` | both |

Their embedded dependency ranges accept Forge 47.4.10, Minecraft 1.20.1, and Architectury 9.2.14. The disposable server log confirms that FTB XMod Compat selected JEI as the FTB Quests recipe helper and enabled FTB Filter System integration.

FTB Quests stores progress against FTB Teams. Players who want shared progression must join the same party; the live world currently contains an established party and player team records.

## Progress migration

The former guide had 396 quests across 29 chapters. The generator selected 109 existing quest blocks and added 11 new lessons. It preserved every one of the 99 quest/task IDs found in current world progress. Completed item detections and manual checkmarks therefore continue to match.

Old chapter-completion IDs for chapters that were merged are not retained as visible chapter objects. Chapter progress is recalculated from the retained quests, while individual quest and task completion remains intact. The complete old definitions are preserved under `audit\questbook-legacy-1.8.0` and are not delivered to players.

## Systems deliberately deferred

- **Tinkers' Construct is not installed.** Mantle is present, and stale Tinkers config files exist, but there is no Tinkers mod jar or valid Tinkers registry. Its three-quest chapter explains this clearly instead of inventing grout, melter, smeltery, casting, tool, repair, or modifier tasks.
- **Botany Pots and Botany Trees are not installed.** The food chapter marks them as deferred and sends players to real Farmer's Delight, Serene Seasons, bee, and ordinary farming systems.
- **No dinosaur/DNA revival mod is installed.** Better Archeology is the only installed fossil/archaeology progression. Bountiful, Artifacts, and Relics are described separately.
- **Immersive Engineering and Create Crafts & Additions were not added.** Create 6 itself already contains Packagers, Stock Links, Stock Tickers, packages, and Item Vaults.

## Installed content validated directly

The installed Create 6 jar contains the real registry and Ponder content for Crushing Wheels, Mechanical Saws, Mechanical Drills, Item Vaults, Packagers, Stock Links, and Stock Tickers. AstikorCarts Redux contains wood-specific Hand Cart, Supply Cart, Animal Cart, Plow, Reaper, and Seed Drill recipes. Better Archeology contains brush, fossiliferous dirt, fossil-part, artifact-shard, unidentified-artifact, and Archeology Table recipes.

Automatic quest tasks reference 98 installed item IDs. FTB Quests loaded all definitions without an unknown-task or invalid-item warning.

## Validation results

- Packwiz manifest: 687 unique destinations, 443 hosted payloads, zero validation errors.
- Fresh client install: 236 jars; personal `options.txt` and screenshot sentinels preserved.
- Fresh server install: 203 jars.
- Disposable dedicated server: reached `Done` in 48.182 seconds after world preparation.
- FTB Quests server parse: 10 chapters, 120 quests, zero reward tables.
- Shutdown: all seven loaded dimensions saved and the JVM exited.
- Existing real client: last launch on 11 August 2026 completed loading with 236 jars and stopped normally. A new interactive client was not launched during this change because the live server remained online.
- Live production server/world: not stopped, updated, copied, or replaced. Port 25565 remained active.

The startup log still contains unrelated pre-existing data warnings: one Create Central Kitchen vegan-hamburger recipe expects absent Miner's Delight, two Aether shield recipes are malformed, a Beautify advancement references a misspelled item, and some bundled advancement JSON uses invalid `alternative(s)` types. None prevented startup or FTB Quest loading, and no new quest relies on those broken recipes.

## Manual in-game checks after publishing

1. Stop the server cleanly and use the guarded update-and-start script so a timestamped world/server backup is created first.
2. Join with one existing party member and one fresh player.
3. Open the quest book and confirm the opening chapter is immediately visible.
4. Confirm an already completed welcome quest remains completed.
5. Join the same FTB Team, complete a cheap checkmark, and verify it appears for the other member.
6. Hover a Create item and hold `W` to open Ponder.
7. Open an installed Patchouli manual from inventory.
8. Confirm optional side-quest labels are visible and do not block the main line.
9. Check Cart Attach/Detach and Slow keybinds, since key conflicts are personal client settings.
10. Visually inspect chapter spacing at the user's GUI scale; the server parser validates data, not taste or text wrapping.

## Maintainer files

- `scripts\Build-BeginnerQuestBook.ps1` — deterministic generator, migration checks, Packwiz deployment, and audit refresh.
- `payload\both\config\ftbquests\quests` — files delivered to client and server.
- `packwiz\config\ftbquests\quests` — side-aware hosted-file metadata.
- `audit\questbook-validation.json` — machine-readable counts and progress-preservation result.
- `audit\questbook-item-ids.txt` — item IDs referenced by the final guide.
- `audit\questbook-legacy-1.8.0` — preserved previous definitions, never shipped.
