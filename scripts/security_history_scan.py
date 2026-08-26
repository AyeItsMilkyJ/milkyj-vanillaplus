#!/usr/bin/env python3
"""Scan publishable worktree files and all locally publishable refs without leaking values."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path


FORBIDDEN_PATHS = (
    re.compile(r"(^|/)resourceful-config-web\.json$", re.I),
    re.compile(r"(^|/)dawnoftimebuilder/patrons_cache\.json$", re.I),
    re.compile(r"(^|/)(playerdata|stats)(/|$)", re.I),
    re.compile(r"(^|/)(launcher_accounts|accounts|usercache|usernamecache)\.json$", re.I),
)
SECRET_CONTENT = (
    re.compile(rb'["\']pass' + rb'word["\']\s*:\s*["\'][^"\']+["\']', re.I),
    re.compile(rb'["\'](?:access_token|refresh_token|client_secret)["\']\s*:\s*["\'][^"\']+["\']', re.I),
)
PRIVATE_LAN_CONTENT = re.compile(
    rb"(?<!\d)(?:10(?:\.\d{1,3}){3}|192\.168(?:\.\d{1,3}){2}|172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2})(?!\d)"
)
ABSOLUTE_WINDOWS_USER_PATH = re.compile(
    rb"(?i)\b[A-Z]:[\\/]+Users[\\/]+(?![<%])[^\\/\s]+[\\/]"
)


def git(root: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(["git", "-C", str(root), *args], check=check, capture_output=True)


def reason_for_path(path: str) -> str | None:
    normalized = path.replace("\\", "/")
    for pattern in FORBIDDEN_PATHS:
        if pattern.search(normalized):
            return "forbidden sensitive/runtime path"
    return None


def contains_secret(data: bytes) -> bool:
    if b"\x00" in data or len(data) > 5 * 1024 * 1024:
        return False
    return any(pattern.search(data) for pattern in SECRET_CONTENT)


def private_location_reason(data: bytes) -> str | None:
    """Reject current-tree location leaks without reproducing their values."""
    if b"\x00" in data or len(data) > 5 * 1024 * 1024:
        return None
    if PRIVATE_LAN_CONTENT.search(data):
        return "literal private LAN address"
    if ABSOLUTE_WINDOWS_USER_PATH.search(data):
        return "literal absolute Windows user-profile path"
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project_root", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--no-write", action="store_true", help="verify without replacing the committed JSON report")
    args = parser.parse_args()
    root = args.project_root.resolve()
    findings: list[dict[str, str]] = []
    known_history: list[dict[str, str]] = []

    baseline_path = root / "audit" / "security-known-history.json"
    known_baseline: set[tuple[str, str]] = set()
    if not baseline_path.is_file():
        findings.append({"scope": "history-baseline", "path": str(baseline_path), "reason": "reviewed history baseline is missing"})
    else:
        try:
            baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
            for entry in baseline.get("entries", []):
                object_id = str(entry.get("object", ""))
                reason = str(entry.get("reason", ""))
                if not re.fullmatch(r"[0-9a-f]{40}", object_id) or reason not in {
                    "literal private LAN address",
                    "literal absolute Windows user-profile path",
                }:
                    raise ValueError("invalid reviewed history entry")
                key = (object_id, reason)
                if key in known_baseline:
                    raise ValueError("duplicate reviewed history entry")
                known_baseline.add(key)
        except (OSError, ValueError, TypeError, json.JSONDecodeError) as exc:
            findings.append({"scope": "history-baseline", "path": "audit/security-known-history.json", "reason": f"invalid reviewed history baseline: {exc}"})

    listed = git(root, "ls-files", "-co", "--exclude-standard").stdout.decode("utf-8", "replace").splitlines()
    for relative in sorted(set(listed)):
        path = root / relative
        if not path.is_file():
            continue
        reason = reason_for_path(relative)
        if reason:
            findings.append({"scope": "worktree", "path": relative, "reason": reason})
        else:
            try:
                data = path.read_bytes()
            except OSError:
                continue
            if contains_secret(data):
                findings.append({"scope": "worktree", "path": relative, "reason": "non-empty secret-like value"})
            location_reason = private_location_reason(data)
            if location_reason:
                findings.append({"scope": "worktree", "path": relative, "reason": location_reason})

    refs_raw = git(root, "for-each-ref", "--format=%(refname)", "refs/heads", "refs/tags").stdout
    refs = sorted(refs_raw.decode("utf-8", "replace").splitlines())
    objects_raw = git(root, "rev-list", "--objects", "--all").stdout.decode("utf-8", "replace").splitlines()
    object_paths: dict[str, str] = {}
    for entry in objects_raw:
        object_id, _, object_path = entry.partition(" ")
        object_paths.setdefault(object_id, object_path)
        if object_path:
            reason = reason_for_path(object_path)
            if reason:
                findings.append({"scope": "history", "path": object_path, "object": object_id, "reason": reason})
    ids = list(object_paths)
    type_result = subprocess.run(
        ["git", "-C", str(root), "cat-file", "--batch-check=%(objectname) %(objecttype)"],
        input=("\n".join(ids) + "\n").encode(), check=True, capture_output=True,
    ).stdout.decode("ascii", "replace").splitlines()
    blob_ids = [line.split()[0] for line in type_result if line.endswith(" blob")]
    batch = subprocess.run(
        ["git", "-C", str(root), "cat-file", "--batch"],
        input=("\n".join(blob_ids) + "\n").encode(), check=True, capture_output=True,
    ).stdout
    offset = 0
    checked_blobs: set[str] = set()
    while offset < len(batch):
        line_end = batch.index(b"\n", offset)
        header = batch[offset:line_end].decode("ascii", "replace").split()
        offset = line_end + 1
        if len(header) < 3:
            break
        object_id, object_type, size_text = header[:3]
        size = int(size_text)
        data = batch[offset:offset + size]
        offset += size + 1
        if object_type != "blob":
            continue
        checked_blobs.add(object_id)
        if contains_secret(data):
            findings.append({
                "scope": "history",
                "path": object_paths.get(object_id) or "<path unavailable>",
                "object": object_id,
                "reason": "non-empty secret-like value",
            })
        location_reason = private_location_reason(data)
        if location_reason:
            location_finding = {
                "scope": "history",
                "path": object_paths.get(object_id) or "<path unavailable>",
                "object": object_id,
                "reason": location_reason,
            }
            if (object_id, location_reason) in known_baseline:
                known_history.append(location_finding)
            else:
                findings.append(location_finding)

    unique = []
    seen = set()
    for finding in findings:
        key = tuple(sorted(finding.items()))
        if key not in seen:
            seen.add(key)
            unique.append(finding)
    known_unique = []
    known_seen = set()
    for finding in known_history:
        key = tuple(sorted(finding.items()))
        if key not in known_seen:
            known_seen.add(key)
            known_unique.append(finding)
    observed_baseline = {(entry["object"], entry["reason"]) for entry in known_unique}
    baselineEntriesNotReachable = [
        {"object": object_id, "reason": reason}
        for object_id, reason in sorted(known_baseline - observed_baseline)
    ]
    result = {
        "scannedAt": datetime.now().astimezone().isoformat(),
        "status": "PASS" if not unique else "FAIL",
        "reachableRefs": refs,
        "publishableWorktreeFilesScanned": len(set(listed)),
        "reachableBlobsScanned": len(checked_blobs),
        "findingCount": len(unique),
        "findings": unique,
        "knownHistoricalPrivacyFindingCount": len(known_unique),
        "knownHistoricalPrivacyFindings": known_unique,
        "baselineEntriesNotReachable": baselineEntriesNotReachable,
        "note": "Blocking findings and reviewed legacy privacy metadata report paths/object IDs only; values and identity records are never emitted. Secret-content and forbidden-path findings can never be baselined.",
    }
    report = root / "audit/security-history-scan.json"
    if not args.no_write:
        report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 1 if unique else 0


if __name__ == "__main__":
    raise SystemExit(main())
