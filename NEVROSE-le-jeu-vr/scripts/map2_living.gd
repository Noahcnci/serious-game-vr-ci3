class_name Map2Living
extends MapBase
## Map 2 (fragment 2) : salon + cuisine, 8 x 6 m (GDD §7).
##
## La coquille (sol/murs/plafond/fenêtre/porte/couloir) vient de
## scenes/map2_living.tscn — instanciée ici enfant de cette racine.
## Cette classe ajoute les meubles Kenney (GLB), les conteneurs interactifs
## (tiroirs / placards verrouillés), les mimics, les spots de dose et les clés.

const SCENE_SHELL := "res://scenes/map2_living.tscn"
const FURN := "res://assets/kenney/furniture/"

# Matériaux propres à la map (teinte calm, dérive sick gérée par MapBase).
var _mat_bois: StandardMaterial3D
var _mat_meuble: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_tissu: StandardMaterial3D


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
	_mat_bois = _new_mat(Color(0.29, 0.21, 0.15))
	_mat_meuble = _new_mat(Color(0.36, 0.42, 0.35))
	_mat_metal = _new_mat(Color(0.54, 0.56, 0.59))
	_mat_tissu = _new_mat(Color(0.48, 0.23, 0.23))
	_reg_breather(_mat_bois, Color(0.29, 0.21, 0.15), Color(0.2, 0.18, 0.12))
	_reg_breather(_mat_meuble, Color(0.36, 0.42, 0.35), Color(0.28, 0.38, 0.26))


func _new_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


# ---------------------------------------------------------------------------
# Coquille (sol/murs/plafond depuis la scène)
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
# Cuisine (mur nord, z = -3). Plan de travail y ≈ 0.9.
# ---------------------------------------------------------------------------
func _build_kitchen() -> void:
	var root := Node3D.new()
	root.name = "Kitchen"
	add_child(root)

	# Bas de cuisine : 6 caissons 0.43 de large, de x = -2.6 à x = +0.55
	# (faces à z = -2.75, profondeur ~0.48 → centre z ≈ -2.51)
	var base_x := [-2.6, -2.17, -1.74, -1.31, -0.88, -0.45]
	for i in base_x.size():
		var lock := InteractiveContainer.LockType.NONE
		var glb := FURN + "kitchenCabinetDrawer.glb"
		if i == 2:
			lock = InteractiveContainer.LockType.KEY # tiroir verrouillé (clé)
		if i == 4:
			lock = InteractiveContainer.LockType.FORCEABLE # se force
		if i == 1:
			glb = FURN + "kitchenSink.glb"
		elif i == 3:
			glb = FURN + "kitchenStove.glb"
		_place_furniture(root, glb, Vector3(base_x[i], 0.0, -2.51), 0.0)
		# Tiroir interactif devant chaque caisson (glisse vers +z)
		var drawer := _make_container(root, "KitchenDrawer%d" % i,
			InteractiveContainer.Mode.SLIDE,
			Vector3(base_x[i], 0.72, -2.28), Vector3.BACK, 0.45, 115.0, lock,
			Vector3(0.4, 0.18, 0.03), _mat_bois)
		drawer.front_mesh.position = Vector3.ZERO

	# Frigo (tout le temps à gauche, x = -3.5)
	_place_furniture(root, FURN + "kitchenFridgeLarge.glb", Vector3(-3.5, 0.0, -2.55), 0.0)
	# Porte de frigo = conteneur rotatif, verrouillée par clé
	var fridge := _make_container(root, "FridgeDoor",
		InteractiveContainer.Mode.ROTATE,
		Vector3(-3.08, 0.66, -2.55), Vector3.ZERO, 0.0, 115.0,
		InteractiveContainer.LockType.KEY,
		Vector3(0.04, 1.25, 0.55), _mat_metal)
	fridge.front_mesh.position = Vector3(0, 0, 0.28)

	# Hauts de cuisine (y ≈ 1.5), 4 caissons
	var upper_x := [-2.5, -1.86, -1.22, -0.58]
	for i in upper_x.size():
		_place_furniture(root, FURN + "kitchenCabinetUpper.glb", Vector3(upper_x[i], 1.32, -2.72), 0.0)

	# Petit électroménager posé sur le plan de travail
	_place_furniture(root, FURN + "toaster.glb", Vector3(0.3, 0.9, -2.6), 15.0)
	_place_furniture(root, FURN + "kitchenCoffeeMachine.glb", Vector3(-1.7, 0.9, -2.65), 0.0)
	_place_furniture(root, FURN + "kitchenMicrowave.glb", Vector3(-2.35, 0.9, -2.65), 0.0)

	# Lumière de la cuisine (grésille en folie)
	var klight := OmniLight3D.new()
	klight.name = "KitchenLight"
	klight.position = Vector3(-1.4, 2.3, -2.0)
	klight.light_color = Color(0.95, 0.88, 0.75)
	klight.light_energy = 1.2
	klight.omni_range = 5.0
	klight.shadow_enabled = false
	root.add_child(klight)
	_reg_flicker(klight, 1.2)


