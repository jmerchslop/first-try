extends SceneTree

## Headless checks for clip state, zero spread, drop teleports, and settings.

var _passed := 0
var _failed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 0
	print("GODOT ", Engine.get_version_info())
	_test_clip_state()
	_test_spread()
	_test_ads_fov()
	_test_settings()
	await _test_arena()
	print("FT1_TESTS passed=%d failed=%d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_clip_state() -> void:
	var clip := ClipState.new()
	_expect(clip.state == ClipState.State.READY, "clip starts READY")
	_expect(clip.status_text() == "CLIP READY", "status READY text")
	clip.note_floor(false)
	_expect(clip.state == ClipState.State.READY, "spawn grace stays READY before first floor contact")
	clip.note_floor(true)
	_expect(clip.state == ClipState.State.READY, "standing on the drop stays READY")
	clip.note_floor(false)
	_expect(clip.state == ClipState.State.AIRBORNE, "leaving the floor starts AIRBORNE")
	_expect(clip.status_text() == "IN THE AIR", "status air text")
	_expect(clip.can_fire(), "airborne can fire")
	_expect(clip.register_shot(), "airborne shot counts")
	_expect(clip.register_target_hit(false), "first target hit counts")
	_expect(not clip.register_target_hit(true), "repeat target hit does not count")
	_expect(clip.hits == 1 and clip.shots == 1, "airborne counts are 1 and 1")
	clip.note_floor(true)
	_expect(clip.state == ClipState.State.LANDED, "touching floor ends the clip")
	_expect(clip.status_text() == "CLIP OVER", "status landed text")
	clip.note_floor(false)
	clip.note_floor(true)
	_expect(clip.state == ClipState.State.LANDED, "jumping after landing does not start a new clip")
	_expect(not clip.can_fire(), "landed cannot fire")
	_expect(not clip.register_shot(), "landed shot is rejected")
	_expect(not clip.register_target_hit(false), "landed hit is rejected")
	_expect(clip.hits == 1 and clip.shots == 1, "landed counts stay frozen")
	clip.reset_clip(3)
	_expect(clip.state == ClipState.State.READY, "teleport returns to READY")
	_expect(clip.hits == 0 and clip.shots == 0, "teleport clears hits and shots")
	_expect(clip.active_drop == 3, "teleport sets the active drop")
	_expect(clip.drop_label() == "DROP 3 TOWER 24M", "drop 3 label")
	clip.reset_clip(1)
	_expect(clip.drop_label() == "DROP 1 CATWALK 6M", "drop 1 label")
	clip.reset_clip(2)
	_expect(clip.drop_label() == "DROP 2 ATRIUM 14M", "drop 2 label")
	clip.reset_clip(4)
	_expect(clip.drop_label() == "DROP 4 CRANE 38M", "drop 4 label")
	# Same-platform jump: READY, touch floor, leave, land again.
	var same := ClipState.new()
	same.note_floor(true)
	same.note_floor(false)
	same.note_floor(true)
	_expect(same.state == ClipState.State.LANDED, "jump off a drop and back lands the clip")


func _test_spread() -> void:
	_expect(is_zero_approx(PlayerController.SPREAD), "spread == 0.0")
	_expect(is_equal_approx(PlayerController.FIRE_RANGE_M, 200.0), "range is 200m")
	_expect(is_equal_approx(PlayerController.FIRE_INTERVAL_S, 0.70), "fire interval is 0.70s")
	_expect(is_equal_approx(PlayerController.WALK_SPEED, 6.0), "walk speed is 6")
	_expect(is_equal_approx(PlayerController.JUMP_VELOCITY, 6.0), "jump velocity is 6")
	var forward := Vector3(0.2, -0.45, -1.0)
	var first := PlayerController.shot_direction(forward)
	var second := PlayerController.shot_direction(forward)
	_expect(first.is_equal_approx(second), "shot direction has no random spread")
	_expect(first.is_equal_approx(forward.normalized()), "shot direction is the camera forward")
	var axis := PlayerController.shot_direction(Vector3(0, 0, -1))
	_expect(axis.is_equal_approx(Vector3(0, 0, -1)), "forward axis is unchanged")


func _test_ads_fov() -> void:
	_expect(is_equal_approx(PlayerController.ads_fov_for(90.0), 36.0), "ADS fov at 90 is 36")
	_expect(is_equal_approx(PlayerController.ads_fov_for(70.0), 30.0), "ADS fov floors at 30")
	_expect(is_equal_approx(PlayerController.ads_fov_for(120.0), 48.0), "ADS fov at 120 is 48")


func _test_settings() -> void:
	var settings := root.get_node("UserSettings")
	var dir := DirAccess.open("user://")
	if dir.file_exists("ft1_test_settings.cfg"):
		dir.remove("ft1_test_settings.cfg")
	settings.save_path = "user://ft1_test_settings.cfg"
	settings.set_mouse_sensitivity(1.25)
	settings.set_ads_sensitivity_multiplier(0.55)
	settings.set_fov(105.0)
	settings.mouse_sensitivity = 0.05
	settings.ads_sensitivity_multiplier = 0.2
	settings.fov = 70.0
	settings.load_settings()
	_expect(is_equal_approx(settings.mouse_sensitivity, 1.25), "settings load sensitivity")
	_expect(is_equal_approx(settings.ads_sensitivity_multiplier, 0.55), "settings load ADS multiplier")
	_expect(is_equal_approx(settings.fov, 105.0), "settings load fov")
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "mouse_sensitivity", 9.0)
	cfg.set_value("settings", "ads_sensitivity_multiplier", -2.0)
	cfg.set_value("settings", "fov", 12.0)
	cfg.save("user://ft1_test_settings.cfg")
	settings.load_settings()
	_expect(is_equal_approx(settings.mouse_sensitivity, 2.5), "sensitivity clamps to 2.5")
	_expect(is_equal_approx(settings.ads_sensitivity_multiplier, 0.20), "ADS multiplier clamps to 0.20")
	_expect(is_equal_approx(settings.fov, 70.0), "fov clamps to 70")
	settings.save_path = "user://ft1_missing.cfg"
	var kept: float = float(settings.fov)
	settings.load_settings()
	_expect(is_equal_approx(float(settings.fov), kept), "missing settings file keeps current values")
	settings.save_path = "user://settings.cfg"
	settings.restore_defaults()
	_expect(is_equal_approx(settings.mouse_sensitivity, 0.20), "defaults restore sensitivity 0.20")
	_expect(is_equal_approx(settings.ads_sensitivity_multiplier, 0.80), "defaults restore ADS 0.80")
	_expect(is_equal_approx(settings.fov, 90.0), "defaults restore fov 90")
	if dir.file_exists("ft1_test_settings.cfg"):
		dir.remove("ft1_test_settings.cfg")


