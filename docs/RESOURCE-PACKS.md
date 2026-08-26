# MilkyCraft Vanilla+ resource-pack stack

Packwiz downloads the pack's resource-pack choices but deliberately leaves the player's selection and order in `options.txt` alone. This prevents updates from resetting a preferred look. A new player therefore chooses a stack once in **Options -> Resource Packs**.

## Recommended order

Place these from **top (highest priority)** to **bottom (lowest priority)** in Minecraft's Selected column:

1. **MilkyJ Stability Fixes** — always keep at the top; it repairs exact missing assets and does not replace the pack's general art.
2. **Fresh Compats** — compatibility layer for Fresh Animations.
3. **Fresh Animations** — entity animation layer.
4. **Shable's Tweaks** — optional vanilla-style detail layer.
5. Choose **one** principal art pack:
   - **Faithful 32x** for a sharper Minecraft look and moderate GPU/VRAM cost.
   - **Bare Bones** for a clean, colourful and lighter look.
   - **FPBR** for the richest/highest-cost material look; use a compatible shader and disable it first when diagnosing visual artefacts.
6. Leave Minecraft and mod-provided built-in packs below these unless a mod explicitly says otherwise.

Do not stack Faithful, Bare Bones and FPBR together. They compete for the same base textures, waste memory, and make visual faults difficult to diagnose.

## Safe troubleshooting

If the sky is black, mirrored, flashing or smeared, first disable the shader while leaving resource packs enabled. If the fault stops, select a known-good shader rather than rearranging every resource pack. If it remains with shaders off, test this minimal stack:

1. MilkyJ Stability Fixes
2. Fresh Compats
3. Fresh Animations

Then add Shable's Tweaks and one principal art pack back one at a time. Resource packs do not belong on the dedicated server and no server restart is needed for this client-side test.

The updater never manages shader archives or shader selection. That separation prevents a pack update from silently enabling an expensive shader on a low-end computer.
