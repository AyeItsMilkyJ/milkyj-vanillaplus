# MilkyCraft Vanilla+ quest progression

Release candidate: `1.9.0-rc2`

Minecraft: `1.20.1`

Forge: `47.4.10`

## Player experience

The Beginner Field Guide contains **210 pack-specific quests across 15 chapters**. It is written for people who have barely touched modded Minecraft, but it remains useful as a project map for an established multiplayer world.

The guide explains the systems already installed. It does not lock recipes, block dimensions, force a class, require every side branch or demand that an existing player rebuild completed work. A player can choose survival, homestead, Create, storage, community or adventure routes in parallel.

Every newly authored lesson answers four questions:

- **WHAT IS THIS?** defines the system and its role;
- **DO THIS:** gives a small, concrete experiment;
- **WHY DO I CARE?** explains the useful result and what it leads into;
- **COMMON FUCK-UP:** describes the likely failure and a practical recovery.

JEI is the exact recipe authority, Jade identifies the block or entity in front of the player, installed Patchouli manuals provide author-written reference material, and Create Ponder demonstrates the exact installed Create arrangements. The quest book supplies order, relationships and safe project scope.

## Layout

| Chapter | Quests | Purpose |
|---|---:|---|
| WHERE THE FUCK DO I START? | 14 | Quest UI, JEI, Jade, recovery, backpack, Waystones, manuals, Ponder, maps and FTB Teams |
| What Leads Into What? | 9 | A route map connecting survival, enchanting, homestead, Create, storage, exploration and community branches |
| Surviving the First Night | 10 | Shelter, iron, sleep, portable supplies, landmarks and a healthy first base |
| Enchanting and the Public Armoury | 9 | Matrix pieces, candle steering, books, Easy Anvils, recovery and a shared armoury |
| Food That Isn't Raw Chicken | 13 | Farmer's Delight basics, a working kitchen, seasons, tea and first bees |
| Homestead Mastery: Farm, Kitchen and Apiary | 18 | Seasonal fields, Cooking for Blockheads, Slice & Dice, Central Kitchen and Productive Bees |
| Create Without Having a Brain Aneurysm | 22 | Ponder, rotation, stress, core machines, logistics, brass, trains and installed-addon orientation |
| Create Projects: Workshop to Railway | 20 | Power rooms, maintainable production lines, contraptions, stock logistics, addons, CEI and rail service |
| Stop Living Out of 46 Chests | 11 | Backpacks, Tom's Storage, drawers, Create Vaults and stock logistics as parallel storage jobs |
| Exploration Without Getting Completely Lost | 15 | Compasses, Waystones, Lootr, preparation, structures, wildlife, relics and boss readiness |
| Expedition Campaigns: Aether, Twilight and Beyond | 24 | Verified Aether, Twilight, Otherside, Alex's Caves, Aquamirae and Mowzie progression |
| Fossils, Archaeology and Dinosaurs | 10 | Vanilla archaeology, Better Archeology and strict namespace separation |
| Vehicles and Transport | 9 | Astikor carts, Small Ships, Immersive Aircraft and Create trains |
| Companions, Fishing and Settlements | 12 | Doggy Talents, Domestication Innovation, fishing, aquariums, guards, trades and bounties |
| Dangerous Shit and Endgame | 14 | Nether travel, End Remastered eyes, End safety, dragon progression and optional lore |
| **Total** | **210** | **151 manual/tutorial quests and 59 automatic-detection quests** |

## How branches connect

The first three interface lessons now lead directly to **How to Read the Field Guide**. Basic help is no longer hidden behind crafting a backpack and Waystone. The remaining orientation lessons still teach those systems, but every main route becomes readable as soon as the player understands the guide.

The six added chapters start from meaningful existing milestones:

| New chapter | Unlock milestone | Reason |
|---|---|---|
| What Leads Into What? | How to Read the Field Guide | lets the player choose a route immediately |
| Enchanting and the Public Armoury | An Iron Foundation | starts with ordinary table, shelf, lapis and anvil materials |
| Homestead Mastery | Build a Working Kitchen | assumes the basic knife, board, garden and pot loop exists |
| Create Projects | Diagnosing a Silent Machine | assumes one complete line and basic troubleshooting |
| Expedition Campaigns | The Boss Threshold | assumes the group can travel, recover and share Lootr rewards |
| Companions, Fishing and Settlements | Build for a Healthy World | assumes a secure permanent settlement exists |

Within the new chapters, explicit dependency forks show what actually stems from what:

- homestead farming and apiary work split after the homestead map;
- the armoury moves from Matrix pieces and candles through books and anvil discipline, then joins the existing Create experience branch only for its optional capstone;
- Create ore, tree, food and contraption projects split after the machine-contract lesson;
- Aether, Twilight, Otherside, Alex's Caves, Aquamirae and Mowzie campaigns split from one expedition briefing;
- the Twilight path splits after the Lich and merges only after Hydra, Ur-Ghast and Snow Queen progress;
- pets, fishing and village projects split from the community map and rejoin at the shared settlement project.

