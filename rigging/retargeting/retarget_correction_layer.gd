# RetargetCorrectionLayer -- Serializable additive corrections applied after a pose transfer.
class_name RetargetCorrectionLayer
extends RefCounted

var layer_id: String = ""
var target_profile_id: String = ""
var bone_offsets: Dictionary = {}


func _init(p_layer_id: String = "") -> void:
	layer_id = p_layer_id


func set_bone_offset(bone_id: String, offset: Dictionary) -> bool:
	var clean_id := bone_id.strip_edges()
	if clean_id.is_empty():
		return false
	bone_offsets[clean_id] = _normalise(offset)
	return true


func validate() -> Array[String]:
	var errors: Array[String] = []
	if layer_id.strip_edges().is_empty():
		errors.append("layer_id is required")
	if bone_offsets.is_empty():
		errors.append("a correction layer needs at least one bone offset")
	return errors


func apply_to_pose(pose: Variant) -> Dictionary:
	if pose == null:
		return {"success": false, "message": "A target pose is required."}
	var missing: Array[String] = []
	for bone_id in bone_offsets:
		if not pose.bone_transforms.has(bone_id):
			missing.append(str(bone_id))
			continue
		var transform: Dictionary = pose.get_bone_transform(str(bone_id))
		var offset: Dictionary = bone_offsets[bone_id]
		transform["position"] = _vec(transform.get("position", [0.0, 0.0]), Vector2.ZERO) + _vec(offset.get("position", [0.0, 0.0]), Vector2.ZERO)
		transform["rotation"] = float(transform.get("rotation", 0.0)) + float(offset.get("rotation", 0.0))
		transform["scale"] = _vec(transform.get("scale", [1.0, 1.0]), Vector2.ONE) * _vec(offset.get("scale", [1.0, 1.0]), Vector2.ONE)
		pose.set_bone_transform(str(bone_id), transform)
	return {"success": true, "missing_bones": missing, "message": "Applied %d correction offsets." % (bone_offsets.size() - missing.size())}


func to_dict() -> Dictionary:
	return {"layer_id": layer_id, "target_profile_id": target_profile_id, "bone_offsets": bone_offsets.duplicate(true)}


func _normalise(offset: Dictionary) -> Dictionary:
	return {"position": _vec(offset.get("position", [0.0, 0.0]), Vector2.ZERO), "rotation": float(offset.get("rotation", 0.0)), "scale": _vec(offset.get("scale", [1.0, 1.0]), Vector2.ONE)}


func _vec(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
