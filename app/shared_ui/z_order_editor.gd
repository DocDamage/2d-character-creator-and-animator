# ZOrderEditor — Z-index and layer reordering utility
class_name ZOrderEditor
extends RefCounted


static func sort_by_z_index(p_objects: Array) -> Array:
	var sorted := p_objects.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("z_index", 0) < b.get("z_index", 0)
	)
	return sorted


static func move_to_front(p_objects: Array, p_target_id: String) -> Array:
	var updated := p_objects.duplicate(true)
	var max_z := -9999
	var target_index := -1
	
	for i in range(updated.size()):
		var z: int = updated[i].get("z_index", 0)
		if z > max_z:
			max_z = z
		if updated[i].get("id", "") == p_target_id:
			target_index = i
	
	if target_index != -1:
		updated[target_index]["z_index"] = max_z + 1
	
	return normalize_z_orders(updated)


static func move_to_back(p_objects: Array, p_target_id: String) -> Array:
	var updated := p_objects.duplicate(true)
	var min_z := 9999
	var target_index := -1
	
	for i in range(updated.size()):
		var z: int = updated[i].get("z_index", 0)
		if z < min_z:
			min_z = z
		if updated[i].get("id", "") == p_target_id:
			target_index = i
	
	if target_index != -1:
		updated[target_index]["z_index"] = min_z - 1
	
	return normalize_z_orders(updated)


static func move_up(p_objects: Array, p_target_id: String) -> Array:
	var sorted := sort_by_z_index(p_objects)
	for i in range(sorted.size() - 1):
		if sorted[i].get("id", "") == p_target_id:
			var temp_z: int = sorted[i].get("z_index", 0)
			sorted[i]["z_index"] = sorted[i + 1].get("z_index", 0)
			sorted[i + 1]["z_index"] = temp_z
			break
	return sorted


static func move_down(p_objects: Array, p_target_id: String) -> Array:
	var sorted := sort_by_z_index(p_objects)
	for i in range(1, sorted.size()):
		if sorted[i].get("id", "") == p_target_id:
			var temp_z: int = sorted[i].get("z_index", 0)
			sorted[i]["z_index"] = sorted[i - 1].get("z_index", 0)
			sorted[i - 1]["z_index"] = temp_z
			break
	return sorted


static func normalize_z_orders(p_objects: Array) -> Array:
	var sorted := sort_by_z_index(p_objects)
	for i in range(sorted.size()):
		sorted[i]["z_index"] = i
	return sorted
