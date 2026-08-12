#!/usr/bin/env python3
"""Audit the exact quest stack against Packwiz and embedded JAR metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from datetime import datetime
from pathlib import Path


METADATA_FILES = (
    "architectury-api.pw.toml",
    "ftb-library-forge.pw.toml",
    "ftb-quests-forge-2001-4-22.pw.toml",
    "ftb-teams-forge-2001-3-2.pw.toml",
    "ftb-xmod-compat-forge-2-1-3.pw.toml",
    "ftb-filter-system-forge-20-0-1.pw.toml",
)


def value(text: str, key: str) -> str | None:
    match = re.search(rf'^{re.escape(key)}\s*=\s*"([^"]+)"', text, re.MULTILINE)
    return match.group(1) if match else None


def sha512(path: Path) -> str:
    digest = hashlib.sha512()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_embedded_metadata(jar: Path) -> dict[str, object]:
    with zipfile.ZipFile(jar) as archive:
        raw = archive.read("META-INF/mods.toml").decode("utf-8", "replace")
    mod_block_match = re.search(r'\[\[mods\]\](.*?)(?=\[\[dependencies\.|\Z)', raw, re.DOTALL)
    mod_block = mod_block_match.group(1) if mod_block_match else ""
    mod_id = value(mod_block, "modId")
    dependencies: list[dict[str, object]] = []
    if mod_id:
        pattern = rf'\[\[dependencies\.{re.escape(mod_id)}\]\](.*?)(?=\[\[dependencies\.|\Z)'
        for match in re.finditer(pattern, raw, re.DOTALL):
            block = match.group(1)
            dependencies.append(
                {
                    "modId": value(block, "modId"),
                    "mandatory": (re.search(r'^mandatory\s*=\s*(true|false)', block, re.MULTILINE) or [None, None])[1],
                    "versionRange": value(block, "versionRange"),
                    "ordering": value(block, "ordering"),
                    "side": value(block, "side"),
                }
            )
    return {
        "modId": mod_id,
        "version": value(mod_block, "version"),
        "displayName": value(mod_block, "displayName"),
        "loaderVersion": value(raw, "loaderVersion"),
        "dependencies": dependencies,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--mods-dir", type=Path, required=True)
    args = parser.parse_args()
    project = args.project_root.resolve()
    mods_dir = args.mods_dir.resolve()
    errors: list[str] = []
    records: list[dict[str, object]] = []

    for metadata_name in METADATA_FILES:
        metadata_path = project / "packwiz/mods" / metadata_name
        if not metadata_path.exists():
            errors.append(f"missing Packwiz metadata: {metadata_name}")
            continue
        raw = metadata_path.read_text(encoding="utf-8")
        filename = value(raw, "filename")
        side = value(raw, "side")
        expected_hash = value(raw, "hash")
        jar = mods_dir / filename if filename else None
        actual_hash = sha512(jar) if jar and jar.exists() else None
        if side != "both":
            errors.append(f"{metadata_name}: expected side=both, found {side!r}")
        if not jar or not jar.exists():
            errors.append(f"{metadata_name}: staged JAR missing: {filename}")
            embedded: dict[str, object] = {}
        else:
            embedded = parse_embedded_metadata(jar)
        if expected_hash != actual_hash:
            errors.append(f"{metadata_name}: SHA-512 mismatch")
        records.append(
            {
                "packwizMetadata": metadata_name,
                "filename": filename,
                "side": side,
                "downloadUrl": value(raw, "url"),
                "hashFormat": value(raw, "hash-format"),
                "expectedSha512": expected_hash,
                "actualSha512": actual_hash,
                "hashVerified": expected_hash == actual_hash,
                "embeddedAuthoritativeMetadata": embedded,
            }
        )

    result = {
        "auditedAt": datetime.now().astimezone().isoformat(),
        "minecraft": "1.20.1",
        "forge": "47.4.10",
        "classification": "all six files are required on both client and dedicated server",
        "sourceOfTruth": "Packwiz download records plus META-INF/mods.toml embedded in each exact downloaded JAR",
        "mods": records,
        "errors": errors,
    }
    output = project / "audit/quest-mods.json"
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
