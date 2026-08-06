# TwoBoneIK — Analytic 2-bone inverse kinematics solver using law of cosines
class_name TwoBoneIK
extends ConstraintInterface

var mid_bone_id: String = ""
var tip_bone_id: String = ""
var target_position: Vector2 = Vector2.ZERO
var bend_positive: bool = true


func _init() -> void:
	type = ConstraintType.TWO_BONE_IK


func evaluate(p_rig: Dictionary, _delta: float) -> void:
	var bones: Dictionary = p_rig.get("bones", {})
	if not bones.has(owner_bone_id) or not bones.has(mid_bone_id) or not bones.has(tip_bone_id):
		return
		
	var bm := BoneManager.new()
	bm.initialize(p_rig)
	
	var root_global := bm.get_global_transform(owner_bone_id)
	var root_pos := root_global.origin
	var mid_bone: Dictionary = bones[mid_bone_id]
	var tip_bone: Dictionary = bones[tip_bone_id]
	
	var l1: float = bones[owner_bone_id].get("length", 50.0)
	var l2: float = mid_bone.get("length", 50.0)
	
	var target_dist := root_pos.distance_to(target_position)
	target_dist = clampf(target_dist, 0.001, l1 + l2 - 0.001)
	
	# Law of Cosines
	var cos_mid := (l1 * l1 + l2 * l2 - target_dist * target_dist) / (2.0 * l1 * l2)
	cos_mid = clampf(cos_mid, -1.0, 1.0)
	var angle_mid := acos(cos_mid)
	
	var cos_root := (l1 * l1 + target_dist * target_dist - l2 * l2) / (2.0 * l1 * target_dist)
	cos_root = clampf(cos_root, -1.0, 1.0)
	var angle_root := acos(cos_root)
	
	var target_dir := (target_position - root_pos).angle()
	var bend_sign := 1.0 if bend_positive else -1.0
	
	var final_root_rot := target_dir + (angle_root * bend_sign)
	var final_mid_rot := (PI - angle_mid) * bend_sign
	
	var root_bone: Dictionary = bones[owner_bone_id]
	var current_root_rot: float = root_bone.get("local_rotation", 0.0)
	var current_mid_rot: float = mid_bone.get("local_rotation", 0.0)
	
	root_bone["local_rotation"] = lerp_angle(current_root_rot, final_root_rot, influence)
	mid_bone["local_rotation"] = lerp_angle(current_mid_rot, final_mid_rot, influence)
