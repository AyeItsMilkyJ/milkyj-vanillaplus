# MilkyCraft Vanilla+ controls

MilkyCraft ships an optional, reversible control profile for its busiest keys. It does **not** put `options.txt` under Packwiz management and does not run during launch. Existing players keep every personal control unless they explicitly run the profile; even then, the patcher changes only bindings that still equal the pack's known defaults.

## Apply or undo the profile

1. Launch the pack once, then close Minecraft completely.
2. Open the instance's `minecraft\scripts\milkycraft-controls` folder.
3. Run `APPLY RECOMMENDED CONTROLS.bat`.

The patcher creates an exact timestamped copy in `minecraft\milkycraft-control-backups` before writing. It skips a binding when the player has already customised it. `RESTORE PREVIOUS CONTROLS.bat` restores the latest complete pre-profile file; use restore before making many newer settings changes because it restores the whole earlier `options.txt`.

New and existing players receive these tools through the normal Packwiz update. They are deliberately not a Prism pre-launch command: automatically rewriting player controls would violate the pack's settings-preservation policy.

## Recommended layout

| Key | Action |
| --- | --- |
| `J` / `Ctrl+J` | Quest book / teams |
| `B` / `Ctrl+B` | Backpack / new waypoint |
| `N` | Wireless storage terminal |
| `Z` | Zoom |
| `Ctrl+Z` | Slow Astikor cart (and Structure Gel undo while holding its building tool) |
| `M` / `Ctrl+M` / `Alt+M` | World map / enlarge minimap / map settings |
| `R` / `U` | JEI recipe / uses |
| `Ctrl+U` | Corpse death history |
| `F6` / `F7` / `F8` | Reload shaders / shader menu / toggle shaders |
| `I` / `Alt+I` / `Ctrl+I` | Aether accessories / Curios / Relics ability selector |
| `G` / `Ctrl+G` | Active ability / villager guide |
| `V` / `Alt+V` / `Ctrl+V` | Quiver / Aether invisibility / Deeper and Darker transmit |
| `Alt+B` / `Shift+B` | Aircraft boost / Deeper and Darker boost |
| `Alt+T` | Toggle TrashSlot |

The full machine-readable mapping and its reasons are in `recommended-controls.json` beside the patcher.

## Deliberate overlaps left alone

Controlling may still colour some bindings red. These are intentional context-only groups rather than competing global actions:

- JEI's `A`, `R`, `U`, `W`, Shift/Ctrl and mouse actions operate while hovering recipes or inventory slots.
- Create, Steam 'n' Rails and Copycats share Left Alt as a held-tool modifier.
- Sneak, Carry On, equipment comparison and Jade details share Left Shift only in their relevant contexts.
- Vehicle `R` actions apply only while mounted; JEI recipe applies in its screen.
- `Ctrl+Z` is cart braking while mounted and Structure Gel undo only while holding its building tool.
- Crafting Tweaks uses `K` and `Tab` inside crafting screens.
- Aether's gravitite jump ability shares Space only when equipped.

Quark's Variant Selector is unbound because the feature is disabled by the shipped Quark configuration. Fetzi's Displays 1.1.0 registers three optional mappings after Architectury's registration event; the current upstream 1.1.1 code retains that lifecycle defect. The profile leaves those unreliable mappings unbound rather than pretending a rebind repairs the mod.

For later personal changes, use **Options -> Controls -> Key Binds** and Controlling's search/conflict filters. Avoid assigning a global action to `R`, `B`, `Z`, `G`, `U`, `V`, `T`, Left Alt or Right Bracket without checking the existing group first.

## Validation

`scripts\Test-RecommendedControls.ps1` tests the patcher against a disposable CRLF `options.txt`. It proves:

- all untouched defaults receive the profile;
- a pre-customised binding is preserved;
- unrelated video, resource-pack, sound and ordinary control lines remain byte-stable;
- the backup is byte-identical;
- a second run is idempotent;
- restore recreates the original options file exactly.

This test cannot replace opening the current client and trying each gameplay context. It validates safe file handling and the static binding layout; the remaining manual check is a normal RC3 client session using Controlling's conflict screen.
