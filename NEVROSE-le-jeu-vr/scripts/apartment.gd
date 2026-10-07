class_name Apartment
extends Node3D
## Générateur procédural de la première pièce (studio — GDD §7).
##
## Zéro texture, zéro mesh importé : que des primitives partageant ~15
## matériaux à couleur plate. C'est ce qui rend la scène "jolie mais pas
## gourmande" sur Quest 2. La folie se lit sur les matériaux : leur teinte
## glisse vers un vert malade quand la jauge monte (GDD §5.2).

# ---------------------------------------------------------------------------
# Dimensions intérieures de la pièce (mètres)
# ---------------------------------------------------------------------------
const ROOM_W := 6.0 # x ∈ [-3, 3]
const ROOM_D := 4.5 # z ∈ [-2.25, 2.25]
const ROOM_H := 2.7
const WALL_T := 0.15

var containers: Array[InteractiveContainer] = []
var _dose: Dose = null
var _spawn_spots: Array[Dictionary] = [] # {pos: Vector3, container: InteractiveContainer|null}
var _insanity := 0.0

# Matériaux partagés (créés une fois)
var _mats := {}
var _breathers: Array[Dictionary] = [] # {mat, calm: Color, sick: Color}
var _lamp_light: OmniLight3D
var _lamp_base_energy := 2.4

# Primitives partagées (une seule ressource mesh pour toute la scène)
var _unit_box: BoxMesh
var _unit_cylinder: CylinderMesh


func _ready() -> void:
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_unit_cylinder = CylinderMesh.new()
	_make_materials()


# ---------------------------------------------------------------------------
# Matériaux : palette chaude "appart lambda", dérive malade en folie
# ---------------------------------------------------------------------------
func _make_materials() -> void:
	_reg("mur", Color(0.72, 0.65, 0.56), Color(0.42, 0.52, 0.38))
	_reg("mur2", Color(0.76, 0.70, 0.62), Color(0.45, 0.55, 0.40))
	_reg("plafond", Color(0.80, 0.77, 0.72), Color(0.5, 0.55, 0.45), false)
	_reg("sol", Color(0.42, 0.29, 0.20), Color(0.25, 0.22, 0.16), false)
	_reg("meuble", Color(0.36, 0.42, 0.35), Color(0.28, 0.38, 0.26))
	_reg("bois", Color(0.29, 0.21, 0.15), Color(0.2, 0.18, 0.12), false)
	_reg("tissu", Color(0.48, 0.23, 0.23), Color(0.3, 0.2, 0.28), false)
	_reg("tissu2", Color(0.69, 0.71, 0.74), Color(0.5, 0.55, 0.5), false)
	_reg("metal", Color(0.54, 0.56, 0.59), Color(0.4, 0.45, 0.4), false)
	_reg("noir", Color(0.04, 0.04, 0.05), Color(0.02, 0.03, 0.02), false)


func _reg(key: String, calm: Color, sick: Color, breathes := true) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = calm
	m.roughness = 0.92
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mats[key] = m
	if breathes:
		_breathers.append({"mat": m, "calm": calm, "sick": sick})


