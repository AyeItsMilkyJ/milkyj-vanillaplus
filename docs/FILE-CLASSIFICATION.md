# File and side classification

The authoritative machine-readable reports are:

- `audit/mods.csv` — every mod JAR, exact SHA-512, source URL, side, and confidence.
- `audit/managed-files.csv` — every managed config/defaultconfig/datapack/resource-pack payload and side.
- `audit/excluded-files.csv` — files deliberately left unmanaged because they are personal/generated, conflicting, stale, or uncertain.
- `audit/summary.json` — counts and platform versions.

## Summary

| Class | Mod JARs |
|---|---:|
| Both client and server | 201 |
| Client only | 35 |
| Dedicated server only | 2 |
| Total unique JARs | 238 |

Side classification is based on actual presence and exact hashes in the working Prism instance and dedicated server. No client/server shared filename had a hash mismatch.

All 201 shared JARs are enumerated in `audit/mods.csv`. The shorter exceptional lists follow.

## Client-only mods

- `AdvancementPlaques-1.20.1-forge-1.6.9.jar`
- `AmbientSounds_FORGE_v6.3.8_mc1.20.1.jar`
- `appleskin-forge-mc1.20.1-2.5.1.jar`
- `BetterAdvancements-Forge-1.20.1-0.4.2.60.jar`
- `BetterF3-7.0.2-Forge-1.20.1.jar`
- `BetterThirdPerson-Forge-1.20-1.9.0.jar`
- `chat_heads-0.15.6-forge-1.20.jar`
- `Controlling-forge-1.20.1-12.0.2.jar`
- `cwb-forge-3.0.0+mc1.20.jar`
- `eatinganimation-1.20.1-5.1.0.jar`
- `embeddium-0.3.31+mc1.20.1.jar`
- `EnchantmentDescriptions-Forge-1.20.1-17.1.21.jar`
- `entity_model_features-3.2.4-1.20.1-forge.jar`
- `entity_texture_features_1.20.1-forge-7.1.jar`
- `entityculling-forge-1.10.5-mc1.20.1.jar`
- `EquipmentCompare-1.20.1-forge-1.3.7.jar`
- `fallingleaves-1.20.1-2.1.2.jar`
- `ImmediatelyFast-Forge-1.5.5+1.20.4.jar`
- `JustEnoughProfessions-forge-1.20.1-3.0.1.jar`
- `JustEnoughResources-1.20.1-1.4.0.247.jar`
- `justzoom_forge_2.1.1_MC_1.20.1.jar`
- `make_bubbles_pop-0.3.0-forge-mc1.19.4-1.20.4.jar`
- `MouseTweaks-forge-mc1.20.1-2.25.1.jar`
- `notenoughanimations-forge-1.12.4-mc1.20.1.jar`
- `oculus-mc1.20.1-1.8.0.jar`
- `particlerain-4.0.0-beta.10+1.20.1-forge.jar`
- `PickUpNotifier-v8.0.0-1.20.1-Forge.jar`
- `Presence Footsteps [FORGE] 1.0.0.jar`
- `Searchables-forge-1.20.1-1.0.3.jar`
- `shulkerboxtooltip-forge-4.0.4+1.20.1.jar`
- `skinlayers3d-forge-1.11.2-mc1.20.1.jar`
- `statisticsplus-1.0.0.jar`
- `TravelersTitles-1.20-Forge-4.0.2.jar`
- `xaerominimap-forge-1.20.1-26.4.2.jar`
- `xaeroworldmap-forge-1.20.1-1.44.2.jar`

## Dedicated-server-only mods

- `alternate_current-mc1.20-1.7.0.jar`
- `Chunky-1.3.146.jar`

## Non-mod files

The Packwiz index contains 687 unique destinations in total:

| Destination category | Entries |
|---|---:|
| Mods | 238 |
| Config | 407 |
| Default configs | 7 |
| Moonlight global datapacks | 2 |
| Resource packs | 33 |

Across all 684 destinations, 507 are `both`, 162 are `client`, and 15 are `server`. Internal files are represented by side-aware `.pw.toml` metadata and repository-hosted payloads, rather than unconditionally copied internal files. The count reflects the 9-chapter repaired guide plus removal of the two generated private/cache files; no mod JAR was removed.

The migration left 38 observed files unmanaged. These are itemised in `audit/excluded-files.csv`; they include JEI bookmarks/history, renderer/Distant Horizons/Oculus/shader choices, generated Chunky state, sound settings, stale Bumblezone/Connector/Continuity configs, and config conflicts for which no safe canonical value was inferred.

## Confidence and unresolved classification

No installed mod JAR remains unclassified: every exact JAR was observed on one or both working sides and has a verified upstream download hash. This is a preservation classification, not a claim that every shared utility technically requires installation on both sides.

The uncertain items are non-JAR config remnants, not mods. They are intentionally excluded and left untouched. Shader packs are also intentionally outside Packwiz management so broken/experimental shaders and personal shader settings cannot be forced back onto clients.
