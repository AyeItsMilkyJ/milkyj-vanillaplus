#!/usr/bin/env python3
"""Validate the exact RC1 compatibility resources against the installed mod JARs."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import tomllib
import zipfile
from pathlib import Path
from typing import Any


JAR_HASHES = {
    "domesticationinnovation-1.7.1-1.20.1.jar": "00f20efea12ea981b8d75e257a136c08e0c00c324554e69cf20193376c942e97",
    "nethersdelight-1.20.1-4.0.jar": "28b072bc5c09ee889468546676c9bf0268eaa415865704bbeeb33f6a37005a30",
    "beautify-2.0.2.jar": "d14eca2341539a9186599e335c72315a4210f90f8e2d8007200c1da70b27bf15",
    "aether-1.20.1-1.5.2-neoforge.jar": "b6b586eb6fdc9ce4b3645cab43642ba87817c5deadef4d87ab884e4fe20ef282",
    "tf_dnv-1.2.3.jar": "f6c4780c214c098a20b5d666f8ef0b8d6e92fa67a36f68f8259de1d9a12ed6f8",
}

FIXED_RESOURCES = {
    "data/beautify/advancements/progression/candelabra.json": "f105986614064ded8142f528a33bfcc79d329dfd99363a76d9b8f8f64cd5717a",
    "data/domesticationinnovation/loot_modifiers/blazing_enchanted_book.json": "733ea7be48dc5bffe499a704bfa196ddef034790ce2ade94abc7e04bf3f6198b",
    "data/nethersdelight/loot_modifiers/chopping_leather.json": "81d79fdfc511e80aba3ab984025d67623998397fa7f43edc2f15db46801f036c",
    "data/nethersdelight/loot_modifiers/chopping_string.json": "aa08932d7e997a595bf0dcfc285a3768e5d94e562bd9445c97b7d041e9fda586",
    "data/tf_dnv/loot_tables/chests/dungeon_shroom_barrel.json": "aed53ece9f961c5c86e859739ba0feb44e1ebee65a507a23b1005fd41af1ba56",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def jar_json(jar: Path, resource: str) -> Any:
    with zipfile.ZipFile(jar) as archive:
        return json.loads(archive.read(resource).decode("utf-8"))


def jar_has(jar: Path, resource: str) -> bool:
    with zipfile.ZipFile(jar) as archive:
        return resource in archive.namelist()


def replace_value(value: Any, old: str, new: str) -> Any:
    if isinstance(value, dict):
        return {key: replace_value(child, old, new) for key, child in value.items()}
    if isinstance(value, list):
        return [replace_value(child, old, new) for child in value]
    return new if value == old else value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--mods-dir", type=Path, required=True)
    args = parser.parse_args()

    project = args.project_root.resolve()
    mods = args.mods_dir.resolve()
    datapack = project / "payload" / "both" / "moonlight-global-datapacks" / "milkyj-compat-fixes"
    metadata_root = project / "packwiz" / "moonlight-global-datapacks" / "milkyj-compat-fixes"
    require(load_json(datapack / "pack.mcmeta")["pack"]["pack_format"] == 15, "wrong datapack format")

    jars: dict[str, Path] = {}
    for name, expected in JAR_HASHES.items():
        jar = mods / name
        require(jar.is_file(), f"missing installed JAR: {name}")
        require(digest(jar) == expected, f"unexpected installed JAR hash: {name}")
        jars[name] = jar

    for relative, expected in FIXED_RESOURCES.items():
        payload = datapack / relative
        metadata = metadata_root / f"{relative}.pw.toml"
        require(payload.is_file(), f"missing compatibility payload: {relative}")
        require(digest(payload) == expected, f"payload changed from validated candidate: {relative}")
        load_json(payload)
        require(metadata.is_file(), f"missing Packwiz descriptor: {relative}")
        descriptor = tomllib.loads(metadata.read_text(encoding="utf-8"))
        require(descriptor.get("side") == "both", f"wrong side for {relative}")
        require(descriptor["download"]["hash"] == expected, f"wrong payload hash for {relative}")
        require(descriptor["filename"] == Path(relative).name, f"wrong filename for {relative}")

    domestication = jars["domesticationinnovation-1.7.1-1.20.1.jar"]
    registered = jar_json(domestication, "data/forge/loot_modifiers/global_loot_modifiers.json")["entries"]
    require("domesticationinnovation:blazing_enchanted_book" in registered, "registered DI ID changed")
    missing = "data/domesticationinnovation/loot_modifiers/blazing_enchanted_book.json"
    shipped = "data/domesticationinnovation/loot_modifiers/blazed_enchanted_book.json"
    require(not jar_has(domestication, missing), "DI mismatch no longer exists in exact JAR")
    require(load_json(datapack / missing) == jar_json(domestication, shipped), "DI alias is not exact")

    nethers = jars["nethersdelight-1.20.1-4.0.jar"]
    semantics = {}
    for stem, bad, targets, item in (
        ("chopping_leather", "minecraft:alternatives", ["minecraft:cow", "minecraft:donkey", "minecraft:horse", "minecraft:llama", "minecraft:mule"], "minecraft:leather"),
        ("chopping_string", "minecraft:alternative", ["minecraft:spider", "minecraft:cave_spider"], "minecraft:string"),
    ):
        relative = f"data/nethersdelight/loot_modifiers/{stem}.json"
        original = jar_json(nethers, relative)
        repaired = load_json(datapack / relative)
        require(original["conditions"][1]["condition"] == bad, f"unexpected original condition: {stem}")
        expected = json.loads(json.dumps(original))
        expected["conditions"][1]["condition"] = "minecraft:any_of"
        require(repaired == expected, f"{stem} changes more than the condition ID")
        actual_targets = [term["predicate"]["type"] for term in repaired["conditions"][1]["terms"]]
        require(actual_targets == targets and repaired["item"] == item, f"loot semantics changed: {stem}")
        require(repaired["conditions"][0]["predicate"]["equipment"]["mainhand"]["tag"] == "nethersdelight:tools/machetes", f"machete condition changed: {stem}")
        semantics[stem] = {"targets": targets, "item": item, "condition": "minecraft:any_of"}
    require(jar_has(nethers, "data/nethersdelight/tags/items/tools/machetes.json"), "machete tag missing")

    aether = jars["aether-1.20.1-1.5.2-neoforge.jar"]
    supported = jar_json(aether, "data/aether/loot_modifiers/remove_seeds.json")
    require(supported["conditions"][0]["condition"] == "minecraft:any_of", "supported any_of evidence missing")

    beautify = jars["beautify-2.0.2.jar"]
    advancement = "data/beautify/advancements/progression/candelabra.json"
    original_advancement = jar_json(beautify, advancement)
    repaired_advancement = load_json(datapack / advancement)
    require(repaired_advancement == replace_value(original_advancement, "beautify:lamp_candleabra", "beautify:lamp_candelabra"), "Beautify override changes more than the typo")
    require(jar_has(beautify, "assets/beautify/models/item/lamp_candelabra.json"), "correct Beautify item model missing")

    tf_dnv = jars["tf_dnv-1.2.3.jar"]
    shroom_barrel = "data/tf_dnv/loot_tables/chests/dungeon_shroom_barrel.json"
    original_shroom_barrel = jar_json(tf_dnv, shroom_barrel)
    repaired_shroom_barrel = load_json(datapack / shroom_barrel)
    require(original_shroom_barrel["pools"][0]["entries"][0]["name"] == "tf_dnv:dungeon_shroom", "unexpected original tf_dnv shroom reference")
    expected_shroom_barrel = json.loads(json.dumps(original_shroom_barrel))
    expected_shroom_barrel["pools"][0]["entries"][0]["name"] = "tf_dnv:chests/dungeon_shroom"
    require(repaired_shroom_barrel == expected_shroom_barrel, "tf_dnv override changes more than the missing chests/ path")
    require(jar_has(tf_dnv, "data/tf_dnv/loot_tables/chests/dungeon_shroom.json"), "corrected tf_dnv shroom loot table is not installed")

    for forbidden in ("create_central_kitchen", "aether", "relics"):
        require(not (datapack / "data" / forbidden).exists(), f"IGNORE SAFELY namespace was integrated: {forbidden}")

    report = {
        "status": "PASS",
        "datapack": datapack.relative_to(project).as_posix(),
        "packFormat": 15,
        "validatedCompatibilityResources": sorted(FIXED_RESOURCES),
        "side": "both",
        "domesticationAliasExact": True,
        "nethersDelightSemantics": semantics,
        "beautifyOnlyTypoChanged": True,
        "tfDnvShroomOnlyPathChanged": True,
        "ignoredFindingsIntegrated": False,
    }
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, KeyError, OSError, UnicodeError, json.JSONDecodeError, tomllib.TOMLDecodeError, zipfile.BadZipFile) as exc:
        print(f"integrated compatibility validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
