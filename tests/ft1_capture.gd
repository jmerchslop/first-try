extends SceneTree

## Plays the FT1 loop far enough to grab the prompt's screenshots.

const OUT_DIRS: PackedStringArray = [
	"/opt/cursor/artifacts",
	"/cursor/stores/self/artifacts",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var packed := load("res://scenes/test_arena.tscn") as PackedScene
	var arena := packed.instantiate()
	root.add_child(arena)
	var player := arena.get_node("Player") as PlayerController
	var hud := arena.get_node("HUD") as FirstTryHud
	var target1 := arena.get_node("Targets/Target_1") as TargetDummy
	var target5 := arena.get_node("Targets/Target_5") as TargetDummy
	await _sim(12)
	_expect_ready(player)
	player.aim_pitch_degrees(-18.0)
	await _shot("ft1_drop1_ready.png")

	Input.action_press("move_forward")
	var guard := 0
	while player.get_clip().state != ClipState.State.AIRBORNE and guard < 180:
		await _physics_only()
		guard += 1
	Input.action_release("move_forward")
	for _i in 8:
		await _physics_only()
	player.aim_at_world(target1.aim_point())
	var fired := player.fire_sniper()
	print("AIR_SHOT fired=", fired, " hits=", player.clip_hits(), " collider=", player.last_collider_name, " state=", player.get_clip().state)
	await _shot("ft1_drop1_airborne_hit.png", true)

	guard = 0
	while player.get_clip().state != ClipState.State.LANDED and guard < 400:
		await _physics_only()
		guard += 1
	player.aim_at_world(target1.aim_point())
	print("LANDED hits=", player.clip_hits(), " shots=", player.clip_shots(), " y=", player.global_position.y)
	await _shot("ft1_clip_over.png")

	await _drop_shot(player, 2, -24.0, "ft1_drop2.png")
	await _drop_shot(player, 3, -10.0, "ft1_drop3_towers.png")
	# Look along the beam so the courtyard is visible below the 1.5m walkway.
	await _drop_shot(player, 4, -42.0, "ft1_drop4_crane.png", -90.0)

	player.teleport_to_drop(1)
	await _sim(8)
	player.aim_at_world(target1.aim_point())
	Input.action_press("ads")
	await _shot("ft1_ads_scope.png")
	Input.action_release("ads")

	hud.set_paused(true)
	await _shot("ft1_settings.png")
	hud.set_paused(false)

	player.teleport_to_drop(1)
	await _sim(4)
	player.global_position = Vector3(8.2, 0.05, 12.2)
	player.velocity = Vector3.ZERO
	player.aim_at_world(Vector3(9.4, 1.15, 7.0))
	await _shot("ft1_cover_block.png")
	print("CAPTURE_DONE")
	quit(0)


func _drop_shot(player: PlayerController, drop: int, pitch: float, file_name: String, yaw_deg: float = INF) -> void:
	player.teleport_to_drop(drop)
	await _sim(8)
	if yaw_deg != INF:
		player.rotation.y = deg_to_rad(yaw_deg)
	player.aim_pitch_degrees(pitch)
	print("DROP_SHOT ", drop, " pos=", player.global_position, " ", player.drop_label())
	await _shot(file_name)


func _expect_ready(player: PlayerController) -> void:
	print(
		"READY state=", player.clip_status_text(),
		" drop=", player.drop_label(),
		" pos=", player.global_position,
		" fov=", player.camera_fov()
	)


func _sim(count: int) -> void:
	RenderingServer.render_loop_enabled = false
	for _i in count:
		await physics_frame


func _physics_only() -> void:
	RenderingServer.render_loop_enabled = false
	await physics_frame


func _shot(file_name: String, flash_crosshair: bool = false) -> void:
	RenderingServer.render_loop_enabled = true
	for _i in 2:
		await process_frame
	if flash_crosshair:
		var hud := root.get_node("TestArena/HUD") as FirstTryHud
		if hud == null:
			hud = root.find_child("HUD", true, false) as FirstTryHud
		if hud != null:
			hud.poke_hit_flash()
		RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	print("FRAME ", file_name, " ", image.get_width(), "x", image.get_height())
	for dir in OUT_DIRS:
		var path := dir.path_join(file_name)
		var err := image.save_png(path)
		if err != OK:
			push_error("Could not save %s (%s)" % [path, error_string(err)])
			continue
		print("SAVED ", path)
