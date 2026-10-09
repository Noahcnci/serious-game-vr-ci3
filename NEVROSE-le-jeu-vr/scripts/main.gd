class_name Main
extends Node3D
## Point d'entrée de NÉVROSE — premier fragment jouable (Meta Quest 2).
##
## GDD §4/§5 : stick gauche = déplacement constant, stick droit = snap 45°,
## gâchettes = interagir/tirer. La jauge de schizo monte tant que la pilule
## n'est pas trouvée ; la pilule spawne dans un conteneur aléatoire (GDD §5.1).

# ---------------------------------------------------------------------------
# Constantes de jeu (tweakables)
# ---------------------------------------------------------------------------
const SNAP_TURN_RAD := PI / 4.0 # 45° — confort VR (GDD §8)
const MOVE_SPEED := 1.8 # m/s, vitesse constante, aucune dérive (GDD §4)
const STICK_DEADZONE := 0.15
const SNAP_COOLDOWN := 0.25 # s entre deux snaps
const RAY_LENGTH := 3.0

const SANITY_RATE := 1.4 # points/seconde tant que pas de dose (monte "vite")
const SANITY_DOSE_RELIEF := 55.0 # reset partiel à la prise (GDD §5.1)
const SANITY_RATE_AFTER_DOSE := 0.7 # la montée ralentit après une dose
const SANITY_RATE_ESCALATION := 0.3 # Round 3 : +0.3 par round (dose_count)

# Limites de la pièce pour le clamp de déplacement (mur = mur, zéro collision coûteuse)
# Map 2 (salon+cuisine) : 8 x 6 m → x ∈ [-3.7, 3.7], z ∈ [-2.7, 2.7]
const ROOM_MIN := Vector2(-3.7, -2.7)
const ROOM_MAX := Vector2(3.7, 2.7)

# Seuils de folie (GDD §5.2) : la folie se lit sur le monde, pas sur une barre.
const FOLIE_LEGERE := 35.0 # vignette douce
const FOLIE_FORTE := 65.0 # vignette marquée + murs qui respirent
const FOLIE_CRITIQUE := 88.0 # teinte critique + messages urgents

# ---------------------------------------------------------------------------
# Nœuds XR (résolus dans main.tscn)
# ---------------------------------------------------------------------------
@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand

# Mains animées (godot-xr-tools) — le script hand.gd lit grip/trigger du
# XRController3D parent et pilote le blend tree automatiquement.
var _left_hand_mesh: Node3D = null
var _right_hand_mesh: Node3D = null
var _body: VRBody = null
var _held_key: KeyObject = null ## Clé actuellement dans la main (GDD §5.6)
const HAND_SCENE_R := preload("res://addons/godot-xr-tools/hands/scenes/lowpoly/right_hand_low.tscn")
const HAND_SCENE_L := preload("res://addons/godot-xr-tools/hands/scenes/lowpoly/left_hand_low.tscn")
# Distance max pour interagir "au contact" (proximité) sans viser au rayon
const PROXIMITY_RADIUS := 0.45

# ---------------------------------------------------------------------------
# État de partie
# ---------------------------------------------------------------------------
var xr_interface: XRInterface
var xr_active := false
var sanity := 0.0
var sanity_rate := SANITY_RATE
var game_over := false
var dose_count := 0

var _snap_cooldown := 0.0
var _desktop_yaw := 0.0
var _pointed: Node = null # conteneur/pilule actuellement pointé
var _chat_hold := 0.0 # temps restant avant retour au compte à rebours
var _chat_accum := 0.0
var _creepy_idx := 0

var apartment: MapBase
var vignette_rect: ColorRect
var chat_label: Label
var center_dot: ColorRect
var gameover_label: Label
var creepy_voices: Node = null ## AudioStreamPlayer3D HRTF (voix dans les murs)

# Journal de session (autoload GameLog). Résolu paresseusement pour rester
# tolérant aux contextes sans autoload (tests headless).
var _logger: GameLogger = null
# Heartbeat de diagnostique : caméra/origine/santé toutes les secondes au début.
var _hb_t := 0.0
var _hb_n := 0


