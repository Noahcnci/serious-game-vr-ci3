extends SceneTree
## Vérifie que chaque meuble de l'extension porte l'échelle attendue (FURN_SCALE).
## Usage : Godot --headless --path . --script res://tools/verify_scale.gd

const EXPECTED := {
	"tableCross": 2.5, "washer": 1.8, "bookcaseOpen": 2.2,
	"bookcaseClosed": 2.2, "cardboardBoxClosed": 1.7, "cardboardBoxOpen": 1.7,
	"trashcan": 1.3, "coatRackStanding": 2.3, "rugDoormat": 1.5,
	"bedDouble": 1.6, "cabinetBedDrawerTable": 1.9, "cabinetBedDrawer": 1.9,
	"desk": 1.9, "chairDesk": 1.5, "lampRoundTable": 1.5,
	"rugRectangle": 1.2, "pottedPlant": 1.5, "pillow": 1.7,
	"pillowLong": 1.7, "toilet": 1.7, "bathroomSinkSquare": 1.4,
	"bathroomCabinet": 1.6, "bathroomMirror": 1.6, "shower": 0.9,
	"bathroomCabinetDrawer": 1.5, "bathtub": 1.45, "coatRack": 1.2,
}


func _initialize() -> void:
	var map := Map2Extended.new()
	root.add_child(map)
	map.build()
	await process_frame
	var checked := 0
	var failures := 0
	# Mobilier PROCÉDURAL uniquement — le salon/cuisine ET la coquille des
	# nouvelles pièces vivent dans le .tscn (Shell) et ne sont pas concernés.
	# NB : le nom de pièce existe DEUX FOIS (Shell/ExtensionEst/X pour les murs
	# du .tscn, X à la racine pour la construction procédurale) → on scanne
	# toutes les occurrences ; la coquille ne contient que murs/sols/lumières.
	for room_name in ["Couloir", "Garage", "Chambre", "SDB", "Dressing", "Jardin"]:
		for room in map.find_children(room_name, "Node3D", true, false):
			for n in room.find_children("*", "Node3D", true, false):
				var base: String = n.name.trim_suffix("2").trim_suffix("3")
				if EXPECTED.has(base):
					var s: float = (n as Node3D).scale.x
					var expected: float = EXPECTED[base]
					checked += 1
					if absf(s - expected) > 0.01:
						failures += 1
						printerr("  [ECHEC] %s : scale=%.2f attendu=%.2f" % [n.get_path(), s, expected])
	if checked == 0:
		printerr("  [ECHEC] aucun meuble trouvé — la vérif ne veut rien dire")
		failures += 1
	print("=== VERIF ECHELLES : %d meubles verifies, %d echec(s) ===" % [checked, failures])
	quit(0 if failures == 0 else 1)
