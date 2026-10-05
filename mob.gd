extends CharacterBody3D

# Minimum speed of the mob in meters per second.
@export var min_speed = 10.0
# Maximum speed of the mob in meters per second.
@export var max_speed = 18.0
# Number of stomps to kill this mob (bosses > 1).
@export var hp := 1
# Bosses are bigger, tankier and worth more points.
var is_boss := false

# Emitted when the player jumped on the mob.
signal squashed

# Limites de l'arene (le centre du mob y reste confine).
const ARENA_X := 12.0
const ARENA_Z := 13.0

var _squashed := false
var _invulnerable := false


func _physics_process(_delta):
	move_and_slide()
	_clamp_to_arena()


func _clamp_to_arena() -> void:
	# Les mobs rebondissent sur les murs de l'arene au lieu de sortir.
	var hx := 0.68 * scale.x
	var hz := 1.1 * scale.z
	var bounced := false
	if position.x > ARENA_X - hx:
		position.x = ARENA_X - hx
		velocity.x = -absf(velocity.x)
		bounced = true
	elif position.x < -ARENA_X + hx:
		position.x = -ARENA_X + hx
		velocity.x = absf(velocity.x)
		bounced = true
	if position.z > ARENA_Z - hz:
		position.z = ARENA_Z - hz
		velocity.z = -absf(velocity.z)
		bounced = true
	elif position.z < -ARENA_Z + hz:
		position.z = -ARENA_Z + hz
		velocity.z = absf(velocity.z)
		bounced = true
	if bounced:
		# Se recaler dans la direction du mouvement (fin du moonwalk).
		rotation.y = atan2(-velocity.x, -velocity.z)


# This function will be called from the Main scene.
func initialize(start_position, player_position):
	# We position the mob by placing it at start_position and rotate it towards
	# player_position, so it looks at the player.
	look_at_from_position(start_position, player_position, Vector3.UP)
	# Rotate this mob randomly within range of -45 and +45 degrees, so that it
	# doesn't move directly towards the player.
	rotate_y(randf_range(-PI / 4, PI / 4))

	# We calculate a random speed (float).
	var random_speed = randf_range(min_speed, max_speed)
	# We calculate a forward velocity that represents the speed.
	velocity = Vector3.FORWARD * random_speed
	# We then rotate the velocity vector based on the mob's Y rotation in order
	# to move in the direction the mob is looking.
	velocity = velocity.rotated(Vector3.UP, rotation.y)

	$AnimationPlayer.speed_scale = random_speed / min_speed


func squash():
	# Garde anti double appel sur un meme stomp (score/signal en double).
	if _invulnerable or _squashed:
		return
	if hp <= 1:
		_squashed = true
		squashed.emit()
		queue_free() # Destroy this node.
		return

	# Boss : encaisse le coup mais survit, bref moment d'invulnerabilite.
	hp -= 1
	_invulnerable = true
	var pivot: Node3D = $Pivot
	var tween := create_tween()
	tween.tween_property(pivot, "scale", Vector3(1.35, 0.65, 1.35), 0.08)
	tween.tween_property(pivot, "scale", Vector3.ONE, 0.18)
	get_tree().create_timer(0.6, true, false, true).timeout.connect(_end_invulnerability)


func _end_invulnerability() -> void:
	_invulnerable = false


func _on_visible_on_screen_notifier_3d_screen_exited():
	queue_free()