Existing chapter semantics were also repaired without changing their IDs or rewards:

- tea and vanilla bees no longer require Slice & Dice automation;
- Productive Bees begins after vanilla-bee safety;
- Create food integration requires both the Mixer lesson and food path;
- brass, Mechanical Crafters, trains, Enchantment Industry and addon orientation are optional advanced branches after the core Create diagnostic path;
- Tom's network tutorial now precedes its advanced terminal path, while backpacks, drawers and Create storage have independent prerequisites;
- photography and wildlife no longer require defeating a boss;
- the Create train transport lesson also requires the schedule lesson;
- Nether roads now appear directly after Nether exploration and End safety appears before entering the End;
- museum/relic memory work is optional rather than a mandatory End tail.

## Enchanting and the public armoury

The pack already contained a full vanilla+ enchanting stack, but the former 200-quest guide did not teach it. The new nine-quest chapter restores the legacy Enchanting Table/bookshelf and Anvil item tasks with their original IDs and rewards, then adds seven focused lessons.

Quark Matrix Enchanting is the primary table. It generates visible pieces with lapis and experience, lets players place compatible results, merges matching pieces to raise their level and uses coloured candles to steer probability. The tuned configuration gives five charges per lapis, delays the piece-price step, favours repeats modestly and doubles each candle's configured weight influence while retaining the four-candle limit. Fifteen bookshelves remain the ordinary maximum, and treasure or undiscoverable enchantments remain outside the table.

Easy Anvils teaches planned book combinations, fixed prior-work costs and the absence of the hard Too Expensive cap. The route then distinguishes the destructive vanilla Grindstone from the later Create: Enchantment Industry recovery workflow. The optional capstone asks another player to use a labelled public armoury safely; valuable equipment always retains a manual confirmation step.

Easy Magic remains installed but is not presented as the active screen. Quark automatically owns the Matrix interface, so Easy Magic's classic reroll control must not be expected there. The exact settings, rejected Infuser candidate and authenticated gameplay gate are in [ENCHANTING.md](ENCHANTING.md).

## Homestead mastery

The homestead chapter teaches three connected loops.

### Field and pantry

Players read the current Serene Seasons state, run labelled seasonal plots, preserve seed stock, build a connected Cooking for Blockheads kitchen, understand each Farmer's Delight workstation, and run a pantry that does not consume every raw ingredient.

### Kitchen automation

The Slicer, Sprinkler, Fertilizer, Central Kitchen Blaze Stove and Cooking Guide are introduced through the exact installed JEI/Ponder boundary. The capstone automates one meal from harvest to labelled output with seed reserve, overflow and shutdown.

### Productive Bees

The apiary path explicitly distinguishes solitary bees from productive hive bees. It then covers nests and cages, the Nest Locator, Advanced Hive plus expansion, required flowers, one deliberate breeding target, Centrifuge/Bottler processing and a compact shared apiary. It discourages uncontrolled free-flying bee counts and loose item buildup because multiplayer performance remains priority one.

## Create learning path

The original 22-lesson Create Basics chapter remains the component course. It covers Ponder, Andesite Alloy, Goggles/Wrench, water/wind/steam power, shafts and ratios, RPM and stress, Press, Fan, Mixer/Basin, food integration, Crushing Wheels, Saw/Drill, belts and filters, a first complete line, diagnostics, brass, Mechanical Crafters, trains, Enchantment Industry and the addon map.

The 20-lesson Create Projects chapter has a four-lesson shared foundation—choose an outcome, measure the network, build a serviceable power room, then document the machine contract. It then forks instead of forcing unrelated addons into one serial tutorial:

| Branch | Dependency flow |
|---|---|
| Production | contract -> ore stream, tree farm and kitchen line |
| Contraptions | contract -> movement boundaries -> chassis/glue -> gantry or elevator |
| Smart routing | contract plus Brass/Mechanical Crafters -> Mechanical Arm routing |
| Stock delivery | contract plus the existing Packages/Stock Links/Tickers lesson -> physical deliveries |
| Kinetic control | contract -> Connected and Components and Additions controls |
| Finish layer | contract -> Copycats, Deco and Rechiseled safety finish |
| Aquatic engineering | contract -> Aquatic Ambitions materials -> Conduit Cage |
| Enchantment Industry | contract -> contained liquid XP -> disenchant/enchant/print flow |
| Railway | contract plus the existing Train Schedule lesson -> signalled two-station service |

The final teammate audit is the merge: every branch endpoint feeds it, and another player must be able to operate, stop and fault-test the documented workshop.

The installed Enchantment Industry version is `1.4.1`. The guide deliberately excludes newer Experience Hatch, Experience Lantern and Blaze Forger claims because those blocks do not exist in this JAR.

