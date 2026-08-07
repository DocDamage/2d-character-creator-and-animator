# LpcProjectProfile -- Versioned LPC-specific project metadata inside a .chrproj manifest.
class_name LpcProjectProfile
extends RefCounted

const PROFILE_SCHEMA_VERSION := "1.3.0"
const METADATA_KEY := "lpc_profile"
const NameSequenceScript = preload("res://lpc/project/lpc_name_sequence.gd")


static func create(options: Dictionary) -> Dictionary:
	var label := str(options.get("label", "LPC Character")).strip_edges()
	if label.is_empty(): label = "LPC Character"
	var index := int(options.get("display_name_index", 0))
	if index <= 0: index = NameSequenceScript.reserve_next()
	var lock: Dictionary = (options.get("source_lock", {}) as Dictionary).duplicate(true)
	var project_uuid := str(options.get("project_uuid", "")).strip_edges()
	if project_uuid.is_empty(): project_uuid = _uuid()
	return {
		"profile_schema_version": PROFILE_SCHEMA_VERSION,
		"project_uuid": project_uuid,
		"display_name_index": index,
		"label": label,
		"source_lock": {"signature": str(lock.get("source_lock_signature", lock.get("signature", ""))), "upstream_commit_sha": str(lock.get("upstream_commit_sha", "")), "catalog_adapter_version": str(lock.get("catalog_adapter_version", "")), "catalog_signature": str(options.get("catalog_signature", ""))},
		"source_library_root": str(options.get("source_library_root", "")),
		"policy": {"profile_id": str(options.get("policy_id", "full_source")), "policy_version": str(options.get("policy_version", "1.0.0")), "custom": (options.get("custom_policy", {}) as Dictionary).duplicate(true)},
		"body_family_id": str(options.get("body_family_id", "")),
		"direction_set": {"id": "lpc_cardinal_4", "directions": ["up", "left", "down", "right"]},
		"selections": [], "layer_groups": {}, "selected_license_options": {}, "palette_state": {},
		"source_frame_references": [], "derivative_references": [], "cels": [], "cel_timeline": {"fps": 10.0, "onion_before": 1, "onion_after": 1}, "pixel_editor_state": {"zoom": 8, "active_tool": "pencil"}, "clips": [], "hybrid_animation_state": {"selected_clip_id": "", "active_direction": "down"}, "frame_meshes": [], "deformation_workspace_state": {"active_mesh_id": "", "preview_mode": "interactive"},
		"rig_adapters": [], "rig_overrides": {}, "bake_caches": [], "validation_reports": [],
		"export_profiles": [], "acceptance_records": [], "credit_manifest_inputs": [],
		"workspace_state": {"workspace_id": "creator", "playhead": 0.0},
	}


