# Independent-style numerical acceptance matrix for Phase 2 weapon workflows.
extends Node

const WeaponDefinitionScript = preload("res://weapons/definitions/weapon_definition.gd")
const GripDefinitionScript = preload("res://weapons/grips/grip_definition.gd")
const WeaponPoseProfileScript = preload("res://weapons/poses/weapon_pose_profile.gd")
const WeaponDriveResolverScript = preload("res://weapons/drive_modes/weapon_drive_resolver.gd")
const WeaponDrivePluginScript = preload("res://weapons/drive_modes/weapon_drive_plugin.gd")
const WeaponPoseSolverScript = preload("res://weapons/solver/weapon_pose_solver.gd")
const WizardModelScript = preload("res://weapons/authoring/weapon_authoring_wizard_model.gd")
const RuntimePackageScript = preload("res://export/project_format/runtime_package.gd")
const RuntimeExporterScript = preload("res://export/project_format/runtime_package_exporter.gd")
const GodotExporterScript = preload("res://export/godot/godot_resource_exporter.gd")
const RigSchemaScript = preload("res://rigging/bones/rig_schema.gd")
const BoneSchemaScript = preload("res://rigging/bones/bone_schema.gd")


func run_tests() -> int:
	var serialized_weapons: Array = []
	var serialized_profiles: Array = []
	var failures: Array = []
	for index in range(20):
		var entry: Dictionary = _make_entry(index)
		var weapon = entry.weapon
		var profile = entry.profile
		var restored_weapon := WeaponDefinitionScript.new().from_dict(weapon.to_dict())
		var restored_profile := WeaponPoseProfileScript.new().from_dict(profile.to_dict())
		var drive := WeaponDriveResolverScript.resolve(restored_profile, restored_weapon, _rig(), "tall", "north", "draw", _drive_context(index))
		var solver := WeaponPoseSolverScript.solve_pose(_rig(), restored_weapon, restored_profile, null, "tall", "north", "draw")
		var wizard := WizardModelScript.new()
		wizard.bind_context(restored_weapon, restored_profile, _rig())
		wizard.set_coverage_dimensions(["tall", "medium"], ["north", "east"])
		var coverage := wizard.evaluate_coverage()
		if not _entry_passes(drive, solver, coverage):
			failures.append({"weapon_id": weapon.weapon_id, "drive": drive, "solver": solver, "coverage": coverage})
		serialized_weapons.append(weapon.to_dict())
		serialized_profiles.append(profile.to_dict())
	var exported := _export_matrix(serialized_weapons, serialized_profiles)
	if failures.is_empty() and exported.get("success", false):
		print("  PASS: QA-WPN-001/QA-SOL-001/QA-WPA-001 twenty weapons resolve, solve, cover, and export")
		return 1
	printerr("  FAIL: Phase 2 weapon acceptance matrix failed: failures=%s export=%s" % [str(failures), str(exported)])
	return 0


func _make_entry(index: int) -> Dictionary:
	var weapon := WeaponDefinitionScript.new("matrix_%02d" % index, "Matrix Weapon %02d" % index)
	weapon.asset_id = "asset_matrix_%02d" % index
	weapon.interaction_family_id = "matrix"
	weapon.supported_body_types = ["tall", "medium"]
	weapon.add_grip(GripDefinitionScript.new("primary", "Primary", GripDefinitionScript.Role.PRIMARY))
	var secondary := GripDefinitionScript.new("secondary", "Secondary", GripDefinitionScript.Role.SECONDARY)
	secondary.local_position = Vector2(12.0 + float(index % 4) * 2.0, 0.0)
	weapon.add_grip(secondary)
	var profile := WeaponPoseProfileScript.new("matrix_pose_%02d" % index, "Matrix Pose %02d" % index)
	profile.weapon_id = weapon.weapon_id
	profile.base_position = Vector2(18.0 + float(index % 5) * 3.0, float(index % 3) * 2.0)
	profile.direction_offsets["east"] = {"position": Vector2(1.0, 0.0), "rotation": 0.0}
	profile.animation_offsets["draw"] = {"position": Vector2.ZERO, "rotation": 0.0}
	profile.primary_grip_id = "primary"
	profile.set_hand_binding(_binding("primary", "upper_r", "lower_r", "hand_r"))
	profile.set_hand_binding(_binding("secondary", "upper_l", "lower_l", "hand_l"))
	_match_drive(index % 7, profile)
	return {"weapon": weapon, "profile": profile}


