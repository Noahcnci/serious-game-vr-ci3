class_name InteractiveContainer
extends Node3D
## Conteneur interactif (GDD §5.1/§5.6) : tiroir qui glisse ou porte de placard
## qui pivote sur charnière. Aucun verrou pour l'instant (round 1 : pilules
## faciles — les verrous arrivent au round 2).

enum Mode { SLIDE, ROTATE }

const OPEN_TIME := 0.35

var mode: Mode = Mode.SLIDE
var slide_axis := Vector3.BACK ## Direction locale d'ouverture (tiroir, vers +Z)
var open_distance := 0.45
var rotate_angle := 115.0 ## Degrés (porte de placard)

var is_open := false
var _tween: Tween
var _closed_pos: Vector3
var _closed_rot_y: float
var area: Area3D
var front_mesh: MeshInstance3D ## Surbrillance au pointage
var dose: Node3D = null ## Pilule cachée dedans (si spawn ici)

var _mat_normal: Material
var _mat_hover: Material


func _init(p_mode: Mode, p_axis: Vector3 = Vector3.BACK, p_dist: float = 0.45, p_angle: float = 115.0) -> void:
	mode = p_mode
	slide_axis = p_axis
	open_distance = p_dist
	rotate_angle = p_angle


func _ready() -> void:
	_closed_pos = position
	_closed_rot_y = rotation.y


## Raycast (main.gd) : la zone d'interaction est l'Area3D enfant.
func on_pointed() -> void:
	if front_mesh and _mat_hover:
		front_mesh.material_override = _mat_hover


func on_unpointed() -> void:
	if front_mesh and _mat_normal:
		front_mesh.material_override = _mat_normal


func interact() -> void:
	if _tween and _tween.is_valid():
		return # ouverture en cours
	is_open = not is_open
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if mode == Mode.SLIDE:
		var target := _closed_pos + slide_axis * (open_distance if is_open else 0.0)
		_tween.tween_property(self, "position", target, OPEN_TIME)
	else:
		var target_y := _closed_rot_y + deg_to_rad(rotate_angle if is_open else 0.0)
		_tween.tween_property(self, "rotation:y", target_y, OPEN_TIME)
	if is_open and dose:
		_reveal_dose()


func _reveal_dose() -> void:
	if not dose:
		return
	dose.visible = true
	if dose is Area3D:
		dose.set_deferred("monitoring", true)
		dose.set_deferred("monitorable", true)