## Écrit une ligne dans le journal .txt (GameLogger), repli sur print().
func _log(cat: String, msg: String) -> void:
	if _logger == null:
		_logger = get_node_or_null("/root/GameLog") as GameLogger
	if _logger != null:
		_logger.log_line(cat, msg)
	else:
		print("[%s] %s" % [cat, msg])

# Lignes de chat à mesure que la schizo monte (GDD §5.2 : le chat donne le
# compte à rebours ET devient inquiétant).
const CHAT_CALME := [
	"T'as pris ta dose ce matin ou tu déconnes ?",
	"Le tiroir de la cuisine. Regarde bien.",
]
const CHAT_INQUIET := [
	"Fréro. Les murs bougent. C'est pas normal.",
	"Il te reste peu de temps. CHERCHE.",
	"Le faux est celui qui tremble. Souviens-toi.",
]
const CHAT_CRITIQUE := [
	"IL EST DANS LA PIÈCE AVEC TOI",
	"ne regarde pas derrière. CHERCHE LES PILULES.",
	"t u   v a s   d e v e n i r   l e   m u r",
]


func _ready() -> void:
	add_to_group("main")
	_log("MAIN", "fragment 1 : _ready()")
	right_hand.button_pressed.connect(_on_right_button_pressed)
	left_hand.button_pressed.connect(_on_left_button_pressed)
	_init_openxr()
	_build_world()
	_build_player_body()
	_build_hud()
	_register_debug_inputs()
	_spawn_dose()
	_update_chat("Tu as oublié ta dose. Elle est dans la pièce. Trouve-la.")


# ---------------------------------------------------------------------------
# OpenXR : démarre la session VR si un casque est présent, sinon fallback bureau
# ---------------------------------------------------------------------------
func _init_openxr() -> void:
	_log("XR", "recherche de l'interface OpenXR…")
	xr_interface = XRServer.find_interface("OpenXR")
	_log("XR", "interface trouvée : %s" % str(xr_interface != null))
	if xr_interface and xr_interface.initialize():
		xr_active = true
		# CRITIQUE : sans use_xr, rien n'est soumis au runtime XR (écran noir).
		get_viewport().use_xr = true
		# Le viewport devient piloté par le runtime XR ; le casque gère sa fréquence.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		_log("XR", "OpenXR initialisé — viewport.use_xr=true")
		print("[NÉVROSE] OpenXR initialisé — mode VR.")
	else:
		xr_active = false
		# Fallback bureau : l'origine XR joue le rôle du joueur, caméra à 1,7 m.
		xr_origin.position.y = 1.7
		_log("XR", "ÉCHEC initialisation OpenXR — fallback bureau")
		print("[NÉVROSE] OpenXR indisponible — mode bureau (tests/debug).")


func is_xr_active() -> bool:
	return xr_active


# ---------------------------------------------------------------------------
# Monde : l'appartement (généré procéduralement, géométrie légère, zéro texture)
# ---------------------------------------------------------------------------
func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.025, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.28, 0.3)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.1, 0.14)
	env.fog_density = 0.035
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.8
	env.glow_bloom = 0.08
	world_env.environment = env
	add_child(world_env)

	apartment = preload("res://scripts/map2_living.gd").new()
	apartment.name = "Map2Living"
	add_child(apartment)
	apartment.build()
	_log("WORLD", "map salon+cuisine construite : %d nœuds" % apartment.get_child_count())
	# GDD §5.6 : signaux verrous (clé / force → bruit → mimic)
	for c in apartment.containers:
		if c.lock_type != InteractiveContainer.LockType.NONE:
			c.lock_broken.connect(_on_container_lock_broken)
			c.unlocked_by_key.connect(_on_container_unlocked_by_key)

	# GDD §5.2/§7 : voix dans les murs (HRTF binaural)
	creepy_voices = preload("res://scripts/creepy_voices.gd").new()
	creepy_voices.name = "CreepyVoices"
	add_child(creepy_voices)
	creepy_voices.configure_room(apartment.room_w, apartment.room_d, apartment.room_h)
	_log("AUDIO", "système voix murs initialisé (HRTF spatial)")