func _match_drive(mode: int, profile) -> void:
	profile.drive_mode = mode as WeaponPoseProfile.DriveMode
	match mode:
		1: profile.drive_settings = {"position_offset": Vector2.ZERO}
		2: profile.drive_settings = {"position_offset": Vector2.ZERO}
		3: profile.drive_settings = {"socket_bone_id": "root", "socket_position": Vector2(2.0, 0.0)}
		4: profile.drive_settings = {"path_points": [Vector2.ZERO, Vector2(10.0, 0.0)], "path_progress": 0.5}
		5: profile.drive_settings = {"position_offset": Vector2.ZERO}
		6: profile.drive_settings = {"plugin_id": "matrix_plugin"}


func _drive_context(index: int) -> Dictionary:
	match index % 7:
		2: return {"controller_position": Vector2(4.0, 3.0), "controller_rotation": 0.0}
		5: return {"world_position": Vector2(6.0, 2.0), "world_rotation": 0.0}
		6: return {"custom_drive_plugins": {"matrix_plugin": WeaponDrivePluginScript.new("matrix_plugin", func(_profile, _weapon, _rig, _context): return {"success": true, "position": Vector2(5.0, 5.0), "rotation": 0.0})}}
	return {}


func _entry_passes(drive: Dictionary, solver: Dictionary, coverage: Dictionary) -> bool:
	if not drive.get("success", false) or not solver.get("success", false) or not coverage.get("success", false):
		return false
	for arm in solver.get("arms", []):
		if float(arm.get("grip_gap", 1.0)) > 0.05 or not (arm.get("limited_joints", []) as Array).is_empty():
			return false
	for cell in coverage.get("cells", []):
		if not bool(cell.get("success", false)):
			return false
	return true


func _export_matrix(weapons: Array, profiles: Array) -> Dictionary:
	var root := "user://phase2_weapon_matrix_%d" % Time.get_ticks_usec()
	var package := RuntimePackageScript.create({"project_id": "phase2_matrix", "weapons": weapons, "weapon_pose_profiles": profiles}, {"matrix_count": weapons.size()})
	var package_path := root.path_join("matrix.chrpack")
	var saved := RuntimeExporterScript.new().export_project(package.get("content", {}) as Dictionary, package_path, package.get("metadata", {}) as Dictionary)
	var loaded := RuntimePackageScript.load(package_path)
	var native := GodotExporterScript.new().export_package(package, root.path_join("godot"), "matrix")
	var resource := load(root.path_join("godot/matrix.tres")) as Resource
	var scene := load(root.path_join("godot/matrix.tscn")) as PackedScene
	var instance := scene.instantiate() if scene != null else null
	var content: Dictionary = loaded.get("package", {}).get("content", {}) if loaded.get("package", {}) is Dictionary else {}
	var valid := bool(saved.get("success", false)) and bool(loaded.get("success", false)) and bool(native.get("success", false)) and resource != null and instance != null and (content.get("weapons", []) as Array).size() == 20 and (content.get("weapon_pose_profiles", []) as Array).size() == 20
	if instance != null:
		instance.free()
	return {"success": valid, "package": package_path, "native": native}


func _binding(grip_id: String, upper: String, lower: String, hand: String) -> Dictionary:
	return {"grip_id": grip_id, "upper_bone_id": upper, "lower_bone_id": lower, "hand_bone_id": hand, "bend_sign": 1.0}


func _rig() -> Dictionary:
	var rig := RigSchemaScript.create_empty_rig("matrix_rig", "Matrix Rig")
	rig["bones"] = {"root": BoneSchemaScript.create_default_bone("root", "Root")}
	for side in ["r", "l"]:
		var upper := BoneSchemaScript.create_default_bone("upper_" + side, "Upper", "root")
		upper["length"] = 40.0
		var lower := BoneSchemaScript.create_default_bone("lower_" + side, "Lower", "upper_" + side)
		lower["length"] = 30.0
		lower["local_position"] = Vector2(40.0, 0.0)
		var hand := BoneSchemaScript.create_default_bone("hand_" + side, "Hand", "lower_" + side)
		hand["local_position"] = Vector2(30.0, 0.0)
		rig["bones"].merge({"upper_" + side: upper, "lower_" + side: lower, "hand_" + side: hand})
	rig["root_bone_id"] = "root"
	return rig
