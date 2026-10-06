extends Node
# Sfx : joue les effets sonores MLG a la demande, depuis n'importe quelle scene.
# Usage : Sfx.play("airhorn")

var _streams := {}

const SOUNDS := ["airhorn", "hitmarker", "sadtrombone", "ding", "boom", "dash"]


func _ready() -> void:
	for sound_name in SOUNDS:
		var stream: AudioStream = load("res://sfx/%s.wav" % sound_name)
		if stream != null:
			_streams[sound_name] = stream
		else:
			push_warning("Sfx: fichier manquant res://sfx/%s.wav" % sound_name)


func play(sound_name: String, volume_db := 0.0) -> void:
	if not _streams.has(sound_name):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
