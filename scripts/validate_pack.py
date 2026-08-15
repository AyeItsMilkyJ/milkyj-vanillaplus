import argparse
import hashlib
import ipaddress
import json
import sys
import tomllib
from collections import Counter
from pathlib import Path
from urllib.parse import unquote, urlparse


PROTECTED_PARTS = {
    "saves",
    "screenshots",
    "logs",
    "crash-reports",
    "shaderpacks",
    "shaderpacks-disabled",
    "xaerowaypoints",
    "xaeroworldmap",
    "distant_horizons_server_data",
    "world",
    "backups",
}
PROTECTED_FILES = {
    "options.txt",
    "optionsof.txt",
    "servers.dat",
    "launcher_accounts.json",
    "accounts.json",
}


def digest(path: Path, algorithm: str) -> str:
    hasher = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def load_toml(path: Path):
    with path.open("rb") as stream:
        return tomllib.load(stream)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project_root", type=Path)
    parser.add_argument("--allow-placeholder", action="store_true")
    parser.add_argument("--allow-private-lan", action="store_true")
    args = parser.parse_args()

    project = args.project_root.resolve()
    pack_root = project / "packwiz"
    pack_path = pack_root / "pack.toml"
    pack = load_toml(pack_path)
    errors: list[str] = []

    if pack.get("pack-format") != "packwiz:1.1.0":
        errors.append("pack.toml pack-format is not packwiz:1.1.0")
    versions = pack.get("versions", {})
    if versions.get("minecraft") != "1.20.1":
        errors.append("Minecraft version drifted from 1.20.1")
    if versions.get("forge") != "47.4.10":
        errors.append("Forge version drifted from 47.4.10")

    index_spec = pack.get("index", {})
    index_path = pack_root / index_spec.get("file", "")
    if not index_path.is_file():
        errors.append(f"index file is missing: {index_path}")
        index = {"files": []}
    else:
        actual_index_hash = digest(index_path, index_spec.get("hash-format", "sha256"))
        if actual_index_hash.lower() != str(index_spec.get("hash", "")).lower():
            errors.append("pack.toml index hash does not match index.toml")
        index = load_toml(index_path)

    side_counts: Counter[str] = Counter()
    category_counts: Counter[str] = Counter()
    destinations: dict[str, str] = {}
    payload_count = 0
    external_count = 0
    preserved_count = 0

    for entry in index.get("files", []):
        relative = entry.get("file", "")
        indexed_path = (pack_root / relative).resolve()
        try:
            indexed_path.relative_to(pack_root.resolve())
        except ValueError:
            errors.append(f"index path escapes pack root: {relative}")
            continue
        if not indexed_path.is_file():
            errors.append(f"indexed file is missing: {relative}")
            continue
        algorithm = entry.get("hash-format", index.get("hash-format", "sha256"))
        if digest(indexed_path, algorithm).lower() != str(entry.get("hash", "")).lower():
            errors.append(f"index hash mismatch: {relative}")
        if not entry.get("metafile", False):
            destination = relative
            side = "both"
        else:
            try:
                metadata = load_toml(indexed_path)
            except Exception as exc:  # noqa: BLE001
                errors.append(f"invalid TOML metadata {relative}: {exc}")
                continue
            side = metadata.get("side", "both")
            if side not in {"client", "server", "both"}:
                errors.append(f"invalid side {side!r}: {relative}")
            filename = metadata.get("filename", "")
            destination = str((Path(relative).parent / filename).as_posix())
            download = metadata.get("download", {})
            url = str(download.get("url", ""))
            parsed = urlparse(url)
            private_lan = False
            if args.allow_private_lan and parsed.scheme == "http" and parsed.hostname:
                try:
                    address = ipaddress.ip_address(parsed.hostname)
                    private_lan = address.version == 4 and address.is_private and not address.is_loopback
                except ValueError:
                    private_lan = False
            if parsed.scheme != "https" and not (
                parsed.scheme == "http" and parsed.hostname in {"127.0.0.1", "localhost"}
            ) and not private_lan:
                errors.append(f"non-HTTPS or invalid download URL: {relative}: {url}")
            if "REPLACE_WITH_" in url and not args.allow_placeholder:
                errors.append(f"repository URL placeholder remains: {relative}")
            marker = "/payload/"
            if marker in parsed.path:
                payload_relative = unquote(parsed.path.split(marker, 1)[1])
                payload_path = (project / "payload" / payload_relative).resolve()
                try:
                    payload_path.relative_to((project / "payload").resolve())
                except ValueError:
                    errors.append(f"payload URL escapes payload root: {relative}")
                    continue
                if not payload_path.is_file():
                    errors.append(f"hosted payload is missing: {payload_relative}")
                else:
                    payload_count += 1
                    payload_hash_format = download.get("hash-format", "sha256")
                    if digest(payload_path, payload_hash_format).lower() != str(download.get("hash", "")).lower():
                        errors.append(f"payload hash mismatch: {payload_relative}")
            else:
                external_count += 1

        destination_lower = destination.lower()
        if entry.get("preserve", False):
            preserved_count += 1
            filename_lower = Path(destination).name.lower()
            binary_setting = filename_lower.endswith((".png", ".jpg", ".jpeg", ".gif", ".webp"))
            if not entry.get("metafile", False):
                errors.append(f"preserve is only allowed on setting metafiles: {relative}")
            elif side != "client" or not destination_lower.startswith("config/") or binary_setting:
                errors.append(f"preserve is only allowed on client text settings: {relative} -> {destination}")

        destination_parts = set(Path(destination_lower).parts)
        if Path(destination_lower).name in PROTECTED_FILES or destination_parts & PROTECTED_PARTS:
            errors.append(f"protected player/server data is managed: {destination}")
        if destination_lower in destinations:
            errors.append(
                f"duplicate destination {destination}: {destinations[destination_lower]} and {relative}"
            )
        destinations[destination_lower] = relative
        side_counts[side] += 1
        category_counts[Path(destination).parts[0] if Path(destination).parts else "root"] += 1

    report = {
        "pack": pack.get("name"),
        "version": pack.get("version"),
        "minecraft": versions.get("minecraft"),
        "forge": versions.get("forge"),
        "indexEntries": len(index.get("files", [])),
        "destinations": len(destinations),
        "sides": dict(sorted(side_counts.items())),
        "categories": dict(sorted(category_counts.items())),
        "hostedPayloads": payload_count,
        "externalDownloads": external_count,
        "preservedClientSettings": preserved_count,
        "errors": errors,
    }
    print(json.dumps(report, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
