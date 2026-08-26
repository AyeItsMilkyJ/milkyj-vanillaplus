# MilkyCraft Vanilla+ 1.9.0-rc3

This Forge 1.20.1 release candidate is a safety, controls and distribution refinement over RC2. Existing players keep the same Prism instance and receive it through the established Packwiz pre-launch update.

## Changes

- Adds a 24-binding, optional recommended control profile with exact backup, custom-binding preservation, atomic writes, idempotent application and one-click restore.
- Assigns memorable quest, team, map, storage and shader keys while separating genuine `R`, `B`, `Z`, `G`, `U`, `V`, `T`, Left Alt and Right Bracket conflicts.
- Leaves intentional GUI, held-tool, tooltip and mutually exclusive vehicle overlaps intact.
- Leaves Fetzi's Displays' three unreliable optional shortcuts unbound; its available 1.1.1 build retains the same late-registration defect, so no unproven mod update was made.
- Correctly classifies eleven player-facing visual/input configs as client-only and preserves each player's existing copy after first install.
- Keeps Embeddium's fingerprint and mixin compatibility pins managed, and leaves the unowned `dynamiclights.json` untouched rather than guessing.
- Adds a tested resource-pack priority guide and updates the mate-distribution builder to discover the current Packwiz instance instead of relying on a legacy instance name.
- Redacts obsolete private LAN/path details from current documentation. The privacy gate now scans current files and every reachable Git blob, reports 13 reviewed legacy metadata blobs separately, and fails on any new occurrence.
- Makes active bootstrap, local-test and LAN-test artifact names version-driven under the public MilkyCraft name.
- Hardens the installer gate with the real RC2-to-RC3 both-to-client settings migration and a post-reload command barrier before shutdown.

No Minecraft, Forge or mod version changed. No quest, reward, world, save, shader selection, resource-pack selection or gameplay configuration changed.

## Automated validation

- Packwiz manifest/hash/side/privacy gate passes.
- Clean client and server resolve to 240 and 206 JARs respectively.
- The disposable Forge server reaches `Done`, reloads the final-priority compatibility datapack, saves all loaded dimensions and exits 0.
- The 11 reclassified preference files retain customised client bytes and are removed as obsolete from an existing server update; the five control files never enter the server payload.
- All 15 chapters and 210 quests parse with a single connected graph and valid item IDs.
- The control-profile test proves untouched defaults change, customised keys and unrelated settings remain byte-stable, the second run is idempotent, and restore is byte-exact.
- The server supervisor suite passes start, status, duplicate/update refusal, scheduled restart, crash recovery, backup verification, rollback preparation, Discord lifecycle and production-path/port protection.

## Still manual

A signed-in client must still launch RC3, open Controlling's conflict view, enter a world and exercise the mapped gameplay contexts. Shader and resource-pack appearance remains GPU- and selection-dependent and cannot be declared universal from a headless test.