# ---------------------------------------------------------------------------
# Joueur : mains VR (modèles low-poly) + corps FPV visible en baissant les yeux.
# Les mains sont attachées aux XRController3D ; le corps à l'origine XR.
# ---------------------------------------------------------------------------
func _build_player_body() -> void:
	_right_hand_mesh = HAND_SCENE_R.instantiate()
	right_hand.add_child(_right_hand_mesh)
	_left_hand_mesh = HAND_SCENE_L.instantiate()
	left_hand.add_child(_left_hand_mesh)
	_log("WORLD", "mains animées (godot-xr-tools) attachées : grip=pointer, grip+trigger=saisir")

	_body = VRBody.new()
	_body.name = "PlayerBody"
	xr_origin.add_child(_body)
	_body.setup(xr_camera)
	_log("WORLD", "corps FPV ajouté (visible en baissant les yeux)")


# ---------------------------------------------------------------------------
# HUD : vignette de folie (shader), chat compte à rebours, point central
# ---------------------------------------------------------------------------
func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	xr_camera.add_child(hud)

	vignette_rect = ColorRect.new()
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_rect.material = ShaderMaterial.new()
	vignette_rect.material.shader = preload("res://scripts/vignette.gdshader")
	hud.add_child(vignette_rect)

	center_dot = ColorRect.new()
	center_dot.size = Vector2(6, 6)
	center_dot.position = Vector2(-3, -3)
	center_dot.set_anchors_preset(Control.PRESET_CENTER)
	center_dot.color = Color(1, 1, 1, 0.65)
	center_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(center_dot)

	chat_label = Label.new()
	chat_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	chat_label.offset_left = 60
	chat_label.offset_right = -60
	chat_label.offset_top = -140
	chat_label.offset_bottom = -60
	chat_label.add_theme_font_size_override("font_size", 28)
	chat_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	chat_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	chat_label.add_theme_constant_override("shadow_offset_x", 2)
	chat_label.add_theme_constant_override("shadow_offset_y", 2)
	chat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chat_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	chat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(chat_label)

	gameover_label = Label.new()
	gameover_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	gameover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gameover_label.add_theme_font_size_override("font_size", 44)
	gameover_label.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1))
	gameover_label.visible = false
	hud.add_child(gameover_label)
	_log("HUD", "HUD prêt : vignette + point central + chat + game over")


# ---------------------------------------------------------------------------
# Inputs bureau (debug/tests headless) : WASD + souris + clic
# ---------------------------------------------------------------------------
func _register_debug_inputs() -> void:
	if xr_active:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_add_key_action(&"dbg_forward", [KEY_W, KEY_UP])
	_add_key_action(&"dbg_back", [KEY_S, KEY_DOWN])
	_add_key_action(&"dbg_left", [KEY_A, KEY_LEFT])
	_add_key_action(&"dbg_right", [KEY_D, KEY_RIGHT])
	_add_key_action(&"dbg_turn_left", [KEY_Q])
	_add_key_action(&"dbg_turn_right", [KEY_E])
	_add_key_action(&"dbg_interact", [KEY_F])
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	_add_event_action(&"dbg_interact", ev)
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_RIGHT
	_add_event_action(&"dbg_snap_right", ev2)


