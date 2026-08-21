#!/usr/bin/env python3
"""Strict, dependency-free validation for the MilkyCraft Vanilla+ FTB Quests guide."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import zipfile
from collections import Counter, defaultdict, deque
from datetime import datetime
from pathlib import Path


ID_RE = re.compile(r'^[0-9A-F]{16}$')
QUEST_BLOCK_RE = re.compile(r'^\t\t\{\r?\n.*?^\t\t\}', re.MULTILINE | re.DOTALL)
QUEST_ID_RE = re.compile(r'^\t\t\tid:\s*"([0-9A-F]{16})"', re.MULTILINE)
ALL_ID_RE = re.compile(r'^\s*id:\s*"([0-9A-F]{16})"', re.MULTILINE)
ITEM_RE = re.compile(r'^\s*item:\s*"([a-z0-9_.-]+:[a-z0-9_./-]+)"', re.MULTILINE)
TAG_RE = re.compile(r'^\s*tag:\s*"#?([a-z0-9_.-]+:[a-z0-9_./-]+)"', re.MULTILINE)
EXPECTED_CHAPTERS = 15
EXPECTED_QUESTS = 210
BEGINNER_FORMAT_CHAPTERS = {
    "roadmap",
    "enchanting_gear",
    "homestead_mastery",
    "create_basics",
    "create_projects",
    "dimension_campaigns",
    "companions_communities",
}


def section(block: str, name: str, next_names: tuple[str, ...]) -> str:
    alternatives = "|".join(re.escape(value) for value in next_names)
    match = re.search(
        rf'^\t\t\t{name}:\s*(.*?)(?=^\t\t\t(?:{alternatives}):|^\t\t\}})',
        block,
        re.MULTILINE | re.DOTALL,
    )
    return match.group(1) if match else ""


def load_registry_evidence(mods_dir: Path) -> tuple[set[str], set[str], set[str], list[str]]:
    item_evidence: set[str] = set()
    tags: set[str] = set()
    namespaces: set[str] = {"minecraft"}
    scanned: list[str] = []

    for jar in sorted(mods_dir.glob("*.jar")):
        scanned.append(jar.name)
        try:
            with zipfile.ZipFile(jar) as archive:
                names = archive.namelist()
                for name in names:
                    model = re.fullmatch(r'assets/([^/]+)/models/item/(.+)\.json', name)
                    if model:
                        namespaces.add(model.group(1))
                        item_evidence.add(f"{model.group(1)}:{model.group(2)}")
                    item_tag = re.fullmatch(r'data/([^/]+)/tags/items/(.+)\.json', name)
                    if item_tag:
                        namespaces.add(item_tag.group(1))
                        tags.add(f"{item_tag.group(1)}:{item_tag.group(2)}")

                # Language keys and data recipes catch dynamic items without a
                # conventional item model while still requiring jar-local proof.
                for name in names:
                    if not (
                        re.fullmatch(r'assets/[^/]+/lang/en_us\.json', name)
                        or re.fullmatch(r'data/[^/]+/recipes/.+\.json', name)
                    ):
                        continue
                    try:
                        raw = archive.read(name).decode("utf-8", "replace")
                    except (KeyError, OSError):
                        continue
                    for key in re.findall(r'"(?:item|block)\.([a-z0-9_.-]+)\.([a-z0-9_./-]+)"\s*:', raw):
                        namespaces.add(key[0])
                        item_evidence.add(f"{key[0]}:{key[1]}")
                    for value in re.findall(r'"(?:item|result)"\s*:\s*"([a-z0-9_.-]+:[a-z0-9_./-]+)"', raw):
                        item_evidence.add(value)
        except zipfile.BadZipFile:
            continue

    return item_evidence, tags, namespaces, scanned


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--quest-root", type=Path)
    parser.add_argument("--mods-dir", type=Path, required=True)
    args = parser.parse_args()

    project = args.project_root.resolve()
    quest_root = (args.quest_root or project / "payload/both/config/ftbquests/quests").resolve()
    chapter_root = quest_root / "chapters"
    errors: list[str] = []
    warnings: list[str] = []

    item_evidence, known_tags, namespaces, jars = load_registry_evidence(args.mods_dir.resolve())
    minecraft_allowlist = {
        "minecraft:beehive", "minecraft:bone_meal", "minecraft:bowl", "minecraft:bread",
        "minecraft:campfire", "minecraft:coal", "minecraft:compass", "minecraft:cooked_beef",
        "minecraft:dragon_breath", "minecraft:ender_pearl", "minecraft:experience_bottle",
        "minecraft:golden_carrot", "minecraft:honey_bottle", "minecraft:honeycomb",
        "minecraft:iron_ingot", "minecraft:item_frame", "minecraft:lead", "minecraft:torch",
        "minecraft:wheat_seeds", "minecraft:writable_book", "minecraft:lava_bucket",
        "minecraft:dragon_egg", "minecraft:anvil", "minecraft:bookshelf",
        "minecraft:enchanted_book", "minecraft:enchanting_table", "minecraft:lapis_lazuli",
    }

    quest_ids: list[str] = []
    task_ids: list[str] = []
    reward_ids: list[str] = []
    dependencies: dict[str, list[str]] = {}
    item_references: set[str] = set()
    tag_references: set[str] = set()
    chapter_results: list[dict[str, object]] = []
    create_format_failures: list[str] = []

    chapter_files = sorted(chapter_root.glob("*.snbt"))
    if len(chapter_files) != EXPECTED_CHAPTERS:
        errors.append(f"expected {EXPECTED_CHAPTERS} chapter files, found {len(chapter_files)}")

    for chapter_file in chapter_files:
        text = chapter_file.read_text(encoding="utf-8")
        title_match = re.search(r'^\ttitle:\s*"((?:\\.|[^"])*)"', text, re.MULTILINE)
        icon_match = re.search(r'^\ticon:\s*"([a-z0-9_.-]+:[a-z0-9_./-]+)"', text, re.MULTILINE)
        chapter_id_match = re.search(r'^\tid:\s*"([0-9A-F]{16})"', text, re.MULTILINE)
        blocks = QUEST_BLOCK_RE.findall(text)
        if not title_match:
            errors.append(f"{chapter_file.name}: missing chapter title")
        if not icon_match:
            errors.append(f"{chapter_file.name}: missing or invalid chapter icon")
        else:
            item_references.add(icon_match.group(1))
        if not chapter_id_match:
            errors.append(f"{chapter_file.name}: missing chapter ID")
        if not blocks:
            errors.append(f"{chapter_file.name}: empty chapter")

        for block in blocks:
            quest_id_match = QUEST_ID_RE.search(block)
            title = re.search(r'^\t\t\ttitle:\s*"((?:\\.|[^"])*)"', block, re.MULTILINE)
            description = section(block, "description", ("dependencies", "id", "rewards", "subtitle", "tasks", "title"))
            task_area = section(block, "tasks", ("title", "x", "y"))
            reward_area = section(block, "rewards", ("subtitle", "tasks", "title"))
            if not quest_id_match:
                errors.append(f"{chapter_file.name}: quest without ID")
                continue
            quest_id = quest_id_match.group(1)
            quest_ids.append(quest_id)
            if not title:
                errors.append(f"{chapter_file.name}/{quest_id}: missing title")
            if not description.strip():
                errors.append(f"{chapter_file.name}/{quest_id}: missing description")
            if not task_area.strip():
                errors.append(f"{chapter_file.name}/{quest_id}: missing task")

            dep_match = re.search(r'^\t\t\tdependencies:\s*\[([^\]]*)\]', block, re.MULTILINE)
            dependencies[quest_id] = re.findall(r'"([0-9A-F]{16})"', dep_match.group(1)) if dep_match else []
            task_ids.extend(ALL_ID_RE.findall(task_area))
            reward_ids.extend(ALL_ID_RE.findall(reward_area))
            item_references.update(ITEM_RE.findall(block))
            tag_references.update(TAG_RE.findall(block))

            if chapter_file.stem in BEGINNER_FORMAT_CHAPTERS:
                required = ("WHAT IS THIS?", "DO THIS:", "WHY DO I CARE?", "COMMON FUCK-UP:")
                if not all(label in description for label in required):
                    create_format_failures.append(quest_id)

        chapter_results.append(
            {
                "file": chapter_file.name,
                "title": title_match.group(1) if title_match else None,
                "icon": icon_match.group(1) if icon_match else None,
                "questCount": len(blocks),
            }
        )

    for label, values in (("quest", quest_ids), ("task", task_ids), ("reward", reward_ids)):
        duplicates = sorted(value for value, count in Counter(values).items() if count > 1)
        if duplicates:
            errors.append(f"duplicate {label} IDs: {', '.join(duplicates)}")
        invalid = sorted(value for value in values if not ID_RE.fullmatch(value) or value[0] in "89ABCDEF")
        if invalid:
            errors.append(f"invalid signed {label} IDs: {', '.join(invalid)}")

    quest_set = set(quest_ids)
    missing_dependencies = sorted({dep for deps in dependencies.values() for dep in deps if dep not in quest_set})
    if missing_dependencies:
        errors.append(f"missing dependencies: {', '.join(missing_dependencies)}")

    indegree = {quest: 0 for quest in quest_ids}
    dependents: dict[str, list[str]] = defaultdict(list)
    for quest, deps in dependencies.items():
        for dep in deps:
            if dep in quest_set:
                indegree[quest] += 1
                dependents[dep].append(quest)
    root_quest_ids = sorted(quest for quest, degree in indegree.items() if degree == 0)
    if len(root_quest_ids) != 1:
        errors.append(f"expected one connected quest root, found {len(root_quest_ids)}: {', '.join(root_quest_ids)}")

    root_reachable: set[str] = set()
    if len(root_quest_ids) == 1:
        reachability_queue = deque(root_quest_ids)
        while reachability_queue:
            quest = reachability_queue.popleft()
            if quest in root_reachable:
                continue
            root_reachable.add(quest)
            reachability_queue.extend(dependents[quest])
        disconnected = sorted(quest_set - root_reachable)
        if disconnected:
            errors.append(f"quests disconnected from the guide root: {', '.join(disconnected)}")

    queue = deque(root_quest_ids)
    visited: set[str] = set()
    while queue:
        quest = queue.popleft()
        if quest in visited:
            continue
        visited.add(quest)
        for child in dependents[quest]:
            indegree[child] -= 1
            if indegree[child] == 0:
                queue.append(child)
    graph_failures = sorted(quest_set - visited)
    if graph_failures:
        errors.append(f"cyclic or unreachable quests: {', '.join(graph_failures)}")

    if len(quest_ids) != EXPECTED_QUESTS:
        errors.append(f"expected {EXPECTED_QUESTS} quests, found {len(quest_ids)}")
    if create_format_failures:
        errors.append(f"beginner-format quests missing required sections: {', '.join(create_format_failures)}")

    unresolved_items: list[str] = []
    for item in sorted(item_references):
        namespace = item.split(":", 1)[0]
        if namespace == "minecraft":
            if item not in minecraft_allowlist:
                unresolved_items.append(item)
        elif namespace not in namespaces or item not in item_evidence:
            unresolved_items.append(item)
    if unresolved_items:
        errors.append(f"unresolved item/icon IDs: {', '.join(unresolved_items)}")

    unresolved_tags = sorted(tag for tag in tag_references if tag not in known_tags)
    if unresolved_tags:
        errors.append(f"unresolved item tags: {', '.join(unresolved_tags)}")

    ledger = project / "audit/quests.csv"
    ledger_rows = list(csv.DictReader(ledger.open(encoding="utf-8-sig", newline=""))) if ledger.exists() else []
    if len(ledger_rows) != len(quest_ids):
        errors.append(f"audit/quests.csv has {len(ledger_rows)} rows; expected {len(quest_ids)}")
    if set(row.get("quest_id", "") for row in ledger_rows) != quest_set:
        errors.append("audit/quests.csv quest IDs do not match generated definitions")

    result = {
        "validatedAt": datetime.now().astimezone().isoformat(),
        "questRoot": quest_root.relative_to(project).as_posix() if quest_root.is_relative_to(project) else "<external quest root>",
        "modsDirectory": args.mods_dir.resolve().relative_to(project).as_posix() if args.mods_dir.resolve().is_relative_to(project) else "<external mods directory>",
        "jarCountScanned": len(jars),
        "chapterCount": len(chapter_files),
        "questCount": len(quest_ids),
        "taskIdCount": len(task_ids),
        "rewardIdCount": len(reward_ids),
        "uniqueQuestIds": len(set(quest_ids)),
        "uniqueTaskIds": len(set(task_ids)),
        "uniqueRewardIds": len(set(reward_ids)),
        "rootQuestIds": root_quest_ids,
        "rootReachableQuests": len(root_reachable),
        "graphVisitedQuests": len(visited),
        "referencedItemAndIconIds": len(item_references),
        "unresolvedItems": unresolved_items,
        "referencedTags": sorted(tag_references),
        "unresolvedTags": unresolved_tags,
        "createBeginnerFormatFailures": create_format_failures,
        "chapters": chapter_results,
        "warnings": warnings,
        "errors": errors,
    }
    report_path = project / "audit/questbook-validation-detailed.json"
    report_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
