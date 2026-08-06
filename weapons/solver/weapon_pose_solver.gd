# WeaponPoseSolver -- Analytic arm alignment with reach, limits, and diagnostics.
class_name WeaponPoseSolver
extends RefCounted

const EPSILON := 0.001
const GRIP_TOLERANCE := 0.05


static func resolve_grip_target(weapon, profile, grip_id: String, body_type_id: String = "", direction_id: String = "", animation_id: String = "") -> Dictionary:
	if weapon == null or profile == null:
		return {}
	var grip = weapon.get_grip(grip_id)
	if grip == null:
		return {}
	var weapon_transform: Dictionary = profile.resolve_transform(body_type_id, direction_id, animation_id)
	var local_transform: Dictionary = grip.resolve_transform(body_type_id)
	var weapon_rotation := float(weapon_transform.get("rotation", 0.0))
	return {"position": _as_vector2(weapon_transform.get("position", Vector2.ZERO)) + _as_vector2(local_transform.get("position", Vector2.ZERO)).rotated(weapon_rotation), "rotation": weapon_rotation + float(local_transform.get("rotation", 0.0)), "grip": grip}


static func solve_pose(rig: Dictionary, weapon, profile, hand_pose_library = null, body_type_id: String = "", direction_id: String = "", animation_id: String = "", influence: float = 1.0, options: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "arms": [], "errors": [], "diagnostics": [], "overlays": []}
	if weapon == null or profile == null:
		return _fail_result(result, "Weapon and pose profile are required")
	if not weapon.is_compatible_with_body_type(body_type_id):
		return _fail_result(result, "Weapon '%s' is incompatible with body type '%s'" % [weapon.weapon_id, body_type_id])
	var bindings: Array = profile.hand_bindings.duplicate(true)
	bindings.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("grip_id", "")) < str(b.get("grip_id", "")))
	var used_hands: Dictionary = {}
	for binding in bindings:
		var hand_id := str(binding.get("hand_bone_id", ""))
		if used_hands.has(hand_id):
			result["success"] = false
			result["errors"].append("Multiple grips bind to hand bone '%s'." % hand_id)
			continue
		used_hands[hand_id] = true
		var target := resolve_grip_target(weapon, profile, str(binding.get("grip_id", "")), body_type_id, direction_id, animation_id)
		if target.is_empty():
			result["success"] = false
			result["errors"].append("Missing grip for hand binding")
			continue
		var hand_pose = _resolve_hand_pose(hand_pose_library, binding, target.get("grip"))
		var arm_result := solve_arm_to_target(rig, binding, target, hand_pose, influence, options)
		result["arms"].append(arm_result)
		result["diagnostics"].append_array(arm_result.get("diagnostics", []))
		result["overlays"].append(WeaponSolverOverlayModel.build(arm_result))
		if not arm_result.get("success", false):
			result["success"] = false
			result["errors"].append_array(arm_result.get("errors", []))
	result["mode"] = "dual_grip" if result["arms"].size() > 1 else "single_grip"
	result["instrumentation"] = WeaponSolverInstrumentation.summarize(result["arms"])
	return result