func _add_key_action(action: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keycodes:
		var ev := InputEventKey.new()
		ev.keycode = k
		_add_event_action(action, ev)


func _add_event_action(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if xr_active or game_over:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_desktop_yaw -= event.relative.x * 0.0025
		xr_origin.rotation.y = _desktop_yaw


# ---------------------------------------------------------------------------
# Boucle principale
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if game_over:
		return
	_tick_sanity(delta)
	_tick_movement(delta)
	_tick_interaction_ray()
	_tick_sanity_feedback(delta)
	_tick_pill_eat_feedback(delta)


func _tick_sanity(delta: float) -> void:
	# Round 3 : montée de schizo plus rapide — chaque round (dose) accélère.
	var eff := sanity_rate + SANITY_RATE_ESCALATION * dose_count
	sanity = minf(100.0, sanity + eff * delta)
	if sanity >= 100.0:
		_trigger_game_over()


# Déplacement : stick gauche (VR) / WASD (bureau). Vitesse constante, clampé
# aux murs de la pièce — pas de RigidBody, coût nul pour le Quest 2.
func _tick_movement(delta: float) -> void:
	var move := Vector2.ZERO
	if xr_active:
		# Sur Quest le runtime OpenXR renvoie Y inversé (stick avant = +Y).
		# On corrige à la source pour garder la convention Godot (avant = -Y).
		move = left_hand.get_vector2(&"primary")
		move.y = -move.y
	else:
		move = Input.get_vector(&"dbg_left", &"dbg_right", &"dbg_forward", &"dbg_back")
		if Input.is_action_pressed(&"dbg_turn_left"):
			_desktop_yaw += SNAP_TURN_RAD * delta * 2.0
		if Input.is_action_pressed(&"dbg_turn_right"):
			_desktop_yaw -= SNAP_TURN_RAD * delta * 2.0
		xr_origin.rotation.y = _desktop_yaw

	if move.length() < STICK_DEADZONE:
		move = Vector2.ZERO

	# Snap turn 45° sur le stick droit (bord d'appui), avec anti-rebond.
	_snap_cooldown -= delta
	if xr_active and _snap_cooldown <= 0.0:
		var turn_x := right_hand.get_vector2(&"primary").x
		if absf(turn_x) > 0.6:
			snap_turn(signf(turn_x))
			_snap_cooldown = SNAP_COOLDOWN

	if move.is_zero_approx():
		return

	# Direction relative au regard (yaw de la caméra uniquement — pas de pitch).
	# Stick vers l'avant = move.y négatif → -move.y positif → on avance.
	var basis_yaw := xr_camera.global_transform.basis
	var forward := -basis_yaw.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis_yaw.x
	right.y = 0.0
	right = right.normalized()

	var displacement := (forward * -move.y + right * move.x) * MOVE_SPEED * delta
	var new_pos: Vector3 = xr_origin.position + displacement
	new_pos.x = clampf(new_pos.x, ROOM_MIN.x, ROOM_MAX.x)
	new_pos.z = clampf(new_pos.z, ROOM_MIN.y, ROOM_MAX.y)
	xr_origin.position = new_pos


func snap_turn(direction: float) -> void:
	if direction == 0.0:
		return
	xr_origin.rotate_y(-direction * SNAP_TURN_RAD)


# ---------------------------------------------------------------------------
# Interaction : rayon depuis la main droite (VR) ou la caméra (bureau).
# Gâchette / clic = ouvrir un conteneur ou prendre la pilule.
# ---------------------------------------------------------------------------
func _tick_interaction_ray() -> void:
	var from: Vector3
	var dir: Vector3
	if xr_active:
		var hand_basis := right_hand.global_transform.basis
		from = right_hand.global_transform.origin
		dir = -hand_basis.z
	else:
		from = xr_camera.global_transform.origin
		dir = -xr_camera.global_transform.basis.z

	var query := PhysicsRayQueryParameters3D.create(from, from + dir * RAY_LENGTH)
	query.collide_with_bodies = false
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var new_pointed: Node = null
	if hit and hit.collider and hit.collider.has_method(&"on_pointed"):
		new_pointed = hit.collider
	# Les conteneurs ET la pilule exposent on_pointed() ; tout est Area3D.
	if hit and hit.collider is Area3D:
		var owner_node: Node = (hit.collider as Area3D).get_parent()
		if owner_node and owner_node.has_method(&"on_pointed"):
			new_pointed = owner_node
		elif (hit.collider as Object).has_method(&"on_pointed"):
			new_pointed = hit.collider

	if new_pointed != _pointed:
		if is_instance_valid(_pointed) and _pointed.has_method(&"on_unpointed"):
			_pointed.on_unpointed()
		_pointed = new_pointed
		if is_instance_valid(_pointed) and _pointed:
			_pointed.on_pointed()
			center_dot.color = Color(0.4, 1.0, 0.9, 0.95)
		else:
			center_dot.color = Color(1, 1, 1, 0.65)


func interact() -> void:
	if game_over:
		_restart()
		return
	# 0) Pilule tenue : gâchette = avaler (si dans la zone bouche)
	if _held_pill and is_instance_valid(_held_pill):
		_held_pill.interact() ## interne : can_eat() → _consume()
		return
	# 1) Clé pointée → la ramasser
	if _pointed is KeyObject and is_instance_valid(_pointed):
		_pickup_key(_pointed as KeyObject)
		return
	# 2) Pilule pointée (pas encore tenue) → la ramasser
	if _pointed is Dose and is_instance_valid(_pointed):
		pickup_pill(_pointed as Dose)
		return
	# 3) Objet pointé au rayon (priorité) → déjà résolu dans _pointed.
	if _pointed != null and is_instance_valid(_pointed) and _pointed.has_method(&"interact"):
		var key_ref: KeyObject = _held_key if _held_key else null
		_pointed.interact(key_ref)
		return
	# 4) Proximité : on cherche un conteneur/pilule interactif près de la main.
	var near := _nearest_interactable()
	if near != null:
		var key_ref2: KeyObject = _held_key if _held_key else null
		near.interact(key_ref2)


# Retourne l'interactable le plus proche d'une main (gâchette), dans un rayon
# PROXIMITY_RADIUS. Utilisé quand le rayon ne vise rien mais qu'on est au contact.
func _nearest_interactable() -> Node:
	var best: Node = null
	var best_d := PROXIMITY_RADIUS
	for hand in [right_hand, left_hand]:
		var origin: Vector3 = hand.global_transform.origin
		for c in apartment.containers:
			if not (c.has_method(&"interact")):
				continue
			var d: float = origin.distance_to(c.global_transform.origin)
			if d < best_d:
				best_d = d
				best = c
		# La pilule en surface (pas dans un conteneur)
		var dose: Node = apartment.get_dose()
		if dose != null and is_instance_valid(dose) and dose.has_method(&"interact"):
			var dd: float = origin.distance_to(dose.global_transform.origin)
			if dd < best_d:
				best_d = dd
				best = dose
	return best


# Ramasse une clé (GDD §5.6) — elle reste "dans la main" (vivante + visible)
# jusqu'à ce qu'elle soit utilisée sur son conteneur.
func _pickup_key(key: KeyObject) -> void:
	if _held_key:
		_update_chat("Ta main est déjà pleine.")
		return
	_held_key = key
	key.is_held = true
	key.name = "HeldKey"
	right_hand.add_child(key) ## remonte dans la main animée → suit le controller
	key.position = Vector3(0.0, -0.08, 0.12)
	key.rotation = Vector3(PI / 2, 0, 0)
	_log("GAME", "clé ramassée")
	_update_chat("Tu as une clé. Elle sert à quelque chose…")


# Ramasse une pilule (GDD §5.1) — elle suit la main, le joueur la porte à la
# bouche (zone ~28 cm sous la caméra) puis gâchette = avaler.
var _held_pill: Dose = null

func pickup_pill(pill: Dose) -> void:
	if _held_pill and is_instance_valid(_held_pill):
		_update_chat("Tu tiens déjà une pilule.")
		return
	_held_pill = pill
	pill.is_held = true
	pill.camera = xr_camera
	pill.name = "HeldPill"
	right_hand.add_child(pill)
	pill.position = Vector3(0.0, -0.06, 0.10)
	pill.rotation = Vector3(PI / 2, 0, 0)
	_log("GAME", "pilule saisie — porte-la à ta bouche et gâchette")
	_update_chat("Tu l'as. Porte-la à ta bouche. Gâchette = avaler.")


## Appelé chaque frame pour vérifier si la pilule est dans la zone bouche
## et afficher l'indicateur (vignette + chat).
func _tick_pill_eat_feedback(delta: float) -> void:
	if _held_pill and is_instance_valid(_held_pill):
		if _held_pill.can_eat():
			# Indicateur : le point central devient vert + chat
			center_dot.color = Color(0.3, 1.0, 0.5, 1.0)
			center_dot.size = Vector2(12, 12)
			center_dot.position = Vector2(-6, -6)
		else:
			center_dot.color = Color(0.4, 1.0, 0.9, 0.95)
			center_dot.size = Vector2(6, 6)
			center_dot.position = Vector2(-3, -3)


# Consomme la clé (après déverrouillage réussi).
func _consume_key() -> void:
	if _held_key and is_instance_valid(_held_key):
		_held_key.queue_free()
	_held_key = null


# Consomme la pilule (après avoir mangé).
func _consume_pill() -> void:
	if _held_pill and is_instance_valid(_held_pill):
		_held_pill.queue_free()
	_held_pill = null


# GDD §5.6 : conteneur forcé ouvert = bruit qui attire les mimics.
func _on_container_lock_broken(container: Node3D, noise: float) -> void:
	_consume_key()
	sanity = minf(100.0, sanity + 8.0)
	_pulse_haptics()
	_log("GAME", "verrou FORCÉ sur %s (bruit=%.1f)" % [container.name, noise])
	_update_chat("Le verrou cède avec un CRAC. Quelque part, quelque chose s'est levé de son sommeil.")
	# Round 3 : le bruit attire un mimic mobile
	spawn_mobile_mimic()


# GDD §5.6 : déverrouillé par la bonne clé (silencieux).
func _on_container_unlocked_by_key(container: Node3D) -> void:
	_consume_key()
	_log("GAME", "déverrouillé par clé : %s" % container.name)
	_update_chat("La clé tourne dans le silence. Il n'a rien entendu.")


# Round 3 : un mimic mobile a atteint le joueur (présence oppressante).
func on_mimic_close() -> void:
	sanity = minf(100.0, sanity + 12.0)
	_pulse_haptics()
	_log("GAME", "mimic mobile atteint le joueur (+12 sanity)")
	_update_chat("Il est là. Juste derrière ta nuque. Tu sens son souffle froid.")


# Round 3 : le bruit d'un verrou forcé attire un mimic mobile (GDD §5.6 → §5.3).
# Il apparaît aux limites de la pièce et dérive vers le joueur.
func spawn_mobile_mimic() -> void:
	var m := Mimic.new()
	m.name = "MobileMimic"
	m.is_mobile = true
	m.move_speed = 0.35
	m.attract_target = xr_camera
	add_child(m)
	# Spawn aux bords de la pièce (loin du joueur)
	var edges := [
		Vector3(-2.8, 0.0, -2.0),
		Vector3(2.8, 0.0, -2.0),
		Vector3(-2.8, 0.0, 2.0),
		Vector3(2.8, 0.0, 2.0),
	]
	m.position = edges.pick_random()
	_log("GAME", "mimic mobile spawné à %s" % m.position)


# Appelé par la pilule quand elle est absorbée (GDD §5.1).
func on_dose_taken() -> void:
	dose_count += 1
	sanity = maxf(0.0, sanity - SANITY_DOSE_RELIEF)
	sanity_rate = SANITY_RATE_AFTER_DOSE
	_consume_pill() ## nettoie la référence (la pilule s'est déjà freed)
	_log("GAME", "dose absorbue n°%d (sanity=%.0f)" % [dose_count, sanity])
	_pulse_haptics()
	_update_chat("Dose absorbue. Ça va mieux… pour l'instant. Cherche la suivante. Il n'y a PAS de sortie.")
	await get_tree().create_timer(2.0).timeout
	_spawn_dose()


# Appelé par un mimic purgé (GDD §5.3) : le doute coûte cher.
func on_mimic_purged() -> void:
	sanity = minf(100.0, sanity + 6.0)
	_pulse_haptics()
	_update_chat("C'était pas ta tasse. Elle t'observait. La prochaine pilule est ailleurs.")


func _spawn_dose() -> void:
	apartment.spawn_dose()
	_log("GAME", "nouvelle dose spawnée")


# ---------------------------------------------------------------------------
# Folie : vignette + murs qui respirent + chat compte à rebours (GDD §5.2/§7)
# ---------------------------------------------------------------------------
func _tick_sanity_feedback(delta: float) -> void:
	var t := sanity / 100.0
	vignette_rect.material.set_shader_parameter(&"intensity", lerpf(0.12, 1.0, t))
	apartment.set_insanity(t)
	_tick_chat(delta, t)
	# Voix dans les murs — plus la schizo monte, plus elles sont fréquentes
	if creepy_voices and creepy_voices.has_method(&"tick"):
		creepy_voices.tick(t, delta)


# Le chat est l'horloge de la pression (GDD §5.2) : compte à rebours avant la
# folie totale + messages qui se fragmentent quand la schizo monte.
func _tick_chat(delta: float, t: float) -> void:
	_chat_hold -= delta
	if _chat_hold > 0.0:
		return
	_chat_accum += delta
	if _chat_accum < 1.0:
		return
	_chat_accum = 0.0
	var remaining := (100.0 - sanity) / maxf(sanity_rate, 0.01)
	var mm := int(remaining) / 60
	var ss := int(remaining) % 60
	var pool: Array = CHAT_CALME
	if t * 100.0 > FOLIE_CRITIQUE:
		pool = CHAT_CRITIQUE
	elif t * 100.0 > FOLIE_LEGERE:
		pool = CHAT_INQUIET
	var line: String = pool[_creepy_idx % pool.size()]
	_creepy_idx += 1
	_update_chat("Il te reste %d:%02d avant que ça bascule.\n%s" % [mm, ss, line])


func _update_chat(text: String) -> void:
	_chat_hold = 3.0
	chat_label.text = text


func _trigger_game_over() -> void:
	game_over = true
	_log("GAME", "GAME OVER — assimilation (sanity=100)")
	gameover_label.text = (
		"L'APPART T'A ASSIMILÉ.\n" +
		"Tu es le mur, maintenant.\n\n" +
		"Tu n'auras jamais réussi à sortir.\n" +
		"Tu n'as fait que DÉCALER. Et ça, ça ne suffit pas.\n\n" +
		"Gâchette / clic : recommencer (et perdre à nouveau)"
	)
	gameover_label.visible = true
	vignette_rect.material.set_shader_parameter(&"intensity", 1.0)


func _restart() -> void:
	game_over = false
	sanity = 0.0
	sanity_rate = SANITY_RATE
	dose_count = 0
	gameover_label.visible = false
	_consume_pill()
	_consume_key()
	apartment.reset_containers()
	_spawn_dose()
	if creepy_voices:
		creepy_voices.enabled = true
	_log("GAME", "restart (round %d)" % dose_count)
	_update_chat("Encore une chance. Trouve la pilule. Il n'y a pas de sortie.")


func _pulse_haptics() -> void:
	if xr_active:
		right_hand.trigger_haptic_pulse(&"haptic", 0.0, 0.25, 70.0, 0.7)


# ---------------------------------------------------------------------------
# Signaux manettes VR (gâchettes)
# ---------------------------------------------------------------------------
func _on_right_button_pressed(action_name: String) -> void:
	# Gâchette index droite = interagir (ouvrir / prendre), au rayon ou au contact.
	if action_name == &"trigger":
		interact()


func _on_left_button_pressed(action_name: String) -> void:
	# Gâchette index gauche = aussi interagir (symétrique, confort ambidextre).
	if action_name == &"trigger":
		interact()
		return
	# Le menu pa gauche sert de reset rapide si le joueur est coincé.
	if action_name == &"menu_button" and game_over:
		_restart()


func _process(delta: float) -> void:
	# Heartbeat de diagnostique : 20 premières secondes, une ligne par seconde.
	_hb_t += delta
	if _hb_n < 20 and _hb_t >= 1.0:
		_hb_t = 0.0
		_hb_n += 1
		_log("HB", "cam=%s | origin=%s | sanity=%.0f | xr=%s | doses=%d" % [
			str(xr_camera.global_transform.origin),
			str(xr_origin.global_transform.origin),
			sanity, str(xr_active), dose_count])
	if not xr_active:
		if Input.is_action_just_pressed(&"dbg_interact"):
			interact()
		if Input.is_action_just_pressed(&"dbg_snap_right"):
			snap_turn(1.0)
