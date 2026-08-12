# Final release gate

**Overall result: FAIL. Do not publish, deploy, update the live server, or distribute this candidate.**

Audited commit: `f1786fafdeacf93de40ce033f11edb1220e09aa5` on `feature/ftb-quests-v1.1.0`.

The Packwiz manifest is structurally valid and the disposable dedicated server starts and stops cleanly, but the release gate cannot pass. Required client/team/copied-data tests were not run, two preserved quest IDs were repurposed, 17 preserved reward definitions changed meaning, the copied 99-ID progress fixture is unavailable, the version lineage regressed, publishable generated data contains a password and third-party UUIDs, `.gitignore` has a playerdata gap, and four broken text sequences remain.

Because the gate failed, the conditional publication procedure was not entered. `Set-PackUrl.ps1`, `Build-Prism-Bootstrap.ps1`, `gh auth status`, repository creation, pushing, HTTP production verification and live maintenance were all deliberately skipped.

Machine-readable evidence:

- `audit/release-gate.json`
- `audit/destination-delta.csv`
- `audit/quest-id-semantics.csv`

## 1. Current mod inventory

The audit searched `packwiz/index.toml`, every file under `packwiz/mods`, `audit/mods.csv`, all 236 clean-client JAR filenames and embedded mod IDs, and all 203 clean-server JAR filenames and embedded mod IDs. Searches included filename fragments, provider project IDs and Forge mod IDs.

| System | Installed | Project/mod IDs searched | Exact evidence | Quest safety |
|---|---:|---|---|---|
| Tinkers' Construct | No | Modrinth `rxIIYO6c`; `tconstruct` | No mod entry, metadata row, audit row, JAR or embedded mod ID. Only old `tconstruct-client.toml` and `tconstruct-common.toml` configs remain. | Three deferred quests are manual checkmarks only. No `tconstruct` item or icon is referenced. |
| Mantle | Yes | Modrinth `Cg6Uc79H`; `mantle` | `packwiz/mods/mantle.pw.toml`, `audit/mods.csv`, and `Mantle-1.20.1-1.11.104.jar` on both clean sides. The JAR embeds `mantle`; exact SHA-512 is `4b05eb01769d3cc299dbfc94c2d4f8d76192e839b53bf83109dd5e72d0dae67f188ffcdefb4683b073fc78fc19e86d84e04023f6ad7542e628817fabacf6db78`. | The Tinkers text says Mantle is a library. No Mantle item task exists. |
| Botany Pots | No | Modrinth `U6BUTZ7K`; `botanypots` | No index mod entry, metadata, audit row, clean JAR or embedded ID. | The one shared Botany information quest is an optional manual checkmark with no item target. |
| Botany Trees | No | Modrinth `mvs7RoIW`; `botanytrees` | No index mod entry, metadata, audit row, clean JAR or embedded ID. | The one shared Botany information quest is an optional manual checkmark with no item target. |
| Fossils and Archeology: Revival | No | CurseForge `223908`; `fossil` | No mod metadata, audit row, clean JAR or embedded ID. Old `fossil-client.toml` and `fossil-common.toml` configs remain. | The archaeology text explains that revival is absent. Its item tasks use only installed Better Archeology IDs. |
| Prehistoric Fauna | No | CurseForge `311600`; `prehistoricfauna` | No mod metadata, audit row, clean JAR or embedded ID. An old `prehistoricfauna-common.toml` remains. | No Prehistoric Fauna item or icon is referenced. |
| Better Archeology | Yes | `betterarcheology` | `betterarcheology-1.2.1-1.20.1.jar` exists on both clean sides and embeds `betterarcheology`. | The real item tasks are `betterarcheology:archeology_table` and `betterarcheology:unidentified_artifact`. |

