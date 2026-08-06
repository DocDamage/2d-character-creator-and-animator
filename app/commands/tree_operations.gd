# TreeOperations — Copy, paste, duplicate, and recursive subtree cloning logic
class_name TreeOperations
extends RefCounted

static var _clipboard: Dictionary = {}


static func copy_object(p_object_data: Dictionary) -> void:
	if not p_object_data.is_empty():
		_clipboard = p_object_data.duplicate(true)


static func has_clipboard_content() -> bool:
	return not _clipboard.is_empty()


static func paste_object(p_id_prefix: String = "obj", p_offset: Vector2 = Vector2(20, 20)) -> Dictionary:
	if _clipboard.is_empty():
		return {}
	return duplicate_object(_clipboard, p_id_prefix, p_offset)


static func duplicate_object(p_object_data: Dictionary, p_id_prefix: String = "obj", p_offset: Vector2 = Vector2(20, 20)) -> Dictionary:
	if p_object_data.is_empty():
		return {}
	
	var clone := clone_subtree(p_object_data, p_id_prefix)
	if clone.has("position"):
		clone["position"] = Vector2(clone["position"]) + p_offset
	elif clone.has("pos_x") and clone.has("pos_y"):
		clone["pos_x"] = clone["pos_x"] + p_offset.x
		clone["pos_y"] = clone["pos_y"] + p_offset.y
	
	return clone


static func clone_subtree(p_root_data: Dictionary, p_id_prefix: String = "obj") -> Dictionary:
	if p_root_data.is_empty():
		return {}
	
	var id_map: Dictionary = {}
	return _recursive_clone(p_root_data, id_map, p_id_prefix)


static func _recursive_clone(p_node: Dictionary, p_id_map: Dictionary, p_prefix: String) -> Dictionary:
	var copy := p_node.duplicate(true)
	var old_id: String = copy.get("id", copy.get("bone_id", copy.get("slot_id", "")))
	
	if not old_id.is_empty():
		var new_id: String = IDService.generate_id(p_prefix)
		p_id_map[old_id] = new_id
		if copy.has("id"):
			copy["id"] = new_id
		if copy.has("bone_id"):
			copy["bone_id"] = new_id
		if copy.has("slot_id"):
			copy["slot_id"] = new_id
	
	if copy.has("parent_id") and p_id_map.has(copy["parent_id"]):
		copy["parent_id"] = p_id_map[copy["parent_id"]]
	
	if copy.has("children") and copy["children"] is Array:
		var new_children: Array = []
		for child in copy["children"]:
			if child is Dictionary:
				new_children.append(_recursive_clone(child, p_id_map, p_prefix))
		copy["children"] = new_children
	
	return copy