# ---------------------------------------------------------------------------
# Salon (moitié sud, z > 0)
# ---------------------------------------------------------------------------
func _build_living_room() -> void:
	var root := Node3D.new()
	root.name = "LivingRoom"
	add_child(root)

	# Canapé en L le long du mur sud et du coin sud-est
	_place_furniture(root, FURN + "loungeSofaLong.glb", Vector3(0.6, 0.0, 2.4), 180.0)
	_place_furniture(root, FURN + "loungeSofaCorner.glb", Vector3(2.5, 0.0, 2.35), 180.0)

	# Table basse devant le canapé
	_place_furniture(root, FURN + "tableCoffee.glb", Vector3(0.6, 0.0, 1.2), 0.0)

	# Tapis sous la table basse
	_place_furniture(root, FURN + "rugRectangle.glb", Vector3(0.6, 0.005, 1.3), 0.0)

	# Meuble TV contre le mur ouest (face vers le canapé, donc rot 90°)
	_place_furniture(root, FURN + "cabinetTelevision.glb", Vector3(-3.55, 0.0, 0.8), 90.0)
	_place_furniture(root, FURN + "televisionModern.glb", Vector3(-3.5, 0.32, 0.8), 90.0)

	# Enceintes de part et d'autre du meuble TV
	_place_furniture(root, FURN + "speaker.glb", Vector3(-3.5, 0.32, -0.2), 90.0)
	_place_furniture(root, FURN + "speaker.glb", Vector3(-3.5, 0.32, 1.8), 90.0)

	# Bibliothèque contre le mur sud, à droite
	_place_furniture(root, FURN + "bookcaseClosedDoors.glb", Vector3(2.6, 0.0, -0.5), 0.0)

	# Placard de rangement (conteneur forceable) contre le mur nord-est
	_place_furniture(root, FURN + "bookcaseClosed.glb", Vector3(3.3, 0.0, -2.5), 180.0)
	var closet := _make_container(root, "ClosetDoor",
		InteractiveContainer.Mode.ROTATE,
		Vector3(3.05, 0.9, -2.6), Vector3.ZERO, 0.0, 115.0,
		InteractiveContainer.LockType.FORCEABLE,
		Vector3(0.5, 1.6, 0.04), _mat_meuble)
	closet.front_mesh.position = Vector3(0, 0, -0.02)

	# Table de chevet + lampe à côté du canapé
	_place_furniture(root, FURN + "sideTableDrawers.glb", Vector3(-1.4, 0.0, 2.5), 0.0)
	_place_furniture(root, FURN + "lampSquareFloor.glb", Vector3(-1.9, 0.0, 2.5), 0.0)

	# Plantes vertes (décor)
	_place_furniture(root, FURN + "pottedPlant.glb", Vector3(-3.6, 0.0, -2.7), 0.0)
	_place_furniture(root, FURN + "plantSmall1.glb", Vector3(3.7, 0.0, 2.7), 0.0)
	_place_furniture(root, FURN + "plantSmall2.glb", Vector3(3.7, 0.0, -0.2), 0.0)

	# Lumière du salon (grésille en folie)
	var llight := OmniLight3D.new()
	llight.name = "LivingLight"
	llight.position = Vector3(0.5, 2.3, 1.0)
	llight.light_color = Color(1.0, 0.82, 0.55)
	llight.light_energy = 1.4
	llight.omni_range = 6.0
	llight.shadow_enabled = false
	root.add_child(llight)
	_reg_flicker(llight, 1.4)

	# Lumière ambiante générale (plafonnier central)
	var clight := OmniLight3D.new()
	clight.name = "CeilLight"
	clight.position = Vector3(0, 2.4, 0)
	clight.light_color = Color(0.92, 0.9, 0.86)
	clight.light_energy = 0.8
	clight.omni_range = 8.0
	clight.shadow_enabled = false
	root.add_child(clight)


