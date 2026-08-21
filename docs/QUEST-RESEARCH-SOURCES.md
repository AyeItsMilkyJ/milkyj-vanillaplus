# Quest research and installed-version boundaries

This file records the evidence used for the MilkyCraft Vanilla+ 200-quest progression guide. It exists so future quest edits do not quietly copy mechanics from a different Minecraft or mod version.

## Evidence order

Quest claims were checked in this order:

1. **LOCAL-CONFIRMED:** the exact JAR, Packwiz pin, config, advancement JSON, recipe/tag data, language keys, Patchouli book or Ponder scene installed in this repository's disposable client;
2. **UPSTREAM-CONFIRMED:** the mod author's source, release notes, wiki or project documentation;
3. **SHOWCASE-CROSS-CHECK:** a tutorial/showcase used to understand presentation or practical order, never to overrule the installed files;
4. **DESIGN:** MilkyCraft's recommended teaching order or project connection, clearly not claimed as a hard mod gate;
5. **MANUAL CHECK:** behaviour that still needs authenticated gameplay, JEI interaction or two-player confirmation.

JEI, installed advancements and local Ponder scenes remain the in-game authority. The guide deliberately says so when recipes or controls can vary.

## Exact Create stack inspected

| Component | Exact installed version/artifact | Progression facts used |
|---|---|---|
| Create | `create-1.20.1-6.0.8.jar` | Ponder, rotation, stress, Press/Fan/Mixer/Basin, logistics, brass, contraptions, packages and railways |
| Steam 'n' Rails | `Steam_Rails-1.7.2+forge-mc1.20.1.jar` | extensions after a working core Create railway |
| Enchantment Industry | `create_enchantment_industry-1.4.1-for-create-6.0.8.jar` | Disenchanter, Printer, Enchanting Guide, Blaze Enchanter, Experience Rotor and liquid XP/Hyper XP/ink |
| Slice & Dice | `sliceanddice-forge-3.6.0.jar` | Slicer, Sprinkler block and liquid Fertilizer integration with the installed food stack |
| Central Kitchen | `create_central_kitchen-1.20.1-for-create-6.0.8-1.5.0.jar` | Blaze Stove, Cooking Guide and generated food integration |
| Connected | `create_connected-1.2.3-mc1.20.1-all.jar` | early and brass-stage kinetic control blocks |
| Copycats+ | `copycats-3.0.7+mc.1.20.1-forge.jar` | canonical copycat building shapes |
| Create Deco | `createdeco-2.0.3-1.20.1-forge.jar` | catwalks, railings and machine-room finish layer |
| Rechiseled: Create | `rechiseledcreate-1.1.1-forge-mc1.20.jar` | optional kinetic Mechanical Chisel/building branch |
| Aquatic Ambitions | `create_aquatic_ambitions-1.20.1-6.0.8-2.0.2.jar` | Prismarine Alloy chain, Conduit Cage and channeling stream |
| Compatible Storage | `create_compatible_storage-2.13.0-mc1.20.1-forge-all.jar` | compatibility layer only; no invented items or recipe progression |
| Components and Additions | `create_ca-2.2 - 1.20.1.jar` | inverted controls, brass gearboxes, brass basin and chain controls |
| Create Ultimine | `createultimine-1.20.1-forge-1.3.1.jar` | optional bulk casing/wrench quality of life, not a technology gate |

Important exclusions derived from the installed JARs:

- Enchantment Industry 1.4.1 does **not** include the newer Experience Hatch, Experience Lantern or Blaze Forger feature set.
- Compatible Storage adds compatibility rather than a new storage progression.
- The guide does not teach Crafts & Additions, Diesel Generators, Bells & Whistles, Contraption Terminals or Immersive Engineering because those mods are not installed.
- Addons without local Ponder scenes are taught through JEI, tooltips and a disposable test, not a promised Ponder animation.

Primary Create sources:

