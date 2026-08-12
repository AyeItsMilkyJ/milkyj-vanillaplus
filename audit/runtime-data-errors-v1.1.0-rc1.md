# Runtime data errors observed in the v1.1.0-rc1 disposable server

Observed during the clean disposable Forge 47.4.10 launch on 12 August 2026. The server still reached `Done`, FTB Quests loaded 10 chapters and 120 quests, and all seven loaded dimensions saved during shutdown.

These are pre-existing pack/mod data issues. The quest-only release candidate does not update the owning mods or silently change their recipes, and no quest references the invalid IDs below.

| Kind | Owning data ID | Exact problem | Quest impact |
|---|---|---|---|
| Recipe | `create_central_kitchen:sequenced_assembly/vegan_hamburger` | References absent `miners_delight:vegan_patty` | None; no quest requires this recipe |
| Recipe | `aether:wood_zanite_vanilla_shield` | Malformed ingredient/result data: missing expected string type | None |
| Recipe | `aether:skyroot_zanite_vanilla_shield` | Malformed ingredient/result data: missing expected string type | None |
| Advancement | `beautify:progression/candelabra` | References unknown `beautify:lamp_candleabra` | None; no quest uses this advancement or item |
| Global loot modifier | `domesticationinnovation:blazing_enchanted_book` | Null/non-object data followed by invalid `minecraft:alternatives` condition | None |
| Global loot modifier | `nethersdelight:chopping_leather` | Unknown condition type `minecraft:alternatives` | None |
| Global loot modifier | `nethersdelight:chopping_string` | Unknown condition type `minecraft:alternative` | None |

The same startup also reports that Curios slot `talisman` is unregistered. That is not an invalid recipe/item reference, but it remains a separate pre-existing integration warning worth testing before a future unrelated compatibility release.
