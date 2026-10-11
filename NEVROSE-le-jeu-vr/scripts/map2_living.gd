class_name Map2Living
extends MapBase
## Map 2 (fragment 2) : salon + cuisine, 8 x 6 m (GDD §7).
##
## Design intérieur professionnel — combine :
##   - Assets Kenney (CC0) déjà présents : nourriture, vaisselle, petit mobilier.
##   - Assets Quaternius (CC0) téléchargés : gros mobilier (cuisine, salon).
## Les modèles Quaternius sont en décimètres (x10), on applique un facteur
## global QUATERNIUS_SCALE pour ramener à une échelle cohérente en mètres.
##
##   - Chaque meuble est ancré contre un mur ou un autre meuble via son AABB.
##   - Circulation centrale libre (axe nord-sud x≈0 et est-ouest z≈0).
##   - Cuisine : frigo, évier, four, placards, tiroirs, hotte (mur nord).
##   - Salon : canapé, fauteuil, table basse, TV, bibliothèque (moitié sud).
##   - Set dressing : nourriture, vaisselle, livres, plantes, lampes, rideaux.
##
## La coquille (sol/murs/plafond/fenêtre/porte/couloir) vient de
## scenes/map2_living.tscn — instanciée ici enfant de cette racine.

const SCENE_SHELL := "res://scenes/map2_living.tscn"
const FURN := "res://assets/kenney/furniture/"
const FOOD := "res://assets/kenney/food/"
const QUAT := "res://assets/quaternius/"

## Facteur d'échelle global pour les modèles Quaternius (décimètres → mètres).
## Les AABB mesurés donnent : chaise ~1.77u, frigo ~3.3u, canapé ~4.7u.
## Un facteur 0.5 ramène à des dimensions réalistes (~0.9m chaise, 1.65m frigo).
const QUATERNIUS_SCALE := 0.5

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
# Helpers Quaternius : charge un FBX, applique l'échelle, le pose.
# ---------------------------------------------------------------------------

