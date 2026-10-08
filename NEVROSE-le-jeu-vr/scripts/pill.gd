class_name Dose
extends Area3D
## La pilule (cœur du jeu — GDD §5.1). Spawne dans un conteneur aléatoire.
## Capsule émissive cyan : visible de loin, coût graphique nul.
##
## Mécanique (2026-10) : GRAB à la main → PORTER À LA BOUCHE → MANGER.
## La pilule suit la main droite une fois saisie. Quand la main entre dans
## la zone "bouche" (rayon 0.25 m du point bas de la caméra), un indicateur
## s'allume et la gâchette = avaler.

const PILL_COLOR := Color(0.35, 1.0, 0.85)

var _spin := true
var is_held := false
var _eat_zone_radius := 0.28 ## m — rayon autour de la "bouche"
var camera: Node3D = null ## XRCamera3D (résolu par main.gd)

## Point de la bouche : légèrement en dessous et devant le centre de la caméra.
func _get_mouth_position() -> Vector3:
	if camera == null or not is_instance_valid(camera):
		return global_transform.origin
	var cam_origin: Vector3 = camera.global_transform.origin
	var cam_down: Vector3 = camera.global_transform.basis.y
	var cam_forward: Vector3 = camera.global_transform.basis.z
	# Bouche = ~15 cm en dessous du centre de la caméra + 5 cm vers l'avant
	return cam_origin - cam_down * 0.15 + cam_forward * 0.05


## Vrai si la pilule (tenue dans la main) est dans la zone de la bouche.
func can_eat() -> bool:
	if not is_held or camera == null:
		return false
	var mouth := _get_mouth_position()
	return global_transform.origin.distance_to(mouth) < _eat_zone_radius


func _ready() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.028
	capsule.height = 0.08
	body.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PILL_COLOR
	mat.emission_enabled = true
	mat.emission = PILL_COLOR
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.35
	body.material_override = mat
	add_child(body)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.09
	shape.shape = sphere
	add_child(shape)

	body_offset_y = 0.05


var body_offset_y := 0.0:
	set(v):
		body_offset_y = v
		for c in get_children():
			if c is MeshInstance3D:
				c.position.y = v


func _process(delta: float) -> void:
	if is_held:
		# Suivre la main — position offset fix par main.gd
		return
	if not _spin or not visible:
		return
	rotate_y(delta * 1.6)
	for c in get_children():
		if c is MeshInstance3D:
			c.position.y = body_offset_y + sin(Time.get_ticks_msec() / 1000.0 * 2.4) * 0.012


func on_pointed() -> void:
	pass


func on_unpointed() -> void:
	pass


## Gâchette quand la pilule est dans la main :
# - Si pas encore dans la bouche → rien (le joueur doit la rapprocher).
# - Si dans la bouche → avaler.
func interact() -> void:
	if not visible:
		return
	if is_held:
		if can_eat():
			_consume()
		return
	# Pas encore tenue : on la ramasse (main.gd gère le reparent)
	_spin = false
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method(&"pickup_pill"):
		main.pickup_pill(self)


## Appelé quand la pilule est avalée.
func _consume() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method(&"on_dose_taken"):
		main.on_dose_taken()
	queue_free()
