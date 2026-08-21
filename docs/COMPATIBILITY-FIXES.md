# Integrated compatibility fixes

Status: the original fixes and Aquatic Ambitions repair are integrated into the `1.9.0-rc2` pre-release. The exact overrides passed static checks, clean Packwiz installation and disposable Forge startup/reload validation.

## Release-candidate overrides

The global datapack at `payload/both/moonlight-global-datapacks/milkyj-compat-fixes` contains these narrowly scoped overrides. Packwiz delivers each file to both clients and dedicated servers. On a clean world, Moonlight automatically loads it after built-in/mod datapacks as `file/milkyj-compat-fixes`.

| Finding | Exact resource | Original error | Repaired behaviour |
|---|---|---|---|
| Domestication Innovation 1.7.1 filename mismatch | `data/domesticationinnovation/loot_modifiers/blazing_enchanted_book.json` | Forge registers `domesticationinnovation:blazing_enchanted_book`, but the JAR ships only `blazed_enchanted_book.json`, causing a `null` global-loot-modifier decode | Supplies the missing registered resource with JSON byte-for-data equivalent to the valid shipped `blazed` definition |
| Nether's Delight 4.0 leather condition | `data/nethersdelight/loot_modifiers/chopping_leather.json` | Unsupported `minecraft:alternatives` condition | Changes only that condition ID to supported `minecraft:any_of`; machete, target entities, and leather output are preserved |
| Nether's Delight 4.0 string condition | `data/nethersdelight/loot_modifiers/chopping_string.json` | Unsupported `minecraft:alternative` condition | Changes only that condition ID to supported `minecraft:any_of`; machete, spiders, and string output are preserved |
| Beautify 2.0.2 advancement typo | `data/beautify/advancements/progression/candelabra.json` | Two references used nonexistent `beautify:lamp_candleabra` | Changes only those references to installed `beautify:lamp_candelabra`; the advancement now loads |
| Twilight Forest - Dungeons & Villages 1.2.3 shroom path | `data/tf_dnv/loot_tables/chests/dungeon_shroom_barrel.json` | Nested entry requested nonexistent `tf_dnv:dungeon_shroom` | Adds only the missing `chests/` segment and resolves to the JAR's installed `data/tf_dnv/loot_tables/chests/dungeon_shroom.json` |
| Twilight Forest - Dungeons & Villages 1.2.3 casket table | `data/tf_dnv/loot_tables/chests/dungeon_barrel.json` | A weighted nested entry requested removed `twilightforest:chests/casket_loot`, so that part of the dungeon barrel could not resolve | Preserves the complete original pool, conditions, weights and other entries while redirecting only the missing nested table to the installed exploration chest table `twilightforest:chests/hedge_maze` |
| Doggy Talents / Farmer's Delight rice interoperability | `data/forge/tags/items/crops/rice.json` | Doggy Talents `rice_grains` and `uncooked_rice` were separate from Forge's shared rice-crop tag, so Farmer's Delight cooking-pot recipes rejected them | Adds both installed items to `forge:crops/rice` with `replace: false`; existing Farmer's Delight rice remains accepted and no recipe definition is replaced |
| Aquatic Ambitions / Upgrade Aquatic prismarine coral | Four recipes under `data/create_aquatic_ambitions/recipes/channeling/upgrade_aquatic/` | Aquatic Ambitions requested nonexistent `dead_prismarine_coral`, `_block`, `_fan` and `_shower` items, so all four recipes failed at startup and reload | Changes only those inputs to Upgrade Aquatic's installed `elder_prismarine_*` dead forms; all live outputs and 25% bonus chances remain unchanged |

The first four definitions came from the validated compatibility worktree/source commit `bb62f885457e37c20b45bd52717f498aa0859b86`. The `tf_dnv` correction was discovered during this integration audit and separately constrained by static equality checking to its single path value.

No mod JAR was edited. The four Aquatic recipe overrides change only invalid ingredient IDs; no output, count, chance or condition changes. The rice repair only extends the shared ingredient tag. The Central Kitchen vegan recipe, Aether's Delight shield overrides, and Relics talisman warning remain deliberately unchanged as previously classified `IGNORE SAFELY`.

## Existing-world pack priority

Minecraft persists enabled datapack order in each world's `level.dat`. If an existing world receives a new mod after `file/milkyj-compat-fixes` was first enabled, that new mod's built-in pack can be appended above the compatibility pack and win the same resource paths. A clean test world will not reproduce that upgrade-only ordering.

After adding mods to an established world, check the next startup log. If an original repaired definition reappears, run this once in the normal server console while no players are active:

```text
datapack enable "file/milkyj-compat-fixes" last
```

The command reloads data and persists the compatibility pack at highest priority. Restart normally and confirm that no targeted recipe, loot-table or advancement error returns. Keep the pre-update cold backup; never edit `level.dat` while the server is running.

## Proof

`scripts/validate_integrated_compatibility.py` pins the exact installed JAR hashes and proves the override semantics. `scripts/Test-InstallerEndToEnd.ps1` then performs clean Packwiz installs and a real disposable Forge launch.

The latest authoritative runs through 22 August 2026 established:

- 240 clean client JARs and 206 clean server JARs;
- 724 Packwiz destinations and 242 mod definitions;
- automatic enablement and final effective priority of `file/milkyj-compat-fixes`;
- 1,258 advancements at startup and after explicit `/reload`;
- zero targeted global-loot-modifier or advancement errors;
- zero Aquatic Ambitions recipe errors at startup and after reload;
- the corrected `tf_dnv:chests/dungeon_shroom` reference loads without a warning;
- the removed `twilightforest:chests/casket_loot` lookup no longer appears during a real world load;
- 210 FTB quests still parse;
- all seven loaded dimensions save; and
- normal JVM exit code 0.

Baseline-to-candidate and candidate-to-baseline Packwiz testing installs and removes all 11 candidate-only compatibility resources while preserving options/keybindings, screenshots, saves, shader settings, and shader packs. The pre-existing Eumus repair and datapack metadata remain part of the tagged baseline and are therefore intentionally excluded from that candidate-only count.

## Recommendation

The original isolated overrides and the four Aquatic recipe resources are suitable for the `1.9.0-rc2` pre-release. Clean-world validation and an established-world priority migration both removed the original errors without introducing a datapack, recipe, loot-table or advancement failure. The separate authenticated multiplayer interaction pass remains required before promotion to a final release.
