# PoseBlendModel -- Deterministically interpolates two compatible absolute named poses.
class_name PoseBlendModel
extends RefCounted

const PoseDefinitionScript = preload("res://rigging/poses/pose_definition.gd")


static func blend_poses(from_pose: Variant, to_pose: Variant, result_id: String, result_name: String, weight: float) -> Dictionary:
	if from_pose == null or to_pose == null:
		return _failure(["Both source poses are required."])
	if int(from_pose.mode) != 0 or int(to_pose.mode) != 0:
		return _failure(["Only absolute poses can use absolute pose blending."])
	if not is_finite(weight) or weight < 0.0 or weight > 1.0:
		return _failure(["Blend weight must be between 0 and 1."])
	var from_rig := str(from_pose.rig_profile_id)
	var to_rig := str(to_pose.rig_profile_id)
	if not from_rig.is_empty() and not to_rig.is_empty() and from_rig != to_rig:
		return _failure(["Both poses must target the same rig."])
	var compatibility_errors := _compatibility_errors(from_pose, to_pose)
	if not compatibility_errors.is_empty():
		return _failure(compatibility_errors)
	var clean_id := result_id.strip_edges()
	if clean_id.is_empty():
		return _failure(["A blended pose ID is required."])
	var result := PoseDefinitionScript.new(clean_id, result_name.strip_edges() if not result_name.strip_edges().is_empty() else clean_id)
	result.rig_profile_id = from_rig if not from_rig.is_empty() else to_rig
	result.tags = _merged_tags(from_pose.tags, to_pose.tags)
	result.metadata = {
		"blend_from_pose_id": str(from_pose.pose_id),
		"blend_to_pose_id": str(to_pose.pose_id),
		"blend_weight": weight,
	}
	for raw_bone_id in from_pose.bone_transforms:
		var bone_id := str(raw_bone_id)
		result.set_bone_transform(bone_id, _blend_transform(from_pose.get_bone_transform(bone_id), to_pose.get_bone_transform(bone_id), weight))
	return {"success": true, "pose": result, "message": "Blended %d transforms at %.0f%%." % [result.bone_transforms.size(), weight * 100.0]}


static func _compatibility_errors(from_pose: Variant, to_pose: Variant) -> Array[String]:
	var errors: Array[String] = []
	var from_ids: Array = from_pose.bone_transforms.keys()
	var to_ids: Array = to_pose.bone_transforms.keys()
	from_ids.sort()
	to_ids.sort()
	if from_ids != to_ids:
		errors.append("Both poses must contain the same bone IDs.")
	return errors


static func _blend_transform(from_transform: Dictionary, to_transform: Dictionary, weight: float) -> Dictionary:
	var from_position := _vector2(from_transform.get("position", [0.0, 0.0]), Vector2.ZERO)
	var to_position := _vector2(to_transform.get("position", [0.0, 0.0]), Vector2.ZERO)
	var from_scale := _vector2(from_transform.get("scale", [1.0, 1.0]), Vector2.ONE)
	var to_scale := _vector2(to_transform.get("scale", [1.0, 1.0]), Vector2.ONE)
	return {
		"position": from_position.lerp(to_position, weight),
		"rotation": lerp_angle(float(from_transform.get("rotation", 0.0)), float(to_transform.get("rotation", 0.0)), weight),
		"scale": from_scale.lerp(to_scale, weight),
	}


static func _vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


static func _merged_tags(first: Array, second: Array) -> Array:
	var tags := first.duplicate()
	for tag in second:
		if tag not in tags:
			tags.append(tag)
	return tags


static func _failure(errors: Array) -> Dictionary:
	return {"success": false, "errors": errors, "message": "; ".join(errors)}
