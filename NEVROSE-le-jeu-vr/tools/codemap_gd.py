#!/usr/bin/env python3
"""Pont graphify <-> GDScript pour NÉVROSE.

graphify (extracteur AST) ne connaît pas l'extension .gd : les scripts Godot
étaient absents du graphe du projet. Ce script régénère ``docs/CODEMAP.md``,
un résumé structurel des scripts (.gd, .gdshader) qui LUI est indexé par
graphify. Le hook git post-commit l'appelle avant chaque rebuild, donc le
graphe couvre toujours la couche code du projet.

Pure stdlib, déterministe, aucun coût API.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCAN_DIRS = ("scripts", "tests", "scenes")
OUT = ROOT / "docs" / "CODEMAP.md"

CLASS_RE = re.compile(r"^class_name\s+(\w+)")
EXTENDS_RE = re.compile(r"^extends\s+(.+)$")
FUNC_RE = re.compile(r"^(?:static\s+)?func\s+(\w+)\s*\(([^)]*)\)")
SIGNAL_RE = re.compile(r"^signal\s+(\w+)")
DOC_RE = re.compile(r"^##\s?(.*)$")
CONST_RE = re.compile(r"^const\s+(\w+)")


def parse_gd(path: Path) -> dict:
    info = {
        "file": path.relative_to(ROOT).as_posix(),
        "class_name": "",
        "extends": "",
        "doc": "",
        "consts": [],
        "signals": [],
        "funcs": [],
    }
    pending_doc: list[str] = []
    try:
        text = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError):
        return info
    for line in text.splitlines():
        stripped = line.rstrip()
        doc_m = DOC_RE.match(stripped)
        if doc_m:
            pending_doc.append(doc_m.group(1).strip())
            continue
        cm = CLASS_RE.match(stripped)
        if cm:
            info["class_name"] = cm.group(1)
            if pending_doc and not info["doc"]:
                info["doc"] = " ".join(pending_doc).strip()
            pending_doc = []
            continue
        em = EXTENDS_RE.match(stripped)
        if em and not info["extends"]:
            info["extends"] = em.group(1).strip()
            pending_doc = []
            continue
        fm = FUNC_RE.match(stripped)
        if fm:
            brief = " ".join(pending_doc).strip()
            args = fm.group(2).strip()
            info["funcs"].append((fm.group(1), args, brief))
            pending_doc = []
            continue
        sm = SIGNAL_RE.match(stripped)
        if sm:
            info["signals"].append(sm.group(1))
            pending_doc = []
            continue
        km = CONST_RE.match(stripped)
        if km:
            info["consts"].append(km.group(1))
            pending_doc = []
            continue
        if stripped and not stripped.startswith("#"):
            pending_doc = []
    return info


def collect() -> list[dict]:
    entries: list[dict] = []
    for d in SCAN_DIRS:
        base = ROOT / d
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*")):
            if p.suffix in (".gd", ".gdshader") and p.is_file():
                if p.suffix == ".gd":
                    entries.append(parse_gd(p))
    return entries


def render(entries: list[dict]) -> str:
    lines: list[str] = [
        "# CODEMAP GDScript — NÉVROSE",
        "",
        "Fichier GÉNÉRÉ par `tools/codemap_gd.py` (appelé par le hook git",
        "post-commit graphify). Ne pas éditer à la main : représentation",
        "indexable du code GDScript dans le graphe graphify, car l'extracteur",
        "AST de graphify ne supporte pas l'extension `.gd`.",
        "",
    ]
    for e in entries:
        title = e["class_name"] or Path(e["file"]).stem
        ext = f" — extends {e['extends']}" if e["extends"] else ""
        lines.append(f"## {title} ({e['file']}){ext}")
        lines.append("")
        if e["doc"]:
            lines.append(e["doc"])
            lines.append("")
        if e["consts"]:
            lines.append("- const: " + ", ".join(f"`{c}`" for c in e["consts"]))
        if e["signals"]:
            lines.append("- signals: " + ", ".join(f"`{s}`" for s in e["signals"]))
        for name, args, brief in e["funcs"]:
            sig = f"{name}({args})" if args else f"{name}()"
            lines.append(f"- `{sig}`" + (f" — {brief}" if brief else ""))
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    entries = collect()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(render(entries), encoding="utf-8")
    print(f"[codemap] {len(entries)} script(s) -> {OUT.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
