#!/usr/bin/env python3
"""Fail when publishable text is not UTF-8 or contains known mojibake."""

from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path


TEXT_SUFFIXES = {
    ".snbt", ".toml", ".md", ".csv", ".json", ".ps1", ".bat", ".cmd",
    ".cfg", ".yml", ".yaml", ".txt", ".properties", ".ini", ".json5",
    ".jsonc", ".mcmeta",
}
PUBLISHABLE_ROOTS = ("bootstrap", "packwiz", "payload", "scripts", "docs", "audit", "tests")
EXCLUDED_PARTS = {".git", ".tools", "build", "dist", "__pycache__"}
BAD_FRAGMENTS = (
    "\u00c3\u00a2",
    "\u00e2\u20ac\u201d",
    "\u00e2\u20ac\u201c",
    "\u00e2\u20ac\u2122",
    "\u00e2\u20ac\u2018",
    "\u00e2\u20ac",
    "\ufffd",
)


def candidates(root: Path):
    top_files = (root / "README.md", root / ".gitignore", root / "project-settings.json")
    for path in top_files:
        if path.is_file():
            yield path
    for name in PUBLISHABLE_ROOTS:
        base = root / name
        if not base.exists():
            continue
        for path in base.rglob("*"):
            relative_parts = set(path.relative_to(root).parts)
            if path.is_file() and path.suffix.lower() in TEXT_SUFFIXES and not (relative_parts & EXCLUDED_PARTS):
                yield path


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]).resolve()
    findings: list[dict[str, object]] = []
    scanned = 0
    for path in sorted(set(candidates(root))):
        scanned += 1
        relative = path.relative_to(root).as_posix()
        raw = path.read_bytes()
        try:
            text = raw.decode("utf-8-sig")
        except UnicodeDecodeError as error:
            findings.append({"path": relative, "kind": "invalid-utf8", "byteOffset": error.start})
            continue
        for fragment in BAD_FRAGMENTS:
            if fragment in text:
                findings.append({
                    "path": relative,
                    "kind": "known-mojibake",
                    "line": text[: text.index(fragment)].count("\n") + 1,
                })
                break

    result = {
        "checkedAt": datetime.now().astimezone().isoformat(),
        "status": "PASS" if not findings else "FAIL",
        "filesScanned": scanned,
        "findings": findings,
    }
    report = root / "audit/encoding-validation.json"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