# ---------------------------------------------------------------------------
# Mimics (fausses tasses — GDD §5.3)
# ---------------------------------------------------------------------------
func _place_mimics() -> void:
	# Une vraie tasse + un mimic (même mesh, l'un tremble) sur la table basse
	const FOOD := "res://assets/kenney/food/"
	var real := _place_furniture(self, FOOD + "cup-tea.glb", Vector3(0.4, 0.23, 1.1), 20.0)
	var fake := Mimic.new()
	fake.name = "MugMimic"
	add_child(fake)
	fake.position = Vector3(0.85, 0.23, 1.3)
	var mug := _place_furniture(fake, FOOD + "cup-tea.glb", Vector3.ZERO, 0.0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.16, 0.16, 0.16)
	cs.shape = bs
	cs.position = Vector3(0, 0.06, 0)
	fake.add_child(cs)
	mimics.append(fake)


# ---------------------------------------------------------------------------
# Spawns de dose (GDD §5.1)
# ---------------------------------------------------------------------------
func _register_spawn_spots() -> void:
	# Tiroirs de cuisine (pilule révélée à l'ouverture)
	for c in containers:
		if c.name.begins_with("KitchenDrawer"):
			_spawn_spots.append({"pos": Vector3.ZERO, "container": c})
	# Porte de frigo
	for c in containers:
		if c.name.begins_with("FridgeDoor"):
			_spawn_spots.append({"pos": Vector3(-3.2, 0.5, -2.4), "container": c})
	# Surfaces ouvertes
	_spawn_spots.append({"pos": Vector3(0.3, 0.93, -2.6), "container": null}) # toaster (plan de travail)
	_spawn_spots.append({"pos": Vector3(0.6, 0.28, 1.2), "container": null}) # table basse
	_spawn_spots.append({"pos": Vector3(0.6, 0.47, 2.4), "container": null}) # canapé
	_spawn_spots.append({"pos": Vector3(-1.4, 0.4, 2.5), "container": null}) # table de chevet
	_spawn_spots.append({"pos": Vector3(2.6, 0.93, -0.5), "container": null}) # bibliothèque
	_spawn_spots.append({"pos": Vector3.ZERO, "container": null, "floor": true}) # sol aléatoire


func _key_spots() -> Array[Vector3]:
	return [
		Vector3(0.6, 0.28, 1.2),  # table basse
		Vector3(0.3, 0.93, -2.6), # plan de travail (près du toaster)
		Vector3(2.6, 0.93, -0.5), # bibliothèque
		Vector3(-1.4, 0.4, 2.5),  # table de chevet
		Vector3(0.6, 0.47, 2.4),  # canapé
	]