- [Create 6.0.8 release](https://github.com/Creators-of-Create/Create/releases/tag/mc1.20.1-6.0.8)
- [Create source](https://github.com/Creators-of-Create/Create)
- [Create user wiki](https://wiki.createmod.net/)
- [Steam 'n' Rails source/wiki](https://github.com/Layers-of-Railways/Railway)
- [Enchantment Industry source](https://github.com/DragonsPlusMinecraft/CreateEnchantmentIndustry)
- [Slice & Dice source](https://github.com/PssbleTrngle/SliceAndDice)
- [Central Kitchen source](https://github.com/DragonsPlusMinecraft/CreateCentralKitchen)
- [Create: Connected source/wiki](https://github.com/hlysine/create_connected)
- [Copycats+ source/wiki](https://github.com/copycats-plus/copycats)
- [Aquatic Ambitions source](https://github.com/davioliva16/create-aquatic-ambitions)
- [Components and Additions source](https://github.com/Sshmoob/Create-Components-and-Additions)

## Adventure progression inspected

| System | Exact installed version | Local progression used by the guide |
|---|---:|---|
| The Aether | 1.5.2 | enter; Skyroot/Holystone and Book of Lore; Zanite -> Altar -> Enchanted Gravitite -> Bronze; sibling Freezer and Moa-incubation branches; Lance -> Silver -> Regen Stone -> Gold |
| Twilight Forest | 4.3.2508 | Magic Map; Naga; Lich; three middle branches; Hydra + Ur-Ghast + Snow Queen merge; troll/giant/highlands route |
| Deeper and Darker | 1.3.3 | Ancient City; Warden; consumed Heart/portal; Otherside exploration; parallel Temple/Transmitter, entry/Staff and Warden/armour branches |
| Alex's Caves | 2.0.2 | Cave Tablet -> Cave Codex -> Cave Map -> six parallel biome discoveries; Cave Book is a sibling manual branch from the Tablet |
| Aquamirae | 6.4.0 | overworld Deep Frozen Ocean/Ice Maze campaign and its installed item/advancement branches |
| Mowzie's Mobs | 1.8.2 | independent encounter advancements rather than an invented universal boss ladder |
| End Remastered | 5.3.3-R | 16 possible custom eyes; any 12 distinct types complete the portal |

The exact Aether and Twilight orders above came from installed advancement parents. Alex's Caves' six cave biomes and Mowzie's main encounters remain parallel because their installed data does not impose one linear order.

Primary adventure sources:

- [Aether official wiki](https://aether.wiki.gg/wiki/The_Aether/The_Aether) and [source](https://github.com/The-Aether-Team/The-Aether)
- [Twilight Forest source](https://github.com/TeamTwilight/twilightforest) and [generated Labyrinth progression example](https://github.com/TeamTwilight/twilightforest/blob/latest/src/generated/resources/data/twilightforest/advancement/progress_labyrinth.json)
- [Deeper and Darker releases](https://github.com/KyaniteMods/DeeperAndDarker/releases)
- [Alex's Caves source](https://github.com/AlexModGuy/AlexsCaves)
- [Aquamirae source](https://github.com/ObscuriaLithium/Aquamirae)
- [End Remastered project page](https://modrinth.com/mod/endrem)

## Homestead and community sources

- [Productive Bees documentation](https://productive-bees.readthedocs.io/en/latest/index.html): solitary-versus-hive bees, Advanced Hives, flowers, Centrifuge, Bottler and breeding concepts.
- [Farmer's Delight source](https://github.com/vectorwing/FarmersDelight): installed cooking concepts.
- [Cooking for Blockheads cooking-table guide](https://mods.twelveiterations.com/minecraft/cooking-for-blockheads/cooking-table): connected kitchen behaviour.
- [Serene Seasons crop-fertility guide](https://github-wiki-see.page/m/Glitchfiend/SereneSeasons/wiki/Crop-Fertility): checked against the repository's actual crop configuration.
- [Doggy Talents Next getting started](https://doggytalentsnext.wiki.gg/wiki/Getting_Started), [Dog Bed](https://doggytalentsnext.wiki.gg/wiki/Dog_Bed) and [level systems](https://doggytalentsnext.wiki.gg/wiki/Leveling_Systems).
- [Domestication Innovation source/config](https://github.com/AlexModGuy/DomesticationInnovation/blob/main/src/main/java/com/github/alexthe668/domesticationinnovation/DIConfig.java): pet-bed and collar configuration boundaries.
- [Waystones FAQ](https://mods.twelveiterations.com/minecraft/waystones/guides/faq), [Nature's Compass source](https://github.com/MattCzyr/NaturesCompass) and [Explorer's Compass source](https://github.com/MattCzyr/ExplorersCompass).

## Supplemental showcases cross-checked

The following videos were used only as supplemental presentation/progression cross-checks. Installed JAR evidence won every disagreement:

- [Twilight Forest 1.20.1 progression showcase](https://www.youtube.com/watch?v=9T_CwlABpIY)
- [Aquatic Ambitions creator showcase](https://www.youtube.com/watch?v=t40J4ZqSoG0)
- [Create: Enchantment Industry overview](https://www.youtube.com/watch?v=JCCfdS9sJZU)

The Enchantment Industry video can expose newer-version features. Those features were deliberately excluded when the 1.4.1 JAR did not contain them.

## Manual checks still required

- exact dynamic Central Kitchen and Slice & Dice recipes in an authenticated JEI session;
- the current Ponder key and any player-specific binding conflicts;
- Doggy Talents and Domestication Innovation bed/collar interaction on a disposable pet;
- Waystone return behaviour inside each installed modded dimension;
- two-player quest-team sharing and dependency-line readability;
- one representative Create contraption, Productive Bees hive and campaign portal in disposable gameplay.

No research or validation touched a live world, live server or personal Prism instance.
