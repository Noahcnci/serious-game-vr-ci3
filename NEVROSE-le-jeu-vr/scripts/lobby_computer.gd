class_name LobbyComputer
extends Area3D
## Ordinateur du lobby : survol au rayon VR, puis gâchette pour lancer le jeu.

signal start_requested

@onready var play_prompt: Label3D = $PlayPrompt
@onready var screen_highlight: MeshInstance3D = $ScreenHighlight

var _activated := false


func _ready() -> void:
	play_prompt.visible = false
	screen_highlight.visible = false


func on_pointed() -> void:
	if _activated:
		return
	play_prompt.visible = true
	screen_highlight.visible = true


func on_unpointed() -> void:
	if _activated:
		return
	play_prompt.visible = false
	screen_highlight.visible = false


## Main transmet toujours la clé tenue (nulle ici) aux objets interactifs.
func interact(_holding_key: Node3D = null) -> void:
	if _activated:
		return
	_activated = true
	play_prompt.text = "CHARGEMENT..."
	play_prompt.visible = true
	screen_highlight.visible = true
	start_requested.emit()