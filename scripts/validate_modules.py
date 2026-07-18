#!/usr/bin/env python3
"""HermesForge module-contract validator.

Checks every modules/<name>/ folder against modules/README.md:
  - AGENT.md exists with valid YAML frontmatter and required fields
  - required markdown sections present (For humans / For agents / What it does)
  - addon/ non-empty and contains a LICENSE* file
  - every recipe listed in frontmatter exists as recipes/<id>.recipe.json
    and parses as JSON with the required recipe keys
  - tests/ folder exists

Exit 0 if all modules pass, 1 otherwise. No third-party deps (PyYAML optional).
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODULES = ROOT / "modules"

REQUIRED_FM = [
    "name", "display_name", "version", "upstream", "upstream_license",
    "godot_min", "godot_max", "type", "provides", "recipes", "status",
]
REQUIRED_SECTIONS = ["## What it does", "## For humans", "## For agents"]
RECIPE_KEYS = ["id", "module", "description", "params"]
VALID_STATUS = {"vendored", "bridged", "tested"}
VALID_TYPE = {"gdextension", "gdscript_plugin", "hybrid", "builtin"}


def parse_frontmatter(text: str):
    """Minimal YAML-frontmatter parser (no PyYAML dependency).

    Handles the flat/scalar + string-list subset the manifests use.
    Returns (dict, body_markdown) or (None, error_message).
    """
    if not text.startswith("---"):
        return None, "missing opening ---"
    end = text.find("\n---", 3)
    if end == -1:
        return None, "missing closing ---"
    fm_text = text[3:end].strip("\n")
    body = text[end + 4:]
    data, current_key = {}, None
    for line in fm_text.splitlines():
        if not line.strip() or line.strip().startswith("#"):
            continue
        m = re.match(r"^(\w[\w]*)\s*:\s*(.*)$", line)
        if m and not line.startswith((" ", "\t", "-")):
            key, val = m.group(1), m.group(2).strip()
            if val == "":
                data[key] = []
                current_key = key
            else:
                data[key] = val.strip('"').strip("'")
                current_key = None
        elif line.strip().startswith("-") and current_key:
            data[current_key].append(line.strip()[1:].strip())
        else:
            return None, f"unparseable line: {line!r}"
    return data, body


def fail(msgs, module, msg):
    msgs.append(f"[{module}] {msg}")


def validate_module(mod_dir: Path, errors: list):
    name = mod_dir.name
    agent = mod_dir / "AGENT.md"
    if not agent.exists():
        return fail(errors, name, "AGENT.md missing")
    fm, body_or_err = parse_frontmatter(agent.read_text(encoding="utf-8"))
    if fm is None:
        return fail(errors, name, f"AGENT.md frontmatter: {body_or_err}")
    body = body_or_err

    for key in REQUIRED_FM:
        if key not in fm or fm[key] in ("", []):
            fail(errors, name, f"AGENT.md frontmatter missing field: {key}")
    if fm.get("name") and fm["name"] != name:
        fail(errors, name, f"frontmatter name '{fm['name']}' != folder '{name}'")
    if fm.get("status") and fm["status"] not in VALID_STATUS:
        fail(errors, name, f"status '{fm['status']}' not in {sorted(VALID_STATUS)}")
    if fm.get("type") and fm["type"] not in VALID_TYPE:
        fail(errors, name, f"type '{fm['type']}' not in {sorted(VALID_TYPE)}")
    for section in REQUIRED_SECTIONS:
        if section not in body:
            fail(errors, name, f"AGENT.md missing section '{section}'")

    addon = mod_dir / "addon"
    if not addon.is_dir() or not any(addon.iterdir()):
        fail(errors, name, "addon/ missing or empty")
    elif not list(addon.glob("LICENSE*")) and not list(addon.glob("**/LICENSE*")):
        fail(errors, name, "addon/ has no LICENSE* file (upstream license required)")

    recipes = fm.get("recipes", [])
    for recipe_id in recipes:
        rpath = mod_dir / "recipes" / f"{recipe_id}.recipe.json"
        if not rpath.exists():
            fail(errors, name, f"recipe '{recipe_id}' listed but {rpath.name} missing")
            continue
        try:
            rdata = json.loads(rpath.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            fail(errors, name, f"recipe '{recipe_id}' invalid JSON: {e}")
            continue
        for key in RECIPE_KEYS:
            if key not in rdata:
                fail(errors, name, f"recipe '{recipe_id}' missing key '{key}'")
        if rdata.get("module") and rdata["module"] != name:
            fail(errors, name, f"recipe '{recipe_id}' module field != '{name}'")

    # tests/ contract: a module either ships its own golden test dir(s), or
    # documents where its end-to-end coverage lives (the templates/golden-demo
    # harness). A tests/README.md pointing at the golden tests satisfies the
    # contract; a bare empty tests/ dir does not (it's untracked by git anyway).
    tests_dir = mod_dir / "tests"
    if not tests_dir.is_dir():
        fail(errors, name, "tests/ folder missing")
    elif not any(tests_dir.iterdir()):
        fail(errors, name, "tests/ folder empty (add a golden test or a README.md pointing at templates/golden-demo)")


def main() -> int:
    if not MODULES.is_dir():
        print("no modules/ directory found", file=sys.stderr)
        return 1
    errors: list = []
    modules = [d for d in sorted(MODULES.iterdir()) if d.is_dir()]
    if not modules:
        print("no modules found", file=sys.stderr)
        return 1
    for mod_dir in modules:
        validate_module(mod_dir, errors)
    for e in errors:
        print(f"FAIL {e}")
    print(f"\n{len(modules)} module(s) checked: " +
          ("ALL PASS" if not errors else f"{len(errors)} problem(s)"))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
