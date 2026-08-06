# Unit Tests for master-plan weapon drive modes.
extends Node

const WeaponDefinitionScript = preload("res://weapons/definitions/weapon_definition.gd")
const GripDefinitionScript = preload("res://weapons/grips/grip_definition.gd")
const WeaponPoseProfileScript = preload("res://weapons/poses/weapon_pose_profile.gd")
const WeaponDriveResolverScript = preload("res://weapons/drive_modes/weapon_drive_resolver.gd")
const WeaponDrivePluginScript = preload("res://weapons/drive_modes/weapon_drive_plugin.gd")
const RigSchemaScript = preload("res://rigging/bones/rig_schema.gd")
const BoneSchemaScript = preload("res://rigging/bones/bone_schema.gd")


func run_tests() -> int:
	var passes := 0
	passes += test_primary_hand_drive_mode()
	passes += test_controller_drive_mode()
	passes += test_body_socket_drive_mode()
	passes += test_path_drive_mode_and_serialization()
	passes += test_world_drive_mode()
	passes += test_custom_drive_mode()
	return passes


func test_primary_hand_drive_mode() -> int:
	var weapon = _make_weapon()
	var profile := WeaponPoseProfileScript.new("pose_driven", "Driven Rifle")
	profile.weapon_id = weapon.weapon_id
	profile.primary_grip_id = "primary"
	profile.drive_mode = profile.DriveMode.PRIMARY_HAND
	profile.drive_settings = {"position_offset": Vector2(2.0, 1.0), "rotation_offset": 0.0}
	profile.set_hand_binding({"grip_id": "primary", "hand_bone_id": "hand_r"})
	var driven: Dictionary = WeaponDriveResolverScript.resolve(profile, weapon, _make_arm_rig())
	var missing: Dictionary = WeaponDriveResolverScript.resolve(profile, weapon, {"bones": {}})
	if driven.get("success", false) and driven.get("drive_mode", "") == "primary_hand" and driven.get("position", Vector2.ZERO).is_equal_approx(Vector2(72.0, 1.0)) and not missing.get("success", true):
		print("  PASS: WPN-008 primary-hand drive derives weapon transform from bound hand")
		return 1
	printerr("  FAIL: WPN-008 primary-hand drive failed: %s" % str(driven))
	return 0


func test_controller_drive_mode() -> int:
	var profile := WeaponPoseProfileScript.new("pose_controller", "Controller Rifle")
	profile.weapon_id = "rifle"
	profile.drive_mode = profile.DriveMode.CONTROLLER
	profile.drive_settings = {"position_offset": Vector2(4.0, 0.0), "rotation_offset": 0.2}
	var driven: Dictionary = WeaponDriveResolverScript.resolve(profile, _make_weapon(), {}, "", "", "", {"controller_position": Vector2(10.0, 5.0), "controller_rotation": PI * 0.5})
	var missing: Dictionary = WeaponDriveResolverScript.resolve(profile, _make_weapon(), {})
	if driven.get("success", false) and driven.get("drive_mode", "") == "controller" and driven.get("position", Vector2.ZERO).is_equal_approx(Vector2(10.0, 9.0)) and is_equal_approx(float(driven.get("rotation", 0.0)), PI * 0.5 + 0.2) and not missing.get("success", true):
		print("  PASS: WPN-009 controller drive resolves context transform and offsets")
		return 1
	printerr("  FAIL: WPN-009 controller drive failed: %s" % str(driven))
	return 0


func test_body_socket_drive_mode() -> int:
	var profile := WeaponPoseProfileScript.new("pose_socket", "Holstered Rifle")
	profile.weapon_id = "rifle"
	profile.drive_mode = profile.DriveMode.BODY_SOCKET
	profile.drive_settings = {"socket_bone_id": "root", "socket_position": Vector2(3.0, 2.0), "position_offset": Vector2(2.0, 0.0)}
	var driven: Dictionary = WeaponDriveResolverScript.resolve(profile, _make_weapon(), _make_arm_rig())
	var invalid := WeaponPoseProfileScript.new("invalid_socket", "Invalid Socket")
	invalid.weapon_id = "rifle"
	invalid.drive_mode = invalid.DriveMode.BODY_SOCKET
	if driven.get("success", false) and driven.get("drive_mode", "") == "body_socket" and driven.get("position", Vector2.ZERO).is_equal_approx(Vector2(5.0, 2.0)) and not invalid.validate().is_empty():
		print("  PASS: WPN-010 body-socket drive follows an authored body-bone socket")
		return 1
	printerr("  FAIL: WPN-010 body-socket drive failed: %s" % str(driven))
	return 0


