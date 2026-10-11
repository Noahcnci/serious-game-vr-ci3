class_name Map2Living
extends MapBase
## Map 2 (fragment 2) : salon + cuisine, 8 x 6 m (GDD §7).
##
## Design 3D professionnel appliqué :
##   - Chaque meuble est ANCRE contre un mur ou un autre meuble, jamais
##     "à peu près" — on calcule la position depuis l'AABB réelle du GLB.
##   - La circulation centrale reste LIBRE sur un axe nord-sud (x ≈ 0) et
##     est-ouest (z ≈ 0) — le joueur VR peut se déplacer sans collision.
##   - La cuisine occupe le tiers nord (z < -1), le salon les deux tiers sud.
##   - La fenêtre (ouest) et la porte (est) sont des points de fuite qui
##     cadrent la composition.
##
## La coquille (sol/murs/plafond/fenêtre/porte/couloir) vient de
## scenes/map2_living.tscn — instanciée ici enfant de cette racine.
## Cette classe ajoute les meubles Kenney (GLB), les conteneurs interactifs,
## les mimics, les spots de dose et les clés.

const SCENE_SHELL := "res://scenes/map2_living.tscn"
const FURN := "res://assets/kenney/furniture/"
const FOOD := "res://assets/kenney/food/"

# Matériaux propres à la map (teinte calm, dérive sick gérée par MapBase).
var _mat_bois: StandardMaterial3D      # structure bois foncé (tiroirs, table)
var _mat_meuble: StandardMaterial3D    # meubles peints (cuisine, placard)
var _mat_metal: StandardMaterial3D     # frigo, poignées, hotte
var _mat_tissu: StandardMaterial3D     # canapé, coussins
var _mat_tissu_bleu: StandardMaterial3D
var _mat_cadre: StandardMaterial3D     # cadres, plinthes, moulures
var _mat_nourriture: StandardMaterial3D

