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
	mob_a.initialize(Vector3(0, 0, -6), Vector3.ZERO)
	mob_a.velocity = Vector3(0, 0, 12)
	main_a.add_child(mob_a)

	await create_timer(1.5).timeout

	var player_dead = not main_a.has_node("Player")
	var retry_visible = main_a.get_node("UserInterface/Retry").visible
	var timer_stopped = main_a.get_node("MobTimer").is_stopped()
	var label_ok = "Score" in main_a.get_node("UserInterface/Retry/Label").text
	var time_ok = Engine.time_scale == 1.0
	var wave_ok = main_a.get_node("UserInterface/WaveLabel").text == "Vague 1"
	print("TEST_A player_dead=%s retry_visible=%s timer_stopped=%s label_ok=%s wave_label=%s" % [player_dead, retry_visible, timer_stopped, label_ok, wave_ok])

	main_a.queue_free()
	await process_frame

	# ---------- Scénario B : écrasement + score ----------
	var main_b: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main_b)
	await process_frame
	# Isolation : aucun spawn automatique pour ce scenario.
	main_b._mobs_to_spawn = 0
	main_b.get_node("MobTimer").stop()

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
	var anim_ok = is_instance_valid(anim) and anim.is_playing() and anim.current_animation == "float"
	var time_ok_b = Engine.time_scale == 1.0
	print("TEST_B score_ok=%s (\"%s\") mob_freed=%s player_alive=%s anim_float_playing=%s time_scale_restored=%s" % [
		score_ok, score_label.text, mob_freed, player_alive, anim_ok, time_ok_b
	])

	main_b.queue_free()
	await process_frame

	# ---------- Scénario C : effectif defini + transition vers vague boss ----------
	var main_c: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main_c)
	await process_frame

	# Une seule creature cette vague : apres son ecrasement, la vague 2 (BOSS)
	# doit demarrer, puis le timer doit spawn le boss.
	main_c._mobs_to_spawn = 1

	var mob_c = null
	for i in range(120): # ~2 s
		await physics_frame
		var list := get_nodes_in_group("mob")
		if list.size() > 0:
			mob_c = list[0]
			break

	if mob_c != null:
		mob_c.velocity = Vector3.ZERO # immobilise la cible avant le stomp
		main_c.get_node("Player").global_position = mob_c.global_position + Vector3(0, 3, 0)

	var wave2_ok := false
	for i in range(300): # ~5 s
		await physics_frame
		if main_c.get_node("UserInterface/WaveLabel").text.begins_with("Vague 2"):
			wave2_ok = true
			break

	var boss_ok := false
	for i in range(300): # ~5 s
		await physics_frame
		for m in get_nodes_in_group("mob"):
			if m.is_boss and m.hp == 3 and m.scale.x > 2.0:
				boss_ok = true
				break
		if boss_ok:
			break

	print("TEST_C wave2_boss_reached=%s boss_spawned=%s" % [wave2_ok, boss_ok])

	main_c.queue_free()
	await process_frame

	# ---------- Scénario D : mecanique de HP du boss (unitaire) ----------
	var boss = mob_scene.instantiate()
	boss.hp = 3
	root.add_child(boss)
	var counter := {"n": 0} # les lambdas ne propagent pas les entiers modifies
	boss.squashed.connect(func(): counter.n += 1)

	boss.squash()
	var hp_after_1: int = boss.hp
	boss._invulnerable = false # bypass du delai pour le test
	boss.squash()
	var hp_after_2: int = boss.hp
	boss._invulnerable = false
	boss.squash()
	await process_frame
	var boss_dead := not is_instance_valid(boss)
	print("TEST_D hp_after_1=%d hp_after_2=%d boss_dead=%s squashed_signals=%d" % [
		hp_after_1, hp_after_2, boss_dead, counter.n
	])

	# ---------- Scénario E : arene fermee ----------
	# Mob lance plein sud : doit rebondir sur le mur et revenir vers le nord.
	var mob_e = mob_scene.instantiate()
	mob_e.position = Vector3.ZERO
	mob_e.velocity = Vector3(0, 0, 10)
	root.add_child(mob_e)
	await create_timer(1.5).timeout
	var mob_bounced: bool = mob_e.velocity.z < 0.0 and mob_e.position.z <= 12.0
	var mob_confined: bool = mob_e.position.z >= -12.0 and absf(mob_e.position.x) <= 12.0

	# Joueur teleporte hors de l'arene : doit etre reclampe a l'interieur.
	var main_e: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main_e)
	await process_frame
	main_e._mobs_to_spawn = 0
	main_e.get_node("MobTimer").stop()
	var player_e = main_e.get_node("Player")
	player_e.global_position = Vector3(50, 0, 0)
	await physics_frame
	await physics_frame
	var player_clamped: bool = absf(player_e.global_position.x) <= 12.0 - 0.79 + 0.05
	print("TEST_E mob_bounced=%s mob_confined=%s player_clamped=%s" % [
		mob_bounced, mob_confined, player_clamped
	])

	quit(0)
