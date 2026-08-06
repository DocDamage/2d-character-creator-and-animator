# SlotSchema — Data schema for attachment slots bound to skeletal bones
class_name SlotSchema
extends RefCounted


static func create_default_slot(p_id: String, p_name: String, p_bone_id: String) -> Dictionary:
	return {
		"id": p_id,
		"name": p_name,
		"bone_id": p_bone_id,
		"local_offset": Vector2.ZERO,
		"local_rotation": 0.0,
		"z_index": 0,
		"active_attachment_id": "",
		"allowed_asset_types": ["sprite", "mesh"],
		"visible": true,
		"attachments": {}
	}


static func validate_slot(p_slot_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not p_slot_data.has("id") or str(p_slot_data.get("id", "")).is_empty():
		errors.append("Slot schema missing valid 'id'.")
	if not p_slot_data.has("bone_id") or str(p_slot_data.get("bone_id", "")).is_empty():
		errors.append("Slot schema missing 'bone_id' binding.")
	return errors


static func to_json_dict(p_slot: Dictionary) -> Dictionary:
	return {
		"id": p_slot.get("id", ""),
		"name": p_slot.get("name", ""),
		"bone_id": p_slot.get("bone_id", ""),
		"local_offset": [p_slot.get("local_offset", Vector2.ZERO).x, p_slot.get("local_offset", Vector2.ZERO).y],
		"local_rotation": p_slot.get("local_rotation", 0.0),
		"z_index": p_slot.get("z_index", 0),
		"active_attachment_id": p_slot.get("active_attachment_id", ""),
		"allowed_asset_types": p_slot.get("allowed_asset_types", []),
		"visible": p_slot.get("visible", true),
		"attachments": p_slot.get("attachments", {})
	}


static func from_json_dict(p_dict: Dictionary) -> Dictionary:
	var offset_arr: Array = p_dict.get("local_offset", [0.0, 0.0])
	return {
		"id": p_dict.get("id", ""),
		"name": p_dict.get("name", ""),
		"bone_id": p_dict.get("bone_id", ""),
		"local_offset": Vector2(float(offset_arr[0]), float(offset_arr[1])),
		"local_rotation": float(p_dict.get("local_rotation", 0.0)),
		"z_index": int(p_dict.get("z_index", 0)),
		"active_attachment_id": p_dict.get("active_attachment_id", ""),
		"allowed_asset_types": p_dict.get("allowed_asset_types", ["sprite", "mesh"]),
		"visible": p_dict.get("visible", true),
		"attachments": p_dict.get("attachments", {})
	}