## Instancie un FBX Quaternius, applique QUATERNIUS_SCALE, l'ajoute sous
## `parent`, le pose à `pos` (pieds au sol), l'oriente de `rot_y` degrés,
## et lui donne une collision box ajustée. Retourne la racine instanciée.
func _place_quaternius(parent: Node, fbx_name: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var packed: PackedScene = load(QUAT + fbx_name)
	if packed == null:
		push_warning("Map2Living: FBX Quaternius introuvable %s" % fbx_name)
		return null
	var n: Node3D = packed.instantiate()
	n.name = fbx_name.get_basename()
	n.scale = Vector3.ONE * QUATERNIUS_SCALE
	parent.add_child(n)
	n.position = pos
	n.rotation.y = deg_to_rad(rot_y)
	_add_box_collision(n)
	return n


# ---------------------------------------------------------------------------
# CUISINE (mur nord, z = -3) — équipement Quaternius + set dressing Kenney.
# ---------------------------------------------------------------------------
func _build_kitchen() -> void:
	var root := Node3D.new()
	root.name = "Kitchen"
	add_child(root)

	# --- Frigo Quaternius (à gauche) ---
	# AABB : 1.298 x 3.308 x 1.302 (× 0.5 = 0.649 x 1.654 x 0.651 m).
	# Pour dos au mur (z = -3 + 0.651 = -2.349) : pos_z = -2.349 + 0 = -2.349.
	# Pour côté gauche à x = -3.7 : pos_x = -3.7 + 0.325 = -3.375.
	_place_quaternius(root, "Kitchen_Fridge.fbx", Vector3(-3.375, 0.0, -2.349), 0.0)

	# Porte frigo = conteneur rotatif, verrouillée par clé.
	# Face avant du frigo à z = -2.349 + 0.651 = -1.698.
	# Charnière gauche (x = -3.7), front centré sur la porte.
	var fridge := _make_container(root, "FridgeDoor",
		InteractiveContainer.Mode.ROTATE,
		Vector3(-3.70, 0.83, -1.70), Vector3.ZERO, 0.0, 115.0,
		InteractiveContainer.LockType.KEY,
		Vector3(0.55, 1.50, 0.04), _mat_metal)
	fridge.front_mesh.position = Vector3(0.28, 0.0, 0.02)

	# --- Bas de cuisine Quaternius : 5 modules de 1.011 de large (×0.5 = 0.506 m) ---
	# x : -2.6 (évier) | -2.1 (tiroir clé) | -1.6 (four) | -1.1 (placard) | -0.6 (tiroir force)
	# pos_z = -3 + 0.56 = -2.44 (profondeur 1.120 × 0.5 = 0.56).
	var base_x := [-2.6, -2.1, -1.6, -1.1, -0.6]
	var base_fbx := [
		"Kitchen_Sink.fbx",       # 0 : évier
		"Kitchen_2Drawers.fbx",   # 1 : tiroir (clé)
		"Kitchen_Oven.fbx",       # 2 : four
		"Kitchen_Cabinet1.fbx",   # 3 : placard
		"Kitchen_1Drawers.fbx",   # 4 : tiroir (forceable)
	]
	for i in base_x.size():
		_place_quaternius(root, base_fbx[i], Vector3(base_x[i], 0.0, -2.44), 0.0)

	# Tiroirs interactifs — un par module (sauf évier et placard).
	# Cavité à z ∈ [-2.72, -2.44]. Front fermé à z = -2.44.
	var drawer_x := [-2.1, -1.6, -0.6]
	var drawer_lock := [
		InteractiveContainer.LockType.KEY,
		InteractiveContainer.LockType.NONE,
		InteractiveContainer.LockType.FORCEABLE,
	]
	var drawer_fbx := ["Kitchen_2Drawers.fbx", "Kitchen_Oven.fbx", "Kitchen_1Drawers.fbx"]
	for i in drawer_x.size():
		# Cavité sombre (fond du tiroir).
		_box(root, "DrawerCavity%d" % i, Vector3(0.45, 0.14, 0.28),
			Vector3(drawer_x[i], 0.36, -2.58), _new_mat(Color(0.10, 0.09, 0.08)))
		_make_container(root, "KitchenDrawer%d" % i,
			InteractiveContainer.Mode.SLIDE,
			Vector3(drawer_x[i], 0.36, -2.44), Vector3.BACK, 0.42, 115.0,
			drawer_lock[i],
			Vector3(0.45, 0.16, 0.03), _mat_bois)

	# --- Hauts de cuisine (mur nord) ---
	# AABB Kitchen_CabinetSmall : 0.861 x 0.947 x 1.071 (×0.5 = 0.43 x 0.47 x 0.54).
	# pos_z = -3 + 0.27 = -2.73. pos_y = 1.32.
	var upper_x := [-2.6, -2.1, -1.1, -0.6]
	for i in upper_x.size():
		_place_quaternius(root, "Kitchen_CabinetSmall.fbx",
			Vector3(upper_x[i], 1.32, -2.73), 0.0)

	# --- Plan de travail continu ---
	_box(root, "CounterTop", Vector3(2.60, 0.03, 0.50),
		Vector3(-1.60, COUNTER_Y - 0.015, -2.72), _mat_meuble)

	# --- Petit électroménager Kenney sur le plan de travail ---
	_place_furniture(root, FURN + "toaster.glb", Vector3(-0.55, COUNTER_Y, -2.70), -10.0)
	_place_furniture(root, FURN + "kitchenCoffeeMachine.glb", Vector3(-2.40, COUNTER_Y, -2.70), 0.0)
	_place_furniture(root, FURN + "kitchenMicrowave.glb", Vector3(-1.90, COUNTER_Y, -2.72), 0.0)
	_place_furniture(root, FURN + "kitchenBlender.glb", Vector3(-1.10, COUNTER_Y, -2.72), 15.0)

	# --- Set dressing cuisine (nourriture + vaisselle Kenney) ---
	_place_food(root, "loaf.glb", Vector3(-2.55, COUNTER_Y, -2.75), 0.0)
	_place_food(root, "cutting-board.glb", Vector3(-2.30, COUNTER_Y, -2.68), 30.0)
	_place_food(root, "apple.glb", Vector3(-2.32, COUNTER_Y + 0.02, -2.68), 0.0)
	_place_food(root, "shaker-salt.glb", Vector3(-1.55, COUNTER_Y, -2.70), 0.0)
	_place_food(root, "shaker-pepper.glb", Vector3(-1.48, COUNTER_Y, -2.70), 0.0)
	_place_food(root, "bottle-oil.glb", Vector3(-1.35, COUNTER_Y, -2.72), 0.0)
	_place_food(root, "tomato.glb", Vector3(-0.80, COUNTER_Y, -2.72), 20.0)
	_place_food(root, "pizza-box.glb", Vector3(-0.35, COUNTER_Y, -2.70), 10.0)
	_place_food(root, "knife-block.glb", Vector3(-2.72, COUNTER_Y, -2.65), 0.0)

	# --- Bar de cuisine (séparation cuisine/salon) ---
	# AABB Shelf_Small1 : 1.944 x 0.577 x 0.550 (×0.5 = 0.97 x 0.29 x 0.28).
	# pos : x = 0.95, z = -2.0. rot 90° face à -x.
	_place_quaternius(root, "Shelf_Small1.fbx", Vector3(0.95, 0.0, -2.0), 90.0)
	# Tabouret Quaternius.
	# AABB Stool : 0.675 x 1.372 x 0.710 (×0.5 = 0.34 x 0.69 x 0.36).
	_place_quaternius(root, "Stool.fbx", Vector3(1.45, 0.0, -2.0), -90.0)
	_place_quaternius(root, "Stool.fbx", Vector3(1.45, 0.0, -1.55), -90.0)

	# Nourriture posée sur le bar.
	_place_food(root, "plate.glb", Vector3(0.95, 0.30, -1.80), 0.0)
	_place_food(root, "glass-wine.glb", Vector3(0.85, 0.30, -1.95), 0.0)
	_place_food(root, "burger-cheese.glb", Vector3(1.05, 0.30, -1.75), 15.0)

	# Poubelle Quaternius près du bar.
	# AABB Trashcan_Small1 : 0.503 x 0.712 x 0.306 (×0.5 = 0.25 x 0.36 x 0.15).
	_place_quaternius(root, "Trashcan_Small1.fbx", Vector3(1.30, 0.0, -0.85), 0.0)

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

	# Suspension Quaternius au-dessus du bar.
	# AABB Light_CeilingSingle : 0.264 x 0.478 x 0.278 (×0.5 = 0.13 x 0.24 x 0.14).
	_place_quaternius(root, "Light_CeilingSingle.fbx", Vector3(0.95, 2.4, -2.0), 0.0)

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
# SALON (moitié sud, z > 0) — Quaternius gros mobilier + Kenney déco.
# ---------------------------------------------------------------------------
func _build_living_room() -> void:
	var root := Node3D.new()
	root.name = "LivingRoom"
	add_child(root)

	# --- Canapé Quaternius (mur sud) ---
	# AABB Couch_Medium1 : 4.688 x 1.910 x 2.203 (×0.5 = 2.34 x 0.96 x 1.10).
	# pos_z = 3 - 1.10 = 1.90. rot 180° dos au mur.
	_place_quaternius(root, "Couch_Medium1.fbx", Vector3(0.6, 0.0, 1.90), 180.0)

	# Fauteuil Quaternius (coin lecture, nord-ouest).
	# AABB Chair_1 : 0.762 x 1.768 x 0.825 (×0.5 = 0.38 x 0.88 x 0.41).
	_place_quaternius(root, "Chair_1.fbx", Vector3(-3.0, 0.0, -0.8), -135.0)

	# --- Tapis Quaternius sous la table basse ---
	# AABB Carpet_1 : 2.131 x 0.037 x 3.093 (×0.5 = 1.07 x 0.02 x 1.55).
	# pos_y = 0.005 (épaisseur minimale).
	_place_quaternius(root, "Carpet_1.fbx", Vector3(0.6, 0.005, 1.20), 0.0)

	# --- Table basse Quaternius ---
	# AABB Table_RoundSmall : 1.941 x 1.147 x 1.941 (×0.5 = 0.97 x 0.57 x 0.97).
	_place_quaternius(root, "Table_RoundSmall.fbx", Vector3(0.6, 0.0, 1.20), 0.0)

	# Déco sur la table basse.
	_place_furniture(root, FURN + "books.glb", Vector3(0.45, 0.57, 1.15), 20.0)
	_place_food(root, "mug.glb", Vector3(0.75, 0.57, 1.25), 0.0)
	_place_food(root, "plate-deep.glb", Vector3(0.60, 0.57, 1.10), 0.0)
	_place_food(root, "cookie.glb", Vector3(0.60, 0.58, 1.10), 0.0)

	# --- Meuble TV Kenney (mur ouest) ---
	# AABB cabinetTelevision : 0.80 x 0.31 x 0.25. rot 90° face à l'est.
	# pos_x = -4 + 0.25 = -3.75.
	_place_furniture(root, FURN + "cabinetTelevision.glb", Vector3(-3.75, 0.0, 0.8), 90.0)
	# TV posée sur le meuble (hauteur 0.31).
	_place_furniture(root, FURN + "televisionModern.glb", Vector3(-3.62, 0.31, 0.8), 90.0)
	# Enceintes de part et d'autre de la TV.
	_place_furniture(root, FURN + "speaker.glb", Vector3(-3.60, 0.31, 0.2), 90.0)
	_place_furniture(root, FURN + "speaker.glb", Vector3(-3.60, 0.31, 1.4), 90.0)

	# --- Bibliothèque Quaternius (mur est) ---
	# AABB Bookshelf : 2.318 x 4.438 x 0.756 (×0.5 = 1.16 x 2.22 x 0.38).
	# rot 180° dos au mur est. pos_x = 4 - 0.38 = 3.62.
	_place_quaternius(root, "Bookshelf.fbx", Vector3(3.62, 0.0, 0.0), 180.0)
	# Livres Kenney empilés sur la bibliothèque.
	_place_furniture(root, FURN + "books.glb", Vector3(3.55, 2.22, 0.05), 10.0)
	_place_furniture(root, FURN + "books.glb", Vector3(3.70, 2.22, -0.08), -5.0)

	# Placard de rangement Quaternius (conteneur forceable) — même mur, au nord.
	# AABB Drawer_4 : 2.794 x 2.070 x 1.119 (×0.5 = 1.40 x 1.04 x 0.56).
	# pos_x = 4 - 0.56 = 3.44.
	_place_quaternius(root, "Drawer_4.fbx", Vector3(3.44, 0.0, -1.5), 180.0)

	# Porte du placard = conteneur rotatif, FORCEABLE.
	# Face avant à z = -1.5 + 0.28 = -1.22. Charnière gauche (x = 3.0).
	var closet := _make_container(root, "ClosetDoor",
		InteractiveContainer.Mode.ROTATE,
		Vector3(3.0, 0.52, -1.22), Vector3.ZERO, 0.0, 115.0,
		InteractiveContainer.LockType.FORCEABLE,
		Vector3(0.65, 0.95, 0.03), _mat_meuble)
	closet.front_mesh.position = Vector3(0.33, 0.0, 0.015)

	# --- Table d'appoint Quaternius (coin lecture) ---
	# AABB NightStand_1 : 0.952 x 0.825 x 0.952 (×0.5 = 0.48 x 0.41 x 0.48).
	_place_quaternius(root, "NightStand_1.fbx", Vector3(-3.55, 0.0, -0.2), 0.0)
	# Lampe de table Kenney sur la table d'appoint.
	_place_furniture(root, FURN + "lampSquareTable.glb", Vector3(-3.55, 0.41, -0.2), 0.0)
	# Lampe sur la table de chevet (à droite du canapé).
	_place_furniture(root, FURN + "lampSquareFloor.glb", Vector3(3.5, 0.0, 2.5), 0.0)

	# --- Plante et déco ---
	_place_quaternius(root, "Houseplant_6.fbx", Vector3(-3.7, 0.0, -2.7), 0.0)
	_place_quaternius(root, "Houseplant_2.fbx", Vector3(3.7, 0.0, 2.7), 0.0)
	_place_quaternius(root, "Houseplant_3.fbx", Vector3(-3.7, 0.0, 2.7), 0.0)
	# Boîtes en carton Kenney dans le coin (déménagement en cours).
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

	# Plafonnier Quaternius central.
	# AABB Light_Ceiling3 : 0.537 x 0.678 x 0.537 (×0.5 = 0.27 x 0.34 x 0.27).
	_place_quaternius(root, "Light_Ceiling3.fbx", Vector3(0, 2.7, 0), 0.0)

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
	fake1.position = Vector3(0.30, 0.57, 1.05)
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
	fake2.position = Vector3(-3.55, 0.41, -0.05)
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
			_spawn_spots.append({"pos": Vector3(-3.44, 0.83, -1.65), "container": c})
	# Surfaces ouvertes.
	_spawn_spots.append({"pos": Vector3(-0.55, 0.61, -2.70), "container": null}) # toaster
	_spawn_spots.append({"pos": Vector3(0.60, 0.57, 1.20), "container": null}) # table basse
	_spawn_spots.append({"pos": Vector3(0.60, 0.96, 1.90), "container": null}) # canapé
	_spawn_spots.append({"pos": Vector3(-3.55, 0.41, -0.20), "container": null}) # table d'appoint
	_spawn_spots.append({"pos": Vector3(3.62, 2.22, 0.00), "container": null}) # dessus bibliothèque
	_spawn_spots.append({"pos": Vector3.ZERO, "container": null, "floor": true}) # sol


func _key_spots() -> Array[Vector3]:
	return [
		Vector3(0.60, 0.57, 1.20),   # table basse
		Vector3(-0.55, 0.61, -2.70), # plan de travail
		Vector3(3.62, 2.22, 0.00),   # dessus bibliothèque
		Vector3(-3.55, 0.41, -0.20), # table d'appoint
		Vector3(0.60, 0.96, 1.90),   # canapé
	]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _place_food(parent: Node, glb_name: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	return _place_furniture(parent, FOOD + glb_name, pos, rot_y)
