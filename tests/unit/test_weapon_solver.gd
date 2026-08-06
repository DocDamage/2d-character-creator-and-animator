# Unit Tests for master-plan arm and hand solver behavior.
extends Node

const WeaponDefinitionScript = preload("res://weapons/definitions/weapon_definition.gd")
const GripDefinitionScript = preload("res://weapons/grips/grip_definition.gd")
const WeaponPoseProfileScript = preload("res://weapons/poses/weapon_pose_profile.gd")
const WeaponPoseSolverScript = preload("res://weapons/solver/weapon_pose_solver.gd")
const RigSchemaScript = preload("res://rigging/bones/rig_schema.gd")
const BoneSchemaScript = preload("res://rigging/bones/bone_schema.gd")
const BoneManagerScript = preload("res://rigging/bones/bone_manager.gd")


func run_tests() -> int:
	var passes := 0
	passes += test_shoulder_allowance_and_reach_diagnostics()
	passes += test_pole_and_wrist_policies()
	passes += test_joint_limits_pixel_mode_and_gap_recovery()
	passes += test_dual_grip_overlays_and_instrumentation()
	passes += test_body_direction_targets_and_refinement()
	return passes


func test_shoulder_allowance_and_reach_diagnostics() -> int:
	var rig := _make_rig()
	var binding := _binding()
	binding["shoulder_allowance"] = 15.0
	var solved := WeaponPoseSolverScript.solve_arm_to_target(rig, binding, {"position": Vector2(80.0, 0.0), "rotation": 0.0})
	var before := float(rig["bones"]["upper_r"].get("local_rotation", 0.0))
	var failed := WeaponPoseSolverScript.solve_arm_to_target(rig, binding, {"position": Vector2(100.0, 0.0), "rotation": 0.0})
	var unchanged := is_equal_approx(before, float(rig["bones"]["upper_r"].get("local_rotation", 0.0)))
	if solved.get("success", false) and is_equal_approx(float(solved.get("shoulder_shift", 0.0)), 10.0) and not failed.get("success", true) and str(failed.get("diagnostics", [{}])[0].get("code", "")) == "UNREACHABLE_GRIP" and unchanged:
		print("  PASS: SOL-001/SOL-008/SOL-012 shoulder allowance reaches safely and failures retain the pose")
		return 1
	printerr("  FAIL: SOL shoulder/reach diagnostics failed: %s" % str(failed))
	return 0


func test_pole_and_wrist_policies() -> int:
	var pole_binding := _binding()
	pole_binding["pole_position"] = Vector2(20.0, -20.0)
	var pole_result := WeaponPoseSolverScript.solve_arm_to_target(_make_rig(), pole_binding, {"position": Vector2(50.0, 20.0), "rotation": 0.0})
	var wrist_rig := _make_rig()
	var wrist_binding := _binding()
	wrist_binding["wrist_mode"] = "preserve"
	var wrist_result := WeaponPoseSolverScript.solve_arm_to_target(wrist_rig, wrist_binding, {"position": Vector2(50.0, 20.0), "rotation": 1.1})
	var manager := BoneManagerScript.new()
	manager.initialize(wrist_rig)
	var preserved_rotation := manager.get_global_transform("hand_r").get_rotation()
	if pole_result.get("success", false) and float(pole_result.get("bend_sign", 0.0)) == -1.0 and wrist_result.get("success", false) and is_equal_approx(preserved_rotation, 0.0):
		print("  PASS: SOL-002/SOL-003/SOL-004 arm targets support pole and wrist policies")
		return 1
	printerr("  FAIL: SOL pole or wrist policy failed: %s / %s" % [str(pole_result), str(wrist_result)])
	return 0


func test_joint_limits_pixel_mode_and_gap_recovery() -> int:
	var limited_binding := _binding()
	limited_binding["joint_limits"] = {"upper": [0.0, 0.0]}
	var limited := WeaponPoseSolverScript.solve_arm_to_target(_make_rig(), limited_binding, {"position": Vector2(30.0, 40.0), "rotation": 0.0})
	var pixel_rig := _make_rig()
	var pixel_binding := _binding()
	pixel_binding["pixel_mode"] = true
	pixel_binding["pixel_angle_step"] = PI * 0.25
	var pixel := WeaponPoseSolverScript.solve_arm_to_target(pixel_rig, pixel_binding, {"position": Vector2(70.0, 0.0), "rotation": 0.0})
	var rotations_ok := _is_quantized(float(pixel_rig["bones"]["upper_r"]["local_rotation"]), PI * 0.25) and _is_quantized(float(pixel_rig["bones"]["lower_r"]["local_rotation"]), PI * 0.25) and _is_quantized(float(pixel_rig["bones"]["hand_r"]["local_rotation"]), PI * 0.25)
	if not limited.get("success", true) and "upper" in limited.get("limited_joints", []) and str(limited.get("diagnostics", [{}])[-1].get("code", "")) == "GRIP_GAP" and pixel.get("success", false) and rotations_ok:
		print("  PASS: SOL-006/SOL-007/SOL-009 limits expose gaps and pixel mode quantizes rotations")
		return 1
	printerr("  FAIL: SOL limits, pixel mode, or gap recovery failed: %s / %s" % [str(limited), str(pixel)])
	return 0


