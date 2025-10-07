#!/usr/bin/env python3
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "TyreVibes"
localizable_path = ROOT / "Localizable.xcstrings"
helper_path = ROOT / "Core" / "Helper" / "LocalizationHelper.swift"

translations: dict[str, str] = {}
pattern = re.compile(r'\s*"(?P<key>(?:\\"|[^"])*)"\s*:\s*"(?P<value>(?:\\"|[^"])*)"[,\n]')

collect = False
with helper_path.open(encoding="utf-8") as f:
    for line in f:
        if "static let translations" in line:
            collect = True
            continue
        if collect:
            if line.strip().startswith(']'):
                collect = False
                break
            match = pattern.match(line)
            if match:
                key = match.group("key").encode('utf-8').decode('unicode_escape')
                value = match.group("value").encode('utf-8').decode('unicode_escape')
                translations[key] = value

if not translations:
    raise SystemExit("No translations found")

with localizable_path.open(encoding="utf-8") as f:
    data = json.load(f)

strings = data.setdefault("strings", {})

for key, value in translations.items():
    entry = strings.setdefault(key, {"extractionState": "manual", "localizations": {}})
    localizations = entry.setdefault("localizations", {})

    en_unit = localizations.setdefault("en", {"stringUnit": {"state": "translated", "value": key}})
    en_unit["stringUnit"] = {"state": "translated", "value": key}

    it_unit = localizations.setdefault("it", {"stringUnit": {"state": "translated", "value": value}})
    it_unit["stringUnit"] = {"state": "translated", "value": value}

with localizable_path.open("w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"Updated {len(translations)} translations in {localizable_path}")
