extends Node

@export var mob_scene: PackedScene

const SAVE_PATH := "user://save.cfg"

var wave := 0
var _mobs_to_spawn := 0 # nombre de spawns restants dans la vague courante
var _mobs_alive := 0 # nombre de mobs encore en vie
var _is_boss_wave := false
var _boss_spawned := false
var _announce_id := 0

# ----- Feedback (hitmarkers, +1, juice) -----
var _time_token := 0 # anti-restoration prematuree du time_scale
var _cam_shake_strength := 0.0
var _cam_base := Vector3.ZERO
var _flash_rect: ColorRect

const START_LIVES := 3
var lives := START_LIVES


func _ready():
	$UserInterface/Retry.hide()
	$UserInterface/WaveBanner.hide()
	# Flash blanc plein ecran ( MLG ) , cree au runtime au-dessus de l'UI.
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UserInterface.add_child(_flash_rect)
	_cam_base = $CameraPivot/Camera3D.position
	_update_lives_label()
	# Musique de fond : boucle generee (music/background_loop.wav).
	var music: AudioStreamWAV = load("res://music/background_loop.wav")
	if music != null:
		music.loop_mode = AudioStreamWAV.LOOP_FORWARD
		$MusicPlayer.stream = music
		$MusicPlayer.volume_db = -14.0
		$MusicPlayer.play()
	_start_wave()


func _process(delta):
	# Screen shake : decroissance quadratique, retour a la position de base.
	if _cam_shake_strength > 0.0:
		_cam_shake_strength = maxf(0.0, _cam_shake_strength - delta * 2.5)
		var s := _cam_shake_strength * _cam_shake_strength
		$CameraPivot/Camera3D.position = _cam_base + Vector3(
			randf_range(-s, s), randf_range(-s, s), 0.0)
	elif $CameraPivot/Camera3D.position != _cam_base:
		$CameraPivot/Camera3D.position = _cam_base


func _start_wave() -> void:
	# Ne pas relancer de vague si le joueur est mort entre-temps.
	if not is_inside_tree() or $UserInterface/Retry.visible:
		return
	wave += 1
	_is_boss_wave = wave % 2 == 0
	_boss_spawned = false
	_mobs_alive = 0
	if _is_boss_wave:
		_mobs_to_spawn = 3 # 1 boss + 2 sbires
	else:
		_mobs_to_spawn = 2 + mini(wave, 3) # peu de mobs, mais abilities

	var label := "Vague %d" % wave
	var banner := "VAGUE %d" % wave
	if _is_boss_wave:
		label += " [BOSS]"
		banner += " — BOSS !"
	$UserInterface/WaveLabel.text = label
	_announce(banner, 1.5)

	$MobTimer.wait_time = maxf(0.15, 0.5 - (wave - 1) * 0.04)
	$MobTimer.start()


func _announce(text: String, duration: float, color := Color.WHITE) -> void:
	_announce_id += 1
	var id := _announce_id
	$UserInterface/WaveBanner.text = text
	$UserInterface/WaveBanner.add_theme_color_override("font_color", color)
	$UserInterface/WaveBanner.show()
	await get_tree().create_timer(duration, true, false, true).timeout
	if id == _announce_id:
		$UserInterface/WaveBanner.hide()


func _on_mob_timer_timeout():
	# Effectif defini : on ne spawn plus quand le quota est epuise.
	if _mobs_to_spawn <= 0:
		$MobTimer.stop()
		return
	_mobs_to_spawn -= 1

	var mob = mob_scene.instantiate()

	# Un boss par vague de boss : c'est le premier spawn de la vague.
	var is_boss_spawn := _is_boss_wave and not _boss_spawned
	if is_boss_spawn:
		_boss_spawned = true
		mob.is_boss = true
		mob.hp = 3
		mob.min_speed = 8.0
		mob.max_speed = 12.0
		mob.stomp_bounce = 17.0 # rebond haut : enchainement des 3 stomps
	else:
		mob.min_speed = 10.0 + wave
		mob.max_speed = 18.0 + wave * 1.5

	# Choose a random location on the SpawnPath.
	var mob_spawn_location = get_node("SpawnPath/SpawnLocation")
	mob_spawn_location.progress_ratio = randf()

	var player_position = $Player.position
	mob.initialize(mob_spawn_location.position, player_position)

	# Moins de mobs, mais des abilities cheloues a partir de la vague 2.
	if not is_boss_spawn:
		var roll := randi() % 100
		if wave >= 2 and roll < 18:
			mob.setup_ability("tank")
		elif wave >= 2 and roll < 36:
			mob.setup_ability("dasher")
		elif wave >= 3 and roll < 48:
			mob.setup_ability("jumper")
		elif wave >= 3 and roll < 58:
			mob.setup_ability("ghost")
		mob.player = $Player

	add_child(mob)
	mob.set_meta("wave_mob", true) # compte dans _mobs_alive (spawns du timer uniquement)
	_mobs_alive += 1
	mob.squashed.connect(_on_mob_squashed.bind(mob))
	mob.stomped.connect(_on_mob_stomped.bind(mob))

	if is_boss_spawn:
		mob.scale = Vector3.ONE * 2.2
		Sfx.play("airhorn")

	if _mobs_to_spawn <= 0:
		$MobTimer.stop()