func _test_arena() -> void:
	var packed := load("res://scenes/test_arena.tscn") as PackedScene
	var arena := packed.instantiate()
	root.add_child(arena)
	for _i in 5:
		await physics_frame
	var player := arena.get_node("Player") as PlayerController
	var hud := arena.get_node("HUD") as FirstTryHud
	_expect(player != null and hud != null, "arena has player and HUD")

	var floor_box := arena.get_node("ArenaGeometry/CourtyardFloor") as CSGBox3D
	_expect(floor_box.size.is_equal_approx(Vector3(50, 1, 50)), "courtyard floor is 50 x 1 x 50")
	_expect(is_equal_approx(floor_box.position.y + floor_box.size.y * 0.5, 0.0), "floor top is Y=0")
	var crane := arena.get_node("ArenaGeometry/CraneBoom") as CSGBox3D
	_expect(is_equal_approx(crane.size.z, 1.5), "crane beam is 1.5m wide")
	_expect(is_equal_approx(crane.position.y + crane.size.y * 0.5, 38.0), "crane top is Y=38")
	var catwalk := arena.get_node("ArenaGeometry/Drop1Catwalk") as CSGBox3D
	_expect(is_equal_approx(catwalk.position.y + catwalk.size.y * 0.5, 6.0), "catwalk top is Y=6")
	var atrium := arena.get_node("ArenaGeometry/Drop2Atrium") as CSGBox3D
	_expect(is_equal_approx(atrium.position.y + atrium.size.y * 0.5, 14.0), "atrium top is Y=14")
	var tower := arena.get_node("ArenaGeometry/Drop3Platform") as CSGBox3D
	_expect(is_equal_approx(tower.position.y + tower.size.y * 0.5, 24.0), "radio tower top is Y=24")
	var other := arena.get_node("ArenaGeometry/Drop3BPlatform") as CSGBox3D
	_expect(is_equal_approx(other.position.y + other.size.y * 0.5, 22.0), "opposing tower top is Y=22")
	var separation := Vector2(tower.position.x, tower.position.z).distance_to(Vector2(other.position.x, other.position.z))
	_expect(absf(separation - 14.0) < 0.05, "opposing tower is 14m away (%.3f)" % separation)

	var heights: Array[float] = [6.0, 14.0, 24.0, 38.0]
	for index in 4:
		var marker := arena.get_node("DropPoints/Spawn_%d" % (index + 1)) as Marker3D
		print("SPAWN_%d pos=%s" % [index + 1, marker.global_position])
		_expect(is_equal_approx(marker.global_position.y, heights[index]), "Spawn_%d Y is %.0f" % [index + 1, heights[index]])

	await _until_grounded(player)
	_expect(FileAccess.file_exists("res://assets/weapons/FirstTry_Intervention_Sniper.glb"), "intervention glb is in the project")
	var camera := player.get_node("CameraPivot/Camera3D") as Camera3D
	var rifle := camera.get_node_or_null("Rifle") as Node3D
	_expect(rifle != null, "Camera3D has a Rifle child")
	var sniper_mesh: MeshInstance3D = null
	if rifle != null:
		sniper_mesh = rifle.find_child("FirstTry_SniperRifle", true, false) as MeshInstance3D
	_expect(sniper_mesh != null, "Rifle has a FirstTry_SniperRifle mesh")
	var csg_leftover := false
	for node in camera.find_children("*", "", true, false):
		if node is CSGCombiner3D:
			csg_leftover = true
		if node is CSGBox3D and node.name in ["Receiver", "Barrel", "Stock", "Scope"]:
			csg_leftover = true
	_expect(not csg_leftover, "no CSG placeholder rifle under the camera")
	_expect(player.is_on_floor(), "player starts on the catwalk")
	_expect(player.get_clip().state == ClipState.State.READY, "boot clip is READY")
	_expect(player.get_clip().active_drop == 1, "boot drop is 1")
	var spawn1 := arena.get_node("DropPoints/Spawn_1") as Marker3D
	_expect(player.global_position.distance_to(spawn1.global_position) < 0.3, "player stands on Spawn_1")

	var target1 := arena.get_node("Targets/Target_1") as TargetDummy
	player.aim_at_world(target1.aim_point())
	_expect(player.fire_sniper(), "first shot fires")
	_expect(target1.is_down(), "pinpoint shot hits target 1 (%s)" % player.last_collider_name)
	_expect(player.clip_hits() == 1 and player.clip_shots() == 1, "hit and shot counters move")
	_expect(not player.fire_sniper(), "second shot is inside the 0.70s bolt time")
	_expect(player.clip_shots() == 1, "blocked shot does not count")

	var target5 := arena.get_node("Targets/Target_5") as TargetDummy
	player.aim_at_world(target5.aim_point())
	# Cooldown is still running from the hit. Step physics until it clears.
	for _i in 50:
		await physics_frame
	player.aim_at_world(target5.aim_point())
	_expect(player.fire_sniper(), "cover test shot fires")
	_expect(not target5.is_down(), "amber cover blocks target 5 (%s)" % player.last_collider_name)
	_expect(player.last_collider_name == "ArenaGeometry", "cover shot hits arena geometry")

	player.global_position = Vector3(13.2, 0.05, 10.8)
	player.velocity = Vector3.ZERO
	player.aim_at_world(target5.aim_point())
	player.force_update_transform()
	# The cover shot spent the bolt. Wait, then shoot from the side without a teleport
	# so the target stays in the blocked state until this shot.
	for _i in 50:
		await physics_frame
	# Waiting on the moved body may have landed the clip. Reset and place again.
	player.teleport_to_drop(1)
	await _until_grounded(player)
	_expect(not target5.is_down(), "teleport restores target 5")
	_expect(player.clip_hits() == 0 and player.clip_shots() == 0, "teleport clears counters")
	_expect(player.velocity.length() < 0.05, "teleport zeroes velocity")
	player.global_position = Vector3(13.2, 0.05, 10.8)
	player.velocity = Vector3.ZERO
	player.aim_at_world(target5.aim_point())
	player.force_update_transform()
	var side_hit := player.fire_sniper()
	_expect(side_hit and target5.is_down(), "walking around cover hits target 5 (%s)" % player.last_collider_name)

	for drop in [2, 3, 4]:
		player.teleport_to_drop(drop)
		await _until_grounded(player)
		var marker := arena.get_node("DropPoints/Spawn_%d" % drop) as Marker3D
		_expect(player.get_clip().state == ClipState.State.READY, "drop %d starts READY" % drop)
		_expect(player.get_clip().active_drop == drop, "drop %d is active" % drop)
		_expect(player.velocity.length() < 0.08, "drop %d velocity is zero" % drop)
		_expect(player.global_position.distance_to(marker.global_position) < 0.35, "drop %d stands on its marker" % drop)
		_expect(is_equal_approx(player.global_position.y, marker.global_position.y) or absf(player.global_position.y - marker.global_position.y) < 0.2, "drop %d feet are on the platform" % drop)

	player.teleport_to_drop(4)
	var active_before := player.get_clip().active_drop
	player.teleport_to_drop(player.get_clip().active_drop)
	_expect(player.get_clip().active_drop == active_before, "R reset keeps the active drop")
	_expect(player.get_clip().state == ClipState.State.READY, "R reset is READY")

	var settings := root.get_node("UserSettings")
	settings.set_fov(110.0)
	_expect(is_equal_approx(player.camera_fov(), 110.0), "FOV slider applies live")
	Input.action_press("ads")
	# process_frame is emitted before _process, so wait two frames for ADS to apply.
	await process_frame
	await process_frame
	_expect(player.is_ads(), "ADS is held")
	_expect(is_equal_approx(player.camera_fov(), 44.0), "ADS fov is max(30, base * 0.40)")
	_expect(rifle != null and not rifle.visible, "ADS hides the rifle")
	Input.action_release("ads")
	await process_frame
	await process_frame
	_expect(not player.is_ads(), "ADS released")
	_expect(is_equal_approx(player.camera_fov(), 110.0), "releasing ADS restores hip fov")
	_expect(rifle != null and rifle.visible, "releasing ADS shows the rifle")
	settings.restore_defaults()
	await process_frame
	_expect(is_equal_approx(player.camera_fov(), 90.0), "default fov returns to 90")
	player.set_ads_held(true)
	_expect(rifle != null and not rifle.visible, "set_ads_held hides the rifle")
	_expect(is_equal_approx(player.camera_fov(), PlayerController.ads_fov_for(90.0)), "set_ads_held fov is ads_fov_for")
	player.set_ads_held(false)
	_expect(rifle != null and rifle.visible, "set_ads_held release shows the rifle")
	_expect(is_equal_approx(player.camera_fov(), 90.0), "set_ads_held release restores hip fov")

	hud.set_paused(true)
	_expect(self.paused, "settings pause the world")
	_expect(not player.fire_sniper(), "paused player cannot fire")
	hud.set_paused(false)
	_expect(not self.paused, "resume unpauses the world")

	for drop in [1, 2, 3, 4]:
		var seconds := await _measure_fall(player, drop)
		print("FALL_%d seconds=%.3f pos=%s on_floor=%s state=%s" % [
			drop,
			seconds,
			player.global_position,
			player.is_on_floor(),
			player.get_clip().state,
		])
		_expect(seconds > 0.4 and seconds < 6.0, "drop %d fall time is a real courtyard fall (%.3f)" % [drop, seconds])
		_expect(player.get_clip().state == ClipState.State.LANDED, "drop %d ends LANDED" % drop)
		_expect(player.global_position.y < 1.5, "drop %d lands on the courtyard" % drop)
		if drop == 1:
			var frozen_hits := player.clip_hits()
			var frozen_shots := player.clip_shots()
			_expect(not player.fire_sniper(), "landed sniper does not fire")
			_expect(player.clip_hits() == frozen_hits and player.clip_shots() == frozen_shots, "landed counts stay frozen")
			Input.action_press("jump")
			for _i in 25:
				await physics_frame
			Input.action_release("jump")
			_expect(player.get_clip().state == ClipState.State.LANDED, "courtyard jump does not start a new clip")

	Input.action_release("move_forward")
	Input.action_release("jump")
	Input.action_release("ads")
	arena.queue_free()


func _measure_fall(player: PlayerController, drop: int) -> float:
	Input.action_release("move_forward")
	player.teleport_to_drop(drop)
	await _until_grounded(player)
	if player.get_clip().state != ClipState.State.READY or not player.is_on_floor():
		return -2.0
	Input.action_press("move_forward")
	var elapsed := 0.0
	var left_at := -1.0
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	for _i in 60 * 12:
		await physics_frame
		elapsed += step
		var state := player.get_clip().state
		if left_at < 0.0 and state == ClipState.State.AIRBORNE:
			left_at = elapsed
			if drop == 1:
				var target := player.get_parent().get_node("Targets/Target_1") as TargetDummy
				player.aim_at_world(target.aim_point())
				player.fire_sniper()
			Input.action_release("move_forward")
		if left_at >= 0.0 and state == ClipState.State.LANDED:
			Input.action_release("move_forward")
			return elapsed - left_at
	Input.action_release("move_forward")
	return -3.0


func _until_grounded(player: PlayerController) -> void:
	for _i in 40:
		if player.is_on_floor() and player.get_clip().state == ClipState.State.READY:
			return
		await physics_frame


func _expect(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS ", label)
	else:
		_failed += 1
		print("FAIL ", label)