static func solve_arm_to_target(rig: Dictionary, binding: Dictionary, target: Dictionary, hand_pose = null, influence: float = 1.0, options: Dictionary = {}) -> Dictionary:
	var target_position := _as_vector2(target.get("position", Vector2.ZERO))
	var result := {"success": false, "reachable": false, "errors": [], "diagnostics": [], "target": target_position, "limited_joints": []}
	var upper_id := str(binding.get("upper_bone_id", ""))
	var lower_id := str(binding.get("lower_bone_id", ""))
	var hand_id := str(binding.get("hand_bone_id", ""))
	var bones: Dictionary = rig.get("bones", {})
	if upper_id.is_empty() or lower_id.is_empty() or hand_id.is_empty():
		return _fail_arm(result, "INVALID_BINDING", "Hand binding requires upper_bone_id, lower_bone_id, and hand_bone_id")
	if not bones.has(upper_id) or not bones.has(lower_id) or not bones.has(hand_id):
		return _fail_arm(result, "MISSING_ARM_BONE", "Hand binding references a missing arm bone")
	var manager := BoneManager.new()
	manager.initialize(rig)
	var upper: Dictionary = bones[upper_id]
	var lower: Dictionary = bones[lower_id]
	var hand: Dictionary = bones[hand_id]
	var shoulder := manager.get_global_transform(upper_id).origin
	var upper_length := float(upper.get("length", 0.0))
	var lower_length := float(lower.get("length", 0.0))
	var allowance := float(binding.get("shoulder_allowance", options.get("shoulder_allowance", 0.0)))
	var reach := WeaponArmReachability.evaluate(shoulder, target_position, upper_length, lower_length, allowance)
	if not bool(reach.get("success", false)):
		result["reachable"] = false
		return _fail_arm(result, str(reach.get("code", "UNREACHABLE_GRIP")), str(reach.get("message", "Grip is unreachable.")), reach)
	var shoulder_shift := float(reach.get("shoulder_shift", 0.0))
	if shoulder_shift > EPSILON:
		var direction := (target_position - shoulder).normalized()
		var parent_transform := manager.get_global_transform(str(upper.get("parent_id", "")))
		upper["local_position"] = parent_transform.affine_inverse() * (shoulder + direction * shoulder_shift)
		shoulder = manager.get_global_transform(upper_id).origin
	result["shoulder"] = shoulder
	result["shoulder_shift"] = shoulder_shift
	var to_target := target_position - shoulder
	var distance := clampf(to_target.length(), EPSILON, upper_length + lower_length - EPSILON)
	var target_direction := to_target.angle() if to_target.length() > EPSILON else manager.get_global_transform(upper_id).get_rotation()
	var bend_sign := _bend_sign(binding, shoulder, target_position)
	var shoulder_angle := acos(clampf((upper_length * upper_length + distance * distance - lower_length * lower_length) / (2.0 * upper_length * distance), -1.0, 1.0))
	var elbow_angle := acos(clampf((upper_length * upper_length + lower_length * lower_length - distance * distance) / (2.0 * upper_length * lower_length), -1.0, 1.0))
	var desired_upper_global := target_direction - shoulder_angle * bend_sign
	var desired_lower_local := (PI - elbow_angle) * bend_sign
	var desired_hand_global := _desired_hand_rotation(manager, hand, target, hand_pose, binding)
	var desired_upper_local := desired_upper_global - _parent_global_rotation(manager, upper)
	var desired_hand_local := desired_hand_global - desired_upper_global - desired_lower_local
	var desired := {"upper": desired_upper_local, "lower": desired_lower_local, "hand": desired_hand_local}
	var limited := _limit_and_quantize(desired, binding, options)
	for joint in limited.get("limited_joints", []):
		result["limited_joints"].append(joint)
		_add_diagnostic(result, "JOINT_LIMIT", "Joint '%s' was clamped to its authored range." % joint, "warning")
	var blend := clampf(influence, 0.0, 1.0)
	upper["local_rotation"] = lerp_angle(float(upper.get("local_rotation", 0.0)), float(limited["upper"]), blend)
	lower["local_rotation"] = lerp_angle(float(lower.get("local_rotation", 0.0)), float(limited["lower"]), blend)
	hand["local_rotation"] = lerp_angle(float(hand.get("local_rotation", 0.0)), float(limited["hand"]), blend)
	_apply_hand_pose_offsets(bones, hand_pose, blend)
	var elbow := manager.get_global_transform(lower_id).origin
	var solved_hand := manager.get_global_transform(hand_id).origin
	var grip_gap := solved_hand.distance_to(target_position)
	result.merge({"success": grip_gap <= GRIP_TOLERANCE, "reachable": true, "distance": float(reach["distance"]), "max_reach": float(reach["max_reach"]), "grip_gap": grip_gap, "shoulder": shoulder, "elbow": elbow, "hand": solved_hand, "bend_sign": bend_sign}, true)
	if grip_gap > GRIP_TOLERANCE:
		return _fail_arm(result, "GRIP_GAP", "Solved hand is %.3f units from the required grip." % grip_gap)
	return result


