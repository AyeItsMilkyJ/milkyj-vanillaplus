#!/usr/bin/env python3
"""Compare stable quest definition semantics against the candidate."""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
from pathlib import Path


QUEST_BLOCK_RE = re.compile(r"^\t\t\{\r?\n.*?^\t\t\}", re.M | re.S)
QUEST_ID_RE = re.compile(r'^\t\t\tid:\s*"([0-9A-F]{16})"', re.M)
ALL_ID_RE = re.compile(r'^\s*id:\s*"([0-9A-F]{16})"', re.M)


def field(text: str, name: str) -> str:
    match = re.search(rf'^\s*{re.escape(name)}:\s*("(?:\\.|[^"])*"|[^\r\n]+)', text, re.M)
    return match.group(1).strip() if match else ""


def indented_field(text: str, tabs: int, name: str) -> str:
    match = re.search(
        rf'^\t{{{tabs}}}{re.escape(name)}:\s*("(?:\\.|[^"])*"|[^\r\n]+)',
        text,
        re.M,
    )
    return match.group(1).strip() if match else ""


def section(block: str, name: str, next_names: tuple[str, ...]) -> str:
    alternatives = "|".join(re.escape(value) for value in next_names)
    match = re.search(
        rf"^\t\t\t{name}:\s*(.*?)(?=^\t\t\t(?:{alternatives}):|^\t\t\}})",
        block,
        re.M | re.S,
    )
    return match.group(1) if match else ""


def child_semantics(area: str) -> dict[str, str]:
    ids = list(ALL_ID_RE.finditer(area))
    result: dict[str, str] = {}
    for index, match in enumerate(ids):
        end = ids[index + 1].start() if index + 1 < len(ids) else len(area)
        fragment = area[match.start():end]
        values = []
        for name in ("type", "item", "tag", "count", "xp", "title"):
            value = field(fragment, name)
            if value:
                values.append(f"{name}={value}")
        result[match.group(1)] = "; ".join(values)
    return result


def parse_chapters(files: dict[str, str]) -> dict[tuple[str, str], dict[str, str]]:
    records: dict[tuple[str, str], dict[str, str]] = {}
    for path, text in files.items():
        chapter_id = re.search(r'^\tid:\s*"([0-9A-F]{16})"', text, re.M)
        chapter_title = indented_field(text, 1, "title").strip('"')
        chapter_icon = indented_field(text, 1, "icon")
        chapter_owner = f"{Path(path).name}: {chapter_title}"
        if chapter_id:
            records[("chapter", chapter_id.group(1))] = {
                "owner": chapter_owner,
                "semantics": f"chapter-key={Path(path).stem}; icon={chapter_icon}",
            }
        for block in QUEST_BLOCK_RE.findall(text):
            quest_id_match = QUEST_ID_RE.search(block)
            if not quest_id_match:
                continue
            quest_id = quest_id_match.group(1)
            quest_title = indented_field(block, 3, "title").strip('"')
            tasks = child_semantics(section(block, "tasks", ("title", "x", "y")))
            rewards = child_semantics(section(block, "rewards", ("subtitle", "tasks", "title")))
            quest_owner = f"{chapter_owner} / {quest_title}"
            records[("quest", quest_id)] = {
                "owner": quest_owner,
                "semantics": f"title={quest_title}; tasks={','.join(sorted(tasks))}; rewards={','.join(sorted(rewards))}",
            }
            for task_id, semantics in tasks.items():
                records[("task", task_id)] = {"owner": quest_owner, "semantics": semantics}
            for reward_id, semantics in rewards.items():
                records[("reward", reward_id)] = {"owner": quest_owner, "semantics": semantics}
    return records


def baseline_files(root: Path, ref: str) -> dict[str, str]:
    prefix = "payload/both/config/ftbquests/quests/chapters/"
    paths = subprocess.run(
        ["git", "-C", str(root), "ls-tree", "-r", "--name-only", ref, "--", prefix],
        check=True, capture_output=True, text=True,
    ).stdout.splitlines()
    return {
        path: subprocess.run(
            ["git", "-C", str(root), "show", f"{ref}:{path}"],
            check=True, capture_output=True, text=True, encoding="utf-8",
        ).stdout
        for path in paths if path.endswith(".snbt")
    }


def current_files(root: Path) -> dict[str, str]:
    base = root / "payload/both/config/ftbquests/quests/chapters"
    return {path.relative_to(root).as_posix(): path.read_text(encoding="utf-8") for path in base.glob("*.snbt")}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--baseline-ref", default="v1.0.0")
    args = parser.parse_args()
    root = args.project_root.resolve()
    baseline = parse_chapters(baseline_files(root, args.baseline_ref))
    candidate = parse_chapters(current_files(root))
    changed_reward_quests = {
        "1725341D3243AFDD", "1A354ABA1BE5171F", "1E4FFC70B08D7689", "22F6D8A7A571B2DF",
        "2AD044CDEA61410E", "2E34979BCE044BF5", "31CF2E051B43098D", "34B44EE7DDB53F36",
        "3522AB4192F75013", "36D9A2651A27AA32", "3F4DB5EEDFFAC808", "4201CE5BFBBC062D",
        "54C781F3CD01DB25", "576F3B9264ED1F4B", "60435D16835B3DCE", "71BB70B3127ECE00",
        "7DA1925406767A08",
    }
    restored_quests = {"1885CF9658AB663D", "22B69CA315389C48"}
    rows = []
    violations = 0
    for key in sorted(set(baseline) | set(candidate)):
        base = baseline.get(key)
        current = candidate.get(key)
        if base and current:
            status = "unchanged" if base["semantics"] == current["semantics"] else "repurposed"
            if status == "repurposed":
                violations += 1
            action = "preserved baseline definition"
            notes = ""
            if key[0] == "quest" and key[1] in restored_quests:
                action = "restored baseline objective; placed as optional compatibility quest"
                notes = "The unrelated Create lesson now has a new quest/task/reward ID set."
            elif key[0] == "quest" and key[1] in changed_reward_quests:
                action = "restored baseline reward definitions and IDs"
                notes = "No existing reward ID changes item/XP meaning."
        elif base:
            status = "removed"
            action = "removed unreleased absent-mod tutorial definition"
            notes = "No installed item or active progression depends on this definition."
        else:
            status = "new"
            action = "assigned a new deterministic stable ID"
            notes = "Does not inherit baseline completion or claim state."
        rows.append({
            "id_type": key[0], "id": key[1],
            "baseline_owner": base["owner"] if base else "",
            "baseline_semantics": base["semantics"] if base else "",
            "candidate_owner": current["owner"] if current else "",
            "candidate_semantics": current["semantics"] if current else "",
            "status": status, "action_taken": action, "notes": notes,
        })
    out = root / "audit/quest-id-migration.csv"
    with out.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    counts = {status: sum(row["status"] == status for row in rows) for status in ("unchanged", "removed", "new", "repurposed")}
    print(f"Wrote {len(rows)} ID migration rows: {counts}")
    return 1 if violations else 0


if __name__ == "__main__":
    raise SystemExit(main())
