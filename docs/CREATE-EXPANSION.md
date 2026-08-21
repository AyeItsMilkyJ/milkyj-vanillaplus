# Create and quality-of-life expansion

Candidate: `1.9.0-rc2`

Source branch: `feature/create-and-content-expansion`

Status: integrated into the `1.9.0-rc2` pre-release. Automated validation is complete; the interaction checks listed below remain explicitly outstanding.

## What was added

This pass deliberately expands systems that already exist instead of adding another broad world-generation, structure, mob or food mod. The pack already has extensive content in those categories, while extra world generation would increase startup, exploration and memory cost for the group's lower-end PCs.

| Component | Version | Side | Player-facing purpose |
|---|---:|---|---|
| Create 6.0.8 Backported Fixes | 1.1.0 | both | Backports narrowly scoped fixes for the installed Create 6.0.8 line, including placard/Schematicannon and Xaero train-map scaling corrections. |
| Create: Aquatic Ambitions | 1.20.1-2.0.2 | both | Adds Conduit Cage channeling for focused prismarine, coral and copper automation. |
| Create: Compatible Storage | 2.13.0 | both | Makes supported containers from the existing storage/building stack behave correctly on Create contraptions. |
| Create: Components and Additions | 2.2 | both | Adds a compact set of mechanical components, centred on a brass gearbox whose faces can be blocked individually. |
| SeasonHUD | 2.0.8 | client only | Shows the already-installed Serene Seasons state in the HUD or Xaero minimap without adding a dedicated-server JAR or server tick work. |

Create: Enchantment Industry was also updated from `1.4.0` to the final legacy `1.4.1` maintenance release. It remains required on both sides and still targets Create `[6.0.8,6.0.9)`. The update fixes Clumps merged-orb handling, XP rounding/loss and several Disenchanter/tank edge cases; it adds no dependency.

The existing 118 quests, IDs, tasks and rewards were retained. Only the installed-addon description in the existing Create chapter was refreshed so players do not follow tutorials for absent addons.

## Aquatic Ambitions compatibility repair

Aquatic Ambitions 2.0.2 generated four Upgrade Aquatic recipes with nonexistent `dead_prismarine_*` inputs. Upgrade Aquatic 6.0.3 registers the corresponding dead forms as `elder_prismarine_*`. The final-priority `milkyj-compat-fixes` datapack now overrides exactly these resources:

- `data/create_aquatic_ambitions/recipes/channeling/upgrade_aquatic/prismarine_coral.json`
- `data/create_aquatic_ambitions/recipes/channeling/upgrade_aquatic/prismarine_coral_block.json`
- `data/create_aquatic_ambitions/recipes/channeling/upgrade_aquatic/prismarine_coral_fan.json`
- `data/create_aquatic_ambitions/recipes/channeling/upgrade_aquatic/prismarine_coral_shower.json`

Only each ingredient changes from `upgrade_aquatic:dead_prismarine_*` to the installed `upgrade_aquatic:elder_prismarine_*`. Outputs and chances are byte-for-data equivalent to the original recipes. The coral, fan and shower still produce one live form plus the original 25% bonus chance; the block still produces exactly one. No wall-fan recipe was invented because Upgrade Aquatic intentionally registers its wall fan without a separate item.

Static validation pins both exact JAR hashes, proves all four broken IDs are absent, proves all four corrected item resources exist, and proves the overrides change nothing else. The original four runtime recipe errors disappeared at startup and after `/reload`.

## Deliberately held or rejected

| Candidate | Decision | Reason |
|---|---|---|
| Create: Extended Wrenches 2.0.0 | removed from this candidate | Functionally loaded, but introduced an avoidable log-level mixin metadata error and missing-refmap warning for a low-value cosmetic tool addon. |
| Copycats+ 3.0.8 | held at installed 3.0.7 | The new artifact includes useful material-storage cleanup but predates upstream's corrective revert for encased-fan airflow passing through solid blocks. Wait for a post-revert release. |
| Create: Contraption Terminals | not added | Remains an explicit pack exclusion despite otherwise reasonable compatibility. |
| Create Crafts & Additions / Immersive Engineering | not added | Explicitly excluded from this pack's direction. |
| Create: Bits 'n' Bobs | not added | Redundant content plus unresolved crash/memory reports were not acceptable for this performance-first pack. |
| Create: Additional Logistics | held | Useful, but current performance reports need resolution before it belongs on a multiplayer world. |
| Create: Pattern Schematics | held | Its legacy/infinite-building behaviour needs server-rule and survival-balance testing first. |

