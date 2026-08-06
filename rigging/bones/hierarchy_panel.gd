# HierarchyPanel — UI data representation model for skeletal bone and slot tree hierarchies
class_name HierarchyPanel
extends RefCounted

signal selection_changed(selected_ids: Array[String])
signal hierarchy_changed()

var _selected_ids: Array[String] = []
var _expanded_nodes: Dictionary = {}


func select_node(p_node_id: String, p_additive: bool = false) -> void:
	if not p_additive:
		_selected_ids.clear()
	if not _selected_ids.has(p_node_id):
		_selected_ids.append(p_node_id)
	selection_changed.emit(_selected_ids)


func deselect_node(p_node_id: String) -> void:
	_selected_ids.erase(p_node_id)
	selection_changed.emit(_selected_ids)


func clear_selection() -> void:
	_selected_ids.clear()
	selection_changed.emit(_selected_ids)


func get_selected_ids() -> Array[String]:
	return _selected_ids


func is_expanded(p_node_id: String) -> bool:
	return _expanded_nodes.get(p_node_id, true)


func set_expanded(p_node_id: String, p_expanded: bool) -> void:
	_expanded_nodes[p_node_id] = p_expanded
	hierarchy_changed.emit()


func build_tree_structure(p_rig: Dictionary) -> Array[Dictionary]:
	var tree: Array[Dictionary] = []
	var bones: Dictionary = p_rig.get("bones", {})
	var root_id: String = p_rig.get("root_bone_id", "")
	
	if root_id.is_empty():
		for b_id in bones:
			if str(bones[b_id].get("parent_id", "")).is_empty():
				tree.append(_build_node_recursive(b_id, p_rig))
	else:
		if bones.has(root_id):
			tree.append(_build_node_recursive(root_id, p_rig))
			
	return tree


func _build_node_recursive(p_bone_id: String, p_rig: Dictionary) -> Dictionary:
	var bones: Dictionary = p_rig.get("bones", {})
	var bone: Dictionary = bones.get(p_bone_id, {})
	
	var child_nodes: Array[Dictionary] = []
	var children: Array = bone.get("children", [])
	for c_id in children:
		if bones.has(c_id):
			child_nodes.append(_build_node_recursive(c_id, p_rig))
			
	var slots: Dictionary = p_rig.get("slots", {})
	for s_id in slots:
		if slots[s_id].get("bone_id", "") == p_bone_id:
			child_nodes.append({
				"id": s_id,
				"name": slots[s_id].get("name", s_id),
				"type": "slot",
				"children": []
			})
			
	return {
		"id": p_bone_id,
		"name": bone.get("name", p_bone_id),
		"type": "bone",
		"children": child_nodes
	}
