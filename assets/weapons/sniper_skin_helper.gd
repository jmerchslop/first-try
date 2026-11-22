# Drop `FirstTry_Intervention_Sniper.glb` into `res://assets/weapons/` in Godot 4.
# It already conforms to the 3-Material-Slot Weapon Skin spec from `03_TEST_ARENA_AND_CEL_SHADED_ART.md`:
#   - Surface 0 (`Slot0_ReceiverCamo`): Main receiver, tactical stock, handguard, pistol grip
#   - Surface 1 (`Slot1_BarrelScopeTrim`): Fluted barrel, 3-baffle muzzle brake, scope, bolt, magazine, bipod, carry handle
#   - Surface 2 (`Slot2_ScopeLens`): Ocular & objective lenses (emissive cyan)
#
# Orientation: Barrel points along -Z (Godot's native forward vector), centered at the receiver
# so rotating around (0, 0, 0) pivots cleanly for Weapon Inspect, Y-Y swaps, and ADS interpolation.

extends Node3D

@onready var sniper_mesh: MeshInstance3D = $FirstTry_SniperRifle

func apply_cel_shaded_skin(camo_texture: Texture2D = null, primary_tint: Color = Color(0.25, 0.28, 0.35), accent_tint: Color = Color(0.1, 0.11, 0.14)) -> void:
	if not sniper_mesh:
		return

	# Shared ink outline pass
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = Color(0.05, 0.05, 0.08)
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.008 # Fine viewmodel ink line

	# Surface 0: Primary Camo / Skin
	var mat_body := StandardMaterial3D.new()
	mat_body.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat_body.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat_body.roughness = 0.85
	mat_body.albedo_color = primary_tint
	if camo_texture:
		mat_body.albedo_texture = camo_texture
	mat_body.next_pass = outline
	sniper_mesh.set_surface_override_material(0, mat_body)

	# Surface 1: Barrel, Scope & Trim
	var mat_trim := StandardMaterial3D.new()
	mat_trim.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat_trim.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat_trim.metallic = 0.6
	mat_trim.roughness = 0.45
	mat_trim.albedo_color = accent_tint
	mat_trim.next_pass = outline
	sniper_mesh.set_surface_override_material(1, mat_trim)
