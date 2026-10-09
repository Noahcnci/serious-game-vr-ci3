extends Node
## Voix dans les murs (GDD §5.2/§7) : AudioStreamPlayer3D HRTF placées
## autour de la pièce. Déclenchées à fréquence croissante selon la schizo.
##
## 15 voix conspirationnistes (CIA, Linky, 5G, chemtrails, etc.) chargées
## depuis assets/voices/. Chaque emplacement spatial = un mur, le plafond
## ou le sol. Plus la schizo monte, plus elles sont fréquentes et proches.
##
## Godot 4 utilise HRTF par défaut pour AudioStreamPlayer3D → audio binaural
## natif sur casque VR (Quest 2, Vive Pro via SteamVR).

const VOICE_DIR := "res://assets/voices/"
const VOICE_COUNT := 15

## Emplacements spatiaux : murs (4), plafond (2), sol (2), coin (2).
## Valeurs par défaut = map 1 (studio 6x4.5). configure_room() les recale
## pour une autre map (ex. salon+cuisine 8x6).
var PLACEMENTS: Array[Vector3] = [
	Vector3(2.65, 1.4, 0.0),   ## mur est (mi-hauteur)
	Vector3(-2.65, 1.4, 0.0),  ## mur ouest
	Vector3(0.0, 1.4, 2.65),   ## mur sud
	Vector3(0.0, 1.4, -2.65),  ## mur nord
	Vector3(0.5, 2.6, 0.3),    ## plafond droit
	Vector3(-0.8, 2.6, -0.5),  ## plafond gauche
	Vector3(1.0, 0.05, 0.8),   ## sol avant-droit
	Vector3(-1.2, 0.05, -0.6), ## sol arrière-gauche
	Vector3(2.5, 0.5, 2.5),    ## coin SE bas
	Vector3(-2.5, 0.5, -2.5),  ## coin NO bas
	Vector3(0.0, 2.6, 0.0),    ## plafond centre
	Vector3(2.65, 2.2, 0.5),   ## mur est haut
	Vector3(-2.65, 2.2, -0.5), ## mur ouest haut
	Vector3(0.5, 0.05, 2.65),  ## sol mur sud
	Vector3(0.0, 1.2, -2.65),  ## mur nord (hauteur yeux)
]


## Recale les emplacements pour une pièce de `w` x `d` mètres, hauteur `h`.
## Appelé par main.gd après _build_world() avec les dims de la map courante.
func configure_room(w: float, d: float, h: float) -> void:
	PLACEMENTS = [
		Vector3(w / 2 - 0.35, 1.4, 0.0),
		Vector3(-w / 2 + 0.35, 1.4, 0.0),
		Vector3(0.0, 1.4, d / 2 - 0.35),
		Vector3(0.0, 1.4, -d / 2 + 0.35),
		Vector3(0.5, h - 0.1, 0.3),
		Vector3(-0.8, h - 0.1, -0.5),
		Vector3(1.0, 0.05, 0.8),
		Vector3(-1.2, 0.05, -0.6),
		Vector3(w / 2 - 0.5, 0.5, d / 2 - 0.5),
		Vector3(-w / 2 + 0.5, 0.5, -d / 2 + 0.5),
		Vector3(0.0, h - 0.1, 0.0),
		Vector3(w / 2 - 0.35, 2.2, 0.5),
		Vector3(-w / 2 + 0.35, 2.2, -0.5),
		Vector3(0.5, 0.05, d / 2 - 0.35),
		Vector3(0.0, 1.2, -d / 2 + 0.35),
	]

var _players: Array[AudioStreamPlayer3D] = []
var _streams: Array[AudioStreamWAV] = []
var _cooldown := 0.0
var _voice_idx := 0
var enabled := true

## Fréquence de base (s) entre deux voix — réduite quand la schizo monte.
const BASE_COOLDOWN := 12.0 ## ~12 s à sanity=0
const MIN_COOLDOWN := 3.0   ## ~3 s à sanity=100

## Volume max (dB) — les voix sont sourdes, pas criantes.
const MAX_VOLUME_DB := -4.0
const MIN_VOLUME_DB := -18.0


func _ready() -> void:
	_load_voices()
	_create_players()


func _load_voices() -> void:
	var dir := DirAccess.open(VOICE_DIR)
	if dir == null:
		push_warning("Voix : dossier %s inaccessible" % VOICE_DIR)
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".wav") and not fname.begins_with("raw_"):
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	_streams.resize(files.size())
	var loaded := 0
	for i in files.size():
		var stream: AudioStreamWAV = load(VOICE_DIR + files[i])
		if stream:
			stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
			_streams[i] = stream
			loaded += 1
	_log("AUDIO", "Voix : %d fichiers chargés" % loaded)


func _create_players() -> void:
	for i in 6: ## 6 emitters simultanés max (polyphonie)
		var p := AudioStreamPlayer3D.new()
		p.name = "WallVoice_%d" % i
		p.bus = "Master"
		p.max_distance = 8.0
		p.position = PLACEMENTS[i % PLACEMENTS.size()]
		add_child(p)
		_players.append(p)


## Appelé par main.gd à chaque frame (ou tick).
## `t` = sanity / 100.0 (0.0 à 1.0)
func tick(t: float, delta: float) -> void:
	if not enabled or _streams.is_empty():
		return
	# Le cooldown diminue quand la schizo monte
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	# Seuil : ne jouer qu'à partir de 20% de schizo
	if t < 0.2:
		_cooldown = BASE_COOLDOWN * (1.0 - t)
		return
	# Jouer une voix
	_play_random_voice(t)
	# Nouveau cooldown (plus court = plus fou)
	var cooldown_range := lerpf(BASE_COOLDOWN, MIN_COOLDOWN, t)
	_cooldown = cooldown_range * randf_range(0.7, 1.3)


func _play_random_voice(t: float) -> void:
	# Trouver un player libre
	var free_player: AudioStreamPlayer3D = null
	for p in _players:
		if not p.playing:
			free_player = p
			break
	if free_player == null:
		return

	# Choisir une voix aléatoire (pas la même deux fois de suite)
	var idx := randi_range(0, _streams.size() - 1)
	while idx == _voice_idx and _streams.size() > 1:
		idx = randi_range(0, _streams.size() - 1)
	_voice_idx = idx
	var stream: AudioStreamWAV = _streams[idx]
	if stream == null:
		return

	# Position spatiale aléatoire (varie pour la surprise)
	var pos_idx := randi_range(0, PLACEMENTS.size() - 1)
	free_player.position = PLACEMENTS[pos_idx]

	# Volume : plus la schizo monte, plus c'est fort
	free_player.volume_db = lerpf(MIN_VOLUME_DB, MAX_VOLUME_DB, t)

	# Pitch : légèrement aléatoire (varie entre lectures)
	free_player.pitch_scale = randf_range(0.85, 1.15)

	free_player.stream = stream
	free_player.play()
	_log("VOIX", "voix #%d jouée à %s (sanity=%.0f)" % [idx + 1, str(PLACEMENTS[pos_idx]), t * 100.0])


func _log(cat: String, msg: String) -> void:
	var logger = get_node_or_null("/root/GameLog")
	if logger:
		logger.log_line(cat, msg)
	else:
		print("[%s] %s" % [cat, msg])
