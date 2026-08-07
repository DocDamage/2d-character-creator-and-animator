# AimConstraint — Rotates owner bone to aim / look-at target bone position
class_name AimConstraint
extends ConstraintInterface

var aim_offset_angle: float = 0.0


func _init() -> void:
	type = ConstraintType.AIM


func evaluate(p_rig: Dictionary, _delta: float) -> void:
	if not enabled or influence <= 0.0:
		return
	var bones: Dictionary = p_rig.get("bones", {})
	if not bones.has(owner_bone_id) or not bones.has(target_bone_id):
		return
		
	var bm := BoneManager.new()
	bm.initialize(p_rig)
	
	var owner_global := bm.get_global_transform(owner_bone_id)
	var target_global := bm.get_global_transform(target_bone_id)
	
	var dir := target_global.origin - owner_global.origin
	if dir.length_squared() < 0.0001:
		return
		
	var target_angle := dir.angle() + aim_offset_angle
	var owner_bone: Dictionary = bones[owner_bone_id]
	var current_rot: float = owner_bone.get("local_rotation", 0.0)
	var target_local_rotation := bm.get_local_rotation_for_global(owner_bone_id, target_angle)
	owner_bone["local_rotation"] = lerp_angle(current_rot, target_local_rotation, clampf(influence, 0.0, 1.0))
	bones[owner_bone_id] = owner_bone
	p_rig["bones"] = bones
