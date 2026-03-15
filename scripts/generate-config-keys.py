#!/usr/bin/env python3
"""Fetch Claude Code settings schema from SchemaStore and update config key completions.

Usage:
    uv run scripts/generate-config-keys.py

Fetches the official JSON schema from json.schemastore.org, extracts all top-level
property names and descriptions, and patches completions/claude.fish between the
BEGIN/END GENERATED CONFIG KEYS markers.
"""

import json
import re
import sys
import urllib.request
from pathlib import Path

SCHEMA_URL = "https://json.schemastore.org/claude-code-settings.json"
COMPLETIONS_FILE = Path(__file__).parent.parent / "completions" / "claude.fish"
BEGIN_MARKER = "# BEGIN GENERATED CONFIG KEYS"
END_MARKER = "# END GENERATED CONFIG KEYS"

CONDITION = '__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set get'


def fetch_schema() -> dict:
    """Fetch the JSON schema from SchemaStore, following redirects."""
    req = urllib.request.Request(SCHEMA_URL, headers={"User-Agent": "fish-claude-completions/1.0"})
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


def extract_properties(schema: dict) -> list[tuple[str, str]]:
    """Extract (property_name, description) pairs from schema properties."""
    props = schema.get("properties", {})
    result = []
    for name, definition in sorted(props.items()):
        if name == "$schema":
            continue
        desc = definition.get("description", "")
        # Truncate long descriptions for fish completion display
        if len(desc) > 60:
            desc = desc[:57] + "..."
        # Escape any double quotes in descriptions
        desc = desc.replace('"', '\\"')
        result.append((name, desc))
    return result


def generate_completions(properties: list[tuple[str, str]]) -> str:
    """Generate fish completion lines for config keys."""
    lines = [BEGIN_MARKER]
    for name, desc in properties:
        line = f'complete -c claude -n "{CONDITION}" -xa {name}'
        if desc:
            line += f' -d "{desc}"'
        lines.append(line)
    lines.append(END_MARKER)
    return "\n".join(lines)


def patch_file(completions_text: str, generated_block: str) -> str:
    """Replace content between BEGIN/END markers with generated block."""
    pattern = re.compile(
        rf"^{re.escape(BEGIN_MARKER)}$.*?^{re.escape(END_MARKER)}$",
        re.MULTILINE | re.DOTALL,
    )
    if not pattern.search(completions_text):
        print(f"ERROR: Could not find {BEGIN_MARKER} / {END_MARKER} markers in completions file", file=sys.stderr)
        sys.exit(1)
    return pattern.sub(generated_block, completions_text)


def main() -> None:
    print(f"Fetching schema from {SCHEMA_URL}...")
    schema = fetch_schema()

    properties = extract_properties(schema)
    print(f"Found {len(properties)} config properties")

    generated = generate_completions(properties)

    completions_text = COMPLETIONS_FILE.read_text()
    patched = patch_file(completions_text, generated)

    if patched == completions_text:
        print("No changes needed -- completions are up to date")
        sys.exit(0)

    COMPLETIONS_FILE.write_text(patched)
    print(f"Updated {COMPLETIONS_FILE} with {len(properties)} config keys")


if __name__ == "__main__":
    main()