Provider identifiers were checked against the official [Tinkers' Construct](https://modrinth.com/mod/tinkers-construct), [Botany Pots](https://modrinth.com/mod/botany-pots), [Botany Trees](https://modrinth.com/mod/botany-trees), [Fossils and Archeology: Revival](https://www.curseforge.com/minecraft/mc-mods/fossils) and [Prehistoric Fauna](https://www.curseforge.com/minecraft/mc-mods/prehistoric-fauna) project records.

Result: **PASS for absent-mod item-task safety.** Mantle is installed; the other deferred content systems are not. No quest has an item task for an absent system.

The dinosaur-revival explanation is not itself a manual-only quest: it is part of `Study the Past` (`702A4062FE9B512F`), whose two automatic targets are valid installed Better Archeology items. It does not target Fossils Revival or Prehistoric Fauna content.

## 2. Managed destination reconciliation

The exact comparison is:

```text
previous total                         708
removed destinations                   -24
added destinations                      +3
replaced destinations                    9  (no count change)
current total                          687
net change                             -21
```

The former delivery had 675 non-quest destinations plus 33 quest/research destinations. The current delivery still has those same 675 non-quest destinations but only 12 quest destinations. Every changed destination is under `config/ftbquests/quests`.

Replaced in place (9):

- `config/ftbquests/quests/chapter_groups.snbt`
- `config/ftbquests/quests/data.snbt`
- `config/ftbquests/quests/chapters/archaeology.snbt`
- `config/ftbquests/quests/chapters/create_basics.snbt`
- `config/ftbquests/quests/chapters/first_days.snbt`
- `config/ftbquests/quests/chapters/homestead.snbt`
- `config/ftbquests/quests/chapters/new_horizons.snbt`
- `config/ftbquests/quests/chapters/travel_storage.snbt`
- `config/ftbquests/quests/chapters/welcome.snbt`

Added (3):

- `config/ftbquests/quests/chapters/endgame.snbt`
- `config/ftbquests/quests/chapters/tinkers_deferred.snbt`
- `config/ftbquests/quests/chapters/vehicles.snbt`

Removed (24):

- `config/ftbquests/quests/RESEARCH-SOURCES.txt`
- `config/ftbquests/quests/STAGING-NOTES.txt`
- `config/ftbquests/quests/chapters/aether.snbt`
- `config/ftbquests/quests/chapters/alex_caves.snbt`
- `config/ftbquests/quests/chapters/building.snbt`
- `config/ftbquests/quests/chapters/combat_enchanting.snbt`
- `config/ftbquests/quests/chapters/create_addons.snbt`
- `config/ftbquests/quests/chapters/create_factory.snbt`
- `config/ftbquests/quests/chapters/creative_expeditions.snbt`
- `config/ftbquests/quests/chapters/creatures_companions.snbt`
- `config/ftbquests/quests/chapters/culture_collection.snbt`
- `config/ftbquests/quests/chapters/frozen_ocean.snbt`
- `config/ftbquests/quests/chapters/graduation.snbt`
- `config/ftbquests/quests/chapters/mod_index.snbt`
- `config/ftbquests/quests/chapters/nether_end.snbt`
- `config/ftbquests/quests/chapters/otherside.snbt`
- `config/ftbquests/quests/chapters/productivebees.snbt`
- `config/ftbquests/quests/chapters/seasons_ecology.snbt`
- `config/ftbquests/quests/chapters/settlements_bounties.snbt`
- `config/ftbquests/quests/chapters/structures_dungeons.snbt`
- `config/ftbquests/quests/chapters/tea_storage.snbt`
- `config/ftbquests/quests/chapters/twilight.snbt`
- `config/ftbquests/quests/chapters/wildlife_fishing.snbt`
- `config/ftbquests/quests/chapters/world_lore.snbt`

The old 33 files are preserved under `audit/questbook-legacy-1.8.0`, and `audit/questbook-change-manifest.md` explicitly records that the two text notes were formerly delivered. The per-path old/new SHA-256 values are in `audit/destination-delta.csv`.

No mod, non-quest config, defaultconfig, datapack or resource-pack destination was lost in this delta. No file was restored because the path-level comparison found no accidental non-quest removal. This count reconciliation passes, but it does not make the quest semantic changes safe.

Current Packwiz validation, with the repository placeholder explicitly allowed:

- 687 entries and 687 unique destinations
- sides: 510 both, 162 client, 15 server
- categories: 407 config, 7 defaultconfigs, 238 mods, 2 datapacks, 33 resource-pack files
- 443 hosted payloads and 244 external downloads
- zero TOML, hash, duplicate-destination or protected-path errors

## 3. Version lineage

| Field | Version |
|---|---|
| Legacy quest source | `1.8.0` |
| Pack version at baseline commit/tag | `1.8.1-packwiz.1` |
| Requested task label | `v1.1.0-rc1` |
| Current manifest version | `1.1.0-rc1` |
| Chosen next candidate | `1.9.0-rc1` |

`1.8.1-packwiz.1` was not introduced by the current quest-refinement commit. It already exists in local baseline tag `v1.0.0` at commit `6d1dba51561052092b8a706d6d5cf493d6bda5e4`, and `audit/questbook-change-manifest.md` identifies it as the beginner-guide rebuild following the preserved `1.8.0` definitions.

The task's `v1.1.0-rc1` label assumed a separate `v1.0.0` release line and silently lowered the internal pack version. The sensible lineage-preserving candidate for a feature-sized quest update is `1.9.0-rc1`.

Result: **FAIL.** The chosen version was documented but deliberately not applied during this audit-only failed gate. Version metadata and artifact names must be aligned in an authorized corrective pass before publication.

## 4. Preserved progress IDs

Result: **FAIL.**

- The repository and disposable builds contain no copied FTB Teams/FTB Quests player-progress fixture and no 99-ID ledger. Therefore the claimed set of 99 IDs cannot be enumerated, compared or parsed. This is not replaced by comparing definition files.
- The local `v1.0.0` already-consolidated definition comparison finds 429 IDs and preserves all 429 in the current candidate. That narrower check passes, but it does not prove the 99 copied progress IDs.
- Quest definitions contain 120 unique quest IDs, 167 unique task IDs and 132 unique reward IDs. Duplicate counts are zero.
- Comparing the preserved legacy guide with the current guide finds 109 shared quest IDs and two semantic repurposes:
  - `1885CF9658AB663D`: `Foreword: A World of Many Ages` became `Power Beyond the First Water Wheel`.
  - `22B69CA315389C48`: `The Covenant of the Hearth` became `Create Food Addons: Kitchen to Factory`.
- The task types for the 109 shared quest blocks did not change, but those two manual checkmarks now represent unrelated learning objectives. An old completion can therefore complete unrelated Create content.
- Seventeen retained quests changed preserved item-reward IDs into XP-reward definitions. A completed but unclaimed old quest can produce a different result after the update. Exact quest IDs and old/new reward definitions are in `audit/quest-id-semantics.csv`.
- The visible guide removes 287 of the 396 legacy quest IDs. Without copied progress, safe handling of unknown removed IDs cannot be demonstrated.
- Old progress parsing, unrelated-reward prevention and new-player clean progression were not tested.

## 5. Functional quest tests

`FAIL (not run)` means a required release test was unavailable or deliberately not inferred from parsing.

| Test | Result | Evidence |
|---|---|---|
| Clean client opens the quest book | **FAIL (not run)** | No authenticated clean client was launched. |
| All 10 chapters are visible | **FAIL (not run)** | Server parsing says 10 chapters; GUI visibility was not inferred. |
| All 120 quests load | **PASS** | FTB Quests logged `Loaded 4 chapter groups, 10 chapters, 120 quests, 0 reward tables`. |
| Intro manual checkmark completes | **FAIL (not run)** | Requires client interaction. |
| Automatic item detection completes | **FAIL (not run)** | Requires client interaction and server sync. |
| Reward can be claimed | **FAIL (not run)** | Requires client interaction. |
| Reward arrives exactly once | **FAIL (not run)** | Requires repeated claim attempt and inventory/XP observation. |
| Completed description remains readable | **FAIL (not run)** | Requires completed-quest GUI; four broken text sequences already exist statically. |
| Two same-team players share progress | **FAIL (not run)** | No two-client test. |
| Outside-team player remains separate | **FAIL (not run)** | No third/separate-team test. |
| No player is forced into a global team | **FAIL (not run)** | No new-player team-state test. |
| Copied existing progress loads | **FAIL (no fixture)** | The claimed copied progress is absent. |
| Copied existing world loads | **FAIL (no offline backup)** | The live world was not hot-copied. |
| Disposable server reaches Done | **PASS** | `Done (41.455s)!` |
| All dimensions save on shutdown | **PASS** | Overworld, Nether, End, Aether, Twilight Forest, Otherside and `graveyard:past` saved; log ended with `All dimensions are saved`. |
| Server JVM exits cleanly | **PASS** | Disposable process exited after shutdown. |
| Client receives server quest definitions | **FAIL (not run)** | No client connected. |
| No quest missing-item/invalid-icon errors | **PASS** | 87 unique item/icon references resolve against the 236-JAR client registry and FTB parsing emitted no quest item/icon error. |
| No quest references air or absent item ID | **PASS** | 83 unique item IDs resolve; absent mods have no item task. |
| No dependency cycles/unreachable quests | **PASS** | All 120 graph nodes visited; zero missing dependencies. |

The disposable log does contain non-quest pack-data errors, so the pass above is specifically for quest item/icon references:

- Create Central Kitchen's `vegan_hamburger` recipe expects absent `miners_delight:vegan_patty`.
- Two Aether shield recipes are malformed.
- A Beautify advancement references unknown `beautify:lamp_candleabra`.
- Curios reports an unregistered talisman slot type.
- Bundled loot-modifier JSON uses invalid `minecraft:alternative(s)` types.

### Exact manual UI work still required from Jack

Use only disposable data and an authenticated clean client:

1. Connect the clean client to the disposable dedicated server and open the quest book.
2. Confirm all 10 chapter tabs and all 120 quests are visible and that dependency lines do not overlap labels.
3. Complete the first manual checkmark and reopen it to confirm the full description remains readable.
4. Complete a cheap automatic item quest and confirm it detects an already-held and a newly-acquired item as intended.
5. Claim one reward, observe the exact XP once, then attempt to claim again and confirm no second award.
6. Connect a second account, deliberately join the same FTB Team and confirm shared progress and readable completed text.
7. Connect or reset a player outside that team and confirm separate progress and no automatic global-team assignment.
8. Confirm the client is displaying the server-supplied definitions rather than stale local definitions.
9. With an offline backup only, load copied existing player quest/team progress and verify the exact 99-ID ledger, parsing, completions and unclaimed rewards.
10. With a separately backed-up offline copy only, load the existing world and shut it down cleanly.
11. Create a genuinely new player/team state and confirm no old completions or rewards are inherited.

## 6. Quest quality

### Counts

| Chapter | Quests |
|---|---:|
| WHERE THE FUCK DO I START? | 13 |
| Surviving the First Night | 10 |
| Food That Isn't Raw Chicken | 13 |
| Tinkers' Construct for Absolute Idiots | 3 |
| Create Without Having a Brain Aneurysm | 22 |
| Stop Living Out of 46 Chests | 11 |
| Exploration Without Getting Completely Lost | 15 |
| Fossils, Archaeology and Dinosaurs | 10 |
| Vehicles and Transport | 9 |
| Dangerous Shit and Endgame | 14 |
| **Total** | **120** |

- 167 task objects: 63 checkmarks, 99 items, 1 kill, 2 dimension and 2 advancement.
- 63 manual-checkmark quests; 57 automatic-detection quests.
- 132 reward objects on 116 quests; every current reward is XP from 2 to 50.
- 25 optional quests.
- 4 no-reward quests: `4DC3990D720C9351`, `7527B8F4C044703F`, `6DE3B73D0A1B5F00`, `7F9807E5C66C1532`.
- 4 deferred information quests: one shared Botany quest and three Tinkers quests.
- 63 quests require manual checkmark interaction. Because no client interaction was run, all 120 still require release-runtime verification, including the 57 automatic quests.
- No item tags are referenced.

### Static quality findings

- No absent-mod item task, unresolved item/icon, unresolved dependency, cycle, unreachable node, exact coordinate overlap, placeholder token or exact duplicate description was found.
- The largest item detection is 32 `create:track` in `Lay the Railway`; that is a reasonable railway milestone. No other detection exceeds 16.
- Current XP-only rewards do not hand out machines, boss drops or progression items. However, the 17 changed preserved reward definitions are a compatibility failure.
- No obvious wrong-version instruction was found statically. The guide says Create 6 and the clean client has `create-1.20.1-6.0.8.jar`; JEI, Patchouli, Ponder/Create, FTB Teams, Ultimine, Carry On and the named storage/vehicle mods are installed. Actual controls remain a manual client check.
- Exact coordinates do not collide, and the graph is valid. Readability and dependency-line clarity cannot pass without seeing the GUI.
- Four mojibake sequences rendered as the code-point sequence U+00E2/U+20AC/U+201D rather than an em dash: two at `create_basics.snbt:147`, one at line 192 and one at line 438. This was a text-quality blocker.

Referenced mod namespaces (23):

```text
beautify
betterarcheology
biomesoplenty
bountiful
comforts
cookingforblockheads
create
explorerscompass
exposure
farmersdelight
herbalbrews
immersive_aircraft
minecraft
naturalist
naturescompass
productivebees
rechiseled
relics
smallships
sophisticatedbackpacks
storagedrawers
toms_storage
waystones
```

Referenced item IDs (83):

```text
beautify:bookstack
beautify:botanist_workbench
beautify:oak_trellis
betterarcheology:archeology_table
betterarcheology:unidentified_artifact
biomesoplenty:fir_sapling
biomesoplenty:glowflower
biomesoplenty:jacaranda_sapling
biomesoplenty:lavender
biomesoplenty:mahogany_sapling
biomesoplenty:orange_maple_sapling
biomesoplenty:palm_sapling
biomesoplenty:redwood_sapling
bountiful:bounty
bountiful:bountyboard
comforts:sleeping_bag_white
cookingforblockheads:cooking_table
cookingforblockheads:fridge
cookingforblockheads:oven
create:andesite_alloy
create:andesite_funnel
create:basin
create:belt_connector
create:brass_ingot
create:chute
create:cogwheel
create:depot
create:encased_fan
create:filter
create:gearbox
create:goggles
create:large_cogwheel
create:mechanical_crafter
create:mechanical_mixer
create:mechanical_press
create:railway_casing
create:schedule
create:shaft
create:track
create:water_wheel
create:wrench
explorerscompass:explorerscompass
exposure:black_and_white_film
exposure:camera
farmersdelight:apple_pie
farmersdelight:beef_stew
farmersdelight:cabbage
farmersdelight:cooking_pot
farmersdelight:cutting_board
farmersdelight:hamburger
farmersdelight:onion
farmersdelight:rice
farmersdelight:stove
farmersdelight:tomato
herbalbrews:green_tea_leaf
herbalbrews:tea_blossom
immersive_aircraft:airship
immersive_aircraft:biplane
immersive_aircraft:gyrodyne
minecraft:beehive
minecraft:honey_bottle
minecraft:honeycomb
minecraft:iron_ingot
naturalist:butterfly
naturescompass:naturescompass
productivebees:bee_cage
productivebees:sturdy_bee_cage
rechiseled:chisel
relics:researching_table
smallships:oak_cog
smallships:oak_galley
smallships:sail
sophisticatedbackpacks:backpack
sophisticatedbackpacks:crafting_upgrade
sophisticatedbackpacks:iron_backpack
sophisticatedbackpacks:pickup_upgrade
storagedrawers:oak_full_drawers_1
toms_storage:ts.crafting_terminal
toms_storage:ts.inventory_cable
toms_storage:ts.inventory_connector
toms_storage:ts.storage_terminal
waystones:return_scroll
waystones:waystone
```

Referenced tags: **none**.

## 7. Security and publication audit

Result: **FAIL.**

Pass findings:

- No GitHub/Microsoft/Minecraft token shape, account database, session file or non-loopback server IP was found in tracked files.
- No tracked publishable file contains an absolute local Windows user path.
- No mod JAR, ZIP, MRPACK, world region, playerdata, backup, log, crash report, screenshot, save, `options.txt`, shader archive or shader setting is tracked.
- Mod downloads are metadata records pointing to upstream providers; downloaded JARs exist only in ignored disposable build directories.
- `.gitignore` correctly covers `build/`, `dist/`, `server-runtime/`, `backups/`, conventional `world/` and `world_*/`, options, screenshots, saves, logs, crash reports, shaderpacks, Prism account files and common server identity/access files.
- The only tracked IP literal is `127.0.0.1`, used by disposable local test tooling.

Blocking findings:

1. `payload/both/config/resourceful-config-web.json` is tracked and Packwiz-managed and contains a generated password value, even though the web feature is disabled. The value is intentionally omitted here. File SHA-256: `276088ffb61e688f471d9e8d7408deccadf851865e60f2b828d76a4d14927e64`.
2. `payload/both/config/dawnoftimebuilder/patrons_cache.json` is tracked and Packwiz-managed and contains five third-party Minecraft UUID/name pairs repeated across patron tiers. They are not live-server player records, but the generated cache is unnecessary personal-identifier data. SHA-256: `401f708858ae05dcc6aeccd6edeb81375c26f6436812d24339666679f8a71c8d`.
3. `git check-ignore playerdata/x.dat` reports `NOT_IGNORED`. `.gitignore` therefore cannot be confirmed to exclude all inappropriate player data.

No secret value or UUID was copied into the machine-readable audit.

## 8. Publication and artifacts

- Repository: **not created or published**; no Git remote is configured.
- Target repository (reserved, not verified): `https://github.com/AyeItsMilkyJ/milkyj-vanillaplus`
- Target raw URL (not active or inserted): `https://raw.githubusercontent.com/AyeItsMilkyJ/milkyj-vanillaplus/main/packwiz/pack.toml`
- Current configured URL still contains `REPLACE_WITH_GITHUB_USERNAME`.
- GitHub authentication was not inspected because the conditional gate failed.
- No commit, push, public tag or GitHub release was made.
- Local test bootstrap: `dist/MilkyJ-VanillaPlus-v1.1.0-rc1-LOCAL-TEST-Prism.zip`, SHA-256 `a1c2d44a1cb1d5d9a2033985d751418c97fef7e2b40a7355f56ea2c2c9a39e6c`.
- Previous bootstrap preserved: `dist/MilkyJ-VanillaPlus-AutoUpdating-Prism.zip`.
- Clean client: 236 JARs.
- Clean server: 203 JARs.

The local test ZIP is not an approved release candidate: it has the wrong version lineage, uses a loopback test URL, and was not rebuilt after this failed gate.

## Files created by this audit

- `docs/RELEASE-GATE.md`
- `audit/release-gate.json`
- `audit/destination-delta.csv`
- `audit/quest-id-semantics.csv`

No existing pack file, quest, mod, config, live server file, live installation, live world, playerdata, backup or release artifact was changed. No server process was stopped or started by this audit.
