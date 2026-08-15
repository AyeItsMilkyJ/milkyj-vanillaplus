# MilkyJ Vanilla+ — player features and evolution

This document describes only systems confirmed in the current `1.9.0-rc1` Forge 1.20.1 pack. Library mods are not advertised as gameplay features, and removed or rejected additions are not presented as installed.

## The short version

MilkyJ Vanilla+ is a multiplayer-friendly adventure and homestead pack built around the idea that additions should still feel at home in Minecraft. It keeps normal survival recognisable, then layers in Create engineering, richer food and farming, useful structures, collectible loot, new wildlife, archaeology, transport, several substantial dimensions and a beginner field guide. Its client and dedicated server have been tuned for modest PCs while preserving long-distance terrain through Distant Horizons.

Current foundation:

- Minecraft 1.20.1 with Forge 47.4.10.
- 235 client JARs and 203 dedicated-server JARs after side classification.
- 118 original pack quests across 9 chapters.
- Seven managed resource-pack choices plus ten optional shader choices in the mate installer.
- Dedicated-server view distance 12 and simulation distance 6.
- Packwiz checks for managed updates before each Prism launch.
- The Windows server supervisor saves and restarts cleanly every three hours.

## How the pack grew

### 1. Vanilla+ foundation

The original direction was a recognisable survival game with more things worth building, finding and collecting. Create became the main technology system because its moving machinery, belts, water wheels, trains and contraptions look and behave like a natural extension of Minecraft. Decorative Blocks, Another Furniture, Handcrafted, Beautify, Supplementaries, Amendments, FramedBlocks, Rechiseled, Macaw's building sets, Twigs, Chimes, Fairy Lights, paintings, statues and display/storage blocks expanded building without replacing the vanilla block language.

### 2. A larger adventure world

The world was expanded with Terralith, Biomes O' Plenty and TerraBlender, then populated with YUNG's structure upgrades, Repurposed Structures, Towns and Towers, Dungeons and Taverns, Dungeons Plus, bridges, IDAS-style integrated structures, The Graveyard and Better Archeology sites. Lootr gives each player their own structure-chest loot, so exploring with friends no longer means one person empties everything first.

The major adventure destinations currently include:

- The Aether and Aether's Delight.
- Twilight Forest and Twilight's Delight.
- Deeper and Darker's Otherside, reached through the Warden/deep-dark progression.
- Alex's Caves and its large themed underground biomes.
- An Incendium-enhanced Nether.
- End Remastered progression and a Nullscape-enhanced End.
- Aquamirae, The Graveyard and Mowzie's Mobs encounters.

Better Nether, Better End and Bumblezone are not installed; the pack uses the alternatives above.

### 3. Homesteading, food and companions

Farmer's Delight anchors the cooking system, with Central Kitchen, Slice & Dice, Brewin' and Chewin', Nether's Delight, Ender's Delight, Aether's Delight, Twilight's Delight, Alex's Caves Delight, Cooking for Blockheads, Herbal Brews, Neapolitan and seasonal farming support. Productive Bees adds beekeeping and resource production. Animal Feeding Trough, Smarter Farmers and Right Click Harvest reduce chores without turning farming into a menu.

Doggy Talents Next, Domestication Innovation, Naturalist, Alex's Mobs, Critters and Companions, Friends & Foes, Creeper Overhaul, Enderman Overhaul, Upgrade Aquatic, unusual fish, exotic aquatic life, birds, butterflies and other ambient creatures make settlements and journeys feel alive. Rice interoperability was repaired so Doggy Talents rice items also work in shared Farmer's Delight-style food recipes.

### 4. Engineering and transport

Create 6 is supported by Create: Steam 'n' Rails, Enchantment Industry, Central Kitchen, Slice & Dice, Connected, Copycats+, Deco, Rechiseled: Create and Create Ultimine. Players can build mechanical processing lines, farms, logistics, trains and experience automation.

Travel also includes Small Ships and upgrades, Immersive Aircraft and AstikorCarts. Waystones, Nature's Compass, Explorer's Compass, Xaero's minimap/world map and Distant Horizons make long expeditions practical without removing survival preparation.

### 5. Storage and multiplayer quality of life

Sophisticated Backpacks, Tom's Simple Storage, Storage Drawers, labels, shulker previews, Carry On and inventory/crafting helpers reduce chest-wall chaos. Corpse provides recoverable death storage. Jade explains blocks and entities, JEI remains the recipe authority, Polymorph resolves recipe collisions, and Create Ponder teaches machine layouts.

