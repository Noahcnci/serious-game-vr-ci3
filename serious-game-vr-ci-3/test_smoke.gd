extends SceneTree

# Test fonctionnel du tutoriel "Votre premier jeu 3D".
# Scénario A : 3 vies + invincibilité clignotante 3 s. Hit -> vie perdue,
#              mob offenseur détruit, pas de game over. A 0 vie : mort réelle.
# Scénario B : un joueur qui tombe sur un mob doit l'écraser
#              (signal squashed -> score +1, rebond).

# Simule une pression/relachement d'action via un vrai InputEventAction :
# Input.action_press() ne met pas a jour is_action_just_pressed() de facon
# fiable depuis _physics_process (horodatage de frame decale), ce qui
# empeche de tester le double saut.

func _press_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _release_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)


func _initialize():
	# ---------- Scénario A : 3 vies + invincibilité 3 s ----------
	# Hit 1 : vie 3 -> 2, joueur invincible, mob offenseur détruit, pas de
	#         game over. Hit pendant l'invincibilité : ignoré. Après
	#         expiration : hit 2 (2 -> 1), hit 3 (1 -> 0) = mort réelle.
	var mob_scene: PackedScene = load("res://mob.tscn")
	var main_a: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main_a)
	await process_frame
	# Isolation : aucun spawn automatique pendant ce scenario.
	main_a._mobs_to_spawn = 0
	main_a.get_node("MobTimer").stop()
	var player_a = main_a.get_node("Player")

	var spawn_ram := func() -> void:
		# Comme dans main.gd : initialize() AVANT add_child. Tir droit
		# déterministe sur le joueur (0, 0, 12 m/s depuis z = -6).
		var m = mob_scene.instantiate()
		m.initialize(Vector3(0, 0, -6), Vector3.ZERO)
		m.velocity = Vector3(0, 0, 12)
		main_a.add_child(m)

	# Hit n°1 : une vie en moins, invincibilité déclenchée.
	spawn_ram.call()
	await create_timer(1.2).timeout
	var hit1_ok: bool = main_a.lives == 2 and main_a.has_node("Player")
	var invincible_on: bool = player_a.invincible
	var retry_hidden: bool = not main_a.get_node("UserInterface/Retry").visible
	var mob_destroyed: bool = get_nodes_in_group("mob").is_empty()

	# Hit pendant l'invincibilité : ignoré (toujours 2 vies, toujours vivant).
	spawn_ram.call()
	await create_timer(1.0).timeout
	var hit_ignored: bool = main_a.lives == 2 and main_a.has_node("Player")

	# Nettoyage : éviter qu'un mob errant ne refasse un hit après expiration.
	for m in get_nodes_in_group("mob"):
		m.queue_free()
	await process_frame

	# Expiration de l'invincibilité (3 s réelles après le hit 1).
	await create_timer(2.3).timeout
	var invincible_off: bool = not player_a.invincible

	# Hit n°2 : deuxième vie perdue.
	spawn_ram.call()
	await create_timer(1.2).timeout
	var hit2_ok: bool = main_a.lives == 1 and main_a.has_node("Player")

	await create_timer(3.2).timeout
	for m in get_nodes_in_group("mob"):
		m.queue_free()
	await process_frame

	# Hit n°3 = dernière vie : mort réelle et écran de fin.
	spawn_ram.call()
	await create_timer(1.5).timeout
	var player_dead: bool = not main_a.has_node("Player")
	var retry_visible: bool = main_a.get_node("UserInterface/Retry").visible
	var timer_stopped: bool = main_a.get_node("MobTimer").is_stopped()
	var label_ok: bool = "Score" in main_a.get_node("UserInterface/Retry/Label").text
	print("TEST_A hit1=%s invincible_on=%s retry_hidden=%s mob_destroyed=%s hit_ignored=%s invincible_off=%s hit2=%s player_dead=%s retry_visible=%s timer_stopped=%s label_ok=%s lives=%d" % [hit1_ok, invincible_on, retry_hidden, mob_destroyed, hit_ignored, invincible_off, hit2_ok, player_dead, retry_visible, timer_stopped, label_ok, main_a.lives])

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

	mob_e.queue_free() # ne pas laisser errer ce mob dans les scenarios suivants
	main_e.queue_free()
	await process_frame

	# ---------- Scénario F : double saut ----------
	var main_f: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main_f)
	await process_frame
	main_f._mobs_to_spawn = 0
	main_f.get_node("MobTimer").stop()
	var player_f = main_f.get_node("Player")

	# Laisser le joueur se poser au sol : au spawn il n'a pas encore
	# de contact physique, un saut immediate consommerait le double saut.
	for i in range(30):
		await physics_frame
		if player_f.is_on_floor():
			break

	var max_y := 0.0
	_press_action("jump")
	await physics_frame
	_release_action("jump")
	# Monter jusqu'a l'apogee (velocity.y devient negative en redescendant).
	# ~12 frames avec jump_impulse=14 et fall_acceleration=75.
	for i in range(30):
		await physics_frame
		if not is_instance_valid(player_f):
			break
		max_y = maxf(max_y, player_f.global_position.y)
		if player_f.velocity.y < 0.0:
			break

	_press_action("jump") # double saut exactement a l'apogee, en plein vol
	await physics_frame
	_release_action("jump")
	for i in range(45):
		await physics_frame
		if not is_instance_valid(player_f):
			break
		max_y = maxf(max_y, player_f.global_position.y)

	# Le boss fait 2.36 m de haut : il faut depasser ~2.4 m pour l'ecraser.
	var double_jump_ok: bool = max_y > 2.4
	print("TEST_F max_height=%.2f double_jump_ok=%s" % [max_y, double_jump_ok])

	main_f.queue_free()
	await process_frame

	# ---------- Scénario G : le boss est ecrasable en jeu (physique reelle) ----------
	# Le joueur tombe sur le boss : il doit encaisser un stomp (hp 3 -> 2),
	# rebondir, rester EN VIE meme en re-touchant le boss invulnerable,
	# et recuperer son saut en l'air. Le time_scale doit revenir a 1.
	var main_g: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main_g)
	await process_frame
	main_g._mobs_to_spawn = 0
	main_g.get_node("MobTimer").stop()

	var boss_g = mob_scene.instantiate()
	boss_g.is_boss = true
	boss_g.hp = 3
	boss_g.stomp_bounce = 17.0
	boss_g.scale = Vector3.ONE * 2.2
	boss_g.velocity = Vector3.ZERO
	main_g.add_child(boss_g)
	boss_g.squashed.connect(main_g._on_mob_squashed.bind(boss_g))
	boss_g.stomped.connect(main_g._on_mob_stomped.bind(boss_g))
	await physics_frame # laisser le boss se poser

	var player_g = main_g.get_node("Player")
	player_g.global_position = boss_g.global_position + Vector3(0, 3.5, 0)

	await create_timer(1.5).timeout

	var boss_damaged: bool = boss_g.hp < 3
	var player_alive_g: bool = main_g.has_node("Player")
	var air_jump_refunded: bool = true
	if player_alive_g:
		air_jump_refunded = player_g._air_jumps_left == 1
	var time_ok_g: bool = Engine.time_scale == 1.0
	print("TEST_G boss_damaged=%s (hp=%d) player_alive=%s air_jump_refunded=%s time_scale_restored=%s" % [
		boss_damaged, boss_g.hp, player_alive_g, air_jump_refunded, time_ok_g
	])

	main_g.queue_free()
	await process_frame

	# ---------- Scénario H : dash (touche Maj) + musique de fond ----------
	# Dash : vitesse horizontale > vitesse de marche pendant l'impulsion,
	# cooldown 1,2 s. Musique : AudioStreamPlayer en lecture a l'arrivee.
	var main_h: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main_h)
	await process_frame
	main_h._mobs_to_spawn = 0
	main_h.get_node("MobTimer").stop()
	var player_h = main_h.get_node("Player")
	var floor_frames_h := 0
	while not player_h.is_on_floor() and floor_frames_h < 30:
		await physics_frame
		floor_frames_h += 1

	var music_ok: bool = main_h.get_node("MusicPlayer").playing

	_press_action("move_right")
	await create_timer(0.4).timeout
	_press_action("dash")
	await create_timer(0.12).timeout # pendant l'impulsion (0,16 s)
	var dash_speed := absf(player_h.velocity.x)
	var dash_ok: bool = player_h._dash_left > 0.0 and dash_speed > 16.0
	# Cooldown : un second dash immediat ne doit pas partir.
	_press_action("dash")
	await create_timer(0.1).timeout
	var cooldown_ok: bool = player_h._dash_left <= 0.0 and absf(player_h.velocity.x) < 20.0
	_release_action("move_right")
	print("TEST_H music_ok=%s dash_ok=%s (speed=%.1f) cooldown_ok=%s" % [music_ok, dash_ok, dash_speed, cooldown_ok])

	main_h.queue_free()
	await process_frame

	quit(0)
