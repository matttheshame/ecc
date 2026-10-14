#!/usr/bin/env python3
"""Generate App/Resources/Localizable.xcstrings from Tools/l10n/strings/*.py.

Bootstrap tool: the catalog it writes is a normal Xcode String Catalog. Once translators
work directly in Xcode (or a TMS), retire this script and treat the .xcstrings as the
source of truth. Until then, edit the Python tables and re-run:

    python3 Tools/l10n/build_catalog.py

Each entry: dict(key=..., en=..., fr=..., nl=..., comment=...).
A language value may be a dict {"one": ..., "other": ...} for plural variations; the
first %lld in the key is the plural argument.
"""
from __future__ import annotations

import importlib.util
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
STRINGS_DIR = pathlib.Path(__file__).resolve().parent / "strings"
CATALOG = ROOT / "App" / "Resources" / "Localizable.xcstrings"
INFOPLIST_CATALOG = ROOT / "App" / "Resources" / "InfoPlist.xcstrings"
LANGUAGES = ("en", "fr", "nl")


def load_entries(table: str = "STRINGS") -> list[dict]:
    entries: list[dict] = []
    for path in sorted(STRINGS_DIR.glob("*.py")):
        spec = importlib.util.spec_from_file_location(path.stem, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for entry in getattr(module, table, []):
            entry = dict(entry)
            entry["_source"] = path.name
            entries.append(entry)
    return entries


def unit(value: str) -> dict:
    return {"stringUnit": {"state": "translated", "value": value}}


def localization(value) -> dict:
    if isinstance(value, dict):
        return {"variations": {"plural": {form: unit(text) for form, text in value.items()}}}
    return unit(value)


def build(entries: list[dict]) -> dict:
    strings: dict[str, dict] = {}
    errors: list[str] = []
    for entry in entries:
        key = entry["key"]
        if key in strings:
            errors.append(f"duplicate key {key!r} ({entry['_source']})")
            continue
        for lang in LANGUAGES:
            value = entry.get(lang)
            if value in (None, "") or (isinstance(value, dict) and not all(value.values())):
                errors.append(f"{key}: missing {lang} ({entry['_source']})")
            if isinstance(value, dict) and set(value) - {"zero", "one", "two", "few", "many", "other"}:
                errors.append(f"{key}: bad plural forms {sorted(value)}")
            if isinstance(value, dict) and "other" not in value:
                errors.append(f"{key}: plural needs 'other'")
        strings[key] = {
            "comment": entry.get("comment", ""),
            "extractionState": "manual",
            "localizations": {lang: localization(entry[lang]) for lang in LANGUAGES if entry.get(lang)},
        }
    if errors:
        sys.exit("\n".join(errors))
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def write(catalog: dict, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(catalog, indent=2, ensure_ascii=False, sort_keys=True, separators=(",", " : "))
    path.write_text(text + "\n", encoding="utf-8")
    print(f"wrote {len(catalog['strings'])} keys to {path.relative_to(ROOT)}")


def main() -> None:
    write(build(load_entries("STRINGS")), CATALOG)
    # Info.plist keys (permission prompts, display name) live in their own catalog.
    write(build(load_entries("INFOPLIST")), INFOPLIST_CATALOG)


if __name__ == "__main__":
    main()