## Validation completed

- Packwiz: 718 unique destinations, 242 mod definitions, valid hashes and zero manifest errors.
- Side classification: 240 clean client JARs and 206 clean dedicated-server JARs; SeasonHUD did not leak to the server.
- Update safety: two clean installs completed, then a second update pass reused managed files correctly while preserving options, keybindings, screenshots, saves, shader settings and mod-specific client preferences.
- Rollback safety: the disposable baseline → RC2 → baseline cycle installed and then removed all five added JARs, restored the previous Enchantment Industry JAR, installed and removed all 11 candidate-only compatibility resources, removed an obsolete managed sentinel, and preserved personal options, keybindings, screenshots, saves and shader files.
- Dedicated server: Forge 47.4.10 reached `Done` in 39.440 seconds, loaded all four both-side Create additions and Enchantment Industry 1.4.1, parsed 9 chapters/118 quests, reloaded the final-priority compatibility datapack, saved all seven loaded dimensions and exited with code 0.
- Error audit: zero Aquatic Ambitions recipe errors at startup or reload; zero new addon-specific construction, datapack, loot or advancement errors.
- Client: an ignored disposable Prism profile reached the main menu in 80.745 seconds with 240 JARs. SeasonHUD loaded its Serene Seasons and Xaero integrations, no targeted error or crash report appeared, and Minecraft closed normally.
- Supervisor: the exact 206-JAR disposable payload reached `Done` on isolated port 25578 under direct Java ownership, accepted a normal stop, saved every loaded dimension, released the port and exited. Production port 25565 was unchanged.
- Performance: the final 206-JAR disposable workload held 20 TPS in clean idle, fresh Chunky generation, completion-gated far exploration and a synthetic loaded-base scenario. Peak sampled used heap was 3,632.5 MiB (about 3.55 GiB), no full GC occurred, all seven dimensions saved, Distant Horizons closed cleanly and the JVM exited 0.
- Quest invariants: 9 chapters, 118 quests, 165 task IDs, 134 reward IDs, no duplicate IDs, no missing dependencies and no cycles.

Existing known-safe warnings remain: Central Kitchen's absent vegan-patty integration recipe, the Aether shield override parsing warnings, the Relics talisman-slot warning, and longstanding third-party mixin metadata warnings. Backported Fixes adds one accepted packaging warning: its mixin config requests `create_6_0_8_backported_fixes.mixins.json.refmap.json`, while the JAR ships an empty `create_6_0_8_backported_fixes.refmap.json`. Both required mixins prepared without an application failure, the server reached `Done`, and the client reached the main menu. This is noisy but non-functional; unlike Extended Wrenches, it has a valid mixin `minVersion` and retains worthwhile targeted fixes.

## Outstanding manual interaction checks

Automated launch/data tests cannot prove every interaction. Complete these checks before promoting the pre-release to final or claiming the interactions themselves are verified:

1. build and Ponder each new Components and Additions block;
2. assemble/disassemble a contraption carrying representative Quark and existing storage containers;
3. run the four repaired elder-prismarine channeling recipes through a Conduit Cage and confirm their JEI entries;
4. exercise Enchantment Industry with merged Clumps orbs, the Disenchanter and a broken multiblock tank;
5. confirm SeasonHUD placement does not cover the preferred Xaero layout; and
6. join the real server with two matching clients for movement, inventory and reconnect sanity.

The automated evidence in this document used disposable clients and servers. Publication and live deployment use the separate guarded release, cold-backup and server-update workflows.
