# PoseMirrorModel -- Mirrors named pose transforms across explicit left/right bone pairs.
class_name PoseMirrorModel
extends RefCounted

const PoseDefinitionScript = preload("res://rigging/poses/pose_definition.gd")


static func mirror_pose(source_pose: Variant, target_id: String, target_name: String, bone_pairs: Dictionary) -> Dictionary:
	if source_pose == null:
		return _failure(["A source pose is required."])
	var source_errors: Array = source_pose.validate()
	if not source_errors.is_empty():
		return _failure(source_errors)
	var clean_target_id := target_id.strip_edges()
	if clean_target_id.is_empty():
		return _failure(["A mirrored pose ID is required."])
	if clean_target_id == str(source_pose.pose_id):
		return _failure(["The mirrored pose must use a new pose ID."])
	var map_errors := validate_bone_pairs(bone_pairs)
	if not map_errors.is_empty():
		return _failure(map_errors)
	var target := PoseDefinitionScript.new(clean_target_id, target_name.strip_edges() if not target_name.strip_edges().is_empty() else clean_target_id)
	target.rig_profile_id = str(source_pose.rig_profile_id)
	target.mode = source_pose.mode
	target.tags = source_pose.tags.duplicate()
	target.metadata = (source_pose.metadata as Dictionary).duplicate(true)
	target.metadata["mirrored_from_pose_id"] = str(source_pose.pose_id)
	target.metadata["mirror_axis"] = "vertical"
	var paired: Array[String] = []
	var unpaired: Array[String] = []
	for raw_source_id in source_pose.bone_transforms:
		var source_id := str(raw_source_id)
		var target_bone_id := str(bone_pairs.get(source_id, source_id))
		if bone_pairs.has(source_id):
			paired.append(source_id)
		else:
			unpaired.append(source_id)
		var transform: Dictionary = source_pose.get_bone_transform(source_id)
		transform["position"] = _mirrored_position(transform.get("position", [0.0, 0.0]))
		transform["rotation"] = -float(transform.get("rotation", 0.0))
		target.set_bone_transform(target_bone_id, transform)
	return {"success": true, "pose": target, "paired_bone_ids": paired, "unpaired_bone_ids": unpaired, "message": "Mirrored %d pose transforms." % target.bone_transforms.size()}


static func validate_bone_pairs(bone_pairs: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var destinations: Dictionary = {}
	for raw_source in bone_pairs:
		var source_id := str(raw_source).strip_edges()
		var target_id := str(bone_pairs[raw_source]).strip_edges()
		if source_id.is_empty() or target_id.is_empty():
			errors.append("Bone-pair IDs cannot be empty.")
			continue
		if source_id == target_id:
			errors.append("Bone '%s' cannot mirror to itself." % source_id)
		if str(bone_pairs.get(target_id, "")) != source_id:
			errors.append("Bone pair '%s' → '%s' must be bidirectional." % [source_id, target_id])
		if destinations.has(target_id) and str(destinations[target_id]) != source_id:
			errors.append("More than one bone maps to '%s'." % target_id)
		destinations[target_id] = source_id
	return errors


static func _mirrored_position(value: Variant) -> Array:
	if value is Vector2:
		return [-value.x, value.y]
	if value is Array and value.size() >= 2:
		return [-float(value[0]), float(value[1])]
	return [0.0, 0.0]


static func _failure(errors: Array) -> Dictionary:
	return {"success": false, "errors": errors, "message": "; ".join(errors)}
