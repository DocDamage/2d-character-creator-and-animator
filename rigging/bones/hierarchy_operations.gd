# HierarchyOperations — Bone reparenting with world-transform lock, sibling reordering, and cloning
class_name HierarchyOperations
extends RefCounted


static func reparent_bone(p_rig: Dictionary, p_bone_id: String, p_new_parent_id: String, p_keep_world_transform: bool = true) -> bool:
	var bones: Dictionary = p_rig.get("bones", {})
	if not bones.has(p_bone_id):
		return false
	if not p_new_parent_id.is_empty() and not bones.has(p_new_parent_id):
		return false
	if is_ancestor_of(p_rig, p_bone_id, p_new_parent_id):
		return false # Prevent circular cycle
		
	var bm := BoneManager.new()
	bm.initialize(p_rig)
	var old_global_tf := bm.get_global_transform(p_bone_id)
	
	var bone: Dictionary = bones[p_bone_id]
	var old_parent_id: String = bone.get("parent_id", "")
	if not old_parent_id.is_empty() and bones.has(old_parent_id):
		var p_children: Array = bones[old_parent_id].get("children", [])
		p_children.erase(p_bone_id)
		
	bone["parent_id"] = p_new_parent_id
	if not p_new_parent_id.is_empty():
		var n_children: Array = bones[p_new_parent_id].get("children", [])
		if not n_children.has(p_bone_id):
			n_children.append(p_bone_id)
			
	if p_keep_world_transform:
		var new_parent_global := bm.get_global_transform(p_new_parent_id) if not p_new_parent_id.is_empty() else Transform2D.IDENTITY
		var new_local_tf := new_parent_global.affine_inverse() * old_global_tf
		bone["local_position"] = new_local_tf.origin
		bone["local_rotation"] = new_local_tf.get_rotation()
		bone["local_scale"] = new_local_tf.get_scale()
		
	return true


static func reorder_child(p_rig: Dictionary, p_parent_id: String, p_bone_id: String, p_new_index: int) -> bool:
	var bones: Dictionary = p_rig.get("bones", {})
	if p_parent_id.is_empty():
		return false
	if not bones.has(p_parent_id):
		return false
		
	var children: Array = bones[p_parent_id].get("children", [])
	if not children.has(p_bone_id):
		return false
		
	children.erase(p_bone_id)
	var target_idx := clampi(p_new_index, 0, children.size())
	children.insert(target_idx, p_bone_id)
	return true


static func is_ancestor_of(p_rig: Dictionary, p_possible_ancestor_id: String, p_bone_id: String) -> bool:
	var bones: Dictionary = p_rig.get("bones", {})
	if p_possible_ancestor_id.is_empty() or p_bone_id.is_empty():
		return false
	var curr_id := p_bone_id
	while not curr_id.is_empty() and bones.has(curr_id):
		var parent_id: String = bones[curr_id].get("parent_id", "")
		if parent_id == p_possible_ancestor_id:
			return true
		curr_id = parent_id
	return false