func test_path_drive_mode_and_serialization() -> int:
	var profile := WeaponPoseProfileScript.new("pose_path", "Whip Path")
	profile.weapon_id = "rifle"
	profile.drive_mode = profile.DriveMode.PATH
	profile.drive_settings = {"path_points": [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0)], "path_progress": 0.75}
	var restored := WeaponPoseProfileScript.new().from_dict(profile.to_dict())
	var driven: Dictionary = WeaponDriveResolverScript.resolve(restored, _make_weapon(), {})
	if driven.get("success", false) and driven.get("drive_mode", "") == "path" and driven.get("position", Vector2.ZERO).is_equal_approx(Vector2(10.0, 5.0)) and is_equal_approx(float(driven.get("rotation", 0.0)), PI * 0.5):
		print("  PASS: WPN-011 path drive serializes and follows a tangent-oriented flexible path")
		return 1
	printerr("  FAIL: WPN-011 path drive failed: %s" % str(driven))
	return 0


func test_world_drive_mode() -> int:
	var profile := WeaponPoseProfileScript.new("pose_world", "Floating Rifle")
	profile.weapon_id = "rifle"
	profile.drive_mode = profile.DriveMode.WORLD
	profile.drive_settings = {"position_offset": Vector2(2.0, 0.0), "rotation_offset": 0.1}
	var driven: Dictionary = WeaponDriveResolverScript.resolve(profile, _make_weapon(), {}, "", "", "", {"world_position": Vector2(4.0, 6.0), "world_rotation": PI * 0.5})
	var missing: Dictionary = WeaponDriveResolverScript.resolve(profile, _make_weapon(), {})
	if driven.get("success", false) and driven.get("drive_mode", "") == "world" and driven.get("position", Vector2.ZERO).is_equal_approx(Vector2(4.0, 8.0)) and is_equal_approx(float(driven.get("rotation", 0.0)), PI * 0.5 + 0.1) and not missing.get("success", true):
		print("  PASS: WPN-012 world drive anchors a floating weapon with local offsets")
		return 1
	printerr("  FAIL: WPN-012 world drive failed: %s" % str(driven))
	return 0


func test_custom_drive_mode() -> int:
	var profile := WeaponPoseProfileScript.new("pose_custom", "Plugin Rifle")
	profile.weapon_id = "rifle"
	profile.drive_mode = profile.DriveMode.CUSTOM
	profile.drive_settings = {"plugin_id": "orbit"}
	var plugin := WeaponDrivePluginScript.new("orbit", func(_profile, _weapon, _rig, _context): return {"success": true, "position": Vector2(9.0, 3.0), "rotation": 0.25})
	var driven: Dictionary = WeaponDriveResolverScript.resolve(profile, _make_weapon(), {}, "", "", "", {"custom_drive_plugins": {"orbit": plugin}})
	if driven.get("success", false) and driven.get("drive_mode", "") == "custom" and driven.get("position", Vector2.ZERO).is_equal_approx(Vector2(9.0, 3.0)) and is_equal_approx(float(driven.get("rotation", 0.0)), 0.25):
		print("  PASS: WPN-013 custom plugin drive resolves through its registered interface")
		return 1
	printerr("  FAIL: WPN-013 custom plugin drive failed: %s" % str(driven))
	return 0


func _make_weapon():
	var weapon := WeaponDefinitionScript.new("rifle", "Training Rifle")
	weapon.asset_id = "asset_rifle"
	weapon.interaction_family_id = "rifle"
	var primary := GripDefinitionScript.new("primary", "Trigger Grip", GripDefinitionScript.Role.PRIMARY)
	weapon.add_grip(primary)
	return weapon


func _make_arm_rig() -> Dictionary:
	var rig := RigSchemaScript.create_empty_rig("arm", "Arm Test Rig")
	var root := BoneSchemaScript.create_default_bone("root", "Root")
	var upper := BoneSchemaScript.create_default_bone("upper_r", "Upper Arm", "root")
	upper["length"] = 40.0
	var lower := BoneSchemaScript.create_default_bone("lower_r", "Lower Arm", "upper_r")
	lower["length"] = 30.0
	lower["local_position"] = Vector2(40.0, 0.0)
	var hand := BoneSchemaScript.create_default_bone("hand_r", "Hand", "lower_r")
	hand["local_position"] = Vector2(30.0, 0.0)
	rig["bones"] = {"root": root, "upper_r": upper, "lower_r": lower, "hand_r": hand}
	rig["root_bone_id"] = "root"
	return rig
