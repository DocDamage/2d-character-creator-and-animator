# RetargetPoseTransfer -- Creates a target-rig pose preview from a mapped source pose.
class_name RetargetPoseTransfer
extends RefCounted

const PoseDefinitionScript = preload("res://rigging/poses/pose_definition.gd")


static func preview(source_pose: Variant, target_profile: Variant, bone_map: Dictionary, factors: Dictionary, result_id: String, result_name: String) -> Dictionary:
	if source_pose == null or target_profile == null:
		return _failure("A source pose and target profile are required.")
	if not source_pose.validate().is_empty() or not target_profile.validate().is_empty():
		return _failure("Source pose and target profile must validate.")
	var clean_id := result_id.strip_edges()
	if clean_id.is_empty():
		return _failure("A target preview pose ID is required.")
	var target_pose := PoseDefinitionScript.new(clean_id, result_name.strip_edges() if not result_name.strip_edges().is_empty() else clean_id)
	target_pose.rig_profile_id = str(target_profile.rig_id)
	target_pose.mode = source_pose.mode
	target_pose.tags = source_pose.tags.duplicate()
	target_pose.metadata = (source_pose.metadata as Dictionary).duplicate(true)
	target_pose.metadata["retargeted_from_pose_id"] = str(source_pose.pose_id)
	target_pose.metadata["target_profile_id"] = str(target_profile.profile_id)
	var unmapped: Array[String] = []
	for raw_source_id in source_pose.bone_transforms:
		var source_id := str(raw_source_id)
		if not bone_map.has(source_id):
			unmapped.append(source_id)
			continue
		var target_id := str(bone_map[source_id])
		var transform: Dictionary = source_pose.get_bone_transform(source_id)
		transform["position"] = _position(transform.get("position", [0.0, 0.0])) * float(factors.get(target_id, 1.0))
		target_pose.set_bone_transform(target_id, transform)
	if target_pose.bone_transforms.is_empty():
		return _failure("No source pose bones have a target mapping.", unmapped)
	return {"success": true, "pose": target_pose, "unmapped_source_bones": unmapped, "message": "Previewed %d retargeted transforms." % target_pose.bone_transforms.size()}


static func _position(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func _failure(message: String, unmapped: Array[String] = []) -> Dictionary:
	return {"success": false, "unmapped_source_bones": unmapped, "message": message}
