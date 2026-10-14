#!/usr/bin/env python3
"""Localization guardrail. Fails (exit 1) when:

  * a Swift literal passed to a UI API is not a catalog key (hardcoded user-facing text),
  * a key-like literal used in Swift is missing from Localizable.xcstrings,
  * a catalog entry lacks a translated en, fr or nl value,
  * a format string's placeholders differ between languages.

Warns about catalog keys that no Swift file references.

    python3 Tools/l10n/check.py
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOG = ROOT / "App" / "Resources" / "Localizable.xcstrings"
SWIFT_DIRS = [ROOT / "App", ROOT / "Packages" / "BruskKit" / "Sources"]
LANGUAGES = ("en", "fr", "nl")

# First segment of every catalog key.
NAMESPACES = {
    "a11y", "app", "auth", "category", "common", "complaint", "error", "flag", "followup",
    "help", "map", "notification", "onboarding", "period", "report", "routing", "settings",
    "share", "state", "status", "textguard", "trend", "trust", "walk", "zone",
}
KEY_RE = re.compile(r"^(%s)\.[A-Za-z0-9_.]+( .*)?$" % "|".join(sorted(NAMESPACES)))

# UI APIs whose first string literal is user-facing text.
UI_CALL_RE = re.compile(
    r"""\b(Text|Button|Label|Toggle|Section|Picker|TextField|SecureField|Tab|Link|LabeledContent|
          DSButton|SectionHeader|StateView|Banner|ListRow|MetricTile|ContentUnavailableView|
          navigationTitle|accessibilityLabel|accessibilityHint|accessibilityValue|help|alert|
          confirmationDialog|LocalizedStringKey|L10n\.string|LocalizedStringResource)
        \(\s*"((?:[^"\\]|\\.)*)"
    """,
    re.VERBOSE,
)
LITERAL_RE = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
INTERPOLATION_RE = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)")
FORMAT_RE = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|lf|f|\.\d+f)")


def strip_comments(source: str) -> str:
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


def normalise(key: str) -> str:
    return FORMAT_RE.sub("%", INTERPOLATION_RE.sub("%", key))


def placeholders(value: str) -> list[str]:
    return sorted(re.sub(r"\d+\$", "", m) for m in FORMAT_RE.findall(value))


def catalog_values(entry: dict, lang: str) -> list[str]:
    loc = entry.get("localizations", {}).get(lang)
    if not loc:
        return []
    if "stringUnit" in loc:
        unit = loc["stringUnit"]
        return [unit["value"]] if unit.get("state") == "translated" and unit.get("value") else []
    forms = loc.get("variations", {}).get("plural", {})
    return [f["stringUnit"]["value"] for f in forms.values() if f["stringUnit"].get("state") == "translated"]


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]
    by_normalised = {normalise(k): k for k in catalog}

    for key, entry in catalog.items():
        for lang in LANGUAGES:
            if not catalog_values(entry, lang):
                errors.append(f"catalog: {key!r} has no translated {lang} value")
        expected = placeholders(key) if "%" in key else None
        for lang in LANGUAGES:
            for value in catalog_values(entry, lang):
                if expected is not None and placeholders(value) != expected and not (
                    # Plural 'one' forms may omit the number ("1 day" → "a day").
                    len(placeholders(value)) < len(expected)
                ):
                    errors.append(f"catalog: {key!r} [{lang}] placeholders {placeholders(value)} != {expected}")

    used: set[str] = set()
    for directory in SWIFT_DIRS:
        for path in sorted(directory.rglob("*.swift")):
            rel = path.relative_to(ROOT)
            source = strip_comments(path.read_text(encoding="utf-8"))
            for lineno, line in enumerate(source.splitlines(), 1):
                for literal in LITERAL_RE.findall(line):
                    if KEY_RE.match(literal):
                        norm = normalise(literal)
                        if norm in by_normalised:
                            used.add(by_normalised[norm])
                        else:
                            errors.append(f"{rel}:{lineno}: key {literal!r} missing from catalog")
                for match in UI_CALL_RE.finditer(line):
                    literal = match.group(2)
                    if not literal or KEY_RE.match(literal):
                        continue
                    if not re.search(r"[A-Za-zÀ-ÿ]", INTERPOLATION_RE.sub("", literal)):
                        continue  # symbols / numbers only
                    errors.append(f"{rel}:{lineno}: hardcoded UI string {literal!r} in {match.group(1)}(…)")

    for key in sorted(set(catalog) - used):
        warnings.append(f"unused key {key!r}")

    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}")
    print(f"{len(catalog)} keys, {len(used)} used, {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
