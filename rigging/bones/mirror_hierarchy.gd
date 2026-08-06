# MirrorHierarchy — Automated left/right bone hierarchy mirroring and symmetry creation
class_name MirrorHierarchy
extends RefCounted


static func mirror_bone_tree(p_rig: Dictionary, p_source_bone_id: String, p_axis_x: float = 0.0) -> Dictionary:
	var bones: Dictionary = p_rig.get("bones", {})
	if not bones.has(p_source_bone_id):
		return {}
		
	var id_map := {}
	_mirror_recursive(p_rig, p_source_bone_id, "", p_axis_x, id_map)
	return id_map


static func _mirror_recursive(p_rig: Dictionary, p_bone_id: String, p_new_parent_id: String, p_axis_x: float, p_id_map: Dictionary) -> String:
	var bones: Dictionary = p_rig.get("bones", {})
	var src_bone: Dictionary = bones[p_bone_id]
	
	var src_name: String = src_bone.get("name", p_bone_id)
	var new_name := mirror_name(src_name)
	var new_id := "bone_m_%d" % [bones.size() + 1]
	
	var mirrored_pos: Vector2 = src_bone.get("local_position", Vector2.ZERO)
	mirrored_pos.x = -mirrored_pos.x
	
	var mirrored_rot: float = -src_bone.get("local_rotation", 0.0)
	var mirrored_rest_angle: float = -src_bone.get("rest_angle", 0.0)
	
	var new_bone := BoneSchema.create_default_bone(new_id, new_name, p_new_parent_id)
	new_bone["length"] = src_bone.get("length", 50.0)
	new_bone["rest_angle"] = mirrored_rest_angle
	new_bone["local_position"] = mirrored_pos
	new_bone["local_rotation"] = mirrored_rot
	new_bone["color"] = Color(1.0, 0.4, 0.4)
	
	bones[new_id] = new_bone
	p_id_map[p_bone_id] = new_id
	
	if not p_new_parent_id.is_empty() and bones.has(p_new_parent_id):
		var p_children: Array = bones[p_new_parent_id].get("children", [])
		if not p_children.has(new_id):
			p_children.append(new_id)
			
	var children: Array = src_bone.get("children", []).duplicate()
	for child_id in children:
		_mirror_recursive(p_rig, child_id, new_id, p_axis_x, p_id_map)
		
	return new_id


static func mirror_name(p_name: String) -> String:
	if p_name.ends_with("_l") or p_name.ends_with("_L"):
		return p_name.left(p_name.length() - 2) + "_r"
	elif p_name.ends_with("_r") or p_name.ends_with("_R"):
		return p_name.left(p_name.length() - 2) + "_l"
	elif p_name.begins_with("left_"):
		return "right_" + p_name.substr(5)
	elif p_name.begins_with("right_"):
		return "left_" + p_name.substr(6)
	return p_name + "_mirrored"
