# MilkyJ Vanilla+ quest progression

Release candidate: `1.9.0-rc1`
Minecraft: `1.20.1`
Forge: `47.4.10`

## Player experience

This book is an in-game field guide for people who have barely touched modded Minecraft. It explains the systems already in the pack; it does not gate recipes, lock dimensions, force a strict class, or demand that an established player rebuild a base.

The first chapter is visible immediately. After **How to Read the Field Guide**, survival, food, Create, storage, exploration, archaeology, vehicles and endgame become parallel branches. Within a chapter, the required path reads left to right. Clearly labelled optional quests sit outside the required chain.

Descriptions use four questions wherever a machine or unfamiliar system needs real teaching:

- **WHAT IS THIS?** defines the system and any technical term.
- **DO THIS:** gives a small, exact first experiment.
- **WHY DO I CARE?** explains the useful result or next unlock.
- **COMMON FUCK-UP:** gives the likely failure and a practical fix.

JEI is the recipe authority, Jade identifies the thing in front of the player, installed Patchouli books provide deeper reference material, and Create Ponder provides the exact animated arrangement for Create 6.0.8. The quest book provides order and context. It is guidance, not a restriction system.

## Layout

| Chapter | Quests | Purpose |
|---|---:|---|
| WHERE THE FUCK DO I START? | 14 | Quest UI, keybinds, JEI, Jade, Ultimine, death recovery, backpacks, Waystones, manuals, Ponder, teams and an optional legacy foreword |
| Surviving the First Night | 10 | Shelter, tools, light, sleep, iron, portable supplies and a sensible first base |
| Food That Isn't Raw Chicken | 13 | Farmer's Delight, Cooking for Blockheads, seasons, food automation, tea and bees |
| Create Without Having a Brain Aneurysm | 22 | Ponder, rotation, stress, machines, logistics, automation, brass, trains and installed addons |
| Stop Living Out of 46 Chests | 11 | Sophisticated Backpacks, Tom's Simple Storage, drawers, filters, vaults and stock logistics |
| Exploration Without Getting Completely Lost | 15 | Compasses, Waystones, Lootr, travel preparation, caves, bosses, relics and optional discovery |
| Fossils, Archaeology and Dinosaurs | 10 | Vanilla archaeology, Better Archeology and strict namespace separation from unrelated relic/bounty systems |
| Vehicles and Transport | 9 | Astikor carts, Small Ships, Immersive Aircraft and Create trains |
| Dangerous Shit and Endgame | 14 | Nether travel, End Remastered eyes, End preparation, bosses and optional group challenges |
| **Total** | **118** | 61 manual/tutorial quests and 57 automatic-detection quests |

Unreleased Tinkers and Botany placeholder tutorials were removed because those mods are absent. Mature exploration and endgame lessons retain stable IDs from the previous guide; the count is intentionally truthful rather than padded to 120.

## Create learning path

Create is the largest chapter because it is the pack's deepest connected system. Its 22 lessons cover:

1. opening and stepping through Ponder;
2. stocking Andesite Alloy;
3. using Engineer's Goggles and the Wrench;
4. a first Water Wheel;
5. wind and later steam power;
6. shafts, cogs, direction and gear ratios;
7. RPM, stress capacity, stress impact and overstress;
8. the Mechanical Press with a Depot, Belt or Basin;
9. Encased Fan washing, smoking, haunting and blasting;
10. Mixer and Basin recipes with heat requirements;
11. Slice & Dice and Central Kitchen integration;
12. opposing Crushing Wheels;
13. Mechanical Saws and Drills;
14. Belts, Depots, Funnels, Chutes, Filters and Mechanical Arms;
15. a complete farm or ore-processing line with overflow handling;
16. a repeatable diagnostic order for silent machinery;
17. brass, Blaze Burner heat and smart brass logistics;
18. Mechanical Crafters, sequenced assembly and Precision Mechanisms;
19. tracks, stations, carriage assembly, driving and Steam 'n' Rails;
20. schedules, signals and useful train service;
21. Create: Enchantment Industry and safe experience handling;
22. the installed-addon map, including Create Connected, Deco, Rechiseled Create and Create Ultimine.