## Adventure campaigns

Campaign teaching uses local advancement parents rather than an invented pack-wide boss ladder.

- **Aether:** safe portal; Skyroot/Holystone and Book of Lore; Zanite -> Altar -> Enchanted Gravitite -> Bronze/Slider; sibling Freezer and Moa-incubation branches; Lance -> Silver/Valkyrie -> Regen Stone -> Gold/Sun Spirit; safe return.
- **Twilight Forest:** Magic Map; Naga; Lich; parallel swamp, dark-forest and snow branches; Hydra + Ur-Ghast + Snow Queen merge; highlands route. The unfinished Final Castle is not advertised as a completed final boss.
- **Deeper and Darker:** Ancient City stealth; Warden and consumed Heart; secure Otherside arrival; targeted biome/material trips; then parallel Temple/Transmitter, entry/Staff and Warden/armour branches.
- **Alex's Caves:** Cave Tablet -> Cave Codex -> Cave Map, followed by six parallel targeted cave-biome discoveries; Cave Book is a sibling manual branch directly from the Tablet.
- **Aquamirae:** correctly described as a Deep Frozen Ocean/Ice Maze overworld campaign, not a dimension.
- **Mowzie's Mobs:** independent encounter lessons, because the installed advancements do not impose one universal boss order.

End Remastered remains in the Endgame chapter. Its four existing item tasks are described as samples toward the installed system's **12 distinct eyes**, not the entirety of the eye hunt.

## Research boundaries

Exact installed versions, primary sources, supplemental showcase links, confidence labels and manual-test boundaries are recorded in [QUEST-RESEARCH-SOURCES.md](QUEST-RESEARCH-SOURCES.md). Installed JAR data wins over a video or wiki written for another version.

## Tasks and existing players

Manual checkmarks are used for reading, UI lessons, explanations, troubleshooting and subjective project tests. Stable inexpensive item tasks remain where holding an item is reliable proof. Existing advancement, dimension and kill checks remain only where the installed trigger already represented the activity reliably.

The generator retains all **111 selected existing quest blocks** with their quest, task and reward IDs, including two restored legacy enchanting foundations. It also preserves the previously published deterministic IDs already present in the 118-quest guide. The maintained expansion now contains 90 authored lessons with deterministic seeds and modest XP rewards. No existing item reward or XP definition changed meaning.

The current generated totals are:

- 210 unique quest IDs;
- 258 unique task IDs;
- 227 unique reward IDs;
- 151 manual/checkmark quests;
- 59 automatic-detection quests;
- zero duplicate, signed-unsafe or missing IDs;
- zero missing dependencies or graph cycles.

Nine definition IDs belonging only to removed unreleased Tinkers/Botany placeholders remain intentionally absent. Tinkers' Construct, Botany Pots and Botany Trees are not installed and are not taught.

## Rewards and teams

Existing rewards retain their exact IDs and definitions. New lessons give modest XP only. There are no command rewards, recipe unlocks, random crates, boss drops, rare artifacts or advanced machines as tutorial prizes.

`default_reward_team` remains `false`, so rewards are individual. FTB Teams controls shared completion: players who deliberately join one team may share progress, while players outside it remain separate. Nobody is automatically placed into a global team.

## Managed data and stable IDs

The managed definitions live at `payload/both/config/ftbquests/quests/`; matching Packwiz metadata is under `packwiz/config/ftbquests/quests/` with `side = "both"`.

`scripts/Build-BeginnerQuestBook.ps1` loads authored expansion data from `scripts/quest-content/ProgressionExpansion.ps1`, preserves selected legacy blocks, generates deterministic IDs and validates the whole graph before deployment. Never change a published seed or ID. Add a new stable seed for a genuinely new lesson.

`audit/quests.csv` is the 210-row release ledger. Each row records chapter, quest ID, title, system, task type and target, dependencies, optional state, reward summary and verification status.

## Validation gates

Automated validation now checks:

- 15 non-empty chapter files and exactly 210 quests;
- unique quest/task/reward IDs and FTB-safe signed values;
- all dependency targets, exactly one guide root, full root reachability and acyclicity;
- installed item/icon and tag evidence against the 240-JAR disposable client;
- the four-part beginner format in all newly authored chapters and Create Basics;
- CSV ledger parity;
- Packwiz TOML, hashes, sides and managed index integrity;
- delivery into disposable client and server installations;
- personal-setting preservation during update and rollback;
- dedicated-server FTB parsing, normal save and JVM exit.

Automated parsing does not verify live UI interaction. Before promoting this pre-release to final, or claiming those interactions are verified, two clean authenticated disposable clients must open the book, inspect all pages and dependency lines, complete a checkmark and automatic task, claim a reward, verify same-team/outside-team behaviour, and manually test representative Matrix enchanting, Create, apiary and dimension lessons. No live world or live Prism instance is used for this work.
