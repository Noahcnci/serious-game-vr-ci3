class_name Map2Living
extends MapBase
## Map 2 (fragment 2) : salon + cuisine, 8 x 6 m (GDD §7).
##
## Design intérieur professionnel — uniquement des assets Kenney (CC0) :
##   - Chaque meuble est ancré contre un mur ou un autre meuble via son AABB.
##   - Circulation centrale libre (axe nord-sud x≈0 et est-ouest z≈0).
##   - Cuisine : frigo, évier, plaques, hotte, hauts, bar + tabourets.
##   - Salon : canapé en L, table basse, TV, bibliothèque, fauteuil, tapis.
##   - Set dressing : nourriture, vaisselle, livres, plantes, cadres, poubelle.
##
## La coquille (sol/murs/plafond/fenêtre/porte/couloir) vient de
## scenes/map2_living.tscn — instanciée ici enfant de cette racine.

const SCENE_SHELL := "res://scenes/map2_living.tscn"
const FURN := "res://assets/kenney/furniture/"
const FOOD := "res://assets/kenney/food/"

var _mat_bois: StandardMaterial3D
var _mat_meuble: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_tissu: StandardMaterial3D
var _mat_cadre: StandardMaterial3D
var _mat_nourriture: StandardMaterial3D

const COUNTER_Y := 0.48


func _init() -> void:
	room_w = 8.0
	room_d = 6.0
	room_h = 2.7


func build() -> void:
	_make_materials()
	_instance_shell()
	_build_kitchen()
	_build_living_room()
	_register_spawn_spots()
	_build_keys(_key_spots())
	_place_mimics()


# ---------------------------------------------------------------------------
# Matériaux
# ---------------------------------------------------------------------------
func _make_materials() -> void:
	_mat_bois = _new_mat(Color(0.28, 0.19, 0.13))
	_mat_meuble = _new_mat(Color(0.55, 0.52, 0.47))
	_mat_metal = _new_mat(Color(0.52, 0.53, 0.55))
	_mat_tissu = _new_mat(Color(0.42, 0.26, 0.22))
	_mat_cadre = _new_mat(Color(0.82, 0.78, 0.72))
	_mat_nourriture = _new_mat(Color(0.72, 0.55, 0.35))
	_reg_breather(_mat_meuble, Color(0.55, 0.52, 0.47), Color(0.42, 0.5, 0.4))
	_reg_breather(_mat_tissu, Color(0.42, 0.26, 0.22), Color(0.35, 0.18, 0.15))
	_reg_breather(_mat_bois, Color(0.28, 0.19, 0.13), Color(0.22, 0.16, 0.11))


func _new_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


# ---------------------------------------------------------------------------
# Coquille
# ---------------------------------------------------------------------------
func _instance_shell() -> void:
	var packed: PackedScene = load(SCENE_SHELL)
	if packed == null:
		push_error("Map2Living: coquille introuvable %s" % SCENE_SHELL)
		return
	var shell: Node3D = packed.instantiate()
	shell.name = "Shell"
	add_child(shell)


