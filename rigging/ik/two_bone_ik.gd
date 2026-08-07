# TwoBoneIK — Analytic 2-bone inverse kinematics solver using law of cosines
class_name TwoBoneIK
extends ConstraintInterface

var mid_bone_id: String = ""
var tip_bone_id: String = ""
var target_position: Vector2 = Vector2.ZERO
var bend_positive: bool = true
var use_pole_target: bool = false
var pole_target_position: Vector2 = Vector2.ZERO


func _init() -> void:
	type = ConstraintType.TWO_BONE_IK


func evaluate(p_rig: Dictionary, _delta: float) -> void:
	if not enabled or influence <= 0.0:
		return
	var bones: Dictionary = p_rig.get("bones", {})
	if not bones.has(owner_bone_id) or not bones.has(mid_bone_id) or not bones.has(tip_bone_id):
		return

	var bm := BoneManager.new()
	bm.initialize(p_rig)

	var root_global := bm.get_global_transform(owner_bone_id)
	var root_pos := root_global.origin
	var mid_bone: Dictionary = bones[mid_bone_id]
	var l1 := maxf(0.0, float((bones[owner_bone_id] as Dictionary).get("length", 0.0)))
	var l2 := maxf(0.0, float(mid_bone.get("length", 0.0)))
	if l1 <= 0.000001 or l2 <= 0.000001:
		return

	var target_delta := target_position - root_pos
	var target_direction := target_delta.angle() if target_delta.length_squared() > 0.000001 else root_global.get_rotation()
	var minimum_reach := absf(l1 - l2) + 0.0001
	var maximum_reach := maxf(minimum_reach, l1 + l2 - 0.0001)
	var target_distance := clampf(target_delta.length(), minimum_reach, maximum_reach)

	# Law of cosines.  The root needs a world-space angle, while the mid joint
	# needs an angle local to its parent (the solved root).  That distinction is
	# what keeps chains stable under a rotated character root.
	var cos_mid := (l1 * l1 + l2 * l2 - target_distance * target_distance) / (2.0 * l1 * l2)
	cos_mid = clampf(cos_mid, -1.0, 1.0)
	var angle_mid := acos(cos_mid)

	var cos_root := (l1 * l1 + target_distance * target_distance - l2 * l2) / (2.0 * l1 * target_distance)
	cos_root = clampf(cos_root, -1.0, 1.0)
	var angle_root := acos(cos_root)

	var bend_sign := 1.0 if bend_positive else -1.0
	if use_pole_target:
		bend_sign = 1.0 if PoleTargetSolver.solve_pole_direction(root_pos, target_position, pole_target_position) else -1.0
	var final_root_global_rotation := target_direction + angle_root * bend_sign
	var final_root_local_rotation := bm.get_local_rotation_for_global(owner_bone_id, final_root_global_rotation)
	var final_mid_global_rotation := final_root_global_rotation + (PI - angle_mid) * bend_sign
	var mid_parent_global_rotation := final_root_global_rotation if str(mid_bone.get("parent_id", "")) == owner_bone_id else bm.get_parent_global_transform(mid_bone_id).get_rotation()
	var final_mid_local_rotation := final_mid_global_rotation - mid_parent_global_rotation if bool(mid_bone.get("inherit_rotation", true)) else final_mid_global_rotation

	var root_bone: Dictionary = bones[owner_bone_id]
	var current_root_rot: float = root_bone.get("local_rotation", 0.0)
	var current_mid_rot: float = mid_bone.get("local_rotation", 0.0)
	var weight := clampf(influence, 0.0, 1.0)
	root_bone["local_rotation"] = lerp_angle(current_root_rot, final_root_local_rotation, weight)
	mid_bone["local_rotation"] = lerp_angle(current_mid_rot, final_mid_local_rotation, weight)
	bones[owner_bone_id] = root_bone
	bones[mid_bone_id] = mid_bone
	p_rig["bones"] = bones
