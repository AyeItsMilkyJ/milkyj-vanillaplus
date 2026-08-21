# 1.9.0-rc2 two-client LAN test

Overall result: **NOT RUN — MANUAL INTERACTION REQUIRED**.

This harness is disposable and LAN-only. It uses Packwiz HTTP port `8765`, Minecraft port `25566`, and the world `build/rc-lan-test/server/rc_lan_test_world`. It refuses production port `25565`, makes no firewall/router changes, and does not copy production whitelist, ops, playerdata, world data, or credentials.

## Start and stop

From the project root, run:

```powershell
.\scripts\Start-RcLanTest.ps1
```

The command prints the exact LAN Packwiz URL and Minecraft address, starts the disposable server, and creates:

`dist/MilkyJ-VanillaPlus-1.9.0-rc2-LAN-TEST-Prism.zip`

When the interaction checks are finished, stop only the disposable processes with:

```powershell
.\scripts\Stop-RcLanTest.ps1
```

Keep `build/rc-lan-test/logs` and `stop-result.json` as test evidence. Do not use the production server for this test.

## Required two-player checks

Every result below remains **NOT RUN** until two people perform and record it.

1. **NOT RUN** — On both PCs, create fresh disposable Prism test application roots and import the LAN-test ZIP. Do not reuse the working player instance.
2. **NOT RUN** — Launch both imported instances and confirm Packwiz downloads the candidate from the exact LAN URL printed by the start script.
3. **NOT RUN** — Connect both authenticated clients to the printed disposable address on port `25566`.
4. **NOT RUN** — Open FTB Quests on both clients; confirm all 14 chapters and 200 quests are visible, readable, and free of broken characters.
5. **NOT RUN** — Complete one manual checkmark quest and confirm it completes only after the click.
6. **NOT RUN** — Complete one inexpensive automatic item-detection quest and confirm holding the correct item is detected.
7. **NOT RUN** — Claim one reward and confirm the received item/XP matches the displayed reward.
8. **NOT RUN** — Reopen the same reward and confirm it cannot be claimed a second time.
9. **NOT RUN** — Reopen completed quests and confirm their full descriptions remain readable.
10. **NOT RUN** — Before joining a team, make different quest progress on each client and confirm it remains separate.
11. **NOT RUN** — Join both players to the same deliberately created FTB Team, complete a new quest, and confirm that new progress shares as expected.
12. **NOT RUN** — Leave a third test player, or one of the two after a clean reset, outside that team and confirm progress stays separate.
13. **NOT RUN** — Confirm neither login automatically forces a player into a global server team.
14. **NOT RUN** — Inspect every chapter page for overlapping quest icons, unreadable dependency lines, or unreachable required quests.
15. **NOT RUN** — Search visible titles/descriptions for Tinkers' Construct, Botany Pots/Trees, Fossils Revival, Prehistoric Fauna, and KubeJS; confirm no visible quest tells players to craft or find absent content.
16. **NOT RUN** — Inspect the roadmap, Homestead Mastery, Create Projects, Expedition Campaigns and Companions chapters; confirm their branch lines stem from the intended lesson and do not overlap icons.
17. **NOT RUN** — Verify one Create Ponder/JEI lesson, one Productive Bees lesson and one dimension-campaign lesson against the actual installed UI before marking the wording approved.

Do not mark this candidate release-ready from automated startup alone. Attach screenshots or short notes for every completed line and retain the disposable logs.