# Hauteur du plan de travail bas (caisson 0.45 + plan 0.03).
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
	_mat_tissu_bleu = _new_mat(Color(0.24, 0.32, 0.42))
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
# CUISINE (mur nord, z = -3).
# Composé : frigo | évier | tiroir | plaques | tiroir | tiroir | four ? Non :
#           frigo | évier | caisson | plaques | caisson | caisson
# Le plan de travail court de x = -2.6 à x = +0.55 en continu.
# ---------------------------------------------------------------------------
func _build_kitchen() -> void:
	var root := Node3D.new()
	root.name = "Kitchen"
	add_child(root)

	# --- Frigo (à gauche, ancré au mur nord) ---
	# AABB kitchenFridgeLarge : 0.52 x 0.92 x 0.406, origine au coin arrière-gauche.
	# Pour que le DOS touche le mur (z=-3) : pos_z = -3 + 0.406 = -2.594.
	# Pour que le CÔTÉ gauche soit à x = -3.7 : pos_x = -3.7.
	_place_furniture(root, FURN + "kitchenFridgeLarge.glb", Vector3(-3.7, 0.0, -2.594), 0.0)

	# Porte du frigo = conteneur rotatif, verrouillée par clé.
	# La face avant du frigo est à z = -2.594 + 0.406 = -2.188.
	# Charnière sur le côté gauche de la porte (x = -3.66) ; le front
	# (0.44 de large) est décalé de +0.22 pour être centré sur la porte.
	var fridge := _make_container(root, "FridgeDoor",
		InteractiveContainer.Mode.ROTATE,
		Vector3(-3.66, 0.5, -2.19), Vector3.ZERO, 0.0, 115.0,
		InteractiveContainer.LockType.KEY,
		Vector3(0.44, 0.9, 0.04), _mat_metal)
	fridge.front_mesh.position = Vector3(0.22, 0.0, 0.02)

	# --- Bas de cuisine : 6 caissons de 0.43 m de large ---
	# Du frigo (x=-3.18) au mur est de la cuisine (x=+0.55) :
	#   caisson 0 : x = -2.6  (évier)
	#   caisson 1 : x = -2.17 (tiroir — VERROUILLÉ par clé)
	#   caisson 2 : x = -1.74 (plaques)
	#   caisson 3 : x = -1.31 (tiroir — FORCEABLE)
	#   caisson 4 : x = -0.88 (tiroir)
	#   caisson 5 : x = -0.45 (tiroir)
	# Tous dos au mur (z = -3 + 0.45 = -2.55 pour les caissons profonds,
	#                    z = -3 + 0.45 = -2.55 aussi pour l'évier).
	var base_x := [-2.6, -2.17, -1.74, -1.31, -0.88, -0.45]
	var base_glb := [
		FURN + "kitchenSink.glb",          # 0 : évier
		FURN + "kitchenCabinetDrawer.glb", # 1 : tiroir (clé)
		FURN + "kitchenStove.glb",         # 2 : plaques
		FURN + "kitchenCabinetDrawer.glb", # 3 : tiroir (forceable)
		FURN + "kitchenCabinetDrawer.glb", # 4 : tiroir
		FURN + "kitchenCabinetDrawer.glb", # 5 : tiroir
	]
	var base_lock := [
		InteractiveContainer.LockType.NONE,
		InteractiveContainer.LockType.KEY,
		InteractiveContainer.LockType.NONE,
		InteractiveContainer.LockType.FORCEABLE,
		InteractiveContainer.LockType.NONE,
		InteractiveContainer.LockType.NONE,
	]
	for i in base_x.size():
		_place_furniture(root, base_glb[i], Vector3(base_x[i], 0.0, -2.55), 0.0)

	# Tiroirs interactifs — un par caisson (sauf l'évier et les plaques).
	# Le tiroir glisse vers +z (vers le joueur).
	# slot_pos = origine du tiroir = son point de fermeture.
	# La cavité du tiroir est à z ∈ [-2.77, -2.46], donc z = -2.46 pour le
	# front fermé. On y ajoute une cavité sombre (fond du tiroir) pour
	# matérialiser l'intérieur et donner un fond à la pilule posée dedans.
	var drawer_x := [-2.17, -1.31, -0.88, -0.45]
	var drawer_lock := [
		InteractiveContainer.LockType.KEY,
		InteractiveContainer.LockType.FORCEABLE,
		InteractiveContainer.LockType.NONE,
		InteractiveContainer.LockType.NONE,
	]
	for i in drawer_x.size():
		# Cavité sombre : le fond du tiroir (visible quand il est ouvert).
		var cavity := _box(root, "DrawerCavity%d" % i, Vector3(0.38, 0.14, 0.30),
			Vector3(drawer_x[i], 0.36, -2.62), _new_mat(Color(0.10, 0.09, 0.08)))
		_make_container(root, "KitchenDrawer%d" % i,
			InteractiveContainer.Mode.SLIDE,
			Vector3(drawer_x[i], 0.36, -2.46), Vector3.BACK, 0.42, 115.0,
			drawer_lock[i],
			Vector3(0.40, 0.16, 0.03), _mat_bois)

	# --- Plan de travail continu (de x = -2.83 à x = -0.23, donc 2.60 m) ---
	# Épaisseur 0.03, profondeur 0.50, hauteur 0.45 + 0.03 = 0.48.
	# On le fait en un seul mesh pour la propreté visuelle.
	var counter := _box(root, "CounterTop", Vector3(2.60, 0.03, 0.50),
		Vector3(-1.53, COUNTER_Y - 0.015, -2.77), _mat_meuble)

	# --- Hauts de cuisine (4 caissons, y = 1.32 pour le bas) ---
	# AABB kitchenCabinetUpper : 0.43 x 0.39 x 0.22, dos au mur.
	# pos_z = -3 + 0.22 = -2.78.
	var upper_x := [-2.6, -2.17, -1.31, -0.88]
	for i in upper_x.size():
		_place_furniture(root, FURN + "kitchenCabinetUpper.glb",
			Vector3(upper_x[i], 1.32, -2.78), 0.0)

	# Hotte au-dessus des plaques (x = -1.74).
	# AABB hoodModern : 0.43 x 0.40 x 0.285.
	# pos_z = -3 + 0.285 = -2.715, pos_y = 1.32 + 0.39 = 1.71.
	_place_furniture(root, FURN + "hoodModern.glb", Vector3(-1.74, 1.71, -2.715), 0.0)

	# --- Petit électroménager sur le plan de travail ---
	# (pos_y = COUNTER_Y = 0.48)
	# Toaster à droite.
	_place_furniture(root, FURN + "toaster.glb", Vector3(-0.55, COUNTER_Y, -2.70), -10.0)
	# Machine à café à gauche.
	_place_furniture(root, FURN + "kitchenCoffeeMachine.glb", Vector3(-2.40, COUNTER_Y, -2.70), 0.0)
	# Micro-ondes entre les deux.
	_place_furniture(root, FURN + "kitchenMicrowave.glb", Vector3(-1.90, COUNTER_Y, -2.72), 0.0)
	# Blender.
	_place_furniture(root, FURN + "kitchenBlender.glb", Vector3(-1.10, COUNTER_Y, -2.72), 15.0)

	# --- Nourriture et déco sur le plan de travail ---
	# (donne du réalisme au set dressing)
	_place_food(root, "loaf.glb",        Vector3(-2.55, COUNTER_Y, -2.75), 0.0)
	_place_food(root, "cutting-board.glb", Vector3(-2.30, COUNTER_Y, -2.68), 30.0)
	_place_food(root, "apple.glb",       Vector3(-2.32, COUNTER_Y + 0.02, -2.68), 0.0)
	_place_food(root, "shaker-salt.glb", Vector3(-1.55, COUNTER_Y, -2.70), 0.0)
	_place_food(root, "shaker-pepper.glb", Vector3(-1.48, COUNTER_Y, -2.70), 0.0)
	_place_food(root, "bottle-oil.glb",  Vector3(-1.35, COUNTER_Y, -2.72), 0.0)
	_place_food(root, "tomato.glb",      Vector3(-0.80, COUNTER_Y, -2.72), 20.0)

	# --- Bar de cuisine (séparation cuisine/salon, x = +1.0) ---
	# AABB kitchenBar : 0.43 x 0.42 x 0.21. Orienté face à -x (rot_y = 90°).
	# On en met 2 côte à côte pour faire un bar de 0.86 m.
	# Le bar est à z = -2.0 (entrée de la cuisine), laissant un passage
	# libre au sud (le dernier cm du bar est à z = -1.57, donc z > -1.4
	# reste dégagé pour la circulation).
	_place_furniture(root, FURN + "kitchenBar.glb",  Vector3(0.95, 0.0, -2.0), 90.0)
	_place_furniture(root, FURN + "kitchenBarEnd.glb", Vector3(0.95, 0.0, -1.58), 90.0)

	# Tabourets de bar (2).
	# AABB stoolBar : 0.265 x 0.435 x 0.23.
	_place_furniture(root, FURN + "stoolBar.glb", Vector3(1.45, 0.0, -2.0), -90.0)
	_place_furniture(root, FURN + "stoolBar.glb", Vector3(1.45, 0.0, -1.55), -90.0)

	# --- Lumière de la cuisine (grésille en folie) ---
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
# SALON (moitié sud, z > 0).
# Composé : canapé en L (sud+est), table basse centrale, meuble TV (ouest),
# bibliothèque (est), coin lecture (nord-ouest).
# ---------------------------------------------------------------------------
func _build_living_room() -> void:
	var root := Node3D.new()
	root.name = "LivingRoom"
	add_child(root)

	# --- Canapé en L (mur sud + mur est) ---
	# loungeSofaLong : 0.98 x 0.46 x 0.82, rot 180° face au nord.
	# Pour que le dos touche le mur sud (z=+3) : pos_z = 3 - 0.82 = 2.18.
	# On met le long du mur sud, décalé vers l'est.
	_place_furniture(root, FURN + "loungeSofaLong.glb", Vector3(0.6, 0.0, 2.18), 180.0)

	# loungeSofaCorner : 0.98 x 0.46 x 0.98, rot 180° pour l'angle sud-est.
	# pos : x = 3 - 0.98 = 2.02, z = 3 - 0.98 = 2.02.
	_place_furniture(root, FURN + "loungeSofaCorner.glb", Vector3(2.02, 0.0, 2.02), 180.0)

	# Ottoman devant le canapé.
	# AABB loungeSofaOttoman : 0.44 x 0.23 x 0.45.
	_place_furniture(root, FURN + "loungeSofaOttoman.glb", Vector3(0.6, 0.0, 1.10), 0.0)

	# --- Tapis sous la table basse (ancrage au sol) ---
	# AABB rugRectangle : 1.57 x 0.01 x 0.92.
	# Centré sous la table basse.
	_place_furniture(root, FURN + "rugRectangle.glb", Vector3(0.6, 0.005, 1.20), 0.0)

	# --- Table basse ---
	# AABB tableCoffee : 0.661 x 0.230 x 0.400, origine au centre en X (min=-0.461).
	# pos_y = 0 (pieds au sol). pos centrée sur le tapis.
	var coffee_table := _place_furniture(root, FURN + "tableCoffee.glb",
		Vector3(0.6, 0.0, 1.20), 0.0)

	# Déco sur la table basse.
	# AABB books : 0.15 x 0.104 x 0.094.
	_place_furniture(root, FURN + "books.glb", Vector3(0.45, 0.23, 1.15), 20.0)
	# AABB mug : 0.344 x 0.273 x 0.285.
	_place_food(root, "mug.glb", Vector3(0.75, 0.23, 1.25), 0.0)

	# --- Meuble TV (mur ouest) ---
	# AABB cabinetTelevision : 0.80 x 0.31 x 0.25.
	# rot_y = 90° → la face (0.80 de large) regarde vers +x (est, vers le canapé).
	# pos_x = -4 + 0.25 = -3.75 (dos au mur ouest).
	# pos_z = 0.8 (centré face au canapé).
	_place_furniture(root, FURN + "cabinetTelevision.glb", Vector3(-3.75, 0.0, 0.8), 90.0)

	# TV posée sur le meuble.
	# AABB televisionModern : 0.685 x 0.455 x 0.128.
	# pos_y = 0.31 (hauteur du meuble).
	_place_furniture(root, FURN + "televisionModern.glb", Vector3(-3.62, 0.31, 0.8), 90.0)

	# Enceintes de part et d'autre de la TV (sur le meuble).
	# AABB speaker : 0.148 x 0.636 x 0.148. On les décolle légèrement du mur
	# (x = -3.60) pour qu'elles ne soient pas à moitié dedans.
	_place_furniture(root, FURN + "speaker.glb", Vector3(-3.60, 0.31, 0.2), 90.0)
	_place_furniture(root, FURN + "speaker.glb", Vector3(-3.60, 0.31, 1.4), 90.0)

	# --- Bibliothèque (mur est, nord du canapé) ---
	# AABB bookcaseClosedDoors : 0.40 x 0.85 x 0.25.
	# pos_x = 4 - 0.25 = 3.75, dos au mur est. rot 180° face à l'ouest.
	_place_furniture(root, FURN + "bookcaseClosedDoors.glb", Vector3(3.75, 0.0, 0.0), 180.0)

	# Placard de rangement (conteneur forceable) — même mur, au nord.
	# AABB bookcaseClosed : 0.40 x 0.85 x 0.25.
	_place_furniture(root, FURN + "bookcaseClosed.glb", Vector3(3.75, 0.0, -1.5), 180.0)

	# Porte du placard = conteneur rotatif, FORCEABLE.
	# La face avant du placard (dos au mur, rot 180°) est à z = -1.5 + 0.25 = -1.25.
	# Charnière sur le côté gauche de la porte (x = 3.55) ; le front est
	# décalé de +0.18 pour être centré sur la porte.
	var closet := _make_container(root, "ClosetDoor",
		InteractiveContainer.Mode.ROTATE,
		Vector3(3.55, 0.45, -1.25), Vector3.ZERO, 0.0, 115.0,
		InteractiveContainer.LockType.FORCEABLE,
		Vector3(0.36, 0.75, 0.03), _mat_meuble)
	closet.front_mesh.position = Vector3(0.18, 0.0, 0.015)

	# --- Coin lecture (nord-ouest du salon) ---
	# Fauteuil lounge (face au sud-est, vers le canapé).
	# AABB loungeChair : 0.49 x 0.46 x 0.41.
	# rot_y = -135° → regarde vers le sud-est.
	_place_furniture(root, FURN + "loungeChair.glb", Vector3(-3.0, 0.0, -0.8), -135.0)

	# Table d'appoint à côté du fauteuil.
	# AABB sideTable : 0.534 x 0.384 x 0.220.
	_place_furniture(root, FURN + "sideTable.glb", Vector3(-3.55, 0.0, -0.2), 0.0)

	# Lampe de table posée sur la table d'appoint.
	# AABB lampSquareTable : 0.12 x 0.29 x 0.12.
	_place_furniture(root, FURN + "lampSquareTable.glb", Vector3(-3.55, 0.38, -0.2), 0.0)

	# Lampe sur la table de chevet (à droite du canapé).
	# AABB lampSquareFloor : 0.12 x 0.86 x 0.12.
	_place_furniture(root, FURN + "lampSquareFloor.glb", Vector3(3.5, 0.0, 2.5), 0.0)

	# --- Plante et déco ---
	# AABB pottedPlant : 0.212 x 0.654 x 0.241.
	_place_furniture(root, FURN + "pottedPlant.glb", Vector3(-3.7, 0.0, -2.7), 0.0)
	# AABB plantSmall1 : 0.095 x 0.140 x 0.095.
	_place_furniture(root, FURN + "plantSmall1.glb", Vector3(3.7, 0.0, 2.7), 0.0)
	# AABB plantSmall2 : 0.095 x 0.140 x 0.095.
	_place_furniture(root, FURN + "plantSmall2.glb", Vector3(-3.7, 0.0, 2.7), 0.0)

	# Poubelle près du bar.
	# AABB trashcan : 0.208 x 0.428 x 0.234.
	_place_furniture(root, FURN + "trashcan.glb", Vector3(1.30, 0.0, -0.85), 0.0)

	# --- Lumières ---
	# Lumière principale du salon (chaude, grésille en folie).
	var llight := OmniLight3D.new()
	llight.name = "LivingLight"
	llight.position = Vector3(0.5, 2.3, 1.0)
	llight.light_color = Color(1.0, 0.82, 0.55)
	llight.light_energy = 1.3
	llight.omni_range = 5.5
	llight.shadow_enabled = false
	root.add_child(llight)
	_reg_flicker(llight, 1.3)

	# Lumière ambiante générale (plafonnier central).
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
# Mimics (GDD §5.3) — 2 mimics statiques dans la map.
# ---------------------------------------------------------------------------
func _place_mimics() -> void:
	# Mimic 1 : tasse sur la table basse (à côté d'une vraie tasse).
	# La vraie tasse est posée par _build_living_room.
	var fake1 := Mimic.new()
	fake1.name = "MugMimic"
	add_child(fake1)
	fake1.position = Vector3(0.30, 0.23, 1.05)
	var mug1 := _place_furniture(fake1, FOOD + "cup-tea.glb", Vector3.ZERO, 0.0)
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
	var mug2 := _place_furniture(fake2, FOOD + "cup-tea.glb", Vector3.ZERO, 30.0)
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(0.16, 0.16, 0.16)
	cs2.shape = bs2
	cs2.position = Vector3(0, 0.06, 0)
	fake2.add_child(cs2)
	mimics.append(fake2)


