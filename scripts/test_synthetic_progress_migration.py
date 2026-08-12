#!/usr/bin/env python3
"""Exercise logical ID-based progress migration without touching real player data."""

from __future__ import annotations

import csv
import json
import re
import sys
from datetime import datetime
from pathlib import Path


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]).resolve()
    fixture = json.loads((root / "tests/fixtures/synthetic-progress-baseline.json").read_text(encoding="utf-8"))
    rows = list(csv.DictReader((root / "audit/quest-id-migration.csv").open(encoding="utf-8-sig", newline="")))
    by_key = {(row["id_type"], row["id"]): row for row in rows}
    checks: list[dict[str, object]] = []

    def check(name: str, passed: bool, evidence: str) -> None:
        checks.append({"name": name, "status": "PASS" if passed else "FAIL", "evidence": evidence})

    for quest_id in fixture["completedQuests"]:
        row = by_key.get(("quest", quest_id), {})
        check("baseline quest completion preserved", row.get("status") == "unchanged", quest_id)
    for task_id in fixture["completedTasks"]:
        row = by_key.get(("task", task_id), {})
        check("baseline task completion preserved", row.get("status") == "unchanged", task_id)
    for reward_id in fixture["claimedRewards"]:
        row = by_key.get(("reward", reward_id), {})
        check("claimed baseline reward remains the same claimed definition", row.get("status") == "unchanged", reward_id)
    for reward_id in fixture["unclaimedRewards"]:
        row = by_key.get(("reward", reward_id), {})
        check("unclaimed baseline reward retains its original definition", row.get("status") == "unchanged", reward_id)

    new_quests = [row for row in rows if row["id_type"] == "quest" and row["status"] == "new"]
    new_rewards = [row for row in rows if row["id_type"] == "reward" and row["status"] == "new"]
    known_progress = set(fixture["completedQuests"] + fixture["claimedRewards"] + fixture["unclaimedRewards"])
    check("new quest starts incomplete", bool(new_quests) and all(row["id"] not in known_progress for row in new_quests), f"{len(new_quests)} new quest IDs")
    check("new reward starts unclaimed", bool(new_rewards) and all(row["id"] not in known_progress for row in new_rewards), f"{len(new_rewards)} new reward IDs")
    team = fixture.get("team", {})
    check("synthetic team progress representation retained", bool(team.get("teamId")) and len(team.get("members", [])) == 2, "logical team-scoped fixture")
    repurposed = [row for row in rows if row["status"] == "repurposed"]
    check("no baseline ID is repurposed", not repurposed, f"{len(repurposed)} repurposed IDs")

    passed = all(item["status"] == "PASS" for item in checks)
    result = {
        "testedAt": datetime.now().astimezone().isoformat(),
        "syntheticMigrationResult": "PASS" if passed else "FAIL",
        "fixture": "tests/fixtures/synthetic-progress-baseline.json",
        "fixtureScope": "Synthetic logical ID/team compatibility model; not a production FTB Quests file-format fixture.",
        "checks": checks,
        "realProductionFixtureResult": "NOT RUN",
        "realProductionFixtureReason": "The unavailable 99-ID fixture was not found in safe repository test data, and the live world/playerdata was intentionally not accessed or hot-copied.",
        "remainingManualGate": "Test a clean snapshot taken only after the production server is stopped.",
    }
    (root / "audit/synthetic-progress-migration.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
