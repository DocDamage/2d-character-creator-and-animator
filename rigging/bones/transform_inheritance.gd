# TransformInheritance — Selective channel transform inheritance resolution
class_name TransformInheritance
extends RefCounted


static func compute_inherited_transform(p_parent_global: Transform2D, p_local_pos: Vector2, p_local_rot: float, p_local_scale: Vector2, p_inherit_pos: bool, p_inherit_rot: bool, p_inherit_scale: bool) -> Transform2D:
	var inherited_offset: Vector2 = p_parent_global.x * p_local_pos.x + p_parent_global.y * p_local_pos.y
	var final_origin: Vector2 = p_parent_global.origin + inherited_offset if p_inherit_pos else p_local_pos
	
	var parent_rot: float = p_parent_global.get_rotation()
	var final_rot: float = parent_rot + p_local_rot if p_inherit_rot else p_local_rot
	
	var parent_scale: Vector2 = p_parent_global.get_scale()
	var final_scale: Vector2 = Vector2(parent_scale.x * p_local_scale.x, parent_scale.y * p_local_scale.y) if p_inherit_scale else p_local_scale
	
	return Transform2D(final_rot, final_scale, 0.0, final_origin)


static func set_inheritance_flags(p_rig: Dictionary, p_bone_id: String, p_pos: bool, p_rot: bool, p_scale: bool) -> void:
	var bones: Dictionary = p_rig.get("bones", {})
	if bones.has(p_bone_id):
		var bone: Dictionary = bones[p_bone_id]
		bone["inherit_position"] = p_pos
		bone["inherit_rotation"] = p_rot
		bone["inherit_scale"] = p_scale
