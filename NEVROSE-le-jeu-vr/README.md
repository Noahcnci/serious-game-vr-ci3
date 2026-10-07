# NÉVROSE — premier fragment VR (Meta Quest 2)

Jeu de fouille d'appartement sous pression de schizophrénie (voir `ASSIMILE_GDD.md`,
version verrouillée). Ce dépôt contient le **premier fragment jouable** : un studio
procédural, la quête des pilules, la jauge de folie, un mimic statique, et
l'export APK pour Meta Quest 2.

## Contrôles (GDD §4, verrouillés)

| Action | Quest 2 | Bureau (debug/tests) |
|---|---|---|
| Déplacement | stick gauche, vitesse constante | WASD / flèches |
| Rotation | stick droit : snap 45° | Q / E ou clic droit |
| Interagir (ouvrir, prendre) | gâchette index, rayon depuis la main droite | F / clic gauche (rayon caméra) |
| Restart après assimilation | gâchette | clic |

## Tester sans casque

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd
```

24 assertions : structure XR, construction de l'appart, montée de la schizo,
prise de dose, ouverture de tiroir, snap turn, game over / restart.

Pour jouer au clavier/souris : ouvrir le projet dans l'éditeur Godot 4.7.2 et
lancer `scenes/main.tscn` (OpenXR absent → fallback bureau automatique).

## Build APK (Meta Quest 2)

Prérequis (déjà installés sur cette machine) :

- Godot 4.7.2 + templates d'export `4.7.2-stable` dans
  `%APPDATA%\Godot\export_templates\4.7.2.stable\`
- Android SDK : `%LOCALAPPDATA%\Android\Sdk` (platform-tools, platforms;android-34,
  build-tools;34.0.0)
- JDK 21 (Temurin), chemin inscrit dans `export/android/java_sdk_path`
  des paramètres éditeur Godot
- Keystore debug : `%USERPROFILE%\.android\debug.keystore` (android/android)

Commande (headless, depuis la racine du projet) :

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-debug "Meta Quest 2" build/nevrose_quest2.apk
```

Ou dans l'éditeur : Projet > Exporter > Meta Quest 2 > Exporter le projet.

Le preset est configuré : Gradle build, arm64-v8a uniquement, XR Mode = OpenXR,
immersif, signé avec le keystore debug (sideload). Version release = passer un
vrai keystore dans le preset.

## Installer sur le casque (sideload)

1. Activer le mode développeur sur le Quest 2 (application Meta > casque).
2. Brancher le casque en USB, accepter la popup "Autoriser le débogage USB".
3. `adb devices` → le casque apparaît.
4. `adb install -r build/nevrose_quest2.apk`
5. Lancer "NÉVROSE" depuis la bibliothèque d'applications (Sources inconnues).

## Direction artistique "jolie mais pas gourmande"

- Zéro texture importée : ~15 matériaux à couleur plate partagés par toute la scène.
- Une primitive partagée (cube unité mis à l'échelle) pour 95 % des meshes.
- 2 OmniLights sans ombre dynamique + émissifs (lampe, plafonnier, vitre, pilule).
- Renderer Compatibility (OpenGL) — recommandé par la doc Godot pour le XR Android.
- La folie se lit sur le monde : les matériaux glissent vers un vert malade,
  la lampe grésille, la vignette shader pulse (quelques instructions).
- Pas d'audio, pas de physique autre que les raycasts d'interaction : APK minuscule.

## Graphify

Ce projet utilise [graphify](https://github.com/Graphify-Labs/graphify) :
`AGENTS.md` (racine) dit à tout agent de consulter `graphify query/explain/path`
avant de lire le code brut, et les hooks git `post-commit`/`post-checkout`
reconstruisent `graphify-out/graph.json` à chaque commit. Commandes utiles :

```
graphify query "comment spawnent les pilules"
graphify explain "Dose"
graphify affected "Apartment"
graphify update .   # AST uniquement, sans coût API
```

## Roadmap (extrait GDD §6)

- [x] Round 1 : pilules faciles, conteneurs ouvrables, premier mimic statique
- [ ] Round 2 : conteneurs verrouillés (clé/code), mimics en duo indiscernables
- [ ] Round 3 : mimics mobiles, montée de schizo plus rapide
- [ ] Round 4 : objets WTF, leurres audio, mimics imitant des pilules
- [ ] Round 5 : dégradation de l'appart (couloirs longs, murs qui respirent)
- [ ] Round 6 : boss final — la dernière pilule au cœur de la folie