static func validate(profile: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["profile_schema_version", "project_uuid", "display_name_index", "label", "source_lock", "policy", "body_family_id", "direction_set", "workspace_state"]:
		if not profile.has(key): errors.append("LPC profile is missing '%s'." % key)
	if str(profile.get("project_uuid", "")).strip_edges().is_empty(): errors.append("LPC profile has no durable project UUID.")
	if int(profile.get("display_name_index", 0)) <= 0: errors.append("LPC profile display-name index must be positive.")
	if str(profile.get("label", "")).strip_edges().is_empty(): errors.append("LPC profile label cannot be empty.")
	var lock: Dictionary = profile.get("source_lock", {})
	if str(lock.get("signature", "")).is_empty() or str(lock.get("upstream_commit_sha", "")).is_empty(): errors.append("LPC profile must bind a source lock signature and commit.")
	var policy: Dictionary = profile.get("policy", {})
	if str(policy.get("profile_id", "")).is_empty(): errors.append("LPC profile must select a policy profile.")
	if str(profile.get("body_family_id", "")).is_empty(): errors.append("LPC profile must select a body family.")
	var directions: Array = (profile.get("direction_set", {}) as Dictionary).get("directions", [])
	if directions.is_empty(): errors.append("LPC profile must record a direction set.")
	for key in ["selections", "derivative_references", "cels", "clips", "frame_meshes"]:
		if not profile.get(key, []) is Array: errors.append("LPC profile field '%s' must be an array." % key)
	if not profile.get("cel_timeline", {}) is Dictionary: errors.append("LPC profile cel_timeline must be an object.")
	if not profile.get("pixel_editor_state", {}) is Dictionary: errors.append("LPC profile pixel_editor_state must be an object.")
	if not profile.get("hybrid_animation_state", {}) is Dictionary: errors.append("LPC profile hybrid_animation_state must be an object.")
	if not profile.get("deformation_workspace_state", {}) is Dictionary: errors.append("LPC profile deformation_workspace_state must be an object.")
	return errors


static func is_lpc_manifest(manifest: Dictionary) -> bool:
	return manifest.get("metadata", {}) is Dictionary and (manifest.get("metadata", {}) as Dictionary).has(METADATA_KEY)


static func from_manifest(manifest: Dictionary) -> Dictionary:
	if not is_lpc_manifest(manifest): return {}
	return ((manifest.get("metadata", {}) as Dictionary).get(METADATA_KEY, {}) as Dictionary).duplicate(true)


static func apply_to_manifest(manifest: Dictionary, profile: Dictionary) -> Dictionary:
	var result := manifest.duplicate(true)
	var metadata: Dictionary = (result.get("metadata", {}) as Dictionary).duplicate(true)
	metadata[METADATA_KEY] = profile.duplicate(true)
	result["metadata"] = metadata
	return result


static func migrate(profile: Dictionary) -> Dictionary:
	var result := profile.duplicate(true)
	var from_version := str(result.get("profile_schema_version", "0.1.0"))
	if from_version == PROFILE_SCHEMA_VERSION: return {"success": true, "changed": false, "profile": result, "errors": []}
	var changed := false
	if from_version == "0.1.0":
		if not result.has("policy"):
			result["policy"] = {"profile_id": str(result.get("policy_profile", "full_source")), "policy_version": "1.0.0", "custom": {}}
		result.erase("policy_profile")
		if not result.has("workspace_state"):
			result["workspace_state"] = {"workspace_id": str(result.get("workspace", "creator")), "playhead": float(result.get("playhead", 0.0))}
		result.erase("workspace"); result.erase("playhead")
		from_version = "1.0.0"; changed = true
	if from_version == "1.0.0":
		if not result.has("cels"): result["cels"] = []
		if not result.has("cel_timeline"): result["cel_timeline"] = {"fps": 10.0, "onion_before": 1, "onion_after": 1}
		if not result.has("pixel_editor_state"): result["pixel_editor_state"] = {"zoom": 8, "active_tool": "pencil"}
		from_version = "1.1.0"; changed = true
	if from_version == "1.1.0":
		if not result.has("hybrid_animation_state"): result["hybrid_animation_state"] = {"selected_clip_id": "", "active_direction": "down"}
		from_version = "1.2.0"; changed = true
	if from_version == "1.2.0":
		if not result.has("deformation_workspace_state"): result["deformation_workspace_state"] = {"active_mesh_id": "", "preview_mode": "interactive"}
		result["profile_schema_version"] = PROFILE_SCHEMA_VERSION; changed = true
		return {"success": true, "changed": changed, "profile": result, "errors": []}
	return {"success": false, "changed": false, "profile": result, "errors": ["Unsupported LPC profile schema %s." % from_version]}


static func _uuid() -> String:
	if IDService != null and IDService.has_method("generate_uuid_v4"): return IDService.generate_uuid_v4()
	var time := Time.get_ticks_usec()
	return "%08x-%04x-4000-8000-%012x" % [time & 0xffffffff, (time >> 32) & 0xffff, time & 0xffffffffffff]
