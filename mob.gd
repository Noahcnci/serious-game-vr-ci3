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
# Emitted on every non-lethal stomp (bosses tanking a hit).
signal stomped

# Ability speciale : "normal", "tank", "dasher", "jumper", "ghost".
var ability := "normal"
# Cible du dasher (pose par Main apres le spawn).
var player: Node3D = null

var _dir := Vector3.ZERO # direction de deplacement de base
var _speed := 0.0 # vitesse de base (magnitude de velocity)

var _ability_clock := 0.0
var _dash_state := 0 # dasher : 0 repos, 1 telegraph, 2 dash
var _dash_dir := Vector3.ZERO
var _vy := 0.0 # vitesse verticale (jumper), integree a la main
var _ghost := false
var _ghost_blink := 0.0

# Impulse given back to the player when stomping this mob (bosses bounce higher).
var stomp_bounce := 14.0

# Limites de l'arene (le centre du mob y reste confine).
const ARENA_X := 12.0
const ARENA_Z := 13.0

var _squashed := false
var _invulnerable := false


func _physics_process(delta):
	_ability_clock += delta
	match ability:
		"dasher":
			_update_dasher()
		"jumper":
			_update_jumper()
		"ghost":
			_update_ghost(delta)
	# Integration verticale manuelle (jumper ; inerte pour les autres :
	# _vy reste 0 et y reste a 0).
	if _vy != 0.0 or position.y > 0.0:
		_vy -= 30.0 * delta
		position.y += _vy * delta
		if position.y <= 0.0:
			position.y = 0.0
			_vy = 0.0
	move_and_slide()
	_clamp_to_arena()


# Fonce sur le joueur par cycles : 2,2 s de marche, telegraph ralenti,
# puis 0,45 s de sprint x3,5 vers la position du joueur.
func _update_dasher() -> void:
	if player == null or _squashed:
		return
	if _dash_state == 0:
		velocity = _dir * _speed
		if _ability_clock >= 2.2:
			_ability_clock = 0.0
			_dash_state = 1
			velocity = _dir * _speed * 0.15 # telegraph : ralenti visible
	elif _dash_state == 1:
		if _ability_clock >= 0.35:
			_ability_clock = 0.0
			_dash_state = 2
			_dash_dir = player.global_position - global_position
			_dash_dir.y = 0.0
			_dash_dir = _dash_dir.normalized()
			velocity = _dash_dir * _speed * 3.5
			$AnimationPlayer.speed_scale *= 2.0
	elif _ability_clock >= 0.45:
		_ability_clock = 0.0
		_dash_state = 0
		$AnimationPlayer.speed_scale = maxf(1.0, $AnimationPlayer.speed_scale / 2.0)
		velocity = _dir * _speed


# Saute toutes les 2,2 s (integration verticale manuelle, voir plus haut).
func _update_jumper() -> void:
	if _ability_clock >= 2.2 and position.y <= 0.01:
		_ability_clock = 0.0
		_vy = 9.0


# Cycle 3 s : 1 s intangible (blink rapide), 2 s tangible.
# Layer 2 coupe = aucune interaction (ni blesser, ni etre ecrase).
func _update_ghost(delta: float) -> void:
	var want_ghost: bool = fmod(_ability_clock, 3.0) < 1.0
	if want_ghost != _ghost:
		_ghost = want_ghost
		set_collision_layer_value(2, not _ghost)
	if _ghost:
		_ghost_blink += delta
		$Pivot.visible = fmod(_ghost_blink, 0.12) < 0.06
	else:
		$Pivot.visible = true


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
	_dir = velocity.normalized()
	_speed = velocity.length()


# A appeler APRES initialize(). Aucun changement d'apparence (sauf tank) :
# le dash, les sauts et le blink se voient en jeu.
func setup_ability(a: String) -> void:
	ability = a
	match a:
		"tank":
			scale = Vector3.ONE * 1.7
			hp = 2 # 2 stomps pour le tuer
			_speed *= 0.6
			velocity = _dir * _speed
			$AnimationPlayer.speed_scale *= 0.6
		"dasher", "jumper", "ghost":
			pass
		_:
			ability = "normal"


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
	stomped.emit() # feedback immediat : hitmarker, popup HP, shake...
	var pivot: Node3D = $Pivot
	var tween := create_tween()
	tween.tween_property(pivot, "scale", Vector3(1.35, 0.65, 1.35), 0.08)
	tween.tween_property(pivot, "scale", Vector3.ONE, 0.18)
	get_tree().create_timer(0.6, true, false, true).timeout.connect(_end_invulnerability)


func _end_invulnerability() -> void:
	_invulnerable = false


func _on_visible_on_screen_notifier_3d_screen_exited():
	queue_free()
