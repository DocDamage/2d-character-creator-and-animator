# ProportionCompensation -- Computes per-mapped-bone scale factors from source and target lengths.
class_name ProportionCompensation
extends RefCounted


static func compute(source_rig: Dictionary, target_rig: Dictionary, bone_map: Dictionary) -> Dictionary:
	var source_bones: Dictionary = source_rig.get("bones", {})
	var target_bones: Dictionary = target_rig.get("bones", {})
	if source_bones.is_empty() or target_bones.is_empty():
		return _failure("Both source and target rigs need bones.")
	if bone_map.is_empty():
		return _failure("At least one mapped bone is required.")
	var factors: Dictionary = {}
	var missing: Array[String] = []
	for raw_source_id in bone_map:
		var source_id := str(raw_source_id)
		var target_id := str(bone_map[raw_source_id])
		if not source_bones.has(source_id) or not target_bones.has(target_id):
			missing.append("%s → %s" % [source_id, target_id])
			continue
		var source_length := float((source_bones[source_id] as Dictionary).get("length", 0.0))
		var target_length := float((target_bones[target_id] as Dictionary).get("length", 0.0))
		if source_length <= 0.0 or target_length <= 0.0:
			return _failure("Mapped bones must have positive lengths.", missing)
		factors[target_id] = target_length / source_length
	if factors.is_empty():
		return _failure("No mapped bones exist on both rigs.", missing)
	return {"success": true, "factors": factors, "missing_mappings": missing, "message": "Calculated %d proportion factors." % factors.size()}


static func scale_position(position: Vector2, factor: float) -> Vector2:
	return position * factor


static func _failure(message: String, missing: Array[String] = []) -> Dictionary:
	return {"success": false, "factors": {}, "missing_mappings": missing, "message": message}
