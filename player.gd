extends CharacterBody3D

signal hit

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

	# Ground Velocity.
	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed

	# Vertical Velocity.
	if not is_on_floor(): # If in the air, fall towards the floor.
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)

	# Jumping.
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		target_velocity.y = jump_impulse

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
				target_velocity.y = bounce_impulse
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


func _on_mob_detector_body_entered(_body):
	die()
