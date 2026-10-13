class_name Map2Extended
extends MapBase
## Map 2 étendue : salon + cuisine (existant) + couloir, garage, chambre,
## salle de bain, dressing (nouvelles pièces).
##
## La coquille existante vient de scenes/map2_extended.tscn (clone de map2_living.tscn).
## Les nouvelles pièces sont construites ici procéduralement :
##   - Couloir : murs/sol/plafond + portes vers les nouvelles pièces.
##   - Garage : béton, établi, lave-linge, cartons, conteneur FORCEABLE.
##   - Chambre : lit, bureau, bibliothèque, conteneurs KEY + NONE.
##   - SDB : sanitaires, armoire de toilette verrouillée KEY.
##   - Dressing : penderie, commode, conteneur FORCEABLE.
##
## Le gameplay (clés, mimics, spawns de dose) est rétrofitté dans la pièce existante
## ET ajouté dans les nouvelles pièces.

const SCENE_SHELL := "res://scenes/map2_extended.tscn"
const FURN := "res://assets/kenney/furniture/"
const FOOD := "res://assets/kenney/food/"
const QUAT := "res://assets/quaternius/"

## Facteur d'échelle global pour les modèles Quaternius (décimètres → mètres).
const QUATERNIUS_SCALE := 0.5

# Matériaux existants (repris de map2_living.gd)
var _mat_bois: StandardMaterial3D
var _mat_meuble: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_tissu: StandardMaterial3D
var _mat_cadre: StandardMaterial3D
var _mat_nourriture: StandardMaterial3D

# Nouveaux matériaux pour l'extension
var _mat_beton: StandardMaterial3D
var _mat_carrelage_blanc: StandardMaterial3D
var _mat_moquette: StandardMaterial3D
var _mat_mur_garage: StandardMaterial3D
var _mat_mur_sdb: StandardMaterial3D
var _mat_porte: StandardMaterial3D

const COUNTER_Y := 0.48

# Dimensions de la map étendue (pour le clamp joueur dans main.gd)
const EXT_W := 14.6  # -4.075 → 10.275
const EXT_D := 12.6  # -3 → +6

# Origines des nouvelles pièces (centre de chaque pièce)
const CORRIDOR_X := 4.675   # x = 4.075 → 5.275
const CORRIDOR_Z := 0.0     # z = -3 → +3
const GARAGE_X := 7.275     # x = 5.275 → 9.275
const GARAGE_Z := -0.5      # z = -3 → +2
const CHAMBRE_X := 6.775    # x = 5.275 → 8.275
const CHAMBRE_Z := 4.0      # z = +2 → +6
const DRESSING_X := 9.275   # x = 8.275 → 10.275
const DRESSING_Z := 3.5     # z = +2 → +5
const SDB_X := 6.525        # x = 5.275 → 7.775
const SDB_Z := 3.5          # z = +2 → +5


func _init() -> void:
	room_w = EXT_W
	room_d = EXT_D
	room_h = 2.7


func build() -> void:
	_make_materials()
	_instance_shell()
	# Nœuds de compatibilité pour le smoke test (décor déjà dans le .tscn)
	var kitchen := Node3D.new()
	kitchen.name = "Kitchen"
	add_child(kitchen)
	var living := Node3D.new()
	living.name = "LivingRoom"
	add_child(living)
	_build_extension()
	_build_existing_gameplay()
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
	# Nouveaux matériaux extension
	_mat_beton = _new_mat(Color(0.5, 0.5, 0.5))
	_mat_carrelage_blanc = _new_mat(Color(0.9, 0.9, 0.88))
	_mat_moquette = _new_mat(Color(0.8, 0.7, 0.65))
	_mat_mur_garage = _new_mat(Color(0.6, 0.6, 0.6))
	_mat_mur_sdb = _new_mat(Color(0.7, 0.8, 0.85))
	_mat_porte = _new_mat(Color(0.4, 0.28, 0.18))
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
		push_error("Map2Extended: coquille introuvable %s" % SCENE_SHELL)
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
		push_warning("Map2Extended: FBX Quaternius introuvable %s" % fbx_name)
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
# EXTENSION : couloir + 4 nouvelles pièces
# ---------------------------------------------------------------------------
func _build_extension() -> void:
	var root := Node3D.new()
	root.name = "Extension"
	add_child(root)

	_build_corridor(root)
	_build_garage(root)
	_build_chambre(root)
	_build_sdb(root)
	_build_dressing(root)


