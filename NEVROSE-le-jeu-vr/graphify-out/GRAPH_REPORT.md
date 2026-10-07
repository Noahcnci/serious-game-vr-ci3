# Graph Report - NEVROSE-le-jeu-vr  (2026-10-06)

## Corpus Check
- 5 files · ~3,212 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 20 file(s) not represented in the graph (top: .uid 7, .gd 6, (none) 2)

## Summary
- 47 nodes · 45 edges · 6 communities (5 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `10cafd6f`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- NÉVROSE — Game Design Document — VERSION FINALE (verrouillée)
- NÉVROSE — premier fragment VR (Meta Quest 2)
- 5. Mécaniques principales
- AGENTS.md
- codemap_gd.py
- CODEMAP GDScript — NÉVROSE

## God Nodes (most connected - your core abstractions)
1. `NÉVROSE — Game Design Document — VERSION FINALE (verrouillée)` - 11 edges
2. `NÉVROSE — premier fragment VR (Meta Quest 2)` - 8 edges
3. `5. Mécaniques principales` - 7 edges
4. `CODEMAP GDScript — NÉVROSE` - 7 edges
5. `parse_gd()` - 3 edges
6. `collect()` - 3 edges
7. `main()` - 3 edges
8. `render()` - 2 edges
9. `Pont graphify <-> GDScript pour NÉVROSE. graphify (extracteur AST) ne connaît…` - 1 edges
10. `graphify` - 1 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (6 total, 1 thin omitted)

### Community 0 - "NÉVROSE — Game Design Document — VERSION FINALE (verrouillée)"
Cohesion: 0.18
Nodes (10): 10. Bonus idées (hors scope jam), 1. Pitch, 2. Le thème « Assimiler », 3. Héros, 4. Contrôles (verrouillés), 6. Progression (rounds), 7. Direction artistique, 8. Confort VR (+2 more)

### Community 1 - "NÉVROSE — premier fragment VR (Meta Quest 2)"
Cohesion: 0.22
Nodes (8): Build APK (Meta Quest 2), Contrôles (GDD §4, verrouillés), Direction artistique "jolie mais pas gourmande", Graphify, Installer sur le casque (sideload), NÉVROSE — premier fragment VR (Meta Quest 2), Roadmap (extrait GDD §6), Tester sans casque

### Community 2 - "5. Mécaniques principales"
Cohesion: 0.29
Nodes (7): 5.1 La quête des pilules (cœur du jeu), 5.2 Jauge de schizo / folie, 5.3 Mimics (side content — mobs occasionnels, pas le cœur du jeu), 5.4 Destruction semi-permanente de l'appart, 5.5 Objets WTF, 5.6 Conteneurs verrouillés (détail), 5. Mécaniques principales

### Community 4 - "codemap_gd.py"
Cohesion: 0.27
Nodes (4): collect(), main(), parse_gd(), render()

### Community 5 - "CODEMAP GDScript — NÉVROSE"
Cohesion: 0.25
Nodes (7): Apartment (scripts/apartment.gd) — extends Node3D, CODEMAP GDScript — NÉVROSE, Dose (scripts/pill.gd) — extends Area3D, InteractiveContainer (scripts/container.gd) — extends Node3D, Main (scripts/main.gd) — extends Node3D, Mimic (scripts/mimic.gd) — extends Area3D, SmokeTest (tests/smoke_test.gd) — extends SceneTree

## Knowledge Gaps
- **29 isolated node(s):** `graphify`, `1. Pitch`, `2. Le thème « Assimiler »`, `3. Héros`, `4. Contrôles (verrouillés)` (+24 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 38 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NÉVROSE — Game Design Document — VERSION FINALE (verrouillée)` connect `NÉVROSE — Game Design Document — VERSION FINALE (verrouillée)` to `5. Mécaniques principales`?**
  _High betweenness centrality (0.111) - this node is a cross-community bridge._
- **What connects `graphify`, `1. Pitch`, `2. Le thème « Assimiler »` to the rest of the system?**
  _29 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Why does `5. Mécaniques principales` connect `5. Mécaniques principales` to `NÉVROSE — Game Design Document — VERSION FINALE (verrouillée)`?**
  _High betweenness centrality (0.078) - this node is a cross-community bridge._