# PoseApplier -- Captures and applies absolute named poses to the existing rig dictionary format.
class_name PoseApplier
extends RefCounted


static func capture_from_rig(pose: Variant, rig: Dictionary, bone_ids: Array = []) -> Dictionary:
	if pose == null:
		return _failure("A pose is required.")
	var bones: Dictionary = rig.get("bones", {})
	if bones.is_empty():
		return _failure("The rig has no bones to capture.")
	var requested_ids: Array = bone_ids if not bone_ids.is_empty() else bones.keys()
	var captured: Array[String] = []
	var missing: Array[String] = []
	for raw_id in requested_ids:
		var bone_id := str(raw_id)
		if not bones.has(bone_id):
			missing.append(bone_id)
			continue
		var bone: Dictionary = bones[bone_id]
		pose.set_bone_transform(bone_id, {
			"local_position": bone.get("local_position", Vector2.ZERO),
			"local_rotation": bone.get("local_rotation", 0.0),
			"local_scale": bone.get("local_scale", Vector2.ONE),
		})
		captured.append(bone_id)
	if captured.is_empty():
		return _failure("No requested bones exist on this rig.", missing)
	if str(pose.rig_profile_id).is_empty():
		pose.rig_profile_id = str(rig.get("id", ""))
	return {"success": true, "captured_bone_ids": captured, "missing_bone_ids": missing, "message": "Captured %d bone transforms." % captured.size()}


static func apply_to_rig(pose: Variant, rig: Dictionary) -> Dictionary:
	if pose == null:
		return _failure("A pose is required.")
	var expected_rig_id := str(pose.rig_profile_id)
	var actual_rig_id := str(rig.get("id", ""))
	if not expected_rig_id.is_empty() and expected_rig_id != actual_rig_id:
		return _failure("Pose targets rig '%s', not '%s'." % [expected_rig_id, actual_rig_id])
	var bones: Dictionary = rig.get("bones", {})
	var applied: Array[String] = []
	var missing: Array[String] = []
	for raw_id in pose.bone_transforms:
		var bone_id := str(raw_id)
		if not bones.has(bone_id):
			missing.append(bone_id)
			continue
		var transform: Dictionary = pose.get_bone_transform(bone_id)
		var bone: Dictionary = bones[bone_id]
		var position := _vector2(transform.get("position", [0.0, 0.0]), Vector2.ZERO)
		var rotation := float(transform.get("rotation", 0.0))
		var scale := _vector2(transform.get("scale", [1.0, 1.0]), Vector2.ONE)
		if int(pose.mode) == 1:
			bone["local_position"] = (bone.get("local_position", Vector2.ZERO) as Vector2) + position
			bone["local_rotation"] = float(bone.get("local_rotation", 0.0)) + rotation
			bone["local_scale"] = (bone.get("local_scale", Vector2.ONE) as Vector2) * scale
		else:
			bone["local_position"] = position
			bone["local_rotation"] = rotation
			bone["local_scale"] = scale
		applied.append(bone_id)
	if applied.is_empty():
		return _failure("None of the pose bones exist on this rig.", missing)
	var action := "Applied additive offsets to" if int(pose.mode) == 1 else "Applied"
	return {"success": true, "applied_bone_ids": applied, "missing_bone_ids": missing, "message": "%s %d bone transforms." % [action, applied.size()]}


static func _vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


static func _failure(message: String, missing: Array[String] = []) -> Dictionary:
	return {"success": false, "captured_bone_ids": [], "applied_bone_ids": [], "missing_bone_ids": missing, "message": message}
