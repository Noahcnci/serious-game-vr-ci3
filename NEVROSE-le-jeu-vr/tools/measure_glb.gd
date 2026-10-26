extends SceneTree
## Mesure les AABB natives des GLB Kenney utilisés par la map 2 étendue.
## Usage : Godot --headless --path . --script res://tools/measure_glb.gd

const FURN := "res://assets/kenney/furniture/"

const FILES := [
	"tableCross.glb", "washer.glb", "bookcaseOpen.glb", "bookcaseClosed.glb",
	"cardboardBoxClosed.glb", "cardboardBoxOpen.glb", "trashcan.glb",
	"coatRackStanding.glb", "rugDoormat.glb", "bedDouble.glb",
	"cabinetBedDrawerTable.glb", "cabinetBedDrawer.glb", "desk.glb",
	"chairDesk.glb", "lampRoundTable.glb", "rugRectangle.glb",
	"pottedPlant.glb", "pillow.glb", "pillowLong.glb",
	"toilet.glb", "bathroomSinkSquare.glb", "bathroomCabinet.glb",
	"bathroomMirror.glb", "shower.glb", "bathroomCabinetDrawer.glb",
	"bathtub.glb", "coatRack.glb",
]


func _initialize() -> void:
	print("=== MESURE AABB GLB (échelle native) ===")
	for f in FILES:
		var packed: PackedScene = load(FURN + f)
		if packed == null:
			print("%s : ERREUR CHARGEMENT" % f)
			continue
		var n: Node3D = packed.instantiate()
		root.add_child(n)
		await process_frame
		var merged := AABB()
		var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
			if first:
				merged = a
				first = false
			else:
				merged = merged.merge(a)
		if first:
			print("%s : aucun mesh" % f)
		else:
			var s := merged.size
			var top25 := (merged.position.y + merged.size.y) * 2.5
			print("%s : taille=(%.3f, %.3f, %.3f) base_y=%.3f  |  à x2.5 : hauteur=%.3f" % [
				f, s.x, s.y, s.z, merged.position.y, top25])
		n.queue_free()
		await process_frame
	print("=== FIN ===")
	quit()