# ---------------------------------------------------------------------------
# CUISINE (mur nord, z = -3)
# ---------------------------------------------------------------------------
func _build_kitchen() -> void:
	var root := Node3D.new()
	root.name = "Kitchen"
	add_child(root)

	# --- Frigo large (à gauche) ---
	# AABB : 0.52 x 0.92 x 0.406, origine coin arrière-gauche.
	# Dos au mur (z = -3 + 0.406 = -2.594), côté gauche à x = -3.7.
	_place_furniture(root, FURN + "kitchenFridgeLarge.glb", Vector3(-3.7, 0.0, -2.594), 0.0)

	# Porte frigo = conteneur rotatif, verrouillée par clé.
	# Charnière gauche (x = -3.66), front centré sur la porte.
	var fridge := _make_container(root, "FridgeDoor",
		InteractiveContainer.Mode.ROTATE,
		Vector3(-3.66, 0.5, -2.19), Vector3.ZERO, 0.0, 115.0,
		InteractiveContainer.LockType.KEY,
		Vector3(0.44, 0.9, 0.04), _mat_metal)
	fridge.front_mesh.position = Vector3(0.22, 0.0, 0.02)

	# --- Bas de cuisine : 6 caissons de 0.43 m ---
	# x : -2.6 (évier) | -2.17 (tiroir clé) | -1.74 (plaques) | -1.31 (tiroir force) | -0.88 (tiroir) | -0.45 (tiroir)
	var base_x := [-2.6, -2.17, -1.74, -1.31, -0.88, -0.45]
	var base_glb := [
		FURN + "kitchenSink.glb",
		FURN + "kitchenCabinetDrawer.glb",
		FURN + "kitchenStove.glb",
		FURN + "kitchenCabinetDrawer.glb",
		FURN + "kitchenCabinetDrawer.glb",
		FURN + "kitchenCabinetDrawer.glb",
	]
	for i in base_x.size():
		_place_furniture(root, base_glb[i], Vector3(base_x[i], 0.0, -2.55), 0.0)

	# Tiroirs interactifs (sauf évier et plaques).
	# Cavité à z ∈ [-2.77, -2.46]. Front fermé à z = -2.46.
	var drawer_x := [-2.17, -1.31, -0.88, -0.45]
	var drawer_lock := [
		InteractiveContainer.LockType.KEY,
		InteractiveContainer.LockType.FORCEABLE,
		InteractiveContainer.LockType.NONE,
		InteractiveContainer.LockType.NONE,
	]
	for i in drawer_x.size():
		# Cavité sombre (fond du tiroir).
		_box(root, "DrawerCavity%d" % i, Vector3(0.38, 0.14, 0.30),
			Vector3(drawer_x[i], 0.36, -2.62), _new_mat(Color(0.10, 0.09, 0.08)))
		_make_container(root, "KitchenDrawer%d" % i,
			InteractiveContainer.Mode.SLIDE,
			Vector3(drawer_x[i], 0.36, -2.46), Vector3.BACK, 0.42, 115.0,
			drawer_lock[i],
			Vector3(0.40, 0.16, 0.03), _mat_bois)

	# --- Plan de travail continu ---
	_box(root, "CounterTop", Vector3(2.60, 0.03, 0.50),
		Vector3(-1.53, COUNTER_Y - 0.015, -2.77), _mat_meuble)

	# --- Hauts de cuisine (4 caissons, y = 1.32) ---
	var upper_x := [-2.6, -2.17, -1.31, -0.88]
	for i in upper_x.size():
		_place_furniture(root, FURN + "kitchenCabinetUpper.glb",
			Vector3(upper_x[i], 1.32, -2.78), 0.0)

	# Hotte au-dessus des plaques.
	_place_furniture(root, FURN + "hoodModern.glb", Vector3(-1.74, 1.71, -2.715), 0.0)

	# --- Petit électroménager sur le plan de travail ---
	_place_furniture(root, FURN + "toaster.glb", Vector3(-0.55, COUNTER_Y, -2.70), -10.0)
	_place_furniture(root, FURN + "kitchenCoffeeMachine.glb", Vector3(-2.40, COUNTER_Y, -2.70), 0.0)
	_place_furniture(root, FURN + "kitchenMicrowave.glb", Vector3(-1.90, COUNTER_Y, -2.72), 0.0)
	_place_furniture(root, FURN + "kitchenBlender.glb", Vector3(-1.10, COUNTER_Y, -2.72), 15.0)

	# --- Set dressing cuisine (nourriture + vaisselle sur le plan de travail) ---
	_place_food(root, "loaf.glb", Vector3(-2.55, COUNTER_Y, -2.75), 0.0)
	_place_food(root, "cutting-board.glb", Vector3(-2.30, COUNTER_Y, -2.68), 30.0)
	_place_food(root, "apple.glb", Vector3(-2.32, COUNTER_Y + 0.02, -2.68), 0.0)
	_place_food(root, "shaker-salt.glb", Vector3(-1.55, COUNTER_Y, -2.70), 0.0)
	_place_food(root, "shaker-pepper.glb", Vector3(-1.48, COUNTER_Y, -2.70), 0.0)
	_place_food(root, "bottle-oil.glb", Vector3(-1.35, COUNTER_Y, -2.72), 0.0)
	_place_food(root, "tomato.glb", Vector3(-0.80, COUNTER_Y, -2.72), 20.0)
	# Pizza dans sa boîte sur le plan de travail (proche du bar).
	_place_food(root, "pizza-box.glb", Vector3(-0.35, COUNTER_Y, -2.70), 10.0)
	# Couteaux dans leur bloc.
	_place_food(root, "knife-block.glb", Vector3(-2.72, COUNTER_Y, -2.65), 0.0)

	# --- Bar de cuisine (séparation cuisine/salon) ---
	# AABB kitchenBar : 0.43 x 0.42 x 0.21. Orienté face à -x (rot_y = 90°).
	# Deux modules côte à côte : bar de 0.86 m à z = -2.0.
	_place_furniture(root, FURN + "kitchenBar.glb", Vector3(0.95, 0.0, -2.0), 90.0)
	_place_furniture(root, FURN + "kitchenBarEnd.glb", Vector3(0.95, 0.0, -1.58), 90.0)

	# Tabourets de bar (2).
	_place_furniture(root, FURN + "stoolBar.glb", Vector3(1.45, 0.0, -2.0), -90.0)
	_place_furniture(root, FURN + "stoolBar.glb", Vector3(1.45, 0.0, -1.55), -90.0)

	# Nourriture posée sur le bar.
	_place_food(root, "plate.glb", Vector3(0.95, 0.43, -1.80), 0.0)
	_place_food(root, "glass-wine.glb", Vector3(0.85, 0.43, -1.95), 0.0)
	_place_food(root, "burger-cheese.glb", Vector3(1.05, 0.43, -1.75), 15.0)

	# Poubelle près du bar.
	_place_furniture(root, FURN + "trashcan.glb", Vector3(1.30, 0.0, -0.85), 0.0)

	# --- Lumières cuisine ---
	var klight := OmniLight3D.new()
	klight.name = "KitchenLight"
	klight.position = Vector3(-1.5, 2.3, -2.0)
	klight.light_color = Color(0.95, 0.88, 0.75)
	klight.light_energy = 1.1
	klight.omni_range = 4.5
	klight.shadow_enabled = false
	root.add_child(klight)
	_reg_flicker(klight, 1.1)

	# Lumière sous les hauts (LED plan de travail).
	var ulight := OmniLight3D.new()
	ulight.name = "UnderCounterLight"
	ulight.position = Vector3(-1.5, 1.20, -2.40)
	ulight.light_color = Color(1.0, 0.92, 0.78)
	ulight.light_energy = 0.45
	ulight.omni_range = 2.0
	ulight.shadow_enabled = false
	root.add_child(ulight)


