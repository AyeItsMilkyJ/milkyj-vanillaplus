# Prophet boundary for Mundane Craft replays

## Status and purpose

This is a stable read-only boundary for a future Prophet integration. Mundane Craft does not currently ship a replay recorder because the evaluated Recordium build fails the pack's loader gate. The boundary documents the inspected MCPR layout so a compatible replacement can be adopted without coupling the modpack to Prophet.

Prophet must treat every original replay and OBS recording as immutable source media. Any marker edit, timeline edit, repair, conversion or Replay Viewer session must operate on a working copy.

## Locations and formats

Paths below are relative to the Prism instance's Minecraft directory; they contain no machine-specific or account-specific prefix.

| Asset | Default inspected location/format | Boundary |
|---|---|---|
| Completed replay | `replay_recordings/*.mcpr` | Prophet may open read-only. Never replace, rename or write inside the original. |
| In-progress/raw replay data | `replay_recordings/raw/` and `replay_recordings/recording/` | Diagnostic recovery input only. Never clean automatically. |
| Replay cache | `.replay_cache/` plus `.mcpr.cache`/`.mcpr.tmp` working data | Implementation detail. Prophet must not read as authoritative media or modify it. |
| Recordium settings | `config/replaymod.json` | Player preference; Prophet must not modify it. |
| Render settings | `config/replaymod-rendersettings.json` | Player preference; Prophet must not modify it. |
| Advanced screenshot settings | `config/replaymod-screenshotsettings.json` | Player preference; Prophet must not modify it. |
| Camera timelines | `timelines.json` inside the working `.mcpr` | Prophet may read from a copied archive. It must not inject paths into the source replay. |
| Markers | `markers.json` inside `.mcpr` | Prophet may read from a copied archive. It must not edit the source replay. |
| Rendered video | User-selected output path in the render dialog | Not fixed by the pack. Prophet may read only files explicitly selected by the creator. |
| Free Camera paths | None in evaluated legacy 2.2.0 | That build has no camera-path recorder and is not shipped. |

An `.mcpr` is a ZIP-based Replay Mod/ReplayStudio container. The inspected Recordium artifact reads/writes these relevant entries:

- `metaData.json`: singleplayer flag, server name, custom server name, duration, recording date, Minecraft version, file format, format version, protocol version, generator, self entity ID and player identifiers;
- `markers.json`: marker name, replay timestamp, position, yaw, pitch and roll;
- `timelines.json`: named timelines containing paths, keyframe times/properties, segments and interpolators;
- `recording.tmcpr`: packet recording stream;
- `mods.json`: required mod IDs, names and versions when present;
- `thumb.jpg`, resource-pack entries and other replay assets when present.

The inspected writer sets MCPR file-format version 14. Prophet must inspect the values in each file rather than assuming every future recording uses version 14.

## Metadata available without launching Minecraft

Prophet may duplicate the `.mcpr` to a temporary read-only workspace, open the copy as a ZIP, and parse only known JSON entries with strict size limits. Useful matching fields are:

- filesystem creation/last-write time, recorded separately because archive timestamps are not authoritative;
- `metaData.json.date` and `duration`;
- Minecraft, protocol, MCPR format and generator versions;
- marker names/timestamps;
- player identifiers already present in the replay;
- a cryptographic hash of the original `.mcpr` computed without changing it.

`serverName` may contain a server address. Player identifiers and marker names may also be private. Prophet should keep them local, redact them from logs by default and never use a server address as a public asset ID.

Dimension transitions are represented in the packet stream rather than a simple inspected metadata field. Prophet should not claim dimensions are available without either a safe packet parser or a future companion bridge.

## Matching a replay to OBS safely

Use a local sidecar owned by Prophet, stored outside the replay archive. Recommended correlation values are:

1. SHA-256 of the immutable `.mcpr`;
2. `metaData.json.date` and `duration`;
3. OBS file creation time and duration;
4. creator-entered session label;
5. marker timestamps/names after privacy review.

Do not depend on filenames alone. Clock offsets and recording-start delays must remain explicit. The sidecar may refer to the source by hash and relative media-library ID, not by a private absolute Windows path.

## Files Prophet may read

- an original `.mcpr`, read-only, or preferably a temporary byte-for-byte copy;
- creator-selected OBS recordings and rendered shots;
- creator-exported diagnostic logs after redaction;
- Prophet-owned sidecars and future shot-plan files;
- marker/timeline/metadata JSON extracted from a working copy.

## Files Prophet must never modify directly

- original `.mcpr` and OBS source files;
- `recording.tmcpr` or any entry inside an original archive;
- `replay_recordings/raw`, `replay_recordings/recording`, `.replay_cache`, `.mcpr.tmp` or `.mcpr.cache` recovery data;
- Minecraft worlds, saves, player data or Distant Horizons databases;
- `options.txt`, keybindings, shader/resource selections or Recordium render/settings files;
- Prism account/session data, `servers.dat`, private server configuration or Packwiz runtime state.

## Future shot-plan interface

Do not put `prophet-replay-shotplan.json` inside `.mcpr`. A future bridge should consume a separate, versioned sidecar and create a disposable working replay or invoke a narrow client-side API. The eventual schema should be defined only after a compatible recorder is selected. At minimum it will need:

- schema version;
- source replay hash and expected MCPR/protocol versions;
- non-secret shot IDs;
- replay-time ranges;
- camera position/rotation or target references;
- interpolation/render intent;
- output naming hints;
- validation errors without private server values.

The bridge should expose capability discovery, read-only replay inspection, working-copy creation, shot-plan validation and explicit render execution. It must never silently edit source media or require a server-side mod.

## FFmpeg and output

Recordium's inspected render code launches an external FFmpeg executable and writes to the path selected in its render settings. Mundane Craft does not bundle FFmpeg and Prophet must not assume a fixed executable or video directory. Record the FFmpeg version and final output hash in a Prophet sidecar when rendering becomes available.