Every Create lesson tells the player to verify the installed recipe or use Ponder. It never assumes content from Crafts & Additions, Diesel Generators, Bells & Whistles, Contraption Terminals, Immersive Engineering or another uninstalled expansion.

## Installed-system boundaries

- **Tinkers' Construct is not installed.** Mantle and old config files do not provide Tinkers content. The unreleased placeholder chapter was removed.
- **Botany Pots and Botany Trees are not installed.** Their unreleased placeholder quest was removed; current farming guidance uses real fields, seasons, food mods and bees.
- **Better Archeology is installed.** Its brush, fossiliferous materials, artifact pieces and Archeology Table are taught as that mod's progression.
- **No dinosaur/DNA revival system is installed.** The book does not pretend that similarly named fossils, amber, eggs or machines from videos belong to this pack.
- **Bountiful, Artifacts and Relics are separate systems.** Their items are not presented as Better Archeology inputs.
- **KubeJS is not installed.** No login script was added solely to display a welcome message.

## Tasks and existing players

Manual checkmarks are used for reading, UI lessons, explanations, troubleshooting and subjective build tests. Stable inexpensive item tasks are used where holding the actual item is a reliable proof. Advancements, dimensions or kills remain only where the installed trigger already represented the activity reliably.

The generator preserves every retained baseline chapter, quest, task and reward ID. Nine definition IDs belonging only to the removed unreleased Tinkers/Botany placeholders are intentionally absent. Existing players do not have to reacquire items merely because layout or wording improved. No command-based progress, scripted reward, consume task, recipe gating or Game Stages rule is introduced.

## Rewards

Existing rewards retain their exact baseline IDs and item/XP definitions so claimed or unclaimed rewards cannot change meaning during an update. Newly authored lessons use new reward IDs and modest XP. There are no random loot crates, command rewards, advanced machines, boss drops, artifacts, relics, high-tier tools or diamond jackpots.

`default_reward_team` is `false`, so rewards are claimed by the individual player rather than once for the whole team. This reduces arguments and avoids one teammate consuming everyone else's small reward.

## Teams

FTB Quests stores progress through FTB Teams. Nobody is automatically placed into one global server team. Players who deliberately join the same FTB Team may share quest progress; players outside that team retain separate progress.

Shared completion does not remove quest descriptions. A new teammate can still open a completed quest and read the lesson, then perform the suggested experiment without being forced to recreate an expensive machine for detection.

The data-level configuration and dedicated-server synchronization can be automated. The exact same-team/outside-team behaviour still requires the release-candidate interaction test with two real clients before release.

## Managed data and stable IDs

The supported FTB Quests 2001.4.22 data lives at:

`config/ftbquests/quests/`

The source payload is `payload/both/config/ftbquests/quests/`. Matching Packwiz metadata is generated under `packwiz/config/ftbquests/quests/`, with `side = "both"`, so single-player clients and dedicated servers receive the same definitions.

`scripts/Build-BeginnerQuestBook.ps1` uses deterministic IDs for new lessons and retains IDs for 109 selected legacy quest blocks. Never change an existing seed or ID after publication. Add a new stable seed for a genuinely new quest.

`audit/quests.csv` is the release ledger. Each row records the chapter, stable quest ID, title, owner/system, task type and target, dependencies, optional status, reward summary, verification state and notes.

## Validation gates

Automated validation checks Packwiz TOML and hashes, required FTB JARs and sides, 9 non-empty chapters, chapter titles/icons, 118 quests, unique quest/task/reward IDs, valid dependency targets, an acyclic reachable graph, installed item/icon evidence, referenced tags, the four-part Create teaching format and CSV parity.

A disposable Packwiz client/server installation then verifies managed-file delivery, personal-file preservation, server startup, FTB parser loading and clean multi-dimension shutdown. Baseline-to-RC update and rollback tests must preserve `options.txt`, keybindings, screenshots, saves and shader settings.

Automated parsing is not release approval. Before publication, a clean authenticated client must connect to the disposable dedicated server, open this book, complete one tutorial checkmark and one item-detection quest, claim a reward, and test same-team plus outside-team progress. A copied production world test must wait for a clean offline backup; the running live world is never hot-copied for this work.