# ---------------------------------------------------------------------------
# SALON (moitié sud, z > 0)
# ---------------------------------------------------------------------------
func _build_living_room() -> void:
	var root := Node3D.new()
	root.name = "LivingRoom"
	add_child(root)

	# --- Canapé en L (mur sud + mur est) ---
	# loungeSofaLong : 0.98 x 0.46 x 0.82, rot 180° dos au mur sud.
	# pos_z = 3 - 0.82 = 2.18.
	_place_furniture(root, FURN + "loungeSofaLong.glb", Vector3(0.6, 0.0, 2.18), 180.0)
	# loungeSofaCorner : 0.98 x 0.46 x 0.98, rot 180° angle sud-est.
	# pos : x = 3 - 0.98 = 2.02, z = 3 - 0.98 = 2.02.
	_place_furniture(root, FURN + "loungeSofaCorner.glb", Vector3(2.02, 0.0, 2.02), 180.0)

	# Coussins sur le canapé.
	_place_furniture(root, FURN + "pillow.glb", Vector3(0.35, 0.46, 2.28), 15.0)
	_place_furniture(root, FURN + "pillowBlue.glb", Vector3(0.85, 0.46, 2.25), -10.0)
	_place_furniture(root, FURN + "pillowLong.glb", Vector3(2.20, 0.46, 2.20), 30.0)

	# Ottoman devant le canapé.
	_place_furniture(root, FURN + "loungeSofaOttoman.glb", Vector3(0.6, 0.0, 1.10), 0.0)

	# --- Tapis sous la table basse ---
	# AABB rugRectangle : 1.57 x 0.01 x 0.92.
	_place_furniture(root, FURN + "rugRectangle.glb", Vector3(0.6, 0.005, 1.20), 0.0)

	# --- Table basse ---
	# AABB tableCoffee : 0.661 x 0.230 x 0.400, origine centrée en X.
	_place_furniture(root, FURN + "tableCoffee.glb", Vector3(0.6, 0.0, 1.20), 0.0)

	# Déco sur la table basse.
	_place_furniture(root, FURN + "books.glb", Vector3(0.45, 0.23, 1.15), 20.0)
	_place_food(root, "mug.glb", Vector3(0.75, 0.23, 1.25), 0.0)
	_place_food(root, "plate-deep.glb", Vector3(0.60, 0.23, 1.10), 0.0)
	_place_food(root, "cookie.glb", Vector3(0.60, 0.24, 1.10), 0.0)

	# --- Meuble TV (mur ouest) ---
	# AABB cabinetTelevision : 0.80 x 0.31 x 0.25. rot 90° face à l'est.
	# pos_x = -4 + 0.25 = -3.75.
	_place_furniture(root, FURN + "cabinetTelevision.glb", Vector3(-3.75, 0.0, 0.8), 90.0)
	# TV posée sur le meuble (hauteur 0.31).
	_place_furniture(root, FURN + "televisionModern.glb", Vector3(-3.62, 0.31, 0.8), 90.0)
	# Enceintes de part et d'autre de la TV.
	_place_furniture(root, FURN + "speaker.glb", Vector3(-3.60, 0.31, 0.2), 90.0)
	_place_furniture(root, FURN + "speaker.glb", Vector3(-3.60, 0.31, 1.4), 90.0)
	# Radio posée sur le meuble TV.
	_place_furniture(root, FURN + "radio.glb", Vector3(-3.60, 0.31, 0.8), 90.0)

	# --- Bibliothèque (mur est) ---
	# AABB bookcaseClosedDoors : 0.40 x 0.85 x 0.25. rot 180° dos au mur est.
	# pos_x = 4 - 0.25 = 3.75.
	_place_furniture(root, FURN + "bookcaseClosedDoors.glb", Vector3(3.75, 0.0, 0.0), 180.0)
	# Livres empilés sur la bibliothèque.
	_place_furniture(root, FURN + "books.glb", Vector3(3.72, 0.85, 0.05), 10.0)
	_place_furniture(root, FURN + "books.glb", Vector3(3.78, 0.85, -0.08), -5.0)

	# Placard de rangement (conteneur forceable) — même mur, au nord.
	_place_furniture(root, FURN + "bookcaseClosed.glb", Vector3(3.75, 0.0, -1.5), 180.0)

	# Porte du placard = conteneur rotatif, FORCEABLE.
	# Face avant à z = -1.5 + 0.25 = -1.25. Charnière gauche (x = 3.55).
	var closet := _make_container(root, "ClosetDoor",
		InteractiveContainer.Mode.ROTATE,
		Vector3(3.55, 0.45, -1.25), Vector3.ZERO, 0.0, 115.0,
		InteractiveContainer.LockType.FORCEABLE,
		Vector3(0.36, 0.75, 0.03), _mat_meuble)
	closet.front_mesh.position = Vector3(0.18, 0.0, 0.015)

	# --- Coin lecture (nord-ouest du salon) ---
	# Fauteuil lounge (face sud-est, vers le canapé).
	# AABB loungeChair : 0.49 x 0.46 x 0.41. rot_y = -135°.
	_place_furniture(root, FURN + "loungeChair.glb", Vector3(-3.0, 0.0, -0.8), -135.0)
	# Table d'appoint.
	# AABB sideTable : 0.534 x 0.384 x 0.220.
	_place_furniture(root, FURN + "sideTable.glb", Vector3(-3.55, 0.0, -0.2), 0.0)
	# Lampe de table sur la table d'appoint.
	_place_furniture(root, FURN + "lampSquareTable.glb", Vector3(-3.55, 0.38, -0.2), 0.0)
	# Lampe sur la table de chevet (à droite du canapé).
	_place_furniture(root, FURN + "lampSquareFloor.glb", Vector3(3.5, 0.0, 2.5), 0.0)

	# --- Plante et déco ---
	_place_furniture(root, FURN + "pottedPlant.glb", Vector3(-3.7, 0.0, -2.7), 0.0)
	_place_furniture(root, FURN + "plantSmall1.glb", Vector3(3.7, 0.0, 2.7), 0.0)
	_place_furniture(root, FURN + "plantSmall2.glb", Vector3(-3.7, 0.0, 2.7), 0.0)
	# Boîtes en carton dans le coin (déménagement en cours — narratif).
	_place_furniture(root, FURN + "cardboardBoxClosed.glb", Vector3(-3.6, 0.0, -1.8), 15.0)
	_place_furniture(root, FURN + "cardboardBoxOpen.glb", Vector3(-3.5, 0.0, -1.4), -10.0)

	# --- Lumières salon ---
	var llight := OmniLight3D.new()
	llight.name = "LivingLight"
	llight.position = Vector3(0.5, 2.3, 1.0)
	llight.light_color = Color(1.0, 0.82, 0.55)
	llight.light_energy = 1.3
	llight.omni_range = 5.5
	llight.shadow_enabled = false
	root.add_child(llight)
	_reg_flicker(llight, 1.3)

	# Plafonnier central.
	var clight := OmniLight3D.new()
	clight.name = "CeilLight"
	clight.position = Vector3(0, 2.4, 0)
	clight.light_color = Color(0.92, 0.90, 0.86)
	clight.light_energy = 0.7
	clight.omni_range = 8.0
	clight.shadow_enabled = false
	root.add_child(clight)

	# Lumière d'appoint du coin lecture.
	var rlight := OmniLight3D.new()
	rlight.name = "ReadingLight"
	rlight.position = Vector3(-3.2, 1.5, -0.5)
	rlight.light_color = Color(1.0, 0.88, 0.70)
	rlight.light_energy = 0.4
	rlight.omni_range = 2.5
	rlight.shadow_enabled = false
	root.add_child(rlight)