static func _bend_sign(binding: Dictionary, shoulder: Vector2, target: Vector2) -> float:
	if binding.has("pole_position"):
		return 1.0 if PoleTargetSolver.solve_pole_direction(shoulder, target, _as_vector2(binding["pole_position"])) else -1.0
	var bend_sign := float(binding.get("bend_sign", 1.0))
	return 1.0 if is_zero_approx(bend_sign) else signf(bend_sign)


static func _desired_hand_rotation(manager: BoneManager, hand: Dictionary, target: Dictionary, hand_pose, binding: Dictionary) -> float:
	var desired := float(target.get("rotation", 0.0))
	if str(binding.get("wrist_mode", "match_grip")) == "preserve":
		desired = manager.get_global_transform(str(hand.get("id", ""))).get_rotation()
	if hand_pose != null:
		desired += float(hand_pose.wrist_rotation_offset)
	return desired


static func _limit_and_quantize(desired: Dictionary, binding: Dictionary, options: Dictionary) -> Dictionary:
	var result := desired.duplicate(true)
	result["limited_joints"] = []
	var limits: Dictionary = binding.get("joint_limits", options.get("joint_limits", {}))
	for joint in ["upper", "lower", "hand"]:
		var limited := WeaponSolverJointLimits.clamp_rotation(float(result[joint]), limits, joint)
		result[joint] = float(limited["value"])
		if bool(limited.get("limited", false)):
			result["limited_joints"].append(joint)
	if bool(binding.get("pixel_mode", options.get("pixel_mode", false))):
		var step := maxf(EPSILON, float(binding.get("pixel_angle_step", options.get("pixel_angle_step", PI / 180.0))))
		for joint in ["upper", "lower", "hand"]:
			result[joint] = snappedf(float(result[joint]), step)
	return result


static func _resolve_hand_pose(hand_pose_library, binding: Dictionary, grip):
	if hand_pose_library == null:
		return null
	var pose_id := str(binding.get("hand_pose_id", grip.hand_pose_id if grip != null else ""))
	return hand_pose_library.get_pose(pose_id) if not pose_id.is_empty() else null


static func _parent_global_rotation(manager: BoneManager, bone: Dictionary) -> float:
	var parent_id := str(bone.get("parent_id", ""))
	return manager.get_global_transform(parent_id).get_rotation() if not parent_id.is_empty() else 0.0


static func _apply_hand_pose_offsets(bones: Dictionary, hand_pose, blend: float) -> void:
	if hand_pose == null:
		return
	for bone_id in hand_pose.bone_rotation_offsets:
		if bones.has(bone_id):
			var bone: Dictionary = bones[bone_id]
			bone["local_rotation"] = lerp_angle(float(bone.get("local_rotation", 0.0)), float(hand_pose.bone_rotation_offsets[bone_id]), blend)


static func _fail_result(result: Dictionary, message: String) -> Dictionary:
	result["success"] = false
	result["errors"].append(message)
	return result


static func _fail_arm(result: Dictionary, code: String, message: String, details: Dictionary = {}) -> Dictionary:
	result["success"] = false
	result["errors"].append(message)
	_add_diagnostic(result, code, message, "error", details)
	return result


static func _add_diagnostic(result: Dictionary, code: String, message: String, severity: String, details: Dictionary = {}) -> void:
	result["diagnostics"].append({"code": code, "message": message, "severity": severity, "details": details.duplicate(true)})


static func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
