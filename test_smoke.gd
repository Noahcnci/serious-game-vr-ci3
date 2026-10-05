extends SceneTree

# Test fonctionnel du tutoriel "Votre premier jeu 3D".
# Scénario A : un mob fonçant droit sur le joueur doit le tuer
#              (signal hit -> Retry visible + MobTimer arrêté).
# Scénario B : un joueur qui tombe sur un mob doit l'écraser
#              (signal squashed -> score +1, rebond).

func _initialize():
	# ---------- Scénario A : mort du joueur ----------
	var main_a: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main_a)
	await process_frame

	var mob_scene: PackedScene = load("res://mob.tscn")
	var mob_a = mob_scene.instantiate()
	# Comme dans main.gd : initialize() AVANT add_child, pour que le corps
	# physique s'enregistre à la bonne position. Tir droit déterministe.
	mob_a.initialize(Vector3(0, 1, -6), Vector3.ZERO)
	mob_a.velocity = Vector3(0, 0, 12)
	main_a.add_child(mob_a)

	await create_timer(1.5).timeout

	var player_dead = not main_a.has_node("Player")
	var retry_visible = main_a.get_node("UserInterface/Retry").visible
	var timer_stopped = main_a.get_node("MobTimer").is_stopped()
	print("TEST_A player_dead=%s retry_visible=%s timer_stopped=%s" % [player_dead, retry_visible, timer_stopped])

	main_a.queue_free()
	await process_frame

	# ---------- Scénario B : écrasement + score ----------
	var main_b: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main_b)
	await process_frame

	var score_label = main_b.get_node("UserInterface/ScoreLabel")
	var player = main_b.get_node("Player")
	var anim: AnimationPlayer = player.get_node("AnimationPlayer")

	var mob_b = mob_scene.instantiate()
	mob_b.velocity = Vector3.ZERO # immobile, en dessous du joueur
	mob_b.squashed.connect(score_label._on_mob_squashed.bind())
	main_b.add_child(mob_b)

	# Le joueur tombe de 3 m de haut directement sur le mob.
	player.position = Vector3(0, 3, 0)

	await create_timer(1.5).timeout

	var score_ok = score_label.text == "Score: 1"
	var mob_freed = not is_instance_valid(mob_b) or mob_b.is_queued_for_deletion()
	var player_alive = main_b.has_node("Player")
	var anim_ok = anim.is_playing() and anim.current_animation == "float"
	print("TEST_B score_ok=%s (\"%s\") mob_freed=%s player_alive=%s anim_float_playing=%s" % [
		score_ok, score_label.text, mob_freed, player_alive, anim_ok
	])

	quit(0)
