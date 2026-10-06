extends CharacterBody3D

signal hit
# Contact mortel absorbe par une vie : Main decide de la suite.
signal hurt(body)

# How fast the player moves in meters per second.
@export var speed = 14
# The downward acceleration while in the air, in meters per second squared.
@export var fall_acceleration = 75
# Vertical impulse applied to the character upon jumping in meters per second.
@export var jump_impulse = 14
# Vertical impulse applied to the character upon bouncing over a mob
# in meters per second.
@export var bounce_impulse = 14

var target_velocity = Vector3.ZERO

# Limites de l'arene (memes constantes que mob.gd).
const _ARENA_X := 12.0
const _ARENA_Z := 13.0

# Nombre de sauts en l'air restants (double saut, recharge a l'atterrissage).
var _air_jumps_left := 1

# Dash (touche Maj) : impulsion horizontale rapide avec cooldown.
const DASH_SPEED := 24.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 1.2
var _dash_left := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.ZERO

# Invincibilite apres un hit (3 s, joueur clignotant).
var invincible := false


# Invincibilite clignotante : le Pivot s'allume/s'eteint a ~7 Hz.
# Mode fantome : layer ET mask de collision du joueur coupes, les mobs le
# traversent au lieu de le bousculer (sinon un mob qui court le pousse
# a sa propre vitesse pendant toute l'invincibilite). Le mask du sol
# (bit 3) est conserve : le joueur reste pose.
# Boucle pilotee par une deadline : la latence des awaits ne peut pas
# faire durer l'invincibilite au-dela de `duration`.
func start_invincibility(duration := 3.0) -> void:
	invincible = true
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, false)
	var end := Time.get_ticks_msec() + int(duration * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().create_timer(0.1, true, false, true).timeout
		if not is_inside_tree():
			return
		$Pivot.visible = not $Pivot.visible
	$Pivot.visible = true
	set_collision_layer_value(1, true)
	set_collision_mask_value(2, true)
	invincible = false


func _physics_process(delta):
	# We create a local variable to store the input direction.
	var direction = Vector3.ZERO

	# We check for each move input and update the direction accordingly.
	if Input.is_action_pressed("move_right"):
		direction.x = direction.x + 1
	if Input.is_action_pressed("move_left"):
		direction.x = direction.x - 1
	if Input.is_action_pressed("move_back"):
		# Notice how we are working with the vector's x and z axes.
		# In 3D, the XZ plane is the ground plane.
		direction.z = direction.z + 1
	if Input.is_action_pressed("move_forward"):
		direction.z = direction.z - 1

	# Prevent diagonal movement from being very fast.
	if direction != Vector3.ZERO:
		direction = direction.normalized()
		# Setting the basis property will affect the rotation of the node.
		$Pivot.basis = Basis.looking_at(direction)
		$AnimationPlayer.speed_scale = 4
	else:
		$AnimationPlayer.speed_scale = 1

	# Ground Velocity : dash prioritaire sur la marche.
	_dash_cd = maxf(0.0, _dash_cd - delta)
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		var dash_input: Vector3 = direction
		if dash_input == Vector3.ZERO:
			dash_input = -$Pivot.basis.z # pas d'input : dash dans le regard
		_dash_dir = Vector3(dash_input.x, 0.0, dash_input.z).normalized()
		_dash_left = DASH_TIME
		_dash_cd = DASH_COOLDOWN
		Sfx.play("dash", -6.0)
	if _dash_left > 0.0:
		_dash_left -= delta
		target_velocity.x = _dash_dir.x * DASH_SPEED
		target_velocity.z = _dash_dir.z * DASH_SPEED
	else:
		target_velocity.x = direction.x * speed
		target_velocity.z = direction.z * speed

	# Vertical Velocity.
	if not is_on_floor(): # If in the air, fall towards the floor.
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)
	else:
		_air_jumps_left = 1 # recharge le double saut a l'atterrissage

	# Jumping : saut normal au sol, double saut en l'air.
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			target_velocity.y = jump_impulse
		elif _air_jumps_left > 0:
			target_velocity.y = jump_impulse
			_air_jumps_left -= 1

	# Iterate through all collisions that occurred this frame.
	for index in range(get_slide_collision_count()):
		# We get one of the collisions with the player.
		var collision = get_slide_collision(index)

		# If there are duplicate collisions with a mob in a single frame,
		# the mob will be deleted after the first collision, and a second
		# call to get_collider() will return null. This prevents the error.
		if collision.get_collider() == null:
			continue

		# If the collider is with a mob.
		if collision.get_collider().is_in_group("mob"):
			var mob = collision.get_collider()
			# Ecrasement tolerant : soit on touche le dessus du mob (normale
			# vers le haut), soit on est au-dessus de lui et on descend.
			var above: bool = global_position.y > mob.global_position.y + 0.2
			var downward: bool = target_velocity.y <= 0.0
			if Vector3.UP.dot(collision.get_normal()) > 0.1 or (above and downward):
				# If so, we squash it and bounce.
				mob.squash()
				target_velocity.y = mob.stomp_bounce
				_air_jumps_left = 1 # MLG : chaque stomp recharge le double saut
				# Prevent further duplicate calls.
				break

	# Moving the Character.
	velocity = target_velocity
	move_and_slide()

	# Confinement dans l'arene (rayon de la sphere de collision).
	position.x = clampf(position.x, -_ARENA_X + 0.79, _ARENA_X - 0.79)
	position.z = clampf(position.z, -_ARENA_Z + 0.79, _ARENA_Z - 0.79)

	# Make the character arc when jumping.
	$Pivot.rotation.x = PI / 6 * velocity.y / jump_impulse


func die():
	hit.emit()
	queue_free()


func _on_mob_detector_body_entered(body):
	# Grace en plongee : un contact avec un mob ALORS QU'ON EST EN L'AIR,
	# au-dessus de lui et en descente, compte comme un stomp au lieu d'une
	# mort. Indispensable pour le boss : il survit au 1er coup et reste
	# colle au joueur pendant son invulnerabilite.
	if body.is_in_group("mob") and not is_on_floor():
		var above: bool = global_position.y > body.global_position.y + 0.2
		var falling: bool = target_velocity.y <= 0.0
		if above and falling:
			body.squash()
			target_velocity.y = body.stomp_bounce
			_air_jumps_left = 1
			return
	if invincible:
		return
	hurt.emit(body)
