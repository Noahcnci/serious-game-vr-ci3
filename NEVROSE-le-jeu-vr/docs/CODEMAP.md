# CODEMAP GDScript — NÉVROSE

Fichier GÉNÉRÉ par `tools/codemap_gd.py` (appelé par le hook git
post-commit graphify). Ne pas éditer à la main : représentation
indexable du code GDScript dans le graphe graphify, car l'extracteur
AST de graphify ne supporte pas l'extension `.gd`.

## Apartment (scripts/apartment.gd) — extends Node3D

- const: `ROOM_W`, `ROOM_D`, `ROOM_H`, `WALL_T`
- `_ready()`
- `_make_materials()`
- `_reg(key: String, calm: Color, sick: Color, breathes := true)`
- `_emissive_mat(key: String, color: Color, energy: float)`
- `_box(parent: Node, name: String, size: Vector3, pos: Vector3, mat: Material)`
- `_cyl(parent: Node, name: String, radius: float, height: float, pos: Vector3, mat: Material)`
- `_make_container(parent: Node, name: String, cmode: InteractiveContainer.Mode, slot_pos: Vector3, axis: Vector3, dist: float, angle := 115.0)`
- `build()`
- `_build_shell()`
- `_build_kitchen()`
- `_build_bed()`
- `_build_wardrobe()`
- `_build_table_set()`
- `_build_shelf()`
- `_build_lamp_and_lights()`
- `_build_window()`
- `_build_mimic_mugs()`
- `_register_spawn_spots()`
- `spawn_dose()` — Nouvelle run / nouvelle dose : une pilule apparaît dans un conteneur (ou sur une surface) tiré au hasard.
- `clear_dose()`
- `reset_containers()` — Reset de run : referme les conteneurs ouverts (GDD §5.4 réparation = super-médoc, ici on répare "manuellement" pour la boucle test).
- `set_insanity(t: float)`
- `_process(_delta: float)`

## InteractiveContainer (scripts/container.gd) — extends Node3D

- const: `OPEN_TIME`
- `_init(p_mode: Mode, p_axis: Vector3 = Vector3.BACK, p_dist: float = 0.45, p_angle: float = 115.0)`
- `_ready()`
- `on_pointed()` — Raycast (main.gd) : la zone d'interaction est l'Area3D enfant.
- `on_unpointed()`
- `interact()`
- `_reveal_dose()`

## Main (scripts/main.gd) — extends Node3D

- const: `SNAP_TURN_RAD`, `MOVE_SPEED`, `STICK_DEADZONE`, `SNAP_COOLDOWN`, `RAY_LENGTH`, `SANITY_RATE`, `SANITY_DOSE_RELIEF`, `SANITY_RATE_AFTER_DOSE`, `ROOM_MIN`, `ROOM_MAX`, `FOLIE_LEGERE`, `FOLIE_FORTE`, `FOLIE_CRITIQUE`, `CHAT_CALME`, `CHAT_INQUIET`, `CHAT_CRITIQUE`
- `_ready()`
- `_init_openxr()`
- `is_xr_active()`
- `_build_world()`
- `_build_hud()`
- `_register_debug_inputs()`
- `_add_key_action(action: StringName, keycodes: Array)`
- `_add_event_action(action: StringName, event: InputEvent)`
- `_unhandled_input(event: InputEvent)`
- `_physics_process(delta: float)`
- `_tick_sanity(delta: float)`
- `_tick_movement(delta: float)`
- `snap_turn(direction: float)`
- `_tick_interaction_ray()`
- `interact()`
- `on_dose_taken()`
- `on_mimic_purged()`
- `_spawn_dose()`
- `_tick_sanity_feedback(delta: float)`
- `_tick_chat(delta: float, t: float)`
- `_update_chat(text: String)`
- `_trigger_game_over()`
- `_restart()`
- `_pulse_haptics()`
- `_on_right_button_pressed(action_name: String)`
- `_on_left_button_pressed(action_name: String)`
- `_process(_delta: float)`

## Mimic (scripts/mimic.gd) — extends Area3D

- `_ready()`
- `_process(_delta: float)`
- `on_pointed()`
- `on_unpointed()`
- `interact()`

## Dose (scripts/pill.gd) — extends Area3D

- const: `PILL_COLOR`
- `_ready()`
- `_process(delta: float)`
- `on_pointed()`
- `on_unpointed()`
- `interact()`

## SmokeTest (tests/smoke_test.gd) — extends SceneTree

- `_assert(cond: bool, label: String)`
- `_initialize()`
- `_finish()`
