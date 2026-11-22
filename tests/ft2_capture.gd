extends SceneTree

## FT2 screenshots: Intervention at the hip, hidden while ADS is held.

const OUT_DIR := "/cursor/stores/self/artifacts"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var arena := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	var player := arena.get_node("Player") as PlayerController
	var target := arena.get_node("Targets/Target_1") as TargetDummy
	await _sim(12)
	var rifle := player.get_node("CameraPivot/Camera3D/Rifle") as Node3D
	print("RIFLE pos=%s rot=%s scale=%s visible=%s" % [rifle.position, rifle.rotation, rifle.scale, rifle.visible])
	player.aim_pitch_degrees(-16.0)
	await _shot("ft2_hip_ready.png")

	Input.action_press("move_forward")
	var guard := 0
	while player.get_clip().state != ClipState.State.AIRBORNE and guard < 180:
		await _physics_only()
		guard += 1
	Input.action_release("move_forward")
	for _i in 10:
		await _physics_only()
	player.aim_pitch_degrees(-22.0)
	print("AIR state=%s rifle_visible=%s" % [player.clip_status_text(), rifle.visible])
	await _shot("ft2_hip_airborne.png")

	player.teleport_to_drop(1)
	await _sim(8)
	player.aim_at_world(target.aim_point())
	Input.action_press("ads")
	await _shot("ft2_ads_hidden.png")
	print("ADS fov=%s rifle_visible=%s" % [player.camera_fov(), rifle.visible])
	Input.action_release("ads")
	await _shot("ft2_ads_released.png")
	print("RELEASED fov=%s rifle_visible=%s" % [player.camera_fov(), rifle.visible])

	var camera := player.get_node("CameraPivot/Camera3D") as Camera3D
	camera.fov = 70.0
	player.aim_pitch_degrees(-8.0)
	await _shot("ft2_closeup_right.png")
	print("CAPTURE_DONE")
	quit(0)


func _sim(count: int) -> void:
	RenderingServer.render_loop_enabled = false
	for _i in count:
		await physics_frame


func _physics_only() -> void:
	RenderingServer.render_loop_enabled = false
	await physics_frame


func _shot(file_name: String) -> void:
	RenderingServer.render_loop_enabled = true
	for _i in 2:
		await process_frame
	var image := root.get_texture().get_image()
	var path := OUT_DIR.path_join(file_name)
	var err := image.save_png(path)
	print("FRAME ", file_name, " ", image.get_width(), "x", image.get_height(), " err=", err, " path=", path)
