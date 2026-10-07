class_name Dose
extends Area3D
## La pilule (cœur du jeu — GDD §5.1). Spawne dans un conteneur aléatoire.
## Capsule émissive cyan : visible de loin, coût graphique nul (pas de lumière
## dynamique dédiée, on s'appuie sur le glow de l'Environment).

const PILL_COLOR := Color(0.35, 1.0, 0.85)

var _spin := true


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


func interact() -> void:
	if not visible:
		return
	_spin = false
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method(&"on_dose_taken"):
		main.on_dose_taken()
	queue_free()
