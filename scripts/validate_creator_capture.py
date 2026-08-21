#!/usr/bin/env python3
"""Fail-closed validation for the optional Creator Capture candidate layer."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tomllib


SHA512_RE = re.compile(r"^[0-9a-f]{128}$")
PRIVATE_PATH_RE = re.compile(r"(?i)(?<![a-z0-9])[a-z]:[\\/]|/users/|/home/[^/\s]+")
ALLOWED_SIDES = {"client", "server", "both"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("project_root", nargs="?", default=Path(__file__).resolve().parents[1])
    parser.add_argument("--artifact-dir", type=Path)
    parser.add_argument("--require-artifacts", action="store_true")
    parser.add_argument(
        "--baseline-server-pass",
        action="store_true",
        help="Record that the operator separately observed the disposable 206-JAR baseline reach Done and stop cleanly.",
    )
    parser.add_argument(
        "--packwiz-e2e-pass",
        action="store_true",
        help="Record that the operator separately observed the disposable Packwiz client/server installation and preservation checks pass.",
    )
    parser.add_argument(
        "--normal-client-main-menu-pass",
        action="store_true",
        help="Record that the operator separately observed an isolated offline Prism profile reach the main menu and close normally.",
    )
    parser.add_argument("--write-report", action="store_true")
    parser.add_argument("--report", type=Path, default=Path("audit/creator-capture-validation.json"))
    return parser.parse_args()


def sha512(path: Path) -> str:
    digest = hashlib.sha512()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_toml(path: Path) -> dict:
    with path.open("rb") as stream:
        return tomllib.load(stream)


def tracked_files(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files"],
        check=True,
        text=True,
        capture_output=True,
    )
    return [line.strip().replace("\\", "/") for line in result.stdout.splitlines() if line.strip()]


def main() -> int:
    args = parse_args()
    root = Path(args.project_root).resolve()
    registry_path = root / "creator-capture" / "candidate-registry.json"
    errors: list[str] = []
    checks: list[dict[str, object]] = []

    def check(name: str, condition: bool, detail: str) -> None:
        checks.append({"name": name, "result": "PASS" if condition else "FAIL", "detail": detail})
        if not condition:
            errors.append(f"{name}: {detail}")

    try:
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Creator Capture validation failed: cannot read registry: {exc}", file=sys.stderr)
        return 1

    check("registry schema", registry.get("schemaVersion") == 1, "schemaVersion must be 1")
    pack = registry.get("pack", {})
    check("public pack name", pack.get("publicName") == "MilkyCraft Vanilla+", "registry publicName must be MilkyCraft Vanilla+")
    check("platform lock", (pack.get("minecraft"), pack.get("forge")) == ("1.20.1", "47.4.10"), "expected Minecraft 1.20.1 / Forge 47.4.10")

    pack_toml = read_toml(root / "packwiz" / "pack.toml")
    versions = pack_toml.get("versions", {})
    check(
        "Packwiz display name matches registry",
        pack_toml.get("name") == pack.get("publicName"),
        "packwiz/pack.toml name must match the public pack name",
    )
    check(
        "Packwiz platform matches registry",
        (versions.get("minecraft"), versions.get("forge")) == (pack.get("minecraft"), pack.get("forge")),
        "packwiz/pack.toml must retain the inspected Minecraft and Forge versions",
    )

    mod_files = sorted((root / "packwiz" / "mods").glob("*.pw.toml"))
    side_counts = {side: 0 for side in sorted(ALLOWED_SIDES)}
    client_jar_names: set[str] = set()
    server_jar_names: set[str] = set()
    production_mod_text: list[tuple[Path, str]] = []
    for metafile in mod_files:
        data = read_toml(metafile)
        side = data.get("side")
        if side not in ALLOWED_SIDES:
            errors.append(f"invalid side in {metafile.relative_to(root)}: {side!r}")
            continue
        side_counts[side] += 1
        filename = data.get("filename")
        if not isinstance(filename, str) or not filename.lower().endswith(".jar"):
            errors.append(f"missing/invalid JAR filename in {metafile.relative_to(root)}")
            continue
        if side in {"client", "both"}:
            client_jar_names.add(filename)
        if side in {"server", "both"}:
            server_jar_names.add(filename)
        production_mod_text.append((metafile, metafile.read_text(encoding="utf-8").lower()))

    check("production side classification", not any("invalid side" in e for e in errors), f"side counts: {side_counts}")
    check("clean managed client JAR count", len(client_jar_names) == 240, f"observed {len(client_jar_names)}, expected 240")
    check("clean managed server JAR count", len(server_jar_names) == 206, f"observed {len(server_jar_names)}, expected 206")

    tracked = tracked_files(root)
    tracked_creator_jars = [path for path in tracked if path.startswith("creator-capture/") and path.lower().endswith(".jar")]
    source_tree_creator_jars = [path.relative_to(root).as_posix() for path in (root / "creator-capture").rglob("*.jar")]
    check(
        "no creator artifact in source tree",
        not tracked_creator_jars and not source_tree_creator_jars,
        f"tracked creator JARs: {tracked_creator_jars}; source-tree creator JARs: {source_tree_creator_jars}",
    )

    candidate_results: list[dict[str, object]] = []
    candidates = registry.get("candidates", [])
    check("candidate registry non-empty", isinstance(candidates, list) and bool(candidates), "at least one evaluated candidate is required")
    for candidate in candidates if isinstance(candidates, list) else []:
        key = str(candidate.get("key", "<missing>"))
        artifact = candidate.get("artifact", {})
        filename = artifact.get("filename")
        expected_hash = artifact.get("sha512")
        eligible = candidate.get("eligible") is True
        status = candidate.get("status")

        check(f"{key} hash syntax", isinstance(expected_hash, str) and bool(SHA512_RE.fullmatch(expected_hash)), "SHA-512 must be 128 lowercase hexadecimal characters")
        check(f"{key} client-only policy", candidate.get("serverAllowed") is False, "creator candidates must never be allowed on the dedicated server")
        if not eligible:
            check(f"{key} rejected status", status == "rejected-incompatible", "an ineligible candidate must fail closed as rejected-incompatible")
            check(f"{key} not Packwiz-managed", candidate.get("productionPackwizManaged") is False, "rejected candidate must not enter production Packwiz metadata")

        needles = {str(filename).lower(), key.lower()}
        if candidate.get("name") == "Recordium":
            needles.update({"recordium", "replaymod-1.20.1-1-shadow.jar"})
        if candidate.get("name") == "Free Camera":
            needles.update({"freecamera", "free-camera-2.2.0"})
        leaked_files = [
            metafile.relative_to(root).as_posix()
            for metafile, text in production_mod_text
            if any(needle and needle in text for needle in needles)
        ]
        leaked_names = [name for name in client_jar_names | server_jar_names if name.lower() == str(filename).lower()]
        if not eligible:
            check(f"{key} absent from production", not leaked_files and not leaked_names, f"metafiles={leaked_files}, JAR destinations={leaked_names}")

        artifact_result: dict[str, object] = {"filename": filename, "verified": False}
        if args.artifact_dir is not None and isinstance(filename, str):
            artifact_path = args.artifact_dir.resolve() / filename
            if artifact_path.is_file():
                actual_hash = sha512(artifact_path)
                artifact_result.update({"verified": actual_hash == expected_hash, "sha512": actual_hash})
                check(f"{key} downloaded artifact hash", actual_hash == expected_hash, f"verified {filename}")
            elif args.require_artifacts:
                check(f"{key} downloaded artifact present", False, f"missing {filename}")
        elif args.require_artifacts:
            check(f"{key} artifact directory supplied", False, "--require-artifacts requires --artifact-dir")

        candidate_results.append(
            {
                "key": key,
                "name": candidate.get("name"),
                "status": status,
                "eligible": eligible,
                "serverAllowed": candidate.get("serverAllowed"),
                "artifact": artifact_result,
                "observedTests": candidate.get("observedTests", []),
                "blockers": candidate.get("blockers", []),
            }
        )

    policy = registry.get("policy", {})
    any_eligible = any(candidate.get("eligible") is True for candidate in candidates if isinstance(candidate, dict))
    check("creator layer defaults off", policy.get("defaultEnabled") is False, "Creator Capture must be opt-in")
    check("production payload unchanged", policy.get("productionPackwizPayloadChanged") is any_eligible, "payload flag must reflect candidate eligibility")
    check("server creator layer forbidden", policy.get("dedicatedServerAllowed") is False, "server policy must remain false")
    check("source replay immutability", policy.get("originalReplayFilesAreImmutable") is True, "original replays must be immutable")

    protected_files = [
        root / "creator-capture" / "candidate-registry.json",
        root / "creator-capture" / "README.md",
        root / "docs" / "CREATOR-CAPTURE.md",
        root / "docs" / "CREATOR-REPLAY-INTEGRATION.md",
    ]
    private_findings: list[str] = []
    for path in protected_files:
        text = path.read_text(encoding="utf-8")
        if PRIVATE_PATH_RE.search(text):
            private_findings.append(path.relative_to(root).as_posix())
    check("no private absolute paths in creator files", not private_findings, f"findings: {private_findings}")

    gitignore = (root / ".gitignore").read_text(encoding="utf-8")
    required_ignores = ["**/replay_recordings/", "**/.replay_cache/", "*.mcpr", "*.mcpr.tmp", "*.mcpr.cache"]
    missing_ignores = [pattern for pattern in required_ignores if pattern not in gitignore]
    check("replay media ignored", not missing_ignores, f"missing patterns: {missing_ignores}")

    report = {
        "schemaVersion": 1,
        "checkedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "result": "PASS" if not errors else "FAIL",
        "pack": {
            "publicName": pack.get("publicName"),
            "minecraft": versions.get("minecraft"),
            "forge": versions.get("forge"),
            "packwizVersion": pack_toml.get("version"),
        },
        "production": {
            "payloadChanged": any_eligible,
            "modMetafiles": len(mod_files),
            "sideCounts": side_counts,
            "cleanManagedClientJarCount": len(client_jar_names),
            "cleanManagedServerJarCount": len(server_jar_names),
            "creatorJarLeakage": False if not errors else any("absent from production" in e or "creator artifact" in e for e in errors),
        },
        "candidates": candidate_results,
        "checks": checks,
        "runtimeMatrix": {
            "packwizUpdate": (
                "PASS - disposable client/server installs resolved 240/206 JARs and preserved personal client settings"
                if args.packwiz_e2e_pass
                else "NOT RUN IN THIS INVOCATION - use --packwiz-e2e-pass only after directly observing the disposable E2E run"
            ),
            "normalClientFreshInteractiveLaunch": (
                "PASS - isolated offline Prism profile reached the main menu and closed normally; no account or live Prism files were copied"
                if args.normal_client_main_menu_pass
                else "NOT RUN IN THIS INVOCATION - use --normal-client-main-menu-pass only after directly observing the isolated offline Prism launch"
            ),
            "creatorClientLaunch": "BLOCKED AT LOADER - Recordium module conflict; Free Camera JavaFML requirement mismatch",
            "multiplayerReplayCreateDhShaderDimensionsLongSession": "NOT RUN - no candidate passed the loader gate",
            "render": "NOT RUN - no candidate passed the loader gate",
            "dedicatedServerBaseline": (
                "PASS - disposable 206-JAR server reached Done; normal stop saved all seven loaded dimensions; JVM exited 0"
                if args.baseline_server_pass
                else "NOT RUN IN THIS INVOCATION - use --baseline-server-pass only after directly observing the disposable run"
            )
        },
        "errors": errors,
    }

    if args.write_report:
        report_path = args.report if args.report.is_absolute() else root / args.report
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    if errors:
        print("Creator Capture validation FAILED:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        "Creator Capture validation passed: "
        f"{len(client_jar_names)} managed client JARs, {len(server_jar_names)} server JARs, "
        f"{len(candidate_results)} rejected candidate(s), no production/server leakage."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