# ---------------------------------------------------------------------------
# Mimics (GDD §5.3) — 2 mimics statiques.
# ---------------------------------------------------------------------------
func _place_mimics() -> void:
	# Mimic 1 : tasse sur la table basse (à côté d'une vraie tasse).
	var fake1 := Mimic.new()
	fake1.name = "MugMimic"
	add_child(fake1)
	fake1.position = Vector3(0.30, 0.23, 1.05)
	_place_furniture(fake1, FOOD + "cup-tea.glb", Vector3.ZERO, 0.0)
	var cs1 := CollisionShape3D.new()
	var bs1 := BoxShape3D.new()
	bs1.size = Vector3(0.16, 0.16, 0.16)
	cs1.shape = bs1
	cs1.position = Vector3(0, 0.06, 0)
	fake1.add_child(cs1)
	mimics.append(fake1)

	# Mimic 2 : tasse sur la table d'appoint du coin lecture.
	var fake2 := Mimic.new()
	fake2.name = "SideTableMimic"
	add_child(fake2)
	fake2.position = Vector3(-3.55, 0.38, -0.05)
	_place_furniture(fake2, FOOD + "cup-tea.glb", Vector3.ZERO, 30.0)
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(0.16, 0.16, 0.16)
	cs2.shape = bs2
	cs2.position = Vector3(0, 0.06, 0)
	fake2.add_child(cs2)
	mimics.append(fake2)