func test_dual_grip_overlays_and_instrumentation() -> int:
	var profile := WeaponPoseProfileScript.new("dual", "Dual Grip")
	profile.weapon_id = "rifle"
	profile.base_position = Vector2(30.0, 0.0)
	profile.set_hand_binding(_binding("primary", "upper_r", "lower_r", "hand_r"))
	profile.set_hand_binding(_binding("secondary", "upper_l", "lower_l", "hand_l"))
	var result := WeaponPoseSolverScript.solve_pose(_make_rig(true), _make_weapon(), profile)
	var metrics: Dictionary = result.get("instrumentation", {})
	var overlays: Array = result.get("overlays", [])
	if result.get("success", false) and result.get("mode", "") == "dual_grip" and int(metrics.get("arm_count", 0)) == 2 and int(metrics.get("reachable_count", 0)) == 2 and overlays.size() == 2 and overlays[0].get("segments", []).size() == 2:
		print("  PASS: SOL-005/SOL-010/SOL-011 dual grips emit overlays and instrumentation")
		return 1
	printerr("  FAIL: SOL dual grip overlays or instrumentation failed: %s" % str(result))
	return 0


func test_body_direction_targets_and_refinement() -> int:
	var profile := WeaponPoseProfileScript.new("offsets", "Offsets")
	profile.weapon_id = "rifle"
	profile.base_position = Vector2(10.0, 0.0)
	profile.body_type_offsets["tall"] = {"position": Vector2(5.0, 0.0), "rotation": 0.0}
	profile.direction_offsets["east"] = {"position": Vector2(0.0, 10.0), "rotation": 0.0}
	var target := WeaponPoseSolverScript.resolve_grip_target(_make_weapon(), profile, "primary", "tall", "east")
	var result := WeaponPoseSolverScript.solve_arm_to_target(_make_rig(), _binding(), target)
	if target.get("position", Vector2.ZERO).is_equal_approx(Vector2(15.0, 10.0)) and result.get("success", false) and float(result.get("grip_gap", 1.0)) <= 0.05:
		print("  PASS: SOL-013/SOL-014/SOL-015 body-direction targets refine to a bounded grip gap")
		return 1
	printerr("  FAIL: SOL target compensation or refinement failed: %s" % str(result))
	return 0


func _binding(grip_id: String = "primary", upper: String = "upper_r", lower: String = "lower_r", hand: String = "hand_r") -> Dictionary:
	return {"grip_id": grip_id, "upper_bone_id": upper, "lower_bone_id": lower, "hand_bone_id": hand, "bend_sign": 1.0}


func _make_weapon():
	var weapon := WeaponDefinitionScript.new("rifle", "Training Rifle")
	weapon.asset_id = "asset_rifle"
	weapon.interaction_family_id = "rifle"
	weapon.add_grip(GripDefinitionScript.new("primary", "Primary", GripDefinitionScript.Role.PRIMARY))
	var secondary := GripDefinitionScript.new("secondary", "Secondary", GripDefinitionScript.Role.SECONDARY)
	secondary.local_position = Vector2(20.0, 0.0)
	weapon.add_grip(secondary)
	return weapon


func _make_rig(include_left: bool = false) -> Dictionary:
	var rig := RigSchemaScript.create_empty_rig("solver", "Solver Rig")
	var root := BoneSchemaScript.create_default_bone("root", "Root")
	var upper := BoneSchemaScript.create_default_bone("upper_r", "Upper R", "root")
	upper["length"] = 40.0
	var lower := BoneSchemaScript.create_default_bone("lower_r", "Lower R", "upper_r")
	lower["length"] = 30.0
	lower["local_position"] = Vector2(40.0, 0.0)
	var hand := BoneSchemaScript.create_default_bone("hand_r", "Hand R", "lower_r")
	hand["local_position"] = Vector2(30.0, 0.0)
	rig["bones"] = {"root": root, "upper_r": upper, "lower_r": lower, "hand_r": hand}
	if include_left:
		var left_upper := BoneSchemaScript.create_default_bone("upper_l", "Upper L", "root")
		left_upper["length"] = 40.0
		var left_lower := BoneSchemaScript.create_default_bone("lower_l", "Lower L", "upper_l")
		left_lower["length"] = 30.0
		left_lower["local_position"] = Vector2(40.0, 0.0)
		var left_hand := BoneSchemaScript.create_default_bone("hand_l", "Hand L", "lower_l")
		left_hand["local_position"] = Vector2(30.0, 0.0)
		rig["bones"].merge({"upper_l": left_upper, "lower_l": left_lower, "hand_l": left_hand})
	rig["root_bone_id"] = "root"
	return rig


func _is_quantized(value: float, step: float) -> bool:
	return is_equal_approx(value, snappedf(value, step))
