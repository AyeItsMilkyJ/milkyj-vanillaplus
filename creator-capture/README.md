# Creator Capture candidate quarantine

This directory is a fail-closed registry for creator-side candidates evaluated for MilkyCraft Vanilla+. It contains no mod JARs, no Packwiz metafiles and no installer. Both currently evaluated candidates are ineligible, so ordinary players and the dedicated server receive no creator tooling.

`candidate-registry.json` pins authoritative project/file identifiers, hashes, inspected source commits, actual legacy features and observed compatibility failures. Run `python scripts/validate_creator_capture.py . --artifact-dir <temporary-download-directory>` to re-check locally downloaded candidate hashes and confirm that no rejected candidate leaked into production Packwiz metadata.

Do not change a candidate to eligible from metadata inspection alone. A replacement build must pass the client, multiplayer, replay, Create, Distant Horizons, shader, dimension, long-session and rendering gates in `docs/CREATOR-CAPTURE.md` using disposable installations. Only then may the pack owner add a normal client-only Packwiz metafile with `optional = true` and `default = false`.
