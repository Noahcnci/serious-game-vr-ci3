class_name Mimic
extends Area3D
## Premier mimic statique (round 1 — GDD §6) : un objet du quotidien qui
## tremble légèrement. Le pointe-t-on ? Il se dissout et la schizo monte un
## peu : le doute coûte cher. Zéro animation coûteuse : tremblement sinus +
## tween d'échelle.

@export var tremble_strength := 0.012

var _base_rot := Vector3.ZERO
var _dissolving := false


func _ready() -> void:
	_base_rot = rotation


func _process(_delta: float) -> void:
	if _dissolving:
		return
	# Tremblement quasi imperceptible — c'est LE signal (GDD §5.3).
	rotation = _base_rot + Vector3(
		sin(Time.get_ticks_msec() / 61.0) * tremble_strength,
		0.0,
		cos(Time.get_ticks_msec() / 47.0) * tremble_strength
	)


func on_pointed() -> void:
	pass


func on_unpointed() -> void:
	pass


func interact() -> void:
	if _dissolving:
		return
	_dissolving = true
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method(&"on_mimic_purged"):
		main.on_mimic_purged()
	var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.4)
	tw.tween_callback(queue_free)
