# BoneSchema — Data schema and serialization for individual skeletal bones
class_name BoneSchema
extends RefCounted


static func create_default_bone(p_id: String, p_name: String, p_parent_id: String = "") -> Dictionary:
	return {
		"id": p_id,
		"name": p_name,
		"parent_id": p_parent_id,
		"length": 50.0,
		"rest_angle": 0.0,
		"rest_position": Vector2.ZERO,
		"local_position": Vector2.ZERO,
		"local_rotation": 0.0,
		"local_scale": Vector2.ONE,
		"color": Color(0.2, 0.7, 1.0, 1.0),
		"group": "default",
		"locked": false,
		"visible": true,
		"inherit_position": true,
		"inherit_rotation": true,
		"inherit_scale": true,
		"children": []
	}


static func validate_bone(p_bone_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not p_bone_data.has("id") or str(p_bone_data.get("id", "")).is_empty():
		errors.append("Bone schema missing valid 'id'.")
	if not p_bone_data.has("name") or str(p_bone_data.get("name", "")).is_empty():
		errors.append("Bone schema missing valid 'name'.")
	if p_bone_data.get("length", 0.0) as float <= 0.0:
		errors.append("Bone length must be greater than zero.")
	return errors


static func to_json_dict(p_bone_data: Dictionary) -> Dictionary:
	return {
		"id": p_bone_data.get("id", ""),
		"name": p_bone_data.get("name", ""),
		"parent_id": p_bone_data.get("parent_id", ""),
		"length": p_bone_data.get("length", 50.0),
		"rest_angle": p_bone_data.get("rest_angle", 0.0),
		"rest_position": [p_bone_data.get("rest_position", Vector2.ZERO).x, p_bone_data.get("rest_position", Vector2.ZERO).y],
		"local_position": [p_bone_data.get("local_position", Vector2.ZERO).x, p_bone_data.get("local_position", Vector2.ZERO).y],
		"local_rotation": p_bone_data.get("local_rotation", 0.0),
		"local_scale": [p_bone_data.get("local_scale", Vector2.ONE).x, p_bone_data.get("local_scale", Vector2.ONE).y],
		"color": p_bone_data.get("color", Color.WHITE).to_html(),
		"group": p_bone_data.get("group", "default"),
		"locked": p_bone_data.get("locked", false),
		"visible": p_bone_data.get("visible", true),
		"inherit_position": p_bone_data.get("inherit_position", true),
		"inherit_rotation": p_bone_data.get("inherit_rotation", true),
		"inherit_scale": p_bone_data.get("inherit_scale", true)
	}


static func from_json_dict(p_dict: Dictionary) -> Dictionary:
	var pos_arr: Array = p_dict.get("local_position", [0.0, 0.0])
	var rest_pos_arr: Array = p_dict.get("rest_position", [0.0, 0.0])
	var scale_arr: Array = p_dict.get("local_scale", [1.0, 1.0])
	
	return {
		"id": p_dict.get("id", ""),
		"name": p_dict.get("name", ""),
		"parent_id": p_dict.get("parent_id", ""),
		"length": float(p_dict.get("length", 50.0)),
		"rest_angle": float(p_dict.get("rest_angle", 0.0)),
		"rest_position": Vector2(float(rest_pos_arr[0]), float(rest_pos_arr[1])),
		"local_position": Vector2(float(pos_arr[0]), float(pos_arr[1])),
		"local_rotation": float(p_dict.get("local_rotation", 0.0)),
		"local_scale": Vector2(float(scale_arr[0]), float(scale_arr[1])),
		"color": Color.html(p_dict.get("color", "33b2ff")),
		"group": p_dict.get("group", "default"),
		"locked": p_dict.get("locked", false),
		"visible": p_dict.get("visible", true),
		"inherit_position": p_dict.get("inherit_position", true),
		"inherit_rotation": p_dict.get("inherit_rotation", true),
		"inherit_scale": p_dict.get("inherit_scale", true),
		"children": []
	}