# ---------------------------------------------------------------------------
# Spawns de dose (GDD §5.1)
# 6 spots : 2 dans des conteneurs (tiroir cuisine, frigo), 4 en surface.
# ---------------------------------------------------------------------------
func _register_spawn_spots() -> void:
	# Tiroir de cuisine verrouillé par clé (révélé à l'ouverture).
	for c in containers:
		if c.name.begins_with("KitchenDrawer") and c.lock_type == InteractiveContainer.LockType.KEY:
			_spawn_spots.append({"pos": Vector3.ZERO, "container": c})
	# Porte du frigo (verrouillée par clé).
	for c in containers:
		if c.name.begins_with("FridgeDoor"):
			_spawn_spots.append({"pos": Vector3(-3.44, 0.5, -2.14), "container": c})
	# Surfaces ouvertes.
	_spawn_spots.append({"pos": Vector3(-0.55, 0.61, -2.70), "container": null}) # toaster (plan de travail)
	_spawn_spots.append({"pos": Vector3(0.60, 0.23, 1.20), "container": null}) # table basse
	_spawn_spots.append({"pos": Vector3(0.60, 0.47, 2.18), "container": null}) # canapé
	_spawn_spots.append({"pos": Vector3(-3.55, 0.38, -0.20), "container": null}) # table d'appoint lecture
	_spawn_spots.append({"pos": Vector3(3.75, 0.85, 0.00), "container": null}) # dessus bibliothèque
	_spawn_spots.append({"pos": Vector3.ZERO, "container": null, "floor": true}) # sol aléatoire


func _key_spots() -> Array[Vector3]:
	return [
		Vector3(0.60, 0.23, 1.20),  # table basse
		Vector3(-0.55, 0.61, -2.70), # plan de travail (près du toaster)
		Vector3(3.75, 0.85, 0.00), # dessus bibliothèque
		Vector3(-3.55, 0.38, -0.20), # table d'appoint lecture
		Vector3(0.60, 0.47, 2.18),  # canapé
	]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Pose un GLB de nourriture (même logique que _place_furniture mais dans
## le dossier food/).
func _place_food(parent: Node, glb_name: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	return _place_furniture(parent, FOOD + glb_name, pos, rot_y)
