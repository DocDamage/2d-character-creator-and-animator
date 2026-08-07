# HierarchyOperations — Bone reparenting with world-transform lock, sibling reordering, and cloning
class_name HierarchyOperations
extends RefCounted


static func reparent_bone(p_rig: Dictionary, p_bone_id: String, p_new_parent_id: String, p_keep_world_transform: bool = true) -> bool:
	var bones: Dictionary = p_rig.get("bones", {})
	if not bones.has(p_bone_id):
		return false
	if not p_new_parent_id.is_empty() and not bones.has(p_new_parent_id):
		return false
	if p_bone_id == p_new_parent_id:
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
		var old_parent: Dictionary = bones[old_parent_id]
		old_parent["children"] = p_children
		bones[old_parent_id] = old_parent
		
	bone["parent_id"] = p_new_parent_id
	bones[p_bone_id] = bone
	if not p_new_parent_id.is_empty():
		var n_children: Array = bones[p_new_parent_id].get("children", [])
		if not n_children.has(p_bone_id):
			n_children.append(p_bone_id)
		var new_parent: Dictionary = bones[p_new_parent_id]
		new_parent["children"] = n_children
		bones[p_new_parent_id] = new_parent
	p_rig["bones"] = bones

	if p_keep_world_transform:
		bm.set_global_transform(p_bone_id, old_global_tf)
	if p_new_parent_id.is_empty():
		p_rig["root_bone_id"] = p_bone_id
	elif str(p_rig.get("root_bone_id", "")) == p_bone_id:
		p_rig["root_bone_id"] = _root_ancestor_id(bones, p_new_parent_id)
		
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
	var visited: Dictionary = {}
	while not curr_id.is_empty() and bones.has(curr_id):
		if visited.has(curr_id): return true
		visited[curr_id] = true
		var parent_id: String = bones[curr_id].get("parent_id", "")
		if parent_id == p_possible_ancestor_id:
			return true
		curr_id = parent_id
	return false


static func _root_ancestor_id(bones: Dictionary, bone_id: String) -> String:
	var current := bone_id
	var visited: Dictionary = {}
	while bones.has(current) and not visited.has(current):
		visited[current] = true
		var parent_id := str((bones[current] as Dictionary).get("parent_id", ""))
		if parent_id.is_empty() or not bones.has(parent_id): return current
		current = parent_id
	return current