# ---------------------------------------------------------------------------
# COULOIR (x = 4.075 → 5.275, z = -3 → +3, 1.2 × 6 m)
# ---------------------------------------------------------------------------
func _build_corridor(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Corridor"
	parent.add_child(root)

	# Mur Ouest du couloir (x = 4.075, prolongation du mur Est existant)
	_wall(root, "CorrWallW", Vector3(4.075, 1.35, 0), Vector3(0.15, 2.7, 6.0), _mat_meuble)

	# Mur Est du couloir (x = 5.275) avec 4 ouvertures de porte
	# Porte garage : z = -2, Porte chambre : z = +0.5, Porte sdb : z = +2.5, Porte dressing : z = +1.5
	_wall(root, "CorrWallE_N", Vector3(5.275, 1.35, -2.5), Vector3(0.15, 2.7, 1.0), _mat_meuble)
	_wall(root, "CorrWallE_M1", Vector3(5.275, 1.35, -0.5), Vector3(0.15, 2.7, 1.0), _mat_meuble)
	_wall(root, "CorrWallE_M2", Vector3(5.275, 1.35, 1.5), Vector3(0.15, 2.7, 1.0), _mat_meuble)
	_wall(root, "CorrWallE_S", Vector3(5.275, 1.35, 2.9), Vector3(0.15, 2.7, 0.2), _mat_meuble)
	# Lintaux au-dessus des portes
	_wall(root, "CorrLintel1", Vector3(5.275, 2.4, -1.5), Vector3(0.15, 0.6, 1.0), _mat_meuble)
	_wall(root, "CorrLintel2", Vector3(5.275, 2.4, 0.5), Vector3(0.15, 0.6, 1.0), _mat_meuble)
	_wall(root, "CorrLintel3", Vector3(5.275, 2.4, 2.5), Vector3(0.15, 0.6, 1.0), _mat_meuble)

	# Murs de jonction N/S
	_wall(root, "CorrWallN", Vector3(4.675, 1.35, -3.0), Vector3(1.2, 2.7, 0.15), _mat_meuble)
	_wall(root, "CorrWallS", Vector3(4.675, 1.35, 3.0), Vector3(1.2, 2.7, 0.15), _mat_meuble)

	# Sol
	_floor(root, "CorrFloor", Vector3(4.675, -0.05, 0), Vector3(1.2, 0.1, 6.0), _mat_bois)

	# Plafond
	_ceiling(root, "CorrCeiling", Vector3(4.675, 2.75, 0), Vector3(1.2, 0.1, 6.0), _mat_meuble)

	# Plinthes
	_plinthe(root, "CorrPlintheW", Vector3(4.08, 0.04, 0), Vector3(0.02, 0.08, 5.9))
	_plinthe(root, "CorrPlintheE", Vector3(5.27, 0.04, 0), Vector3(0.02, 0.08, 5.9))

	# Décor couloir
	_place_furniture(root, FURN + "coatRackStanding.glb", Vector3(4.3, 0, -2.5), 90.0)
	_place_furniture(root, FURN + "rugDoormat.glb", Vector3(4.675, 0, 0), 0.0)

	# Cadres photo
	_box(root, "CorrFrame1", Vector3(0.44, 0.56, 0.03), Vector3(4.15, 1.6, -1.0), _mat_cadre)
	_box(root, "CorrPhoto1", Vector3(0.36, 0.48, 0.035), Vector3(4.15, 1.6, -1.0), _new_mat(Color(0.3, 0.35, 0.42)))

	# Lumière couloir
	var clight := OmniLight3D.new()
	clight.name = "CorridorLight"
	clight.position = Vector3(4.675, 2.3, 0)
	clight.light_color = Color(0.95, 0.88, 0.75)
	clight.light_energy = 0.9
	clight.omni_range = 4.0
	clight.shadow_enabled = false
	root.add_child(clight)
	_reg_flicker(clight, 0.9)

	# Plafonnier
	_place_quaternius(root, "Light_Ceiling1.fbx", Vector3(4.675, 2.7, 0), 0.0)


# ---------------------------------------------------------------------------
# GARAGE (x = 5.275 → 9.275, z = -3 → +2, 4 × 5 m)
# ---------------------------------------------------------------------------
func _build_garage(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Garage"
	parent.add_child(root)

	# Murs garage
	_wall(root, "GarageWallN", Vector3(7.275, 1.35, -3.0), Vector3(4.0, 2.7, 0.15), _mat_mur_garage)
	_wall(root, "GarageWallE", Vector3(9.275, 1.35, -0.5), Vector3(0.15, 2.7, 5.0), _mat_mur_garage)
	_wall(root, "GarageWallS_W", Vector3(6.275, 1.35, 2.0), Vector3(2.0, 2.7, 0.15), _mat_mur_garage)
	_wall(root, "GarageWallS_E", Vector3(8.775, 1.35, 2.0), Vector3(1.0, 2.7, 0.15), _mat_mur_garage)
	# Mur Ouest = mur Est du couloir (déjà construit)

	# Sol béton
	_floor(root, "GarageFloor", Vector3(7.275, -0.05, -0.5), Vector3(4.0, 0.1, 5.0), _mat_beton)

	# Plafond
	_ceiling(root, "GarageCeiling", Vector3(7.275, 2.75, -0.5), Vector3(4.0, 0.1, 5.0), _mat_mur_garage)

	# Porte garage (grande ouverture côté Nord)
	# Montants + linteau
	_box(root, "GarageDoorFrameL", Vector3(0.1, 2.14, 0.1), Vector3(6.275, 1.07, -2.9), _mat_porte)
	_box(root, "GarageDoorFrameR", Vector3(0.1, 2.14, 0.1), Vector3(8.275, 1.07, -2.9), _mat_porte)
	_box(root, "GarageDoorLintel", Vector3(2.2, 0.1, 0.1), Vector3(7.275, 2.2, -2.9), _mat_porte)

	# Meubles garage
	_place_furniture(root, FURN + "tableCross.glb", Vector3(6.5, 0, -1.5), 0.0)
	_place_furniture(root, FURN + "washer.glb", Vector3(8.8, 0, -2.5), 180.0)
	_place_furniture(root, FURN + "bookcaseOpen.glb", Vector3(9.0, 0, -0.5), -90.0)

	# Cartons
	_place_furniture(root, FURN + "cardboardBoxClosed.glb", Vector3(5.8, 0, -2.5), 15.0)
	_place_furniture(root, FURN + "cardboardBoxClosed.glb", Vector3(6.2, 0, -2.2), -10.0)
	_place_furniture(root, FURN + "cardboardBoxOpen.glb", Vector3(5.9, 0, -1.8), 30.0)
	_place_furniture(root, FURN + "cardboardBoxClosed.glb", Vector3(8.5, 0, 1.5), 45.0)
	_place_furniture(root, FURN + "cardboardBoxOpen.glb", Vector3(8.0, 0, 1.3), -20.0)

	# Poubelle
	_place_furniture(root, FURN + "trashcan.glb", Vector3(9.0, 0, 1.5), 0.0)

	# Pneus (cylindres)
	_tire(root, "Tire1", Vector3(5.8, 0.15, 0.5))
	_tire(root, "Tire2", Vector3(5.8, 0.15, 0.9))
	_tire(root, "Tire3", Vector3(5.8, 0.45, 0.7))

	# Lumière garage
	var glight := OmniLight3D.new()
	glight.name = "GarageLight"
	glight.position = Vector3(7.275, 2.3, -0.5)
	glight.light_color = Color(0.85, 0.82, 0.78)
	glight.light_energy = 0.8
	glight.omni_range = 5.0
	glight.shadow_enabled = false
	root.add_child(glight)
	_reg_flicker(glight, 0.8)

	# Conteneur : tiroir de l'établi (FORCEABLE)
	_make_container(root, "GarageDrawer",
		InteractiveContainer.Mode.SLIDE,
		Vector3(6.5, 0.36, -1.35), Vector3.BACK, 0.42, 115.0,
		InteractiveContainer.LockType.FORCEABLE,
		Vector3(0.45, 0.16, 0.03), _mat_metal)


# ---------------------------------------------------------------------------
# CHAMBRE (x = 5.275 → 8.275, z = +2 → +6, 3 × 4 m)
# ---------------------------------------------------------------------------
func _build_chambre(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Chambre"
	parent.add_child(root)

	# Murs chambre
	_wall(root, "ChambreWallS", Vector3(6.775, 1.35, 6.0), Vector3(3.0, 2.7, 0.15), _mat_meuble)
	_wall(root, "ChambreWallE", Vector3(8.275, 1.35, 4.0), Vector3(0.15, 2.7, 4.0), _mat_meuble)
	_wall(root, "ChambreWallN_W", Vector3(5.775, 1.35, 2.0), Vector3(1.0, 2.7, 0.15), _mat_meuble)
	_wall(root, "ChambreWallN_E", Vector3(7.775, 1.35, 2.0), Vector3(1.0, 2.7, 0.15), _mat_meuble)
	# Mur Ouest = mur Est du couloir (déjà construit)

	# Sol moquette
	_floor(root, "ChambreFloor", Vector3(6.775, -0.05, 4.0), Vector3(3.0, 0.1, 4.0), _mat_moquette)

	# Plafond
	_ceiling(root, "ChambreCeiling", Vector3(6.775, 2.75, 4.0), Vector3(3.0, 0.1, 4.0), _mat_meuble)

	# Meubles chambre
	_place_furniture(root, FURN + "bedDouble.glb", Vector3(7.5, 0, 5.0), 180.0)
	_place_furniture(root, FURN + "cabinetBedDrawerTable.glb", Vector3(5.7, 0, 5.5), 90.0)
	_place_furniture(root, FURN + "bookcaseClosed.glb", Vector3(5.8, 0, 3.0), 90.0)
	_place_furniture(root, FURN + "desk.glb", Vector3(7.5, 0, 2.8), 0.0)
	_place_furniture(root, FURN + "chairDesk.glb", Vector3(7.5, 0, 3.3), 180.0)

	# Déco
	_place_furniture(root, FURN + "lampRoundTable.glb", Vector3(5.7, 0.55, 5.5), 0.0)
	_place_furniture(root, FURN + "rugRectangle.glb", Vector3(6.775, 0, 4.5), 0.0)
	_place_furniture(root, FURN + "pottedPlant.glb", Vector3(8.0, 0, 2.5), 0.0)
	_place_furniture(root, FURN + "pillow.glb", Vector3(7.3, 0.6, 5.0), 0.0)

	# Cadre photo
	_box(root, "ChambreFrame", Vector3(0.44, 0.56, 0.03), Vector3(6.5, 1.6, 5.92), _mat_cadre)

	# Lumière chambre
	var chlight := OmniLight3D.new()
	chlight.name = "ChambreLight"
	chlight.position = Vector3(6.775, 2.3, 4.0)
	chlight.light_color = Color(1.0, 0.88, 0.72)
	chlight.light_energy = 0.9
	chlight.omni_range = 4.5
	chlight.shadow_enabled = false
	root.add_child(chlight)
	_reg_flicker(chlight, 0.9)

	# Conteneur : tiroir table de nuit (KEY)
	_make_container(root, "NightstandDrawer",
		InteractiveContainer.Mode.SLIDE,
		Vector3(5.7, 0.36, 5.4), Vector3.BACK, 0.35, 115.0,
		InteractiveContainer.LockType.KEY,
		Vector3(0.4, 0.14, 0.03), _mat_bois)

	# Conteneur : placard bibliothèque (NONE)
	_make_container(root, "BookcaseDoor",
		InteractiveContainer.Mode.ROTATE,
		Vector3(5.55, 0.9, 3.0), Vector3.ZERO, 0.0, 110.0,
		InteractiveContainer.LockType.NONE,
		Vector3(0.6, 1.2, 0.03), _mat_meuble)


# ---------------------------------------------------------------------------
# SALLE DE BAIN (x = 5.275 → 7.775, z = +2 → +5, 2.5 × 3 m)
# ---------------------------------------------------------------------------
func _build_sdb(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "SDB"
	parent.add_child(root)

	# Murs SDB
	_wall(root, "SDBWallS", Vector3(6.525, 1.35, 5.0), Vector3(2.5, 2.7, 0.15), _mat_mur_sdb)
	_wall(root, "SDBWallE", Vector3(7.775, 1.35, 3.5), Vector3(0.15, 2.7, 3.0), _mat_mur_sdb)
	_wall(root, "SDBWallN", Vector3(6.525, 1.35, 2.0), Vector3(2.5, 2.7, 0.15), _mat_mur_sdb)
	# Mur Ouest = mur Est du couloir (déjà construit)

	# Sol carrelage
	_floor(root, "SDBFloor", Vector3(6.525, -0.05, 3.5), Vector3(2.5, 0.1, 3.0), _mat_carrelage_blanc)

	# Plafond
	_ceiling(root, "SDBCeiling", Vector3(6.525, 2.75, 3.5), Vector3(2.5, 0.1, 3.0), _mat_mur_sdb)

	# Sanitaires
	_place_furniture(root, FURN + "toilet.glb", Vector3(7.3, 0, 4.5), 180.0)
	_place_furniture(root, FURN + "bathroomSinkSquare.glb", Vector3(5.8, 0, 4.5), 90.0)
	_place_furniture(root, FURN + "bathroomCabinet.glb", Vector3(5.8, 0, 3.5), 90.0)
	_place_furniture(root, FURN + "bathroomMirror.glb", Vector3(5.55, 1.2, 4.5), 90.0)
	_place_furniture(root, FURN + "shower.glb", Vector3(7.0, 0, 2.5), 0.0)
	_place_furniture(root, FURN + "bathroomCabinetDrawer.glb", Vector3(7.5, 0, 3.0), -90.0)

	# Tapis de bain
	_place_furniture(root, FURN + "rugRectangle.glb", Vector3(6.5, 0, 3.5), 0.0)

	# Serviettes (boîtes colorées)
	_box(root, "Towel1", Vector3(0.4, 0.6, 0.05), Vector3(5.55, 1.2, 3.0), _new_mat(Color(0.6, 0.75, 0.8)))
	_box(root, "Towel2", Vector3(0.4, 0.5, 0.05), Vector3(5.55, 1.1, 3.5), _new_mat(Color(0.8, 0.6, 0.6)))

	# Lumière SDB
	var slight := OmniLight3D.new()
	slight.name = "SDBLight"
	slight.position = Vector3(6.525, 2.3, 3.5)
	slight.light_color = Color(0.95, 0.95, 1.0)
	slight.light_energy = 0.8
	slight.omni_range = 3.5
	slight.shadow_enabled = false
	root.add_child(slight)
	_reg_flicker(slight, 0.8)

	# Conteneur : armoire de toilette (KEY)
	_make_container(root, "SDBCabinet",
		InteractiveContainer.Mode.ROTATE,
		Vector3(5.55, 1.2, 3.0), Vector3.ZERO, 0.0, 110.0,
		InteractiveContainer.LockType.KEY,
		Vector3(0.5, 0.7, 0.03), _mat_meuble)


# ---------------------------------------------------------------------------
# DRESSING (x = 8.275 → 10.275, z = +2 → +5, 2 × 3 m)
# ---------------------------------------------------------------------------
func _build_dressing(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Dressing"
	parent.add_child(root)

	# Murs dressing
	_wall(root, "DressWallS", Vector3(9.275, 1.35, 5.0), Vector3(2.0, 2.7, 0.15), _mat_meuble)
	_wall(root, "DressWallE", Vector3(10.275, 1.35, 3.5), Vector3(0.15, 2.7, 3.0), _mat_meuble)
	_wall(root, "DressWallN", Vector3(9.275, 1.35, 2.0), Vector3(2.0, 2.7, 0.15), _mat_meuble)
	# Mur Ouest = mur Est de la chambre (déjà construit)

	# Sol moquette
	_floor(root, "DressFloor", Vector3(9.275, -0.05, 3.5), Vector3(2.0, 0.1, 3.0), _mat_moquette)

	# Plafond
	_ceiling(root, "DressCeiling", Vector3(9.275, 2.75, 3.5), Vector3(2.0, 0.1, 3.0), _mat_meuble)

	# Meubles dressing
	_place_furniture(root, FURN + "bookcaseOpen.glb", Vector3(9.8, 0, 2.5), 180.0)
	_place_furniture(root, FURN + "bookcaseOpen.glb", Vector3(9.8, 0, 3.5), 180.0)
	_place_furniture(root, FURN + "cabinetBedDrawer.glb", Vector3(8.6, 0, 4.5), 90.0)
	_place_furniture(root, FURN + "coatRack.glb", Vector3(9.9, 0, 4.5), -90.0)
	_place_furniture(root, FURN + "bathroomMirror.glb", Vector3(9.275, 1.5, 4.9), 180.0)
	_place_furniture(root, FURN + "pillowLong.glb", Vector3(9.8, 1.0, 3.0), 0.0)
	_place_furniture(root, FURN + "cardboardBoxClosed.glb", Vector3(8.6, 0, 2.5), 20.0)

	# Lumière dressing
	var dlight := OmniLight3D.new()
	dlight.name = "DressingLight"
	dlight.position = Vector3(9.275, 2.3, 3.5)
	dlight.light_color = Color(1.0, 0.9, 0.8)
	dlight.light_energy = 0.7
	dlight.omni_range = 3.0
	dlight.shadow_enabled = false
	root.add_child(dlight)
	_reg_flicker(dlight, 0.7)

	# Conteneur : tiroir commode (FORCEABLE)
	_make_container(root, "DresserDrawer",
		InteractiveContainer.Mode.SLIDE,
		Vector3(8.6, 0.36, 4.4), Vector3.BACK, 0.35, 115.0,
		InteractiveContainer.LockType.FORCEABLE,
		Vector3(0.4, 0.14, 0.03), _mat_bois)


# ---------------------------------------------------------------------------
# GAMEPLAY rétrofit (pièce existante)
# ---------------------------------------------------------------------------
func _build_existing_gameplay() -> void:
	# Les conteneurs existants de la map 2 sont dans map2_living.gd
	# On les recrée ici pour qu'ils soient dans le même arbre que la map étendue
	# Tiroir cuisine verrouillé par clé
	_make_container(self, "KitchenDrawerKey",
		InteractiveContainer.Mode.SLIDE,
		Vector3(-2.1, 0.36, -2.44), Vector3.BACK, 0.42, 115.0,
		InteractiveContainer.LockType.KEY,
		Vector3(0.45, 0.16, 0.03), _mat_bois)

	# Porte frigo verrouillée par clé
	var fridge := _make_container(self, "FridgeDoor",
		InteractiveContainer.Mode.ROTATE,
		Vector3(-3.70, 0.83, -1.70), Vector3.ZERO, 0.0, 115.0,
		InteractiveContainer.LockType.KEY,
		Vector3(0.55, 1.50, 0.04), _mat_metal)
	fridge.front_mesh.position = Vector3(0.28, 0.0, 0.02)

	# Placard verrouillé par force
	var closet := _make_container(self, "ClosetDoor",
		InteractiveContainer.Mode.ROTATE,
		Vector3(3.0, 0.52, -1.22), Vector3.ZERO, 0.0, 115.0,
		InteractiveContainer.LockType.FORCEABLE,
		Vector3(0.65, 0.95, 0.03), _mat_meuble)
	closet.front_mesh.position = Vector3(0.33, 0.0, 0.015)


# ---------------------------------------------------------------------------
# Mimics (GDD §5.3) — 2 mimics statiques.
# ---------------------------------------------------------------------------
func _place_mimics() -> void:
	# Mimic 1 : tasse sur la table basse (à côté d'une vraie tasse)
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

	# Mimic 2 : tasse sur la table d'appoint du coin lecture
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
	# Conteneurs KEY de la pièce existante
	for c in containers:
		if c.name.begins_with("KitchenDrawer") and c.lock_type == InteractiveContainer.LockType.KEY:
			_spawn_spots.append({"pos": Vector3.ZERO, "container": c})
	for c in containers:
		if c.name.begins_with("FridgeDoor"):
			_spawn_spots.append({"pos": Vector3(-3.44, 0.83, -1.65), "container": c})

	# Surfaces ouvertes pièce existante
	_spawn_spots.append({"pos": Vector3(-0.55, 0.61, -2.70), "container": null}) # toaster
	_spawn_spots.append({"pos": Vector3(0.60, 0.57, 1.20), "container": null}) # table basse
	_spawn_spots.append({"pos": Vector3(0.60, 0.96, 1.90), "container": null}) # canapé
	_spawn_spots.append({"pos": Vector3(-3.55, 0.41, -0.20), "container": null}) # table d'appoint
	_spawn_spots.append({"pos": Vector3(3.62, 2.22, 0.00), "container": null}) # bibliothèque
	_spawn_spots.append({"pos": Vector3.ZERO, "container": null, "floor": true}) # sol map 2

	# --- Nouvelles pièces ---
	# Garage : tiroir établi (FORCEABLE)
	for c in containers:
		if c.name.begins_with("GarageDrawer"):
			_spawn_spots.append({"pos": Vector3(6.5, 0.55, -1.5), "container": c})
	# Chambre : tiroir table nuit (KEY)
	for c in containers:
		if c.name.begins_with("NightstandDrawer"):
			_spawn_spots.append({"pos": Vector3(5.7, 0.5, 5.4), "container": c})
	# Chambre : placard bibliothèque (NONE)
	for c in containers:
		if c.name.begins_with("BookcaseDoor"):
			_spawn_spots.append({"pos": Vector3(5.55, 0.6, 3.0), "container": c})
	# SDB : armoire toilette (KEY)
	for c in containers:
		if c.name.begins_with("SDBCabinet"):
			_spawn_spots.append({"pos": Vector3(5.55, 1.0, 3.0), "container": c})
	# Dressing : tiroir commode (FORCEABLE)
	for c in containers:
		if c.name.begins_with("DresserDrawer"):
			_spawn_spots.append({"pos": Vector3(8.6, 0.5, 4.4), "container": c})

	# Surfaces ouvertes nouvelles pièces
	_spawn_spots.append({"pos": Vector3(6.5, 0.82, -1.5), "container": null}) # établi garage
	_spawn_spots.append({"pos": Vector3(7.5, 0.6, 5.0), "container": null}) # lit chambre
	_spawn_spots.append({"pos": Vector3(7.5, 0.78, 2.8), "container": null}) # bureau chambre
	_spawn_spots.append({"pos": Vector3(5.8, 0.82, 4.5), "container": null}) # lavabo SDB
	_spawn_spots.append({"pos": Vector3(9.8, 1.0, 3.0), "container": null}) # étagère dressing
	_spawn_spots.append({"pos": Vector3(4.675, 0.0, 0.0), "container": null, "floor": true}) # sol couloir
	_spawn_spots.append({"pos": Vector3(7.275, 0.0, -0.5), "container": null, "floor": true}) # sol garage
	_spawn_spots.append({"pos": Vector3(6.775, 0.0, 4.0), "container": null, "floor": true}) # sol chambre


func _key_spots() -> Array[Vector3]:
	return [
		Vector3(0.60, 0.57, 1.20),   # table basse
		Vector3(-0.55, 0.61, -2.70), # plan de travail
		Vector3(3.62, 2.22, 0.00),   # bibliothèque
		Vector3(-3.55, 0.41, -0.20), # table d'appoint
		Vector3(0.60, 0.96, 1.90),   # canapé
		Vector3(6.5, 0.82, -1.5),    # établi garage
		Vector3(7.5, 0.78, 2.8),     # bureau chambre
		Vector3(5.8, 0.82, 4.5),     # lavabo SDB
		Vector3(9.8, 1.0, 3.0),      # étagère dressing
		Vector3(4.675, 0.0, 0.0),    # sol couloir
	]


# ---------------------------------------------------------------------------
# Helpers de construction (murs, sols, plafonds, plinthes, pneus)
# ---------------------------------------------------------------------------
func _wall(parent: Node, name: String, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	parent.add_child(body)

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	return body


func _floor(parent: Node, name: String, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	return _wall(parent, name, pos, size, mat)


func _ceiling(parent: Node, name: String, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	return _wall(parent, name, pos, size, mat)


func _plinthe(parent: Node, name: String, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _new_mat(Color(0.24, 0.16, 0.11))
	mi.position = pos
	parent.add_child(mi)
	return mi


func _tire(parent: Node, name: String, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = 0.15
	mi.mesh = cyl
	mi.material_override = _new_mat(Color(0.08, 0.08, 0.08))
	mi.position = pos
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _place_food(parent: Node, glb_name: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	return _place_furniture(parent, FOOD + glb_name, pos, rot_y)
