class_name TargetDummy
extends StaticBody3D

const COLOR_UP := Color("#F43F5E")
const COLOR_DOWN := Color("#4C0519")

var _down := false
var _flash := 0.0
var _mat: StandardMaterial3D
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("targets")
	_mesh = get_node("Mesh") as MeshInstance3D
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR_UP
	_mat.roughness = 0.72
	_mesh.material_override = _mat


func aim_point() -> Vector3:
	return global_position


func is_down() -> bool:
	return _down


func mark_hit() -> bool:
	if _down:
		return false
	_down = true
	_mat.albedo_color = COLOR_DOWN
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.45, 0.55)
	_mat.emission_energy_multiplier = 1.6
	_mesh.rotation = Vector3(0.0, 0.0, deg_to_rad(76.0))
	_flash = 0.12
	return true


func restore() -> void:
	_down = false
	_flash = 0.0
	_mesh.rotation = Vector3.ZERO
	_mat.albedo_color = COLOR_UP
	_mat.emission_enabled = false


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	if _flash <= 0.0 and _down:
		_mat.emission_enabled = false
