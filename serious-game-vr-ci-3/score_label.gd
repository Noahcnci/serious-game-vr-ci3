extends Label

var score = 0


func _on_mob_squashed():
	add_score(1)


func add_score(points: int) -> void:
	score += points
	text = "Score: %s" % score
