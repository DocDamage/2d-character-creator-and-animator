# RetargetBoneMap -- Builds an explicit source-bone to target-bone map from semantic profiles.
class_name RetargetBoneMap
extends RefCounted


static func build(source_profile: Variant, target_profile: Variant) -> Dictionary:
	if source_profile == null or target_profile == null:
		return _failure("Both source and target skeleton profiles are required.")
	var source_errors: Array = source_profile.validate()
	var target_errors: Array = target_profile.validate()
	if not source_errors.is_empty() or not target_errors.is_empty():
		return _failure("Profiles must validate before mapping.", source_errors + target_errors)
	var source_roles: Array = source_profile.bone_roles.keys()
	source_roles.sort()
	var bone_map: Dictionary = {}
	var matched_roles: Array[String] = []
	var missing_target_roles: Array[String] = []
	for raw_role in source_roles:
		var role := str(raw_role)
		var source_bone_id := str(source_profile.bone_roles[role])
		var target_bone_id := str(target_profile.bone_roles.get(role, ""))
		if target_bone_id.is_empty():
			missing_target_roles.append(role)
			continue
		bone_map[source_bone_id] = target_bone_id
		matched_roles.append(role)
	var missing_source_roles: Array[String] = []
	for raw_role in target_profile.bone_roles:
		var role := str(raw_role)
		if not source_profile.bone_roles.has(role):
			missing_source_roles.append(role)
	missing_source_roles.sort()
	var root_source_id := str(source_profile.bone_roles.get("root", ""))
	var root_target_id := str(target_profile.bone_roles.get("root", ""))
	if root_source_id.is_empty() or root_target_id.is_empty() or not bone_map.has(root_source_id):
		return _failure("Both profiles must map their root role.", ["root is missing from the compatible role map"])
	return {
		"success": true,
		"complete": missing_target_roles.is_empty(),
		"source_profile_id": str(source_profile.profile_id),
		"target_profile_id": str(target_profile.profile_id),
		"bone_map": bone_map,
		"matched_roles": matched_roles,
		"missing_target_roles": missing_target_roles,
		"missing_source_roles": missing_source_roles,
		"message": "%d semantic bones mapped; %d source roles are unsupported." % [matched_roles.size(), missing_target_roles.size()],
	}


static func validate_map(bone_map: Dictionary, source_bone_ids: Array, target_bone_ids: Array) -> Array[String]:
	var errors: Array[String] = []
	var mapped_targets: Dictionary = {}
	for raw_source_id in bone_map:
		var source_id := str(raw_source_id)
		var target_id := str(bone_map[raw_source_id])
		if source_id not in source_bone_ids or target_id not in target_bone_ids:
			errors.append("Mapping '%s' → '%s' references an unavailable bone." % [source_id, target_id])
		if mapped_targets.has(target_id):
			errors.append("Target bone '%s' is mapped more than once." % target_id)
		mapped_targets[target_id] = source_id
	return errors


static func _failure(message: String, errors: Array = []) -> Dictionary:
	return {"success": false, "complete": false, "bone_map": {}, "matched_roles": [], "missing_target_roles": [], "missing_source_roles": [], "errors": errors, "message": message}