func _emissive_mat(key: String, color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.6
	_mats[key] = m
	return m


# ---------------------------------------------------------------------------
# Helpers de construction
# ---------------------------------------------------------------------------
func _box(parent: Node, name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = _unit_box
	mi.scale = size
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _cyl(parent: Node, name: String, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = _unit_cylinder
	mi.scale = Vector3(radius * 2.0, height, radius * 2.0)
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _make_container(parent: Node, name: String, cmode: InteractiveContainer.Mode, slot_pos: Vector3, axis: Vector3, dist: float, angle := 115.0) -> InteractiveContainer:
	var c := InteractiveContainer.new(cmode, axis, dist, angle)
	c.name = name
	c.position = slot_pos
	parent.add_child(c)
	# Zone d'interaction : boîte un peu plus grosse que le conteneur
	c.area = Area3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 0.5, 0.6)
	cs.shape = bs
	c.area.add_child(cs)
	c.add_child(c.area)
	containers.append(c)
	return c


# ---------------------------------------------------------------------------
# Construction complète de la pièce
# ---------------------------------------------------------------------------
func build() -> void:
	_build_shell()
	_build_kitchen()
	_build_bed()
	_build_wardrobe()
	_build_table_set()
	_build_shelf()
	_build_lamp_and_lights()
	_build_window()
	_build_mimic_mugs()
	_register_spawn_spots()


# Coquille : sol, plafond, 4 murs + couloir noir derrière la porte.
func _build_shell() -> void:
	var root := Node3D.new()
	root.name = "Shell"
	add_child(root)
	var m_mur: Material = _mats["mur"]
	var m_mur2: Material = _mats["mur2"]
	var m_sol: Material = _mats["sol"]
	var m_plaf: Material = _mats["plafond"]
	var m_noir: Material = _mats["noir"]

	_box(root, "Floor", Vector3(ROOM_W + 0.6, 0.1, ROOM_D + 0.6), Vector3(0, -0.05, 0), m_sol)
	_box(root, "Ceiling", Vector3(ROOM_W + 0.6, 0.1, ROOM_D + 0.6), Vector3(0, ROOM_H + 0.05, 0), m_plaf)

	# Mur nord (cuisine) : plein
	_box(root, "WallN", Vector3(ROOM_W + 0.6, ROOM_H, WALL_T), Vector3(0, ROOM_H / 2, -(ROOM_D / 2) - WALL_T / 2), m_mur)
	# Mur ouest : plein
	_box(root, "WallW", Vector3(WALL_T, ROOM_H, ROOM_D + 0.6), Vector3(-(ROOM_W / 2) - WALL_T / 2, ROOM_H / 2, 0), m_mur2)
	# Mur sud (fenêtre) : 4 segments autour d'une fenêtre 1,6 × 1,2
	var win_w := 1.6
	var win_sill := 0.9
	var win_top := 2.1
	var seg_w := (ROOM_W - win_w) / 2.0
	_box(root, "WallS_L", Vector3(seg_w, ROOM_H, WALL_T), Vector3(-(win_w / 2) - seg_w / 2, ROOM_H / 2, ROOM_D / 2 + WALL_T / 2), m_mur)
	_box(root, "WallS_R", Vector3(seg_w, ROOM_H, WALL_T), Vector3(win_w / 2 + seg_w / 2, ROOM_H / 2, ROOM_D / 2 + WALL_T / 2), m_mur)
	_box(root, "WallS_Top", Vector3(win_w, ROOM_H - win_top, WALL_T), Vector3(0, win_top + (ROOM_H - win_top) / 2, ROOM_D / 2 + WALL_T / 2), m_mur)
	_box(root, "WallS_Sill", Vector3(win_w, win_sill, WALL_T), Vector3(0, win_sill / 2, ROOM_D / 2 + WALL_T / 2), m_mur)
	# Mur est (porte z ∈ [0.55, 1.45], h 2.1) + linteau
	var door_z0 := 0.55
	var door_z1 := 1.45
	var door_h := 2.1
	var seg_a := door_z0 + ROOM_D / 2 # longueur segment nord
	var seg_b := ROOM_D / 2 - door_z1
	_box(root, "WallE_A", Vector3(WALL_T, ROOM_H, seg_a), Vector3(ROOM_W / 2 + WALL_T / 2, ROOM_H / 2, door_z0 - seg_a / 2), m_mur2)
	_box(root, "WallE_B", Vector3(WALL_T, ROOM_H, seg_b), Vector3(ROOM_W / 2 + WALL_T / 2, ROOM_H / 2, door_z1 + seg_b / 2), m_mur2)
	_box(root, "WallE_Lintel", Vector3(WALL_T, ROOM_H - door_h, door_z1 - door_z0), Vector3(ROOM_W / 2 + WALL_T / 2, door_h + (ROOM_H - door_h) / 2, (door_z0 + door_z1) / 2), m_mur2)

	# Couloir noir : 1,8 m de tunnel qui vend "l'appart continue ailleurs"
	var corr_d := 1.8
	var corr_c := (door_z0 + door_z1) / 2.0
	var corr_w := door_z1 - door_z0
	_box(root, "CorrFloor", Vector3(corr_d, 0.1, corr_w + 0.3), Vector3(ROOM_W / 2 + corr_d / 2, -0.05, corr_c), m_noir)
	_box(root, "CorrCeil", Vector3(corr_d, 0.1, corr_w + 0.3), Vector3(ROOM_W / 2 + corr_d / 2, ROOM_H + 0.05, corr_c), m_noir)
	_box(root, "CorrN", Vector3(corr_d, ROOM_H, WALL_T), Vector3(ROOM_W / 2 + corr_d / 2, ROOM_H / 2, door_z0 - WALL_T / 2), m_noir)
	_box(root, "CorrS", Vector3(corr_d, ROOM_H, WALL_T), Vector3(ROOM_W / 2 + corr_d / 2, ROOM_H / 2, door_z1 + WALL_T / 2), m_noir)
	_box(root, "CorrEnd", Vector3(WALL_T, ROOM_H, corr_w + 0.3), Vector3(ROOM_W / 2 + corr_d, ROOM_H / 2, corr_c), m_noir)


# Cuisine le long du mur nord : caisson, plan de travail, 3 tiroirs.
func _build_kitchen() -> void:
	var root := Node3D.new()
	root.name = "Kitchen"
	add_child(root)
	var m_meuble: Material = _mats["meuble"]
	var m_bois: Material = _mats["bois"]
	var m_metal: Material = _mats["metal"]

	_box(root, "Carcass", Vector3(2.6, 0.84, 0.6), Vector3(-1.3, 0.42, -1.95), m_meuble)
	_box(root, "CounterTop", Vector3(2.7, 0.05, 0.68), Vector3(-1.3, 0.885, -1.95), m_bois)

	# 3 tiroirs qui glissent vers +Z
	for i in 3:
		var cx := -2.2 + i * 0.9
		var drawer := _make_container(root, "Drawer%d" % i, InteractiveContainer.Mode.SLIDE, Vector3(cx, 0.72, -1.63), Vector3.BACK, 0.45)
		drawer.front_mesh = _box(drawer, "Front", Vector3(0.8, 0.17, 0.03), Vector3.ZERO, m_bois)
		_box(drawer, "Body", Vector3(0.74, 0.12, 0.5), Vector3(0, 0, -0.26), m_meuble)
		_box(drawer, "Handle", Vector3(0.3, 0.025, 0.03), Vector3(0, 0.0, 0.03), m_metal)
		drawer._mat_normal = m_bois
		var hover := StandardMaterial3D.new()
		hover.albedo_color = Color(0.45, 0.75, 0.7)
		hover.emission_enabled = true
		hover.emission = Color(0.2, 0.6, 0.55)
		hover.emission_energy_multiplier = 0.5
		drawer._mat_hover = hover


# Coin chambre : lit + oreiller, le long du mur ouest côté sud.
func _build_bed() -> void:
	var root := Node3D.new()
	root.name = "Bed"
	add_child(root)
	var m_bois: Material = _mats["bois"]
	var m_tissu: Material = _mats["tissu"]
	var m_tissu2: Material = _mats["tissu2"]

	_box(root, "Frame", Vector3(2.0, 0.25, 1.4), Vector3(-1.95, 0.125, 1.3), m_bois)
	_box(root, "Mattress", Vector3(1.92, 0.18, 1.32), Vector3(-1.95, 0.34, 1.3), m_tissu2)
	_box(root, "Blanket", Vector3(1.3, 0.06, 1.34), Vector3(-1.6, 0.45, 1.3), m_tissu)
	_box(root, "Pillow", Vector3(0.45, 0.12, 0.6), Vector3(-2.75, 0.47, 1.3), m_tissu2)


# Placard sur le mur est (porte pivotante) — spawn de pilule possible.
func _build_wardrobe() -> void:
	var root := Node3D.new()
	root.name = "Wardrobe"
	add_child(root)
	var m_meuble: Material = _mats["meuble"]
	var m_noir: Material = _mats["noir"]

	_box(root, "Body", Vector3(0.6, 2.1, 1.2), Vector3(2.65, 1.05, -1.5), m_meuble)
	_box(root, "Interior", Vector3(0.5, 1.9, 1.05), Vector3(2.62, 1.05, -1.5), m_noir)

	# 2 portes pivotantes sur charnières latérales (axe Y)
	var door_w := 0.55
	for i in 2:
		var hinge_z := -2.1 + i * 1.1 # charnière sud puis nord
		var door := InteractiveContainer.new(InteractiveContainer.Mode.ROTATE, Vector3.ZERO, 0.0, 115.0)
		door.name = "WardrobeDoor%d" % i
		root.add_child(door)
		door.position = Vector3(2.32, 1.05, hinge_z)
		if i == 1:
			door.rotate_angle = -115.0 # la porte nord pivote dans l'autre sens
		var mesh_z := door_w / 2.0 * (1.0 if i == 0 else -1.0)
		door.front_mesh = _box(door, "Door", Vector3(0.04, 2.0, door_w), Vector3(0, 0, mesh_z), m_meuble)
		door._mat_normal = m_meuble
		var hover := StandardMaterial3D.new()
		hover.albedo_color = Color(0.45, 0.75, 0.7)
		hover.emission_enabled = true
		hover.emission = Color(0.2, 0.6, 0.55)
		hover.emission_energy_multiplier = 0.5
		door._mat_hover = hover
		# Zone d'interaction
		door.area = Area3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.3, 2.0, door_w)
		cs.shape = bs
		cs.position = Vector3(0, 0, mesh_z)
		door.area.add_child(cs)
		door.add_child(door.area)
		containers.append(door)


# Table + 2 chaises au centre.
func _build_table_set() -> void:
	var root := Node3D.new()
	root.name = "TableSet"
	add_child(root)
	var m_bois: Material = _mats["bois"]

	_box(root, "Top", Vector3(1.3, 0.05, 0.8), Vector3(-0.2, 0.75, 0.3), m_bois)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(root, "Leg", Vector3(0.06, 0.75, 0.06), Vector3(-0.2 + sx * 0.58, 0.375, 0.3 + sz * 0.33), m_bois)
	# Chaises (assis + dossier)
	_box(root, "ChairA_Seat", Vector3(0.42, 0.05, 0.42), Vector3(-0.2, 0.46, 1.05), m_bois)
	_box(root, "ChairA_Back", Vector3(0.42, 0.5, 0.05), Vector3(-0.2, 0.73, 1.24), m_bois)
	_box(root, "ChairB_Seat", Vector3(0.42, 0.05, 0.42), Vector3(0.75, 0.46, 0.3), m_bois)
	_box(root, "ChairB_Back", Vector3(0.05, 0.5, 0.42), Vector3(0.94, 0.73, 0.3), m_bois)
	# Tapis sous la table
	_box(root, "Rug", Vector3(1.9, 0.012, 1.3), Vector3(0.2, 0.006, 0.5), _mats["tissu"])


# Étagère murale ouest + quelques boîtes.
func _build_shelf() -> void:
	var root := Node3D.new()
	root.name = "Shelf"
	add_child(root)
	var m_bois: Material = _mats["bois"]
	var m_meuble: Material = _mats["meuble"]
	for i in 3:
		var y := 1.0 + i * 0.4
		_box(root, "Plank%d" % i, Vector3(0.26, 0.04, 1.4), Vector3(-2.85, y, -0.5), m_bois)
	# Boîtes posées sur les planches
	_box(root, "BoxA", Vector3(0.2, 0.18, 0.3), Vector3(-2.85, 1.11, -0.9), m_meuble)
	_box(root, "BoxB", Vector3(0.18, 0.22, 0.25), Vector3(-2.85, 1.51, -0.25), m_meuble)
	_box(root, "BoxC", Vector3(0.2, 0.15, 0.35), Vector3(-2.85, 1.86, -0.6), m_bois)


# Lampadaire (émissif + OmniLight sans ombre) et plafonnier.
func _build_lamp_and_lights() -> void:
	var root := Node3D.new()
	root.name = "Lights"
	add_child(root)
	var m_metal: Material = _mats["metal"]

	_cyl(root, "LampPole", 0.025, 1.55, Vector3(2.55, 0.775, 1.95), m_metal)
	_cyl(root, "LampBase", 0.14, 0.03, Vector3(2.55, 0.015, 1.95), m_metal)
	var shade_mat := _emissive_mat("lampe", Color(1.0, 0.82, 0.55), 1.8)
	_cyl(root, "LampShade", 0.16, 0.22, Vector3(2.55, 1.62, 1.95), shade_mat)

	_lamp_light = OmniLight3D.new()
	_lamp_light.name = "LampLight"
	_lamp_light.position = Vector3(2.55, 1.6, 1.95)
	_lamp_light.light_color = Color(1.0, 0.78, 0.5)
	_lamp_light.light_energy = _lamp_base_energy
	_lamp_light.omni_range = 5.5
	_lamp_light.shadow_enabled = false # perf Quest 2 : pas d'ombre dynamique
	root.add_child(_lamp_light)

	var ceil_mat := _emissive_mat("plafonnier", Color(0.95, 0.92, 0.85), 1.2)
	_box(root, "CeilFixture", Vector3(0.5, 0.04, 0.5), Vector3(0, ROOM_H - 0.02, 0), ceil_mat)
	var ceil_light := OmniLight3D.new()
	ceil_light.name = "CeilLight"
	ceil_light.position = Vector3(0, ROOM_H - 0.3, 0)
	ceil_light.light_color = Color(0.92, 0.9, 0.86)
	ceil_light.light_energy = 1.1
	ceil_light.omni_range = 7.0
	ceil_light.shadow_enabled = false
	root.add_child(ceil_light)


# Fenêtre : cadre + vitre émissive (nuit bleue). L'extérieur n'existe pas —
# c'est le délire qui viendra s'y loger (GDD §7).
func _build_window() -> void:
	var root := Node3D.new()
	root.name = "Window"
	add_child(root)
	var m_bois: Material = _mats["bois"]
	var pane_mat := _emissive_mat("vitre", Color(0.14, 0.2, 0.32), 0.55)

	# Cadre
	_box(root, "FrameT", Vector3(1.7, 0.06, 0.1), Vector3(0, 2.08, ROOM_D / 2), m_bois)
	_box(root, "FrameB", Vector3(1.7, 0.06, 0.1), Vector3(0, 0.92, ROOM_D / 2), m_bois)
	_box(root, "FrameL", Vector3(0.06, 1.22, 0.1), Vector3(-0.82, 1.5, ROOM_D / 2), m_bois)
	_box(root, "FrameR", Vector3(0.06, 1.22, 0.1), Vector3(0.82, 1.5, ROOM_D / 2), m_bois)
	_box(root, "FrameM", Vector3(0.04, 1.16, 0.06), Vector3(0, 1.5, ROOM_D / 2), m_bois)
	# Vitre
	_box(root, "Pane", Vector3(1.58, 1.14, 0.02), Vector3(0, 1.5, ROOM_D / 2 + 0.04), pane_mat)


# Les deux tasses (GDD §5.3 : deux objets identiques, l'un tremble).
func _build_mimic_mugs() -> void:
	var root := Node3D.new()
	root.name = "MimicMugs"
	add_child(root)
	var m_mug := StandardMaterial3D.new()
	m_mug.albedo_color = Color(0.78, 0.8, 0.83)
	m_mug.roughness = 0.7
	_mats["tasse"] = m_mug

	# Vraie tasse : posée sur la table, immobile
	var real := Node3D.new()
	real.name = "MugReal"
	root.add_child(real)
	real.position = Vector3(-0.42, 0.775, 0.18)
	_cyl(real, "Cup", 0.045, 0.09, Vector3(0, 0.045, 0), m_mug)
	_box(real, "Handle", Vector3(0.02, 0.05, 0.03), Vector3(0.055, 0.05, 0), m_mug)

	# Mimic : identique, mais il tremble très légèrement
	var fake := Mimic.new()
	fake.name = "MugMimic"
	root.add_child(fake)
	fake.position = Vector3(-0.05, 0.775, 0.5)
	_cyl(fake, "Cup", 0.045, 0.09, Vector3(0, 0.045, 0), m_mug)
	_box(fake, "Handle", Vector3(0.02, 0.05, 0.03), Vector3(0.055, 0.05, 0), m_mug)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.16, 0.16, 0.16)
	cs.shape = bs
	cs.position = Vector3(0, 0.06, 0)
	fake.add_child(cs)