func _on_mob_squashed(mob):
	if mob != null and mob.is_boss:
		$UserInterface/ScoreLabel.add_score(5)
		Sfx.play("boom")
		_hitmarker(mob.global_position + Vector3(0, 2.5, 0))
		_popup("+5 BOSS !", mob.global_position + Vector3(0, 3.2, 0), Color(1.0, 0.3, 0.15))
		_cam_shake(0.9)
		_flash(0.6)
		_hit_stop(0.2, 0.35) # slow-mo sur la mort du boss
	else:
		var pts := 1
		var txt := "+1"
		if mob != null and mob.ability == "tank":
			pts = 2
			txt = "+2 TANK !"
		$UserInterface/ScoreLabel.add_score(pts)
		Sfx.play("hitmarker")
		_hitmarker(mob.global_position + Vector3(0, 1.6, 0))
		_popup(txt, mob.global_position + Vector3(0, 2.2, 0))
		_cam_shake(0.3)
		_hit_stop(0.05, 0.06) # hit-stop sec
	if mob != null and mob.has_meta("wave_mob"):
		_mobs_alive -= 1
		_check_wave_end()


# Fin de vague : meme logique pour un kill ou une despawn (vie perdue).
func _check_wave_end() -> void:
	# Dernier survivant de la vague : plus rapide et annonce.
	if _mobs_alive == 1:
		_highlight_last_mob()

	if _mobs_alive <= 0:
		$MobTimer.stop()
		Sfx.play("ding")
		_announce("VAGUE SUIVANTE...", 2.0)
		get_tree().create_timer(2.0).timeout.connect(_start_wave)


# Chaque coup non mortel encaisse par le boss : feedback immediat.
func _on_mob_stomped(mob):
	Sfx.play("hitmarker")
	_hitmarker(mob.global_position + Vector3(0, 2.5, 0))
	_popup("BOSS HP : %d" % mob.hp, mob.global_position + Vector3(0, 3.2, 0), Color(0.9, 0.3, 0.05))
	_cam_shake(0.5)
	_hit_stop(0.1, 0.07)


# Le joueur encaisse un hit : une vie en moins, mob offenseur detruit,
# invincibilite clignotante 3 s. A 0 vie : vraie mort (ecran game over).
func _on_player_hurt(body) -> void:
	lives -= 1
	_update_lives_label()
	_cam_shake(0.6)
	if is_instance_valid(body) and body.is_in_group("mob"):
		_despawn_mob(body)
	if lives <= 0:
		$MobTimer.stop()
		Sfx.play("sadtrombone")
		$Player.die() # signal hit -> _on_player_hit (ecran game over)
	else:
		$Player.start_invincibility(3.0)


# Destruction d'un mob sans kill (celui qui a touche le joueur).
# La fin de vague ne se declenche que pour un mob reellement compte
# (meta wave_mob), sinon un mob de test ferait avancer les vagues.
func _despawn_mob(mob) -> void:
	if mob == null or mob.is_queued_for_deletion():
		return
	var counted: bool = mob.has_meta("wave_mob")
	mob.queue_free()
	if counted:
		_mobs_alive -= 1
		_check_wave_end()


func _update_lives_label() -> void:
	$UserInterface/LivesLabel.text = "Vies : %d" % max(lives, 0)


# Gel du temps (hit-stop / slow-mo). Restauration en temps reel.
func _hit_stop(scale: float, duration: float) -> void:
	_time_token += 1
	var id := _time_token
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if id == _time_token:
		Engine.time_scale = 1.0


func _cam_shake(strength: float) -> void:
	_cam_shake_strength = maxf(_cam_shake_strength, strength)


func _flash(strength: float) -> void:
	_flash_rect.color = Color(1, 1, 1, strength)
	var tween := create_tween()
	tween.tween_property(_flash_rect, "color:a", 0.0, 0.4)


func _hitmarker(world_pos: Vector3) -> void:
	var label := _make_popup_label("×", 48, Color.WHITE, world_pos)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "scale", Vector2(1.6, 1.6), 0.12)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.finished.connect(label.queue_free)


func _popup(text: String, world_pos: Vector3, color := Color.WHITE) -> void:
	# Gigue aleatoire : plusieurs popups au meme endroit ne se superposent pas.
	var jittered := world_pos + Vector3(randf_range(-0.6, 0.6), randf_range(-0.2, 0.4), 0)
	var label := _make_popup_label(text, 26, color, jittered)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 70.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)


func _make_popup_label(text: String, font_size: int, color: Color, world_pos: Vector3) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_font_size_override("font_size", font_size)
	$UserInterface.add_child(label)
	var cam := get_viewport().get_camera_3d()
	label.position = cam.unproject_position(world_pos) - label.size / 2
	return label


func _highlight_last_mob() -> void:
	var remaining := get_tree().get_nodes_in_group("mob")
	if remaining.is_empty():
		return
	var last = remaining[0]
	last.min_speed *= 1.5
	last.max_speed *= 1.5
	last.velocity *= 1.5
	_announce("DERNIER MOB !", 1.2)


func _on_player_hit():
	# Ecran de fin : le joueur vient de mourir (0 vie restante).
	var score: int = $UserInterface/ScoreLabel.score
	var best: int = _load_best()
	var msg := "Score : %d" % score
	if score > best:
		_save_best(score)
		Sfx.play("ding")
		msg += "  —  NOUVEAU RECORD !"
	else:
		msg += "  —  Record : %d" % best
	$UserInterface/Retry/Label.text = msg + "\nAppuyez sur Entrée pour réessayer."
	$UserInterface/Retry.show()


func _unhandled_input(event):
	if event.is_action_pressed("ui_accept") and $UserInterface/Retry.visible:
		# This restarts the current scene.
		get_tree().reload_current_scene()


func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return int(cfg.get_value("game", "best", 0))
	return 0


func _save_best(value: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", value)
	cfg.save(SAVE_PATH)
