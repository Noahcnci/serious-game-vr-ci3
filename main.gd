extends Node

@export var mob_scene: PackedScene

const SAVE_PATH := "user://save.cfg"

var wave := 0
var _mobs_to_spawn := 0 # nombre de spawns restants dans la vague courante
var _mobs_alive := 0 # nombre de mobs encore en vie
var _is_boss_wave := false
var _boss_spawned := false
var _announce_id := 0


func _ready():
	$UserInterface/Retry.hide()
	$UserInterface/WaveBanner.hide()
	_start_wave()


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
		_mobs_to_spawn = 4 + wave * 2

	var label := "Vague %d" % wave
	var banner := "VAGUE %d" % wave
	if _is_boss_wave:
		label += " [BOSS]"
		banner += " — BOSS !"
	$UserInterface/WaveLabel.text = label
	_announce(banner, 1.5)

	$MobTimer.wait_time = maxf(0.15, 0.5 - (wave - 1) * 0.04)
	$MobTimer.start()


func _announce(text: String, duration: float) -> void:
	_announce_id += 1
	var id := _announce_id
	$UserInterface/WaveBanner.text = text
	$UserInterface/WaveBanner.show()
	await get_tree().create_timer(duration).timeout
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
	else:
		mob.min_speed = 10.0 + wave
		mob.max_speed = 18.0 + wave * 1.5

	# Choose a random location on the SpawnPath.
	var mob_spawn_location = get_node("SpawnPath/SpawnLocation")
	mob_spawn_location.progress_ratio = randf()

	var player_position = $Player.position
	mob.initialize(mob_spawn_location.position, player_position)

	add_child(mob)
	_mobs_alive += 1
	mob.squashed.connect(_on_mob_squashed.bind(mob))

	if is_boss_spawn:
		mob.scale = Vector3.ONE * 2.2

	if _mobs_to_spawn <= 0:
		$MobTimer.stop()


func _on_mob_squashed(mob):
	if mob != null and mob.is_boss:
		$UserInterface/ScoreLabel.add_score(5)
	else:
		$UserInterface/ScoreLabel._on_mob_squashed()
	_mobs_alive -= 1

	# Dernier survivant de la vague : plus rapide et annonce.
	if _mobs_alive == 1:
		_highlight_last_mob()

	if _mobs_alive <= 0:
		$MobTimer.stop()
		_announce("VAGUE SUIVANTE...", 2.0)
		get_tree().create_timer(2.0).timeout.connect(_start_wave)


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
	$MobTimer.stop()
	var score: int = $UserInterface/ScoreLabel.score
	var best: int = _load_best()
	var msg := "Score : %d" % score
	if score > best:
		_save_best(score)
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
