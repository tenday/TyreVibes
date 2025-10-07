#!/usr/bin/env python3
import re
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1] / "TyreVibes"
SWIFT_FILES = list(ROOT.rglob("*.swift"))

PATTERNS = {
    "Text": re.compile(r'Text\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    "Button": re.compile(r'Button\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    "Alert": re.compile(r'alert\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    "NavigationTitle": re.compile(r'\.navigationTitle\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    "placeholder": re.compile(r'placeholder:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    "Label": re.compile(r'Label\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    "Section": re.compile(r'Section\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    "ToolbarTitle": re.compile(r'ToolbarItem\([^\)]*title:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
}

results = {}

for swift_file in SWIFT_FILES:
    content = swift_file.read_text(encoding="utf-8", errors="ignore")
    for name, pattern in PATTERNS.items():
        for match in pattern.finditer(content):
            value = match.group(1)
            if not value.strip():
                continue
            entry = results.setdefault(value, {"occurrences": []})
            line = content[:match.start()].count("\n") + 1
            entry["occurrences"].append({
                "file": swift_file.relative_to(ROOT).as_posix(),
                "line": line,
                "context": name,
            })

# Filter out values already localized via placeholders
filtered = {k: v for k, v in results.items() if not k.startswith("%")}

output_path = ROOT / "Localization" / "localization_inventory.json"
output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(json.dumps(filtered, indent=2, ensure_ascii=False), encoding="utf-8")

print(f"Extracted {len(filtered)} candidate strings to {output_path}")
