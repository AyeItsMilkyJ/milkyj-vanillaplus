# Integrated compatibility fixes

Status: integrated and automatically validated on `integration/v1.9.0-rc1-final`. Nothing has been published, pushed, or merged. The original five fixes and the later rice-tag interoperability repair were deployed locally only after verified cold backups.

## Release-candidate overrides

The existing highest-priority global datapack at `payload/both/moonlight-global-datapacks/milkyj-compat-fixes` now contains these narrowly scoped overrides. Packwiz delivers each file to both clients and dedicated servers; Moonlight loads the datapack after built-in/mod datapacks as `file/milkyj-compat-fixes`.

| Finding | Exact resource | Original error | Repaired behaviour |
|---|---|---|---|
| Domestication Innovation 1.7.1 filename mismatch | `data/domesticationinnovation/loot_modifiers/blazing_enchanted_book.json` | Forge registers `domesticationinnovation:blazing_enchanted_book`, but the JAR ships only `blazed_enchanted_book.json`, causing a `null` global-loot-modifier decode | Supplies the missing registered resource with JSON byte-for-data equivalent to the valid shipped `blazed` definition |
| Nether's Delight 4.0 leather condition | `data/nethersdelight/loot_modifiers/chopping_leather.json` | Unsupported `minecraft:alternatives` condition | Changes only that condition ID to supported `minecraft:any_of`; machete, target entities, and leather output are preserved |
| Nether's Delight 4.0 string condition | `data/nethersdelight/loot_modifiers/chopping_string.json` | Unsupported `minecraft:alternative` condition | Changes only that condition ID to supported `minecraft:any_of`; machete, spiders, and string output are preserved |
| Beautify 2.0.2 advancement typo | `data/beautify/advancements/progression/candelabra.json` | Two references used nonexistent `beautify:lamp_candleabra` | Changes only those references to installed `beautify:lamp_candelabra`; the advancement now loads |
| Twilight Forest - Dungeons & Villages 1.2.3 shroom path | `data/tf_dnv/loot_tables/chests/dungeon_shroom_barrel.json` | Nested entry requested nonexistent `tf_dnv:dungeon_shroom` | Adds only the missing `chests/` segment and resolves to the JAR's installed `data/tf_dnv/loot_tables/chests/dungeon_shroom.json` |
| Doggy Talents / Farmer's Delight rice interoperability | `data/forge/tags/items/crops/rice.json` | Doggy Talents `rice_grains` and `uncooked_rice` were separate from Forge's shared rice-crop tag, so Farmer's Delight cooking-pot recipes rejected them | Adds both installed items to `forge:crops/rice` with `replace: false`; existing Farmer's Delight rice remains accepted and no recipe definition is replaced |

The first four definitions came from the validated compatibility worktree/source commit `bb62f885457e37c20b45bd52717f498aa0859b86`. The `tf_dnv` correction was discovered during this integration audit and separately constrained by static equality checking to its single path value.

No mod JAR, mod version, recipe definition, quest, quest ID, reward, or unrelated loot entry was changed. The rice repair only extends the shared ingredient tag. The Central Kitchen vegan recipe, Aether's Delight shield overrides, and Relics talisman warning remain deliberately unchanged as previously classified `IGNORE SAFELY`.

## Proof

`scripts/validate_integrated_compatibility.py` pins the exact installed JAR hashes and proves the override semantics. `scripts/Test-InstallerEndToEnd.ps1` then performs clean Packwiz installs and a real disposable Forge launch.

The authoritative run on 13 August 2026 established:

- 236 clean client JARs and 203 clean server JARs;
- 689 Packwiz destinations and 238 mod definitions;
- automatic enablement and final effective priority of `file/milkyj-compat-fixes`;
- 1,258 advancements at startup and after explicit `/reload`;
- zero targeted global-loot-modifier or advancement errors;
- the corrected `tf_dnv:chests/dungeon_shroom` reference loads without a warning;
- 118 FTB quests still parse;
- all seven loaded dimensions save; and
- normal JVM exit code 0.

Baseline-to-candidate and candidate-to-baseline Packwiz testing also installed and removed all five candidate-only compatibility resources while preserving options/keybindings, screenshots, saves, shader settings, and shader packs.

## Remaining `tf_dnv` warning

`tf_dnv:chests/dungeon_barrel` still references missing `twilightforest:chests/casket_loot`. The installed Twilight Forest 4.3.2508 JAR and its upstream 1.20 branch contain a keepsake-casket block loot table but no chest table with that ID. The add-on's dungeon structures use `dungeon_barrel`, so this can produce a dead weighted nested-loot entry during real exploration. No existing table is an unambiguous semantic replacement.

Classification: **FIX LATER**. Ask the add-on author which loot table was intended, then implement and validate a dedicated alias or corrected override. Do not guess by redirecting it to hedge-maze or keepsake-casket block loot.

## Recommendation

The six proven isolated overrides should be included in 1.9.0. The unresolved casket warning should not block the current RC automatically, but it must remain documented for a later compatibility update.
