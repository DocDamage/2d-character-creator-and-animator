# TransformConstraint — Position, rotation, scale, and copy transform constraints
class_name TransformConstraint
extends ConstraintInterface

var copy_position: bool = true
var copy_rotation: bool = true
var copy_scale: bool = true


func _init() -> void:
	type = ConstraintType.TRANSFORM


func evaluate(p_rig: Dictionary, _delta: float) -> void:
	var bones: Dictionary = p_rig.get("bones", {})
	if not bones.has(owner_bone_id) or not bones.has(target_bone_id):
		return
		
	var owner_bone: Dictionary = bones[owner_bone_id]
	var target_bone: Dictionary = bones[target_bone_id]
	
	if copy_position:
		var target_pos: Vector2 = target_bone.get("local_position", Vector2.ZERO)
		var current_pos: Vector2 = owner_bone.get("local_position", Vector2.ZERO)
		owner_bone["local_position"] = current_pos.lerp(target_pos, influence)
		
	if copy_rotation:
		var target_rot: float = target_bone.get("local_rotation", 0.0)
		var current_rot: float = owner_bone.get("local_rotation", 0.0)
		owner_bone["local_rotation"] = lerp_angle(current_rot, target_rot, influence)
		
	if copy_scale:
		var target_scale: Vector2 = target_bone.get("local_scale", Vector2.ONE)
		var current_scale: Vector2 = owner_bone.get("local_scale", Vector2.ONE)
		owner_bone["local_scale"] = current_scale.lerp(target_scale, influence)
