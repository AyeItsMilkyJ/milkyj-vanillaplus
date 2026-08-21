# MilkyCraft Vanilla+ 1.9.0-rc2

This is a Forge 1.20.1 pre-release delivered through the existing Packwiz update feed. Existing players keep their current Prism instance and press **Play**; new players import the one-time Prism ZIP.

## Highlights

- Expands the guide to 210 connected quests across 15 chapters.
- Adds a nine-quest **Enchanting and the Public Armoury** route covering Quark Matrix pieces, matching-piece merges, coloured-candle influence, books, Easy Anvils, Grindstones and Create: Enchantment Industry.
- Tunes Matrix enchanting to waste less lapis, make useful repeats more practical and make candle steering meaningful while retaining bookshelf, experience and treasure-enchantment progression.
- Adds Create: Aquatic Ambitions, Compatible Storage, Components and Additions, exact Create 6.0.8 backported fixes and client-only SeasonHUD.
- Updates Create: Enchantment Industry to 1.4.1 for its final Forge 1.20.1 maintenance fixes.
- Integrates narrow datapack repairs for Domestication Innovation, Nether's Delight, Beautify, Twilight Forest Dungeons & Villages, shared rice recipes and Aquatic Ambitions coral recipes.
- Keeps the public MilkyCraft name, visible server console, three-hour graceful restarts, Discord status integration, permanent Packwiz updates and preservation of player settings.
- Fixes a Windows PowerShell 5.1 edge case that could leave the visible server console waiting for input before Java started.

## Validation

- Packwiz manifest: 724 managed destinations with valid hashes and side metadata.
- Clean payloads: 240 client JARs and 206 dedicated-server JARs.
- Quests: 15 chapters, 210 quests, all reachable, with no duplicate IDs, missing dependencies, unresolved item IDs or parser errors.
- Disposable Forge server: reached `Done`, loaded the full quest book, saved every loaded dimension and exited normally.
- Update and rollback: changed and obsolete managed files behaved correctly while options, controls, saves, screenshots, shaders and player-specific settings remained intact.

## Pre-release limitation

The headless and static gates cannot operate the Matrix, Anvil or new Create GUIs, or prove multiplayer quest/team behaviour. The full authenticated two-client checklist remains outstanding: quest-page readability and dependency lines, manual and automatic task completion, reward claiming and double-claim protection, FTB Team sharing/isolation, Matrix/candle/anvil behaviour, representative Create interactions, and reconnect sanity. This release is therefore intentionally labelled `rc2` rather than final. Use inexpensive test items for the first enchanting session and report any GUI conflict before committing valuable equipment.

## Server owners

Stop the dedicated server cleanly and use the guarded update-and-start workflow. It creates and verifies a timestamped cold backup before changing managed files, refuses to update a running JVM, requires the updated server to reach `Done`, and retains the rollback path.

Existing worlds persist datapack order. If the startup log shows one of the repaired Aquatic Ambitions, loot or advancement definitions after adding new mods, run `datapack enable "file/milkyj-compat-fixes" last` once in the server console with no players active, then restart and recheck the log. Clean worlds already receive this priority automatically.