# ---------------------------------------------------------------------------
# Spawns de dose (GDD §5.1)
# ---------------------------------------------------------------------------
func _register_spawn_spots() -> void:
	# Tiroir de cuisine verrouillé par clé.
	for c in containers:
		if c.name.begins_with("KitchenDrawer") and c.lock_type == InteractiveContainer.LockType.KEY:
			_spawn_spots.append({"pos": Vector3.ZERO, "container": c})
	# Porte du frigo (verrouillée par clé).
	for c in containers:
		if c.name.begins_with("FridgeDoor"):
			_spawn_spots.append({"pos": Vector3(-3.44, 0.5, -2.14), "container": c})
	# Surfaces ouvertes.
	_spawn_spots.append({"pos": Vector3(-0.55, 0.61, -2.70), "container": null}) # toaster
	_spawn_spots.append({"pos": Vector3(0.60, 0.23, 1.20), "container": null}) # table basse
	_spawn_spots.append({"pos": Vector3(0.60, 0.47, 2.18), "container": null}) # canapé
	_spawn_spots.append({"pos": Vector3(-3.55, 0.38, -0.20), "container": null}) # table d'appoint
	_spawn_spots.append({"pos": Vector3(3.75, 0.85, 0.00), "container": null}) # dessus bibliothèque
	_spawn_spots.append({"pos": Vector3.ZERO, "container": null, "floor": true}) # sol


func _key_spots() -> Array[Vector3]:
	return [
		Vector3(0.60, 0.23, 1.20),   # table basse
		Vector3(-0.55, 0.61, -2.70), # plan de travail
		Vector3(3.75, 0.85, 0.00),   # dessus bibliothèque
		Vector3(-3.55, 0.38, -0.20), # table d'appoint
		Vector3(0.60, 0.47, 2.18),   # canapé
	]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _place_food(parent: Node, glb_name: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	return _place_furniture(parent, FOOD + glb_name, pos, rot_y)
