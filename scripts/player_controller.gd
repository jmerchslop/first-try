class_name PlayerController
extends CharacterBody3D

## First-person body, pinpoint sniper, and drop teleports.

const WALK_SPEED := 6.0
const JUMP_VELOCITY := 6.0
const GROUND_ACCEL := 80.0
const AIR_ACCEL := 10.0
const EYE_HEIGHT := 1.6
const SPREAD := 0.0
const FIRE_RANGE_M := 200.0
const FIRE_INTERVAL_S := 0.70
const TRACER_SECONDS := 0.10
const VIEW_KICK_DEG := 2.0
const VIEW_KICK_RETURN_DEG := 18.0
const PITCH_LIMIT_DEG := 89.0
const WORLD_MASK := 1

var confirmed_hits_serial: int = 0
var last_collider_name: String = ""

var _clip := ClipState.new()
var _camera_pivot: Node3D
var _camera: Camera3D
var _tracer: MeshInstance3D
var _spawns: Array[Marker3D] = []
var _gravity: float = 9.8
var _pitch: float = 0.0
var _kick: float = 0.0
var _cooldown: float = 0.0
var _tracer_left: float = 0.0
var _ads: bool = false
var _booted: bool = false


static func shot_direction(forward: Vector3) -> Vector3:
	# Pinpoint: spread stays 0, so the ray is the camera forward with no random cone.
	if not is_zero_approx(SPREAD):
		push_error("fire_sniper spread must be 0.0")
	return forward.normalized()


static func ads_fov_for(base_fov: float) -> float:
	return maxf(30.0, base_fov * 0.40)


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = WORLD_MASK
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)
	_camera_pivot = get_node("CameraPivot") as Node3D
	_camera = get_node("CameraPivot/Camera3D") as Camera3D
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	_build_rifle()
	_build_tracer()
	FirstTrySettings.live.settings_changed.connect(_on_settings_changed)
	_on_settings_changed()


func boot() -> void:
	_cache_spawns()
	_booted = true
	teleport_to_drop(1)
	_capture_mouse()


func get_clip() -> ClipState:
	return _clip


func clip_status_text() -> String:
	return _clip.status_text()


func clip_hits() -> int:
	return _clip.hits


func clip_shots() -> int:
	return _clip.shots


func drop_label() -> String:
	return _clip.drop_label()


func is_clip_ready() -> bool:
	return _clip.state == ClipState.State.READY


func is_ads() -> bool:
	return _ads


func set_ads_held(held: bool) -> void:
	_ads = held
	_apply_fov()


func camera_fov() -> float:
	return _camera.fov


func teleport_to_drop(index: int) -> void:
	if index < 1 or index > _spawns.size():
		return
	var spawn := _spawns[index - 1]
	velocity = Vector3.ZERO
	global_transform = spawn.global_transform
	global_position = spawn.global_position + Vector3(0.0, 0.02, 0.0)
	velocity = Vector3.ZERO
	_pitch = 0.0
	_kick = 0.0
	_cooldown = 0.0
	_ads = false
	_tracer_left = 0.0
	_tracer.visible = false
	_clip.reset_clip(index)
	_restore_targets()
	_apply_camera_pose()
	_apply_fov()
	force_update_transform()


func aim_at_world(point: Vector3) -> void:
	var eye := global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var dir := point - eye
	var horizontal := Vector2(dir.x, dir.z).length()
	rotation.y = atan2(-dir.x, -dir.z)
	_pitch = clampf(atan2(dir.y, horizontal), deg_to_rad(-PITCH_LIMIT_DEG), deg_to_rad(PITCH_LIMIT_DEG))
	_kick = 0.0
	_apply_camera_pose()
	force_update_transform()


func aim_pitch_degrees(degrees: float) -> void:
	_pitch = clampf(deg_to_rad(degrees), deg_to_rad(-PITCH_LIMIT_DEG), deg_to_rad(PITCH_LIMIT_DEG))
	_kick = 0.0
	_apply_camera_pose()


func fire_sniper() -> bool:
	if not _booted or _camera == null:
		return false
	if get_tree() != null and get_tree().paused:
		return false
	if _cooldown > 0.0 or not _clip.can_fire():
		return false
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var direction := shot_direction(forward)
	var end := origin + direction * FIRE_RANGE_M
	_cooldown = FIRE_INTERVAL_S
	_clip.register_shot()
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = WORLD_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var tracer_end := end
	last_collider_name = ""
	if not hit.is_empty():
		tracer_end = hit.get("position") as Vector3
		var collider := hit.get("collider") as Object
		if collider is Node:
			last_collider_name = (collider as Node).name
		if collider is TargetDummy:
			var dummy := collider as TargetDummy
			var fresh := dummy.mark_hit()
			if _clip.register_target_hit(not fresh):
				confirmed_hits_serial += 1
	_show_tracer(origin, tracer_end)
	# Kick is applied after the ray so it cannot move the shot that just fired.
	_kick = deg_to_rad(VIEW_KICK_DEG)
	_apply_camera_pose()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _booted or get_tree().paused:
		return
	_refresh_ads()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := FirstTrySettings.live.mouse_sensitivity
		if _ads:
			sens *= FirstTrySettings.live.ads_sensitivity_multiplier
		rotate_y(deg_to_rad(-motion.relative.x * sens))
		_pitch = clampf(
			_pitch - deg_to_rad(motion.relative.y * sens),
			deg_to_rad(-PITCH_LIMIT_DEG),
			deg_to_rad(PITCH_LIMIT_DEG)
		)
		_apply_camera_pose()
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if event.is_action_pressed("drop_1"):
		teleport_to_drop(1)
	elif event.is_action_pressed("drop_2"):
		teleport_to_drop(2)
	elif event.is_action_pressed("drop_3"):
		teleport_to_drop(3)
	elif event.is_action_pressed("drop_4"):
		teleport_to_drop(4)
	elif event.is_action_pressed("reset_drop"):
		teleport_to_drop(_clip.active_drop)


