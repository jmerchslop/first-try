extends Node3D

## Rooftop Relay greybox. Platforms, cover, plates, and ladders are solid scenery.
## Shots do not bounce or pierce. Open sky is -Z.

const SPAWN_FEET: Array[Vector3] = [
	Vector3(0.0, 6.0, 14.2),
	Vector3(-12.4, 14.0, 2.0),
	Vector3(16.0, 24.0, 8.55),
	Vector3(0.0, 38.0, -1.0),
]
const SPAWN_YAW: Array[float] = [0.0, -90.0, 0.0, 0.0]
const TOWER_A_X := 16.0
const TOWER_A_Z := 8.0
const TOWER_SEPARATION := 14.0
const TOWER_BEARING_DEG := 18.0

const TARGET_SCENE := preload("res://scenes/target.tscn")


func _ready() -> void:
	_build()
	var sun := get_node("Sun") as DirectionalLight3D
	sun.rotation_degrees = Vector3(-50.0, -32.0, 0.0)
	var player := get_node("Player") as PlayerController
	player.boot()


func _build() -> void:
	var floor_mat := _mat("#475569")
	var wall_mat := _mat("#64748B")
	var wall_dark := _mat("#334155")
	var blue := _mat("#2563EB")
	var green := _mat("#16A34A")
	var yellow := _mat("#EAB308")
	var tower := _mat("#A16207")
	var ladder := _mat("#FACC15")
	var red := _mat("#DC2626")
	var red_dark := _mat("#991B1B")
	var amber := _mat("#F59E0B")
	var cyan := _mat("#38BDF8", 0.32, 0.55)
	var atrium := _mat("#94A3B8")

	var combiner := CSGCombiner3D.new()
	combiner.name = "ArenaGeometry"
	combiner.use_collision = false
	combiner.collision_layer = 1
	combiner.collision_mask = 0
	add_child(combiner)

	_box(combiner, "CourtyardFloor", Vector3(50, 1, 50), Vector3(0, -0.5, 0), floor_mat)

	# South tiers. The catwalk sticks north off the Y=6 roof into the courtyard.
	_box(combiner, "SouthRoof", Vector3(42, 6, 10), Vector3(0, 3, 20), wall_mat)
	_box(combiner, "SouthUpper", Vector3(26, 5, 5), Vector3(0, 8.5, 22.5), wall_dark)
	_box(combiner, "SouthEastMass", Vector3(8, 10, 8), Vector3(12, 5, 21), wall_dark)
	_box(combiner, "Drop1Catwalk", Vector3(8, 0.4, 2.2), Vector3(0, 5.8, 14.05), blue)

	# West tiers and the green atrium lip. The ramp is scenery beside the fall line.
	_box(combiner, "WestLow", Vector3(10, 7, 20), Vector3(-20, 3.5, -8), wall_mat)
	_box(combiner, "WestHigh", Vector3(8, 14, 12), Vector3(-21, 7, 2), wall_dark)
	_box(combiner, "AtriumHousing", Vector3(3.2, 3.0, 5.0), Vector3(-18.4, 12.3, 2), atrium)
	_box(combiner, "Drop2Atrium", Vector3(6.6, 0.4, 6), Vector3(-14.1, 13.8, 2), green)
	_box(combiner, "AtriumRamp", Vector3(6.2, 0.28, 2.2), Vector3(-16.2, 9.0, 9.3), wall_mat, Vector3(0, 0, -30))

	# East mass, kept clear of the x=16 fall from the radio tower.
	_box(combiner, "EastBlock", Vector3(6, 7, 22), Vector3(22, 3.5, 2), wall_mat)

	# Twin towers. Drop 3 lands on the 24m cap. The 22m tower is scenery, 14m away.
	var bearing := deg_to_rad(TOWER_BEARING_DEG)
	var tower_b_x := TOWER_A_X - sin(bearing) * TOWER_SEPARATION
	var tower_b_z := TOWER_A_Z - cos(bearing) * TOWER_SEPARATION
	_box(combiner, "Drop3Column", Vector3(3.2, 24, 3.2), Vector3(TOWER_A_X, 12, TOWER_A_Z), tower)
	_box(combiner, "Drop3Platform", Vector3(5.5, 0.4, 5.5), Vector3(TOWER_A_X, 23.8, TOWER_A_Z), yellow)
	_box(combiner, "Drop3BColumn", Vector3(3.2, 22, 3.2), Vector3(tower_b_x, 11, tower_b_z), tower)
	_box(combiner, "Drop3BPlatform", Vector3(5.0, 0.4, 5.0), Vector3(tower_b_x, 21.8, tower_b_z), yellow)
	_ladder(combiner, "LadderA", TOWER_A_X - 2.9, TOWER_A_Z, 20.0, ladder)
	_ladder(combiner, "LadderB", tower_b_x + 1.85, tower_b_z, 18.0, ladder)

	# 1.5m-wide crane boom, top face at Y=38, over the courtyard.
	_box(combiner, "CraneMast", Vector3(1.5, 37.6, 1.5), Vector3(-18.5, 18.8, -1), red_dark)
	_box(combiner, "CraneCab", Vector3(2.2, 1.6, 2.0), Vector3(-18.5, 39.0, -1), red_dark)
	_box(combiner, "CraneBoom", Vector3(40, 0.45, 1.5), Vector3(0, 37.775, -1), red)

	_box(combiner, "CoverBlock", Vector3(2.6, 2.8, 2.0), Vector3(7.76, 1.4, 8.0), amber)
	_box(combiner, "CoverWest", Vector3(2.0, 2.0, 2.0), Vector3(-8.5, 1.0, 9.0), amber)
	_box(combiner, "CoverNorth", Vector3(2.2, 1.8, 2.0), Vector3(5.2, 0.9, -11.2), amber)
	_box(combiner, "CoverFarWest", Vector3(1.8, 2.2, 1.8), Vector3(-13.5, 1.1, -6.0), amber)

	_box(combiner, "PlateA", Vector3(2.4, 1.5, 0.12), Vector3(-12.4, 1.35, -10.2), cyan, Vector3(0, 18, -48))
	_box(combiner, "PlateB", Vector3(2.0, 1.35, 0.12), Vector3(-11.8, 1.45, -7.4), cyan, Vector3(0, -12, -36))

	combiner.use_collision = true

	var points := Node3D.new()
	points.name = "DropPoints"
	add_child(points)
	for index in SPAWN_FEET.size():
		var marker := Marker3D.new()
		marker.name = "Spawn_%d" % (index + 1)
		marker.position = SPAWN_FEET[index]
		marker.rotation_degrees = Vector3(0.0, SPAWN_YAW[index], 0.0)
		points.add_child(marker)

	var targets := Node3D.new()
	targets.name = "Targets"
	add_child(targets)
	var spots: Array[Vector3] = [
		Vector3(-4.5, 0.9, 0.5),
		Vector3(-7.0, 0.9, -3.0),
		Vector3(4.6, 0.9, -1.0),
		Vector3(8.8, 0.9, -16.8),
		Vector3(10.6, 0.9, 6.2),
	]
	for index in spots.size():
		var target := TARGET_SCENE.instantiate() as TargetDummy
		target.name = "Target_%d" % (index + 1)
		target.position = spots[index]
		targets.add_child(target)


func _ladder(parent: Node, prefix: String, face_x: float, z: float, top_y: float, mat: StandardMaterial3D) -> void:
	_box(parent, "%sRail" % prefix, Vector3(0.12, top_y - 1.5, 0.12), Vector3(face_x, top_y * 0.5, z), mat)
	var y := 1.8
	var count := 0
	while y < top_y - 1.2:
		_box(parent, "%sRung%d" % [prefix, count], Vector3(0.28, 0.1, 0.8), Vector3(face_x, y, z), mat)
		y += 1.75
		count += 1


func _box(parent: Node, box_name: String, size: Vector3, pos: Vector3, mat: StandardMaterial3D, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = pos
	box.rotation_degrees = rot_deg
	box.material = mat
	box.use_collision = false
	parent.add_child(box)


func _mat(hex: String, roughness: float = 0.92, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
