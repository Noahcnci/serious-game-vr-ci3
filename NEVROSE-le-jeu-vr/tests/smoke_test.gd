class_name SmokeTest
extends SceneTree
## Test fonctionnel headless — lance :
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd
##
## Scénarios :
##   A — la scène principale s'instancie, les nœuds XR existent
##   B — l'appartement procédural est construit (coquille + meubles + conteneurs)
##   C — la jauge de schizo monte avec le temps (GDD §5.2)
##   D — la pilule spawne ; la prendre soulage la schizo (GDD §5.1)
##   E — un conteneur s'ouvre et révèle son contenu
##   F — le snap turn 45° tourne l'origine (GDD §4/§8)

var _failures := 0


func _assert(cond: bool, label: String) -> void:
	if cond:
		print("  [OK] ", label)
	else:
		_failures += 1
		printerr("  [ECHEC] ", label)


func _initialize() -> void:
	print("=== SMOKE TEST NÉVROSE ===")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_assert(packed != null, "A: main.tscn se charge")
	if packed == null:
		_finish()
		return

	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# --- A : structure XR ---
	_assert(main.get_node_or_null("XROrigin3D/XRCamera3D") != null, "A: XRCamera3D présente")
	_assert(main.get_node_or_null("XROrigin3D/LeftHand") != null, "A: manette gauche présente")
	_assert(main.get_node_or_null("XROrigin3D/RightHand") != null, "A: manette droite présente")
	_assert(main.is_xr_active() == false, "A: headless = fallback bureau (OpenXR inactif)")

	# --- B : appartement (Map2Living — salon + cuisine) ---
	var apt: MapBase = main.apartment
	_assert(apt != null, "B: appartement (MapBase) instancié")
	_assert(apt.get_node_or_null("Shell/Floor") != null, "B: sol construit")
	_assert(apt.get_node_or_null("Shell/WallN") != null, "B: mur nord construit")
	_assert(apt.get_node_or_null("Kitchen") != null, "B: cuisine construite")
	_assert(apt.get_node_or_null("LivingRoom") != null, "B: salon construit")
	_assert(apt.containers.size() >= 5, "B: conteneurs interactifs (tiroirs + placard) : %d" % apt.containers.size())
	_assert(apt.get_node_or_null("MugMimic") != null, "B: mimic statique présent (round 1)")

	# --- C : montée de la schizo ---
	var s0: float = main.sanity
	for i in 30:
		await physics_frame
	_assert(main.sanity > s0, "C: la schizo monte toute seule (%.2f -> %.2f)" % [s0, main.sanity])

	# --- D : dose ---
	_assert(is_instance_valid(apt._dose), "D: une dose a spawné")
	var s_before_dose: float = main.sanity
	main.on_dose_taken() # simule la prise (la dose se libère dans la foulée)
	await process_frame
	_assert(main.sanity < s_before_dose, "D: la dose reset la schizo (%.2f -> %.2f)" % [s_before_dose, main.sanity])
	_assert(main.dose_count == 1, "D: compteur de doses = 1")

	# --- E : conteneur ---
	var drawer: InteractiveContainer = null
	for c in apt.containers:
		if c.mode == InteractiveContainer.Mode.SLIDE:
			drawer = c
			break
	_assert(drawer != null, "E: tiroir trouvé")
	drawer.interact()
	await create_timer(0.6).timeout
	_assert(drawer.is_open, "E: le tiroir s'ouvre")
	_assert(drawer.position.z > -2.0, "E: le tiroir a glissé (z = %.2f)" % drawer.position.z)
	drawer.interact()
	await create_timer(0.6).timeout
	_assert(not drawer.is_open, "E: le tiroir se referme")

	# --- F : snap turn ---
	var yaw0: float = main.xr_origin.rotation.y
	main.snap_turn(1.0)
	_assert(is_equal_approx(main.xr_origin.rotation.y, yaw0 - PI / 4.0), "F: snap turn -45°")

	# --- Game over ---
	main.sanity = 99.9
	for i in 10:
		await physics_frame
	_assert(main.game_over, "GO: 100% de schizo déclenche l'assimilation")
	main._restart()
	_assert(not main.game_over and main.sanity == 0.0, "GO: le restart réinitialise la run")

	_finish()


func _finish() -> void:
	print("=== RESULTAT: %s (%d échec(s)) ===" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