func _process(_delta: float) -> void:
	if not _booted or get_tree().paused:
		return
	_refresh_ads()


func _physics_process(delta: float) -> void:
	if not _booted or get_tree().paused:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _kick > 0.0:
		_kick = move_toward(_kick, 0.0, deg_to_rad(VIEW_KICK_RETURN_DEG) * delta)
		_apply_camera_pose()
	if Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		fire_sniper()
	_apply_movement(delta)
	_clip.note_floor(is_on_floor())
	_update_tracer(delta)


func _apply_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	wish.y = 0.0
	if wish.length() > 0.001:
		wish = wish.normalized()
	if is_on_floor():
		var target := wish * WALK_SPEED
		velocity.x = move_toward(velocity.x, target.x, GROUND_ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, GROUND_ACCEL * delta)
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
		elif velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
		if wish.length() > 0.001:
			var target_air := wish * WALK_SPEED
			velocity.x = move_toward(velocity.x, target_air.x, AIR_ACCEL * delta)
			velocity.z = move_toward(velocity.z, target_air.z, AIR_ACCEL * delta)
	move_and_slide()


func _refresh_ads() -> void:
	var held := Input.is_action_pressed("ads") and not get_tree().paused
	if held == _ads:
		return
	_ads = held
	_apply_fov()


func _apply_fov() -> void:
	if _camera == null:
		return
	var base := FirstTrySettings.live.fov
	if _ads:
		_camera.fov = ads_fov_for(base)
	else:
		_camera.fov = base


func _apply_camera_pose() -> void:
	if _camera_pivot == null:
		return
	_camera_pivot.rotation.x = _pitch - _kick


func _on_settings_changed() -> void:
	_apply_fov()


func _cache_spawns() -> void:
	_spawns.clear()
	var points := get_parent().get_node("DropPoints") as Node3D
	for index in 4:
		_spawns.append(points.get_node("Spawn_%d" % (index + 1)) as Marker3D)


func _restore_targets() -> void:
	for node in get_tree().get_nodes_in_group("targets"):
		if node is TargetDummy:
			(node as TargetDummy).restore()


func _capture_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_tracer(from: Vector3, to: Vector3) -> void:
	var delta := to - from
	var full := delta.length()
	# Start ahead of the camera so the segment stays a thin line instead of filling the view.
	if full < 1.0:
		return
	var start := from + delta * (0.9 / full)
	var span := to - start
	var length := span.length()
	_tracer.visible = true
	_tracer.global_position = start + span * 0.5
	var dir := span / length
	if absf(dir.dot(Vector3.UP)) > 0.98:
		_tracer.look_at(to, Vector3.RIGHT)
	else:
		_tracer.look_at(to, Vector3.UP)
	_tracer.scale = Vector3(1.0, 1.0, length)
	_tracer_left = TRACER_SECONDS


func _update_tracer(delta: float) -> void:
	if _tracer_left <= 0.0:
		return
	_tracer_left -= delta
	if _tracer_left <= 0.0:
		_tracer.visible = false


func _build_tracer() -> void:
	_tracer = MeshInstance3D.new()
	_tracer.name = "Tracer"
	_tracer.top_level = true
	_tracer.visible = false
	_tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := BoxMesh.new()
	box.size = Vector3(0.025, 0.025, 1.0)
	_tracer.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#FDE68A")
	_tracer.material_override = mat
	add_child(_tracer)


func _build_rifle() -> void:
	var rifle := CSGCombiner3D.new()
	rifle.name = "Rifle"
	rifle.use_collision = false
	rifle.position = Vector3(0.26, -0.22, -0.42)
	_camera.add_child(rifle)
	var dark := _gun_mat(Color("#1F2937"), 0.45)
	var steel := _gun_mat(Color("#111827"), 0.35)
	_gun_box(rifle, "Receiver", Vector3(0.07, 0.1, 0.36), Vector3.ZERO, dark)
	_gun_box(rifle, "Barrel", Vector3(0.028, 0.028, 0.42), Vector3(0.0, 0.02, -0.36), steel)
	_gun_box(rifle, "Stock", Vector3(0.055, 0.09, 0.16), Vector3(0.0, 0.0, 0.24), dark)
	_gun_box(rifle, "Scope", Vector3(0.04, 0.046, 0.16), Vector3(0.0, 0.08, -0.02), steel)


func _gun_mat(color: Color, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.42
	mat.metallic = metallic
	return mat


func _gun_box(parent: Node, box_name: String, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = pos
	box.material = mat
	parent.add_child(box)