# ---------------------------------------------------------------------------
# Spawns de pilules (GDD §5.1 : tiroirs, plans de travail, tables, sol, placards)
# ---------------------------------------------------------------------------
func _register_spawn_spots() -> void:
	# Tiroirs de la cuisine (la pilule n'apparaît que si on les ouvre)
	for c in containers:
		if c.name.begins_with("Drawer"):
			_spawn_spots.append({"pos": Vector3.ZERO, "container": c})
	# Intérieur du placard
	for c in containers:
		if c.name.begins_with("WardrobeDoor"):
			_spawn_spots.append({"pos": Vector3.ZERO, "container": c})
	# Surfaces ouvertes
	_spawn_spots.append({"pos": Vector3(-0.9, 0.95, -1.9), "container": null}) # plan de travail
	_spawn_spots.append({"pos": Vector3(0.15, 0.83, 0.25), "container": null}) # table
	_spawn_spots.append({"pos": Vector3(-2.72, 0.56, 1.3), "container": null}) # oreiller
	_spawn_spots.append({"pos": Vector3.ZERO, "container": null, "floor": true}) # sol aléatoire


## Nouvelle run / nouvelle dose : une pilule apparaît dans un conteneur
## (ou sur une surface) tiré au hasard.
func spawn_dose() -> void:
	clear_dose()
	var spot: Dictionary = _spawn_spots.pick_random()
	_dose = Dose.new()
	_dose.name = "Dose"
	if spot.get("floor", false):
		add_child(_dose)
		_dose.position = Vector3(randf_range(-1.8, 1.8), 0.09, randf_range(-1.4, 1.6))
	elif spot["container"] != null:
		var c: InteractiveContainer = spot["container"]
		c.dose = _dose
		if c.mode == InteractiveContainer.Mode.SLIDE:
			# Tiroir : la pilule est dedans et sort avec lui.
			c.add_child(_dose)
			_dose.position = Vector3(0, 0.12, -0.05)
		else:
			# Placard : posée à l'intérieur, révélée quand une porte s'ouvre.
			add_child(_dose)
			_dose.position = Vector3(2.55, 0.8, -1.5)
		_dose.visible = false
		_dose.monitoring = false
		_dose.monitorable = false
	else:
		add_child(_dose)
		_dose.position = spot["pos"]


func clear_dose() -> void:
	if is_instance_valid(_dose):
		_dose.queue_free()
	_dose = null
	for c in containers:
		c.dose = null


## Reset de run : referme les conteneurs ouverts (GDD §5.4 réparation = super-médoc,
## ici on répare "manuellement" pour la boucle test).
func reset_containers() -> void:
	clear_dose()
	for c in containers:
		if c.is_open:
			c.interact()


# ---------------------------------------------------------------------------
# Folie : les matériaux glissent vers la teinte malade, la lampe grésille.
# Appelé chaque frame par main.gd avec t ∈ [0, 1].
# ---------------------------------------------------------------------------
func set_insanity(t: float) -> void:
	_insanity = t
	for b in _breathers:
		(b["mat"] as StandardMaterial3D).albedo_color = (b["calm"] as Color).lerp(b["sick"] as Color, t)


func _process(_delta: float) -> void:
	# Grésillement de la lampe quand ça va mal — coût nul, effet fort.
	if _lamp_light and _insanity > 0.55:
		var jitter := sin(Time.get_ticks_msec() / 37.0) * sin(Time.get_ticks_msec() / 91.0)
		_lamp_light.light_energy = _lamp_base_energy * (1.0 + jitter * 0.35 * _insanity)
