#!/usr/bin/env python3
"""Verify config/Config.qml declares exactly what config/defaults.lua defines.

The two files necessarily duplicate the schema: defaults.lua drives the merge and
validation pass, Config.qml exposes the result to QML. JsonAdapter silently drops
any JSON key it has not declared, so a property missing here does not error --
the option just stops working, with no diagnostic anywhere. That failure mode is
invisible enough to be worth a dedicated check.

Run from the shell root:  python3 scripts/check-schema.py
Exit status 0 when they agree, 1 otherwise.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# QML declared type -> acceptable Python types for the Lua default.
# `var` accepts anything, which is the point of using it for variable-shape data.
TYPEMAP = {
    "int": (int,),
    "real": (int, float),
    "bool": (bool,),
    "string": (str,),
    "var": None,
}

SECTION_RE = re.compile(r"property\s+JsonObject\s+(\w+)\s*:\s*JsonObject\s*\{")
PROPERTY_RE = re.compile(r"property\s+(\w+)\s+(\w+)\s*:")


def compiled_config() -> dict:
    result = subprocess.run(
        ["lua", "config/compile.lua", "--print"],
        cwd=ROOT, capture_output=True, text=True,
    )
    if result.returncode != 0:
        sys.exit(f"compile.lua failed ({result.returncode}):\n{result.stderr}")
    return json.loads(result.stdout)


def declared_properties(qml: str) -> dict:
    """Section name -> {property name: declared QML type}."""
    body = qml[qml.index("JsonAdapter {"):]
    sections = {}

    for match in SECTION_RE.finditer(body):
        # Brace-match to find where this section ends, so nested blocks and
        # comments containing braces cannot confuse the extraction.
        depth, i = 1, match.end()
        while depth and i < len(body):
            if body[i] == "{":
                depth += 1
            elif body[i] == "}":
                depth -= 1
            i += 1

        inner = body[match.end():i - 1]
        sections[match.group(1)] = {
            name: qtype
            for qtype, name in (m.groups() for m in PROPERTY_RE.finditer(inner))
            if name != "JsonObject"
        }

    return sections


def compare(lua_sections: dict, qml_sections: dict) -> list:
    problems = []

    for name in sorted(set(lua_sections) - set(qml_sections)):
        problems.append(f"section {name!r} is in defaults.lua but not declared in Config.qml")
    for name in sorted(set(qml_sections) - set(lua_sections)):
        problems.append(f"section {name!r} is in Config.qml but not in defaults.lua")

    for section in sorted(set(lua_sections) & set(qml_sections)):
        lua_props = lua_sections[section]
        qml_props = qml_sections[section]

        for key in sorted(set(lua_props) - set(qml_props)):
            problems.append(
                f"{section}.{key} is configurable in Lua but not declared in QML "
                f"(it would be silently ignored)"
            )
        for key in sorted(set(qml_props) - set(lua_props)):
            problems.append(
                f"{section}.{key} is declared in QML but has no default in Lua "
                f"(it would never be populated)"
            )

        for key in sorted(set(lua_props) & set(qml_props)):
            value, qtype = lua_props[key], qml_props[key]
            expected = TYPEMAP.get(qtype)
            if expected is None:
                continue

            if isinstance(value, bool):
                if qtype != "bool":
                    problems.append(f"{section}.{key}: Lua bool vs QML {qtype}")
            elif isinstance(value, (list, dict)):
                problems.append(
                    f"{section}.{key}: Lua {type(value).__name__} needs `var`, "
                    f"QML declares {qtype}"
                )
            elif isinstance(value, str):
                if qtype != "string":
                    problems.append(f"{section}.{key}: Lua string vs QML {qtype}")
            elif not isinstance(value, expected):
                problems.append(
                    f"{section}.{key}: Lua {type(value).__name__} vs QML {qtype}"
                )

    return problems


def main() -> int:
    config = compiled_config()
    lua_sections = {k: v for k, v in config.items() if isinstance(v, dict)}
    qml_sections = declared_properties((ROOT / "config/Config.qml").read_text())

    lua_count = sum(len(v) for v in lua_sections.values())
    qml_count = sum(len(v) for v in qml_sections.values())
    print(f"defaults.lua  {len(lua_sections):>3} sections  {lua_count:>4} options")
    print(f"Config.qml    {len(qml_sections):>3} sections  {qml_count:>4} properties")

    problems = compare(lua_sections, qml_sections)
    if problems:
        print(f"\n{len(problems)} mismatch(es):")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print("\nschema matches exactly")
    return 0


if __name__ == "__main__":
    sys.exit(main())
