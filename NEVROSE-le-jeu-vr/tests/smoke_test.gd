class_name SmokeTest
extends SceneTree
## Test fonctionnel headless — lance :
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd
##
## Scénarios :
##   A — la scène principale s'instancie, les nœuds XR existent, le lobby précède la partie
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

	# --- A : lobby (avant le départ) ---
	var lobby: LobbyWorld = main.lobby
	_assert(lobby != null, "A: lobby présent au boot")
	_assert(not main.game_started, "A: partie non lancée au boot")
	_assert(main.apartment == null, "A: appartement absent avant le départ")
	_assert(main.phone == null, "A: téléphone absent avant le départ")
	var sanity_lobby: float = main.sanity
	for i in 10:
		await physics_frame
	_assert(main.sanity == sanity_lobby, "A: folie figée dans le lobby")
	lobby.computer.on_unpointed()
	_assert(not lobby.computer.play_prompt.visible, "A: prompt masqué quand l'ordinateur n'est pas visé")
	lobby.computer.on_pointed()
	_assert(lobby.computer.play_prompt.visible, "A: prompt visible au survol de l'ordinateur")

	# Le vrai dispatch passe par l'objet pointé puis par interact().
	main._pointed = main.lobby.computer
	main.interact()
	await process_frame
	await process_frame
	_assert(main.game_started, "A: l'ordinateur lance la partie")
	_assert(main.lobby == null, "A: référence du lobby effacée après le départ")
	_assert(not is_instance_valid(lobby), "A: lobby libéré après le départ")

	# --- A : smartphone (créé après le départ) ---
	_assert(main.phone != null, "A: smartphone Messenger présent")
	_assert(not main.phone.is_in_hand, "A: téléphone initialement dans la poche")
	main.phone.toggle_pocket()
	_assert(main.phone.is_in_hand, "A: sortie du téléphone de la poche vers la main")
	main.phone.toggle_pocket()
	_assert(not main.phone.is_in_hand, "A: retour du téléphone dans la poche")

	# --- B : appartement (Map2Extended — salon + cuisine + extension) ---
	var apt: MapBase = main.apartment
	_assert(apt != null, "B: appartement (MapBase) instancié")
	_assert(apt.get_node_or_null("Shell/Floor") != null, "B: sol construit")
	_assert(apt.get_node_or_null("Shell/WallN") != null, "B: mur nord construit")
	_assert(apt.get_node_or_null("Kitchen") != null, "B: cuisine construite")
	_assert(apt.get_node_or_null("LivingRoom") != null, "B: salon construit")
	_assert(apt.containers.size() >= 5, "B: conteneurs interactifs (tiroirs + placard) : %d" % apt.containers.size())
	_assert(apt.get_node_or_null("MugMimic") != null, "B: mimic statique présent (round 1)")
	_assert(apt.get_node_or_null("SideTableMimic") != null, "B: 2e mimic statique présent (table d'appoint)")
	_assert(apt.mimics.size() >= 2, "B: au moins 2 mimics dans la map : %d" % apt.mimics.size())
	_assert(apt.get_node_or_null("Extension") == null, "B: ancien runtime Extension absent")
	_assert(apt.get_node_or_null("Shell/ExtensionEst") != null, "B: extension éditée présente")
	var chemins_extension := [
		"Shell/ExtensionEst/Chambre/LitDouble",
		"Shell/ExtensionEst/Chambre/Bureau",
		"Shell/ExtensionEst/Garage/LaveLinge",
		"Shell/ExtensionEst/SDB/Baignoire",
		"Shell/ExtensionEst/Dressing/Armoire1",
	]
	for chemin in chemins_extension:
		var meuble := apt.get_node_or_null(chemin) as Node3D
		_assert(meuble != null, "B: meuble présent : %s" % chemin)
		if meuble != null:
			_assert(is_equal_approx(meuble.scale.x, meuble.scale.y) and is_equal_approx(meuble.scale.x, meuble.scale.z), "B: échelle uniforme : %s" % chemin)

	# --- B : pitch de la souris en fallback bureau ---
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(0.0, 100.0)
	main._update_desktop_look(mouse_motion.relative)
	_assert(not is_zero_approx(main.xr_camera.rotation.x), "B: le pitch souris modifie la caméra")
	mouse_motion.relative = Vector2(0.0, 100000.0)
	main._update_desktop_look(mouse_motion.relative)
	_assert(is_equal_approx(main.xr_camera.rotation.x, deg_to_rad(-80.0)), "B: le pitch reste clampé à -80°")
	mouse_motion.relative = Vector2(0.0, -200000.0)
	main._update_desktop_look(mouse_motion.relative)
	_assert(is_equal_approx(main.xr_camera.rotation.x, deg_to_rad(80.0)), "B: le pitch reste clampé à +80°")
	main._desktop_pitch = 0.0
	main.xr_camera.rotation.x = 0.0

	# --- B : collisions de la capsule avec les murs et les meubles ---
	main.xr_origin.position = Vector3(6.5, 1.7, 2.0)
	main._move_with_collisions(Vector3(0.0, 0.0, -2.0))
	await physics_frame
	await physics_frame
	_assert(main.xr_origin.position.z > 1.4, "B: le mur du couloir bloque la capsule (z = %.2f)" % main.xr_origin.position.z)
	main.xr_origin.position = Vector3(1.675, 1.7, -1.0)
	main._move_with_collisions(Vector3(0.0, 0.0, -3.0))
	await physics_frame
	await physics_frame
	_assert(main.xr_origin.position.z > -2.15, "B: le frigo bloque la capsule (z = %.2f)" % main.xr_origin.position.z)
	main.xr_origin.position = Vector3(0.0, 1.7, 0.0)
	main.xr_origin.rotation = Vector3.ZERO
	main.xr_camera.rotation = Vector3.ZERO
	main._desktop_yaw = 0.0
	main._desktop_pitch = 0.0

	# --- B : une seule voix à la fois, intro comprise ---
	_assert(main.creepy_voices._is_voice_playing(), "B: le murmure d'introduction est actif")
	main.creepy_voices._play_random_voice(0.5)
	var voices_playing := 0
	for player in main.creepy_voices._players:
		if player.playing:
			voices_playing += 1
	_assert(voices_playing == 1, "B: aucune voix ne se superpose à l'intro")
	for player in main.creepy_voices._players:
		player.stop()
	main.creepy_voices._play_random_voice(0.5)
	voices_playing = 0
	for player in main.creepy_voices._players:
		if player.playing:
			voices_playing += 1
	_assert(voices_playing == 1, "B: une voix aléatoire démarre après l'arrêt des players")
	for player in main.creepy_voices._players:
		player.stop()

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
	# On prend le premier tiroir NON verrouillé (un tiroir verrouillé
	# répondrait par un flash "verrouillé" au lieu de s'ouvrir).
	var drawer: InteractiveContainer = null
	for c in apt.containers:
		if c.mode == InteractiveContainer.Mode.SLIDE and not c.is_locked:
			drawer = c
			break
	_assert(drawer != null, "E: tiroir trouvé")
	drawer.interact()
	await create_timer(0.6).timeout
	_assert(drawer.is_open, "E: le tiroir s'ouvre")
	_assert(drawer.position.z > -2.1, "E: le tiroir a glissé (z = %.2f)" % drawer.position.z)
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
	# En fallback bureau, seul le game over dédié reste visible.
	_assert(main.gameover_label.visible, "GO: game over bureau visible en fallback desktop")
	_assert(not main.vr_gameover_label.visible, "GO: game over VR masqué en fallback desktop")
	_assert(not main.chat_label.visible, "GO: chat masqué pendant le game over")
	_assert(not main.center_dot.visible, "GO: point central masqué pendant le game over")
	main._restart()
	_assert(not main.game_over and main.sanity == 0.0, "GO: le restart réinitialise la run")
	# Le restart restaure le HUD et masque les deux écrans de game over.
	_assert(main.chat_label.visible, "GO: chat réaffiché après le restart")
	_assert(main.center_dot.visible, "GO: point central réaffiché après le restart")
	_assert(not main.gameover_label.visible, "GO: game over bureau masqué après le restart")
	_assert(not main.vr_gameover_label.visible, "GO: game over VR masqué après le restart")

	_finish()


func _finish() -> void:
	print("=== RESULTAT: %s (%d échec(s)) ===" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
