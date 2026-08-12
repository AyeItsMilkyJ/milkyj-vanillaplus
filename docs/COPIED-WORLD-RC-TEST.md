# Stopped-production copied-world test

Result: **NOT RUN**.

This test is deliberately deferred. Never hot-copy the running world, never point the RC server at the production path, and never run it on port `25565`.

## Required procedure

1. Announce maintenance and stop the production Minecraft server cleanly from its console.
2. Record its former JVM PID, confirm that PID no longer exists, confirm port `25565` is no longer listening, and confirm the world `session.lock` can be opened exclusively.
3. Run the guarded snapshot command with explicit paths and the stopped PID:

   ```powershell
   .\scripts\Prepare-CopiedWorldRcTest.ps1 `
     -ProductionServerRoot 'C:\EXACT\PRODUCTION\SERVER' `
     -ProductionWorldName 'world' `
     -StoppedProductionServerPid 12345 `
     -Confirm
   ```

4. Confirm the script created a timestamped `backups/pre-rc-copy-YYYYMMDD-HHMMSS.zip` under the production server and a separate copy at `build/copied-world-rc-test/server/copied_rc_world`. If either is missing, stop.
5. Restart the unchanged stable production server using its normal stable launcher and verify it is healthy before continuing.
6. Prepare a disposable RC server under `build/copied-world-rc-test/server`, set `level-name=copied_rc_world`, `server-port=25566`, and verify its resolved world path is the copied directory—not the production directory.
7. Start only that disposable RC server. Verify overworld and every mod dimension, player inventories/locations, teams, claimed and unclaimed rewards, existing completion, and new incomplete quest state against the stopped snapshot.
8. Stop the RC server cleanly, confirm all dimensions saved and the JVM exited. Retain logs and written results for approval.
9. Only after approval, delete the guarded `build/copied-world-rc-test` environment. Never delete the timestamped production backup as part of the test script.

## Mandatory pass evidence

- The real copied-player progress result must be recorded separately from the synthetic fixture.
- Previously claimed rewards remain claimed and cannot be claimed again.
- Unclaimed old rewards retain their original definition.
- Newly authored quest/reward IDs start incomplete and unclaimed.
- Inventories, player positions, teams, dimensions and world data load without loss.
- The stable production world was never opened by the RC process.

Until this process is performed from a clean stopped snapshot, the real production-progress gate remains **NOT RUN** and the candidate remains **NOT RELEASE-READY — MANUAL TESTS REQUIRED**.