Other quality-of-life features include Ultimine/VeinMiner-style excavation, falling trees, comfort items, easier anvils and enchanting, visual workbenches, equipment comparison, enchantment descriptions, advancement plaques, third-person improvements, zoom, controller/search helpers and clearer HUD information. Simple Voice Chat was removed because the group uses Discord.

### 6. A real beginner field guide

The old shallow quest list became a 118-quest field guide designed for players new to mods. Its nine chapters cover starting controls and interfaces, first-night survival, food and homesteading, Create, storage, exploration, archaeology, vehicles and endgame. The 22-lesson Create chapter explains Ponder, rotation, RPM, stress, power sources, processing, logistics, brass, trains and the installed addons. Quests teach and suggest experiments; they do not lock recipes or force established players to rebuild their base.

### 7. Visual choices and distant terrain

Managed resource-pack choices are Bare Bones, Faithful 32x, FPBR, Fresh Animations, Fresh Compats, Shable's Tweaks and the custom MilkyJ Stability Fixes layer. The stability layer repairs exact missing model, texture, sound and atlas paths without replacing unrelated art.

The mate installer contains ten optional shaders:

1. HyShaders Vanilla Lite
2. MakeUp Ultra Fast
3. Sildur's Enhanced Default
4. BSL
5. TAA — Distant Horizons Port
6. Bloop
7. Daybreak
8. Neon Skylines
9. Hysteria
10. Solas

No shader is forced. MakeUp, HyShaders and Sildur's are the safer low-cost choices; BSL is the balanced showcase option tested with the current Oculus/Distant Horizons stack. Shader behaviour still varies by GPU and driver.

### 8. Performance and server reliability

The current optimization stack uses ModernFix, FerriteCore, Embeddium, Entity Culling, ImmediatelyFast, AI Improvements, FastSuite, Alternate Current, Clumps, Let Me Despawn, Packet Fixer and bounded Chunky pregeneration. Client-only rendering mods are kept off the dedicated server. Sodium and Lithium are not installed because this is Forge 1.20.1 and Embeddium already fills the relevant client-rendering role.

Distant Horizons supplies long-distance silhouettes while the server keeps normal view distance at 12 and ticking simulation at 6. Server-side distant generation was constrained after real watchdog evidence, avoiding the earlier uncontrolled world-generation crash pattern. Clean tests reached 20 TPS, saved every loaded dimension and exited normally.

The server supervisor:

- launches Forge directly under Java 17;
- detects unexpected exits and relaunches with a delay;
- announces scheduled restarts in chat;
- runs `save-all flush` and performs a normal stop;
- restarts every 180 minutes after the server reaches `Done`; and
- keeps the Java process in the supervisor console rather than opening a separate GUI window.

### 9. Permanent updates and compatibility repairs

Players import one Prism ZIP once and keep using that same instance. Before every launch, Packwiz compares the public manifest, downloads only changed managed files and removes obsolete files it previously managed. It does not overwrite accounts, saves, screenshots, logs, controls, video/render settings, resource-pack order, shader selection or per-shader settings. Mod-specific client settings now receive sensible defaults on their first install and are preserved on later updates; server and gameplay configs still update normally.

Compatibility work has repaired:

- Domestication Innovation's mismatched loot-modifier filename.
- Nether's Delight's unsupported leather/string loot conditions.
- Beautify's misspelled candelabra advancement item.
- Twilight Forest Dungeons & Villages loot-table paths.
- Doggy Talents/Farmer's Delight rice tags.
- stale JEI, Guard Villagers and Quark configuration keys.
- missing Decorative Blocks and hanging-flower-pot models.
- exact Chimes, Naturalist, Alex's Caves and Supplementaries sound paths.
- Bountiful and several biome/block texture fallbacks.

Cubes Without Borders was removed after it contributed to framebuffer conflicts. Broken Complementary variants, Bliss, Photon and other known-bad local shader copies were quarantined rather than shipped. No live world was deleted or replaced during this work.

## Accuracy notes for a public description

- Do not claim every mod is lightweight; the pack is large, but it is deliberately optimized and side-classified.
- Do not promise that every shader works on every graphics card.
- Do not advertise Better Nether, Better End, Bumblezone, Simple Voice Chat, Immersive Engineering, Create Crafts & Additions, Tinkers' Construct, Botany Pots or a dinosaur-DNA revival system: they are not installed.
- Do not describe dependencies and libraries as major gameplay features.
- Do not publish a private server address, personal file path, account information or world download on a public modpack page.
